import * as jwt from "jsonwebtoken";
import {
  Entitlement,
  EntitlementStatus,
  PREMIUM_MONTHLY_PRODUCT_ID,
} from "./entitlement";

const IOS_BUNDLE_ID = "com.cheesetabby.doremi";
const PRODUCTION_HOST = "https://api.storekit.itunes.apple.com";
const SANDBOX_HOST = "https://api.storekit-sandbox.itunes.apple.com";

export interface AppStoreCredentials {
  /** App Store Connect 에서 받은 In-App Purchase 키(.p8) 본문. */
  privateKey: string;
  keyId: string;
  issuerId: string;
}

/** App Store Server API 호출용 토큰. 유효기간은 최대 1시간이다. */
function createBearerToken(credentials: AppStoreCredentials): string {
  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    {
      iss: credentials.issuerId,
      iat: now,
      exp: now + 15 * 60,
      aud: "appstoreconnect-v1",
      bid: IOS_BUNDLE_ID,
    },
    credentials.privateKey,
    {
      algorithm: "ES256",
      header: { alg: "ES256", kid: credentials.keyId, typ: "JWT" },
    }
  );
}

/**
 * JWS 의 payload 만 꺼낸다. 서명은 검증하지 않는다 — 여기서 얻은 값은
 * transactionId 뿐이고, 실제 판정은 Apple 서버에 다시 물어 본 응답으로 한다.
 */
function decodeJwsPayload(jws: string): Record<string, unknown> {
  const segments = jws.split(".");
  if (segments.length !== 3) throw new Error("영수증 형식이 올바르지 않습니다.");
  const payload = Buffer.from(segments[1], "base64url").toString("utf8");
  return JSON.parse(payload) as Record<string, unknown>;
}

/** 1=활성, 2=만료, 3=결제 재시도, 4=결제 유예, 5=취소(환불) */
function toStatus(status: number | undefined): EntitlementStatus {
  switch (status) {
    case 1:
      return "active";
    case 4:
      return "grace";
    case 3:
      return "onHold";
    default:
      return "expired";
  }
}

async function fetchSubscriptionStatuses(
  host: string,
  transactionId: string,
  token: string
): Promise<{ ok: boolean; notFound: boolean; body: any }> {
  const response = await fetch(
    `${host}/inApps/v1/subscriptions/${encodeURIComponent(transactionId)}`,
    { headers: { Authorization: `Bearer ${token}` } }
  );
  if (response.status === 404) {
    return { ok: false, notFound: true, body: null };
  }
  if (!response.ok) {
    throw new Error(
      `App Store 조회 실패 (${response.status}): ${await response.text()}`
    );
  }
  return { ok: true, notFound: false, body: await response.json() };
}

export async function verifyAppStorePurchase(
  signedTransaction: string,
  credentials: AppStoreCredentials
): Promise<Entitlement> {
  const claimed = decodeJwsPayload(signedTransaction);
  const transactionId = claimed["transactionId"];
  if (typeof transactionId !== "string") {
    throw new Error("영수증에 거래 번호가 없습니다.");
  }

  const token = createBearerToken(credentials);
  // 운영에서 못 찾으면 샌드박스(테스터 계정) 거래일 수 있다.
  let result = await fetchSubscriptionStatuses(
    PRODUCTION_HOST,
    transactionId,
    token
  );
  if (result.notFound) {
    result = await fetchSubscriptionStatuses(
      SANDBOX_HOST,
      transactionId,
      token
    );
  }
  if (!result.ok) {
    throw new Error("App Store 에서 구매를 찾지 못했습니다.");
  }

  const group = (result.body?.data ?? [])[0];
  const latest = (group?.lastTransactions ?? [])[0];
  if (!latest) {
    throw new Error("App Store 에서 구독 상태를 받지 못했습니다.");
  }

  const info = decodeJwsPayload(latest.signedTransactionInfo as string);
  if (info["bundleId"] !== IOS_BUNDLE_ID) {
    throw new Error("다른 앱의 영수증입니다.");
  }
  if (info["productId"] !== PREMIUM_MONTHLY_PRODUCT_ID) {
    throw new Error("구독 상품이 영수증에 없습니다.");
  }

  const expiresAt =
    typeof info["expiresDate"] === "number" ? (info["expiresDate"] as number) : null;
  let status = toStatus(latest.status as number | undefined);
  if (expiresAt !== null && expiresAt <= Date.now() && status === "active") {
    status = "expired";
  }

  return {
    status,
    productId: PREMIUM_MONTHLY_PRODUCT_ID,
    platform: "ios",
    expiresAt,
    latestOrderId:
      typeof info["originalTransactionId"] === "string"
        ? (info["originalTransactionId"] as string)
        : null,
    accountToken:
      typeof info["appAccountToken"] === "string"
        ? (info["appAccountToken"] as string)
        : null,
  };
}
