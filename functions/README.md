# 구독 영수증 검증 (Cloud Functions)

앱은 더 이상 스스로 유료 잠금을 열지 않는다. 결제·복원으로 받은 영수증을
`verifyPurchase` 로 보내면, 이 함수가 Google Play / App Store 에 다시 물어
확인한 결과를 `subscriptions/{uid}` 에 적는다. 앱은 그 문서만 읽는다.
Firestore 규칙에서 이 컬렉션은 **읽기 전용**이라 앱을 고쳐도 열 수 없다.
검증에 성공한 구매는 `subscriptionVerifications/{uid}` 에 서버 전용 식별자를
남기고, `reconcileSubscriptions`가 앱 실행 여부와 관계없이 주기적으로 재확인한다.
Firebase Auth 계정이 삭제되면 `cleanupDeletedUserData`가 보호자·구독·영수증
소유권·재검증 문서를 함께 삭제한다.

## 배포 전에 준비할 것

### 1. Firebase

- 요금제를 **Blaze** 로 올린다 (함수가 외부 네트워크를 호출한다).
- 배포 지역은 `asia-northeast3`(서울). 앱의
  `lib/subscription/subscription_backend.dart` 의 `_region` 과 같아야 한다.
- Firebase Console → App Check에서 Android는 Play Integrity, iOS는 App Attest를
  등록한다. 디버그 빌드는 실행 로그에 나온 디버그 토큰도 등록해야 한다.
- `verifyPurchase`는 App Check를 강제하므로 앱 등록 전에 함수를 먼저 배포하면
  결제 검증이 거부된다.

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
- 해지·환불: 정기 재검증 뒤 `subscriptions/{uid}`가 잠김 상태로 바뀌는지 본다.
- 만료: 서버 상태가 아직 `active`여도 앱은 `expiresAt`이 지나면 즉시 잠가야 한다.
- 호출 제한: 같은 UID로 10분 안에 11번째 검증을 요청하면
  `resource-exhausted`가 반환되는지 확인한다.

Firestore 규칙 테스트는 Java가 설치된 환경에서 실행한다.

```bash
firebase emulators:exec --only firestore "npm --prefix functions run test:rules"
```

## 아직 하지 않은 것

**스토어 서버 알림(RTDN / App Store Server Notifications V2)** 은 붙이지
않았다. 현재는 매시간 실행되는 정기 작업이 각 구독을 6시간 간격으로 확인하므로
해지·환불 반영에 지연이 있을 수 있다. 실시간으로 당기려면
Play 는 Pub/Sub 트리거 함수, Apple 은 알림 수신용 HTTPS 함수를 추가하고
같은 `writeEntitlement` 를 호출하면 된다.

## 설계 메모

- `accountTokenFor(uid)` 는 uid 로부터 항상 같은 UUID 를 만든다. 앱이 결제할 때
  이 값을 스토어에 심고(Android `obfuscatedAccountId`, iOS `appAccountToken`),
  서버가 같은 계산을 다시 해 영수증의 주인을 확인한다. 별도 저장이 없다.
  Dart 쪽 구현은 `lib/subscription/entitlement.dart` 에 있고, 두 구현이
  어긋나면 `test/subscription_server_verification_test.dart` 가 깨진다.
- 구매자 식별자가 없는 예전 영수증은 검증된 Play 구매 토큰 또는 Apple
  `originalTransactionId`의 지문을 최초 사용자에게 묶어 여러 계정이 돌려쓰지
  못하게 한다.
- iOS 는 클라이언트가 보낸 JWS 의 서명을 직접 검증하지 않는다. 거기서 꺼내는
  값은 `transactionId` 뿐이고, 판정은 Apple 서버에 다시 물어 본 응답으로 한다.
- 결제 거래는 서버 검증 호출이 성공한 뒤에만 스토어에 완료 처리한다. 일시적인
  검증 실패에서는 완료하지 않아 다음 거래 전달 때 다시 시도할 수 있다.
- `verifyPurchase`는 UID당 10분 10회, 영수증 64KB로 제한한다.
