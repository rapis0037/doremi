# 구독 영수증 검증 (Cloud Functions)

앱은 더 이상 스스로 유료 잠금을 열지 않는다. 결제·복원으로 받은 영수증을
`verifyPurchase` 로 보내면, 이 함수가 Google Play / App Store 에 다시 물어
확인한 결과를 `subscriptions/{uid}` 에 적는다. 앱은 그 문서만 읽는다.
Firestore 규칙에서 이 컬렉션은 **읽기 전용**이라 앱을 고쳐도 열 수 없다.

## 배포 전에 준비할 것

### 1. Firebase

- 요금제를 **Blaze** 로 올린다 (함수가 외부 네트워크를 호출한다).
- 배포 지역은 `asia-northeast3`(서울). 앱의
  `lib/subscription/subscription_backend.dart` 의 `_region` 과 같아야 한다.

### 2. Google Play

1. Google Cloud 콘솔에서 **Google Play Android Developer API** 를 켠다.
2. Play Console → 사용자 및 권한 → 함수 런타임 서비스 계정
   (`doremi-496ea@appspot.gserviceaccount.com`)을 초대하고
   **재무 데이터 보기** 권한을 준다. 반영까지 최대 24시간 걸린다.
3. 별도 키 파일은 필요 없다. 함수가 런타임 기본 자격 증명을 쓴다.

### 3. App Store

App Store Connect → 사용자 및 액세스 → 통합 → **In-App Purchase 키** 발급.
받은 값을 시크릿으로 넣는다.

```bash
firebase functions:secrets:set APP_STORE_KEY_ID
firebase functions:secrets:set APP_STORE_ISSUER_ID
firebase functions:secrets:set APP_STORE_PRIVATE_KEY
```

`APP_STORE_PRIVATE_KEY` 는 `.p8` 파일 내용을 그대로(`-----BEGIN PRIVATE KEY-----`
줄 포함) 붙여 넣는다. 파일은 저장소에 두지 않는다.

## 배포

```bash
cd functions && npm install && npm run deploy
```

규칙도 함께 올려야 한다.

```bash
firebase deploy --only firestore:rules
```

## 확인 방법

- Android: Play Console 라이선스 테스터 계정으로 구독 → Firestore
  `subscriptions/{uid}` 에 `status: active` 와 `expiresAt` 이 찍히는지 본다.
- iOS: 샌드박스 테스터로 구독. 운영 API 에서 못 찾으면 샌드박스로 자동 재시도한다.
- 해지: 스토어에서 해지한 뒤 앱을 다시 켜면 복원 결과가 서버로 다시 전달되어
  만료로 바뀐다.

## 아직 하지 않은 것

**스토어 서버 알림(RTDN / App Store Server Notifications V2)** 은 붙이지
않았다. 지금은 앱이 켜질 때마다 복원 결과를 서버에 확인시키는 방식이라,
해지·환불이 반영되는 시점이 "다음 실행"이다. 실시간으로 당기려면
Play 는 Pub/Sub 트리거 함수, Apple 은 알림 수신용 HTTPS 함수를 추가하고
같은 `writeEntitlement` 를 호출하면 된다.

## 설계 메모

- `accountTokenFor(uid)` 는 uid 로부터 항상 같은 UUID 를 만든다. 앱이 결제할 때
  이 값을 스토어에 심고(Android `obfuscatedAccountId`, iOS `appAccountToken`),
  서버가 같은 계산을 다시 해 영수증의 주인을 확인한다. 별도 저장이 없다.
  Dart 쪽 구현은 `lib/subscription/entitlement.dart` 에 있고, 두 구현이
  어긋나면 `test/subscription_server_verification_test.dart` 가 깨진다.
- 구매자 식별자가 없는 예전 영수증은 `purchaseReceipts/{지문}` 문서로 최초
  사용자에게 묶어, 같은 영수증을 여러 계정이 돌려쓰지 못하게 한다.
- iOS 는 클라이언트가 보낸 JWS 의 서명을 직접 검증하지 않는다. 거기서 꺼내는
  값은 `transactionId` 뿐이고, 판정은 Apple 서버에 다시 물어 본 응답으로 한다.
