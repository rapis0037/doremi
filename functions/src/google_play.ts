import { google } from "googleapis";
import {
  Entitlement,
  EntitlementStatus,
  PREMIUM_MONTHLY_PRODUCT_ID,
} from "./entitlement";

const ANDROID_PACKAGE_NAME = "com.cheesetabby.doremi";

/**
 * 서비스 계정 키 파일을 두지 않고 함수 런타임의 기본 자격 증명을 쓴다.
 * Play Console 에서 이 프로젝트의 서비스 계정(<projectId>@appspot.gserviceaccount.com)
 * 을 사용자로 초대하고 "재무 데이터 보기" 권한을 주면 된다.
 */
const auth = new google.auth.GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/androidpublisher"],
});

const publisher = google.androidpublisher({ version: "v3", auth });

/** Play 의 subscriptionState 를 앱이 이해하는 상태로 옮긴다. */
function toStatus(state: string | null | undefined): EntitlementStatus {
  switch (state) {
    case "SUBSCRIPTION_STATE_ACTIVE":
    // 해지를 눌렀어도 이미 결제한 기간이 끝날 때까지는 이용할 수 있다.
    case "SUBSCRIPTION_STATE_CANCELED":
      return "active";
    case "SUBSCRIPTION_STATE_IN_GRACE_PERIOD":
      return "grace";
    case "SUBSCRIPTION_STATE_ON_HOLD":
      return "onHold";
    case "SUBSCRIPTION_STATE_PAUSED":
      return "paused";
    default:
      return "expired";
  }
}

export async function verifyGooglePlayPurchase(
  purchaseToken: string
): Promise<Entitlement> {
  const response = await publisher.purchases.subscriptionsv2.get({
    packageName: ANDROID_PACKAGE_NAME,
    token: purchaseToken,
  });
  const purchase = response.data;

  const lineItem = (purchase.lineItems ?? []).find(
    (item) => item.productId === PREMIUM_MONTHLY_PRODUCT_ID
  );
  if (!lineItem) {
    throw new Error("구독 상품이 영수증에 없습니다.");
  }

  const expiry = lineItem.expiryTime ? Date.parse(lineItem.expiryTime) : NaN;
  let status = toStatus(purchase.subscriptionState);
  // 상태가 활성이어도 만료 시각이 지났으면 만료로 본다.
  if (Number.isFinite(expiry) && expiry <= Date.now() && status === "active") {
    status = "expired";
  }

  return {
    status,
    productId: PREMIUM_MONTHLY_PRODUCT_ID,
    platform: "android",
    expiresAt: Number.isFinite(expiry) ? expiry : null,
    latestOrderId: purchase.latestOrderId ?? null,
    accountToken:
      purchase.externalAccountIdentifiers?.obfuscatedExternalAccountId ?? null,
  };
}
