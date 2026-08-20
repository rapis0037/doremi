import * as crypto from "crypto";

/** 앱에서 파는 유일한 구독 상품. 다른 상품 ID 는 받지 않는다. */
export const PREMIUM_MONTHLY_PRODUCT_ID = "doremi_premium_monthly";

export type EntitlementStatus =
  | "active"
  | "grace"
  | "onHold"
  | "paused"
  | "expired";

export type StorePlatform = "android" | "ios";

export interface Entitlement {
  status: EntitlementStatus;
  productId: string;
  platform: StorePlatform;
  /** epoch milliseconds. 스토어가 알려 주지 않으면 null. */
  expiresAt: number | null;
  latestOrderId: string | null;
  /**
   * 스토어 기록에 남아 있는 구매자 식별자.
   * Android 는 obfuscatedExternalAccountId, iOS 는 appAccountToken.
   * 예전 구매에는 없을 수 있어 null 을 허용한다.
   */
  accountToken: string | null;
}

export function grantsAccess(status: EntitlementStatus): boolean {
  return status === "active" || status === "grace";
}

/**
 * uid 로부터 항상 같은 UUID 를 만든다. 앱이 결제할 때 이 값을 스토어에
 * 심어 두고(Android obfuscatedAccountId / iOS appAccountToken), 서버는 같은
 * 계산을 다시 해 영수증의 주인이 맞는지 확인한다. 따로 저장할 필요가 없다.
 *
 * 앱의 lib/subscription/entitlement.dart 와 계산이 반드시 같아야 한다.
 */
export function accountTokenFor(uid: string): string {
  const digest = crypto
    .createHash("sha256")
    .update(`doremi:${uid}`)
    .digest();
  const bytes = Buffer.from(digest.subarray(0, 16));
  // RFC 4122 버전 5(이름 기반), variant 10xx 로 맞춘다.
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20, 32),
  ].join("-");
}

/** 영수증 원문을 그대로 저장하지 않기 위한 소유권 잠금 키. */
export function receiptFingerprint(receipt: string): string {
  return crypto.createHash("sha256").update(receipt).digest("hex");
}
