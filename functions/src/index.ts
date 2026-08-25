import { initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import * as functionsV1 from "firebase-functions/v1";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

import {
  AppStoreCredentials,
  verifyAppStorePurchase,
  verifyAppStoreTransaction,
} from "./app_store";
import {
  Entitlement,
  PREMIUM_MONTHLY_PRODUCT_ID,
  accountTokenFor,
  grantsAccess,
  receiptFingerprint,
} from "./entitlement";
import { verifyGooglePlayPurchase } from "./google_play";

initializeApp();

const appStoreKeyId = defineSecret("APP_STORE_KEY_ID");
const appStoreIssuerId = defineSecret("APP_STORE_ISSUER_ID");
const appStorePrivateKey = defineSecret("APP_STORE_PRIVATE_KEY");

const REGION = "asia-northeast3";
const VERIFICATION_COLLECTION = "subscriptionVerifications";
const RATE_LIMIT_COLLECTION = "functionRateLimits";
const RECHECK_INTERVAL_MS = 6 * 60 * 60 * 1000;
const RETRY_INTERVAL_MS = 60 * 60 * 1000;
const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000;
const RATE_LIMIT_MAX_CALLS = 10;
const MAX_RECEIPT_LENGTH = 64 * 1024;

/**
 * 앱이 결제·복원으로 받은 영수증을 스토어에 다시 물어 확인하고,
 * 결과를 subscriptions/{uid} 에 기록한다. 앱은 이 문서만 읽는다.
 */
export const verifyPurchase = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
    secrets: [appStoreKeyId, appStoreIssuerId, appStorePrivateKey],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    await enforceRateLimit(uid);

    const platform = request.data?.platform;
    const productId = request.data?.productId;
    const receipt = request.data?.receipt;
    if (platform !== "android" && platform !== "ios") {
      throw new HttpsError("invalid-argument", "지원하지 않는 스토어입니다.");
    }
    if (productId !== PREMIUM_MONTHLY_PRODUCT_ID) {
      throw new HttpsError("invalid-argument", "알 수 없는 상품입니다.");
    }
    if (
      typeof receipt !== "string" ||
      receipt.length === 0 ||
      receipt.length > MAX_RECEIPT_LENGTH
    ) {
      throw new HttpsError("invalid-argument", "영수증 형식이 올바르지 않습니다.");
    }

    let entitlement: Entitlement;
    try {
      entitlement =
        platform === "android"
          ? await verifyGooglePlayPurchase(receipt)
          : await verifyAppStorePurchase(receipt, {
              keyId: appStoreKeyId.value(),
              issuerId: appStoreIssuerId.value(),
              privateKey: appStorePrivateKey.value(),
            });
    } catch (error) {
      logger.error("영수증 검증 실패", { uid, platform, error });
      throw new HttpsError("internal", "영수증을 확인하지 못했습니다.");
    }

    // 스토어 기록에 구매자 식별자가 있으면 이 계정 것인지 확인한다.
    const expectedToken = accountTokenFor(uid);
    if (
      entitlement.accountToken !== null &&
      entitlement.accountToken !== expectedToken
    ) {
      logger.warn("다른 계정의 영수증 제출", { uid, platform });
      throw new HttpsError("permission-denied", "다른 계정의 구매입니다.");
    }

    const verificationReference =
      platform === "android" ? receipt : entitlement.latestOrderId;
    if (!verificationReference) {
      throw new HttpsError("internal", "구매 식별자를 확인하지 못했습니다.");
    }

    await claimReceipt(uid, verificationReference, receipt, platform);
    await writeVerificationReference(uid, platform, verificationReference);
    await writeEntitlement(uid, entitlement);

    return {
      status: entitlement.status,
      expiresAt: entitlement.expiresAt,
      productId: entitlement.productId,
    };
  }
);

/** 앱이 실행되지 않아도 만료·환불 상태를 주기적으로 다시 확인한다. */
export const reconcileSubscriptions = onSchedule(
  {
    region: REGION,
    schedule: "every 1 hours",
    timeoutSeconds: 540,
    secrets: [appStoreKeyId, appStoreIssuerId, appStorePrivateKey],
  },
  async () => {
    const due = await getFirestore()
      .collection(VERIFICATION_COLLECTION)
      .where("nextCheckAt", "<=", Timestamp.now())
      .orderBy("nextCheckAt")
      .limit(50)
      .get();
    const credentials: AppStoreCredentials = {
      keyId: appStoreKeyId.value(),
      issuerId: appStoreIssuerId.value(),
      privateKey: appStorePrivateKey.value(),
    };

    for (let offset = 0; offset < due.docs.length; offset += 10) {
      await Promise.all(
        due.docs
          .slice(offset, offset + 10)
          .map((snapshot) =>
            reconcileSubscription(snapshot.id, snapshot.data(), credentials)
          )
      );
    }
  }
);

/** 인증 계정이 삭제되면 UID와 연결된 개인정보를 서버에서도 제거한다. */
export const cleanupDeletedUserData = functionsV1
  .runWith({ failurePolicy: true })
  .region(REGION)
  .auth.user()
  .onDelete(async (user) => {
    const firestore = getFirestore();
    const receipts = await firestore
      .collection("purchaseReceipts")
      .where("uid", "==", user.uid)
      .get();
    const references = [
      firestore.collection("guardians").doc(user.uid),
      firestore.collection("subscriptions").doc(user.uid),
      firestore.collection(VERIFICATION_COLLECTION).doc(user.uid),
      firestore.collection(RATE_LIMIT_COLLECTION).doc(user.uid),
      ...receipts.docs.map((snapshot) => snapshot.ref),
    ];

    for (let offset = 0; offset < references.length; offset += 500) {
      const batch = firestore.batch();
      for (const reference of references.slice(offset, offset + 500)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
  });

async function enforceRateLimit(uid: string): Promise<void> {
  const reference = getFirestore().collection(RATE_LIMIT_COLLECTION).doc(uid);
  await getFirestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const now = Date.now();
    const windowStartedAt = snapshot.get("windowStartedAt");
    const startedAt =
      windowStartedAt instanceof Timestamp ? windowStartedAt.toMillis() : 0;
    const count = snapshot.get("count");
    if (now - startedAt >= RATE_LIMIT_WINDOW_MS) {
      transaction.set(reference, {
        windowStartedAt: Timestamp.fromMillis(now),
        count: 1,
      });
      return;
    }
    if (typeof count === "number" && count >= RATE_LIMIT_MAX_CALLS) {
      throw new HttpsError(
        "resource-exhausted",
        "결제 확인 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요."
      );
    }
    transaction.update(reference, {
      count: (typeof count === "number" ? count : 0) + 1,
    });
  });
}

/**
 * 같은 영수증을 여러 계정이 돌려쓰지 못하도록 최초 사용자에게 묶어 둔다.
 * 예전 구매처럼 구매자 식별자가 없는 영수증을 막는 최후의 방어선이다.
 */
async function claimReceipt(
  uid: string,
  ownershipReference: string,
  submittedReceipt: string,
  platform: string
): Promise<void> {
  const firestore = getFirestore();
  const reference = firestore
    .collection("purchaseReceipts")
    .doc(receiptFingerprint(`${platform}:${ownershipReference}`));
  // 기존 배포본이 원문 영수증 해시로 잠근 기록도 함께 확인한다.
  const legacyReference = firestore
    .collection("purchaseReceipts")
    .doc(receiptFingerprint(submittedReceipt));

  await firestore.runTransaction(async (transaction) => {
    const [snapshot, legacySnapshot] = await transaction.getAll(
      reference,
      legacyReference
    );
    const owner = snapshot.get("uid") as string | undefined;
    const legacyOwner = legacySnapshot.get("uid") as string | undefined;
    if (
      (owner !== undefined && owner !== uid) ||
      (legacyOwner !== undefined && legacyOwner !== uid)
    ) {
      throw new HttpsError("permission-denied", "이미 다른 계정이 사용한 구매입니다.");
    }
    if (owner === undefined) {
      transaction.set(reference, {
        uid,
        platform,
        claimedAt: FieldValue.serverTimestamp(),
      });
    }
  });
}

async function writeVerificationReference(
  uid: string,
  platform: string,
  reference: string
): Promise<void> {
  await getFirestore()
    .collection(VERIFICATION_COLLECTION)
    .doc(uid)
    .set(
      {
        platform,
        reference,
        nextCheckAt: Timestamp.now(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
}

async function reconcileSubscription(
  uid: string,
  data: FirebaseFirestore.DocumentData,
  credentials: AppStoreCredentials
): Promise<void> {
  const platform = data["platform"];
  const reference = data["reference"];
  const verification = getFirestore()
    .collection(VERIFICATION_COLLECTION)
    .doc(uid);
  if (
    (platform !== "android" && platform !== "ios") ||
    typeof reference !== "string" ||
    reference.length === 0
  ) {
    logger.error("구독 재검증 기록이 올바르지 않음", { uid });
    await verification.update({
      nextCheckAt: Timestamp.fromMillis(Date.now() + RETRY_INTERVAL_MS),
    });
    return;
  }

  try {
    const entitlement =
      platform === "android"
        ? await verifyGooglePlayPurchase(reference)
        : await verifyAppStoreTransaction(reference, credentials);
    await writeEntitlement(uid, entitlement);
    await verification.update({
      nextCheckAt: Timestamp.fromMillis(Date.now() + RECHECK_INTERVAL_MS),
      checkedAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    logger.warn("구독 정기 재검증 실패", { uid, platform, error });
    await verification.update({
      nextCheckAt: Timestamp.fromMillis(Date.now() + RETRY_INTERVAL_MS),
    });
  }
}

async function writeEntitlement(
  uid: string,
  entitlement: Entitlement
): Promise<void> {
  await getFirestore()
    .collection("subscriptions")
    .doc(uid)
    .set(
      {
        status: entitlement.status,
        active: grantsAccess(entitlement.status, entitlement.expiresAt),
        productId: entitlement.productId,
        platform: entitlement.platform,
        expiresAt: entitlement.expiresAt,
        // 기존 만료 전용 스케줄러가 사용하던 필드를 제거한다.
        nextCheckAt: FieldValue.delete(),
        latestOrderId: entitlement.latestOrderId,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
}
