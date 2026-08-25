import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

import { verifyAppStorePurchase } from "./app_store";
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
const MAX_RECEIPT_LENGTH = 64 * 1024;

/**
 * 앱이 결제·복원으로 받은 영수증을 스토어에 다시 물어 확인하고,
 * 결과를 subscriptions/{uid} 에 기록한다. 앱은 이 문서만 읽는다.
 */
export const verifyPurchase = onCall(
  {
    region: REGION,
    secrets: [appStoreKeyId, appStoreIssuerId, appStorePrivateKey],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

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

    await claimReceipt(uid, receipt, entitlement);
    await writeEntitlement(uid, entitlement);

    return {
      status: entitlement.status,
      expiresAt: entitlement.expiresAt,
      productId: entitlement.productId,
    };
  }
);

/**
 * 같은 영수증을 여러 계정이 돌려쓰지 못하도록 최초 사용자에게 묶어 둔다.
 * 예전 구매처럼 구매자 식별자가 없는 영수증을 막는 최후의 방어선이다.
 */
async function claimReceipt(
  uid: string,
  receipt: string,
  entitlement: Entitlement
): Promise<void> {
  // App Store의 originalTransactionId는 갱신되어도 유지된다. 제출된 JWS
  // 원문만 해시하면 같은 구독의 다른 표현을 별개 구매로 오인할 수 있다.
  const ownershipKey =
    entitlement.platform === "ios" && entitlement.latestOrderId !== null
      ? `ios:${entitlement.latestOrderId}`
      : `${entitlement.platform}:${receipt}`;
  const reference = getFirestore()
    .collection("purchaseReceipts")
    .doc(receiptFingerprint(ownershipKey));

  await getFirestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const owner = snapshot.get("uid") as string | undefined;
    if (owner !== undefined && owner !== uid) {
      throw new HttpsError("permission-denied", "이미 다른 계정이 사용한 구매입니다.");
    }
    if (owner === undefined) {
      transaction.set(reference, {
        uid,
        platform: entitlement.platform,
        originalTransactionId: entitlement.latestOrderId,
        claimedAt: FieldValue.serverTimestamp(),
      });
    }
  });
}

async function writeEntitlement(
  uid: string,
  entitlement: Entitlement
): Promise<void> {
  const nextCheckAt =
    grantsAccess(entitlement.status) && entitlement.expiresAt !== null
      ? entitlement.expiresAt
      : FieldValue.delete();
  await getFirestore()
    .collection("subscriptions")
    .doc(uid)
    .set(
      {
        status: entitlement.status,
        active: grantsAccess(entitlement.status),
        productId: entitlement.productId,
        platform: entitlement.platform,
        expiresAt: entitlement.expiresAt,
        nextCheckAt,
        latestOrderId: entitlement.latestOrderId,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
}

/**
 * 앱이 실행되지 않아도 만료 시각이 지난 권한을 닫는다. 갱신된 사용자는 앱의
 * StoreKit 복원 결과가 다시 검증되면서 새 만료 시각으로 갱신된다.
 */
export const expireSubscriptions = onSchedule(
  {
    region: REGION,
    schedule: "every 30 minutes",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const firestore = getFirestore();
    const now = Date.now();

    while (true) {
      const snapshot = await firestore
        .collection("subscriptions")
        .where("nextCheckAt", "<=", now)
        .limit(400)
        .get();
      if (snapshot.empty) return;

      const batch = firestore.batch();
      for (const document of snapshot.docs) {
        batch.set(
          document.ref,
          {
            status: "expired",
            active: false,
            nextCheckAt: FieldValue.delete(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
      await batch.commit();
    }
  }
);
