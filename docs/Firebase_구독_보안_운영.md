# Firebase · 구독 · 보안 구현 및 운영 기록

이 문서는 너두! 도레미의 Firebase 보안 규칙과 인앱 구독 검증을 어떻게 설계하고,
실제 Firebase 프로젝트에 어떻게 배포·확인했는지 기록한다. 저장소의 코드만 보고
"배포되어 있을 것"이라고 가정하지 않도록 운영 확인 절차도 함께 적었다.

- Firebase 프로젝트: `doremi-496ea` (`88743352145`)
- Firestore: Standard / Native, `asia-northeast3`
- Cloud Functions: 2세대, `asia-northeast3`
- iOS 번들 ID: `com.cheesetabby.doremi`
- 구독 상품 ID: `doremi_premium_monthly`
- 기준 작업일: 2026-08-24~25

> 시크릿의 이름과 등록 절차만 문서화한다. Key ID, Issuer ID, `.p8` 원문 같은
> 실제 자격 증명은 저장소와 문서에 남기지 않는다.

## 1. 최종 구조

앱은 스토어의 구매 성공 이벤트만으로 프리미엄 권한을 켜지 않는다. 로그인된 앱이
영수증을 callable 함수로 보내고, 서버가 Apple 또는 Google에 다시 확인한 결과만
Firestore에 기록한다.

```text
App Store / Google Play
          │ 구매 결과와 영수증
          ▼
Flutter SubscriptionController
          │ verifyPurchase (Firebase callable + Firebase Auth)
          ▼
Cloud Functions ────────▶ App Store Server API / Google Play API
          │ 검증된 결과만 Admin SDK로 기록
          ▼
Firestore subscriptions/{uid}
          │ 본인 읽기 전용 실시간 스트림
          ▼
Flutter Entitlement → 1·2·3단계 접근 판정
```

신뢰 경계는 다음과 같다.

- 클라이언트가 보내는 `platform`, `productId`, 영수증은 모두 신뢰하지 않는다.
- 스토어 서버의 응답과 Firebase 인증 UID만 권한 판정에 사용한다.
- 클라이언트는 `subscriptions` 및 `purchaseReceipts`에 쓸 수 없다.
- Cloud Functions의 Admin SDK만 검증 결과를 쓴다.

## 2. Firestore 보안 규칙

규칙 파일은 저장소 루트의 `firestore.rules`다.

### `guardians/{guardianId}`

- 인증 UID와 문서 ID가 같은 사용자만 읽기·생성·수정·삭제할 수 있다.
- 허용 필드를 `keys().hasOnly(...)`로 제한한다.
- 로그인 제공자, 이메일, 온보딩 단계, 아이 나이·닉네임, 감각 설정 등 주요 필드의
  타입과 범위를 규칙에서도 확인한다.
- 앱의 Dart 유효성 검사만 믿지 않으므로 변조된 클라이언트가 임의 필드를 저장할 수 없다.

### `subscriptions/{uid}`

- 본인 문서만 읽을 수 있다.
- 클라이언트 쓰기는 조건 없이 거부한다(`allow write: if false`).
- 서버는 Admin SDK를 사용하므로 규칙을 우회해 검증된 결과를 기록한다.

### `purchaseReceipts/{fingerprint}`

- 클라이언트 읽기·쓰기를 모두 거부한다.
- 영수증 원문은 저장하지 않고 소유권 키의 SHA-256 지문만 문서 ID로 쓴다.

### 나머지 경로

포괄적인 허용 규칙을 두지 않았다. 명시되지 않은 모든 컬렉션은 기본 거부된다.
규칙에서 다른 문서를 `get()` 또는 `exists()`로 조회하지 않으므로 규칙 평가를 위한
추가 Firestore 읽기도 발생하지 않는다.

## 3. 규칙은 반드시 실제 Firebase에 배포한다

로컬 파일 수정만으로는 운영 데이터가 보호되지 않는다. 변경할 때마다 아래 명령으로
컴파일과 릴리스를 완료해야 한다.

```bash
firebase deploy --only firestore:rules \
  --project doremi-496ea \
  --non-interactive
```

성공 로그에는 다음 두 문장이 모두 있어야 한다.

```text
rules file firestore.rules compiled successfully
released rules firestore.rules to cloud.firestore
```

2026-08-24 작업에서는 강화된 규칙을 실제 `cloud.firestore`에 릴리스했다. 배포 후
비인증 REST 요청으로 `guardians`, `subscriptions`, `purchaseReceipts`, 임의 컬렉션을
조회했으며 모두 HTTP `403`으로 차단되는 것을 확인했다.

## 4. 구매 검증 함수

구현은 `functions/src/index.ts`의 `verifyPurchase`다.

1. Firebase Auth UID가 없으면 `UNAUTHENTICATED`로 거부한다.
2. 플랫폼은 `ios` 또는 `android`만 허용한다.
3. 상품 ID는 `doremi_premium_monthly` 하나만 허용한다.
4. 영수증은 빈 문자열을 거부하고 최대 64KiB로 제한한다.
5. iOS는 App Store Server API, Android는 Google Play Developer API에 재조회한다.
6. 스토어에 구매자 식별자가 있으면 UID에서 만든 계정 토큰과 대조한다.
7. 동일 구매를 다른 Firebase 계정이 재사용하지 못하도록 소유권을 잠근다.
8. 검증된 상태만 `subscriptions/{uid}`에 기록하고 앱에 반환한다.

비로그인 상태로 실제 배포 URL을 호출했을 때 HTTP `401`과
`로그인이 필요합니다.` 응답이 반환되는 것도 확인했다.

## 5. 플랫폼별 검증

### iOS

- Flutter `in_app_purchase_storekit`의 StoreKit 2 경로가 제공하는 JWS를 서버로 보낸다.
- 클라이언트 JWS에서는 조회에 필요한 `transactionId`만 꺼낸다.
- 운영 App Store Server API에서 거래를 찾지 못하면 Sandbox API로 재시도한다.
- Apple 서버가 돌려준 최신 거래에서 번들 ID와 상품 ID를 다시 확인한다.
- App Store의 `originalTransactionId`를 소유권 키로 사용한다. 갱신 JWS가 달라져도
  같은 원구독을 다른 계정이 재사용할 수 없다.

App Store Server API 자격 증명은 다음 Secret Manager 항목으로만 관리한다.

```text
APP_STORE_KEY_ID
APP_STORE_ISSUER_ID
APP_STORE_PRIVATE_KEY
```

`.p8` 파일이나 본문을 Git, 환경 설정 파일, 문서에 커밋하면 안 된다.

### Android

- `purchases.subscriptionsv2.get`으로 구매 토큰을 조회한다.
- 함수 런타임의 기본 서비스 계정 자격 증명을 사용하며 별도 JSON 키를 저장하지 않는다.
- Play Console에서 해당 서비스 계정에 필요한 구독 조회 권한을 부여해야 한다.
- `obfuscatedExternalAccountId`가 있으면 Firebase UID에서 계산한 토큰과 대조한다.

## 6. 계정과 영수증 재사용 방지

앱과 서버는 동일한 `accountTokenFor(uid)` 알고리즘을 구현한다.

```text
sha256("doremi:<firebase uid>")
→ 앞 16바이트
→ RFC 4122 variant의 UUID 형태
```

- iOS: `appAccountToken`
- Android: `obfuscatedAccountId`

이 값은 UID의 원문을 스토어에 보내지 않으면서 구매 계정을 안정적으로 연결한다.
Dart와 TypeScript 구현이 달라지면 정상 구매도 거절되므로 두 구현의 일치 테스트를
유지해야 한다.

구매자 토큰이 없는 과거 구매도 대비한다. iOS는 `originalTransactionId`, Android는
구매 토큰을 플랫폼 이름과 함께 해시해 `purchaseReceipts`에 최초 UID를 트랜잭션으로
기록한다. 이미 다른 UID가 소유한 키라면 `PERMISSION_DENIED`로 거부한다.

## 7. 구독 상태와 만료 처리

접근을 허용하는 상태는 `active`와 `grace`뿐이다. `onHold`, `paused`, `expired`는
콘텐츠를 잠근다. 무료 이용 기간이 끝났고 활성 구독도 없으면 홈의 1·2·3단계가
모두 구독 다이얼로그로 연결된다.

만료 누락을 막기 위해 두 겹으로 검사한다.

### 앱의 즉시 검사

`Entitlement.grantsAccess`는 상태만 보지 않고 `expiresAt`도 확인한다. Firestore 문서가
아직 `active`더라도 만료 시각이 지났으면 앱에서 즉시 접근을 거부한다.

### 서버의 정기 만료 처리

`expireSubscriptions`는 Cloud Scheduler가 30분마다 실행하는 2세대 함수다.

- 활성/유예 구독을 기록할 때 `nextCheckAt = expiresAt`을 함께 저장한다.
- `nextCheckAt <= 현재 시각` 문서를 최대 400개씩 읽는다.
- `status: expired`, `active: false`로 바꾸고 `nextCheckAt`을 제거한다.
- 처리할 문서가 더 있으면 같은 실행 안에서 다음 배치를 계속 처리한다.

이 구조는 앱이 다시 실행되지 않아도 만료된 권한이 계속 열려 있는 문제를 막는다.
갱신된 사용자가 앱을 실행하면 StoreKit/Play 복원 결과를 다시 서버에 검증해 새 만료
시각을 기록한다.

> App Store Server Notifications V2와 Google RTDN은 아직 구현하지 않았다.
> 따라서 환불·갱신을 완전한 실시간으로 반영하는 구조는 아니며, 현재는 앱 실행 시
> 재검증과 최대 30분 단위의 만료 차단을 조합한다.

## 8. 배포된 Functions

2026-08-24 기준 두 함수가 실제 Firebase에 배포되어 있다.

| 함수 | 트리거 | 리전 | 역할 |
| --- | --- | --- | --- |
| `verifyPurchase` | callable v2 | `asia-northeast3` | 로그인 사용자 영수증 검증 및 권한 기록 |
| `expireSubscriptions` | scheduled v2 | `asia-northeast3` | 30분 주기 만료 권한 차단 |

배포 및 확인 명령:

```bash
cd functions
npm ci
npm run typecheck
npm run build
cd ..

firebase deploy \
  --only functions:verifyPurchase,functions:expireSubscriptions \
  --project doremi-496ea \
  --non-interactive

firebase functions:list --project doremi-496ea
```

Artifact Registry에는 7일이 지난 함수 컨테이너 이미지를 자동 삭제하는 정책을
설정해 불필요한 저장 비용 누적을 막았다.

## 9. 비용 영향

Blaze는 기본 월정액이 아니라 사용량 기반이다. 현재 추가된 정기 작업은 하루 48회,
월 약 1,440회 실행된다.

- Cloud Scheduler 작업 1개: 결제 계정당 무료 작업 3개 이내
- 함수 호출 약 1,440회/월: 월 무료 호출량보다 매우 작음
- 빈 만료 쿼리: 실행당 최소 1읽기, 하루 약 48읽기
- Firestore 무료 할당량: 하루 50,000읽기 / 20,000쓰기
- Secret Manager 활성 버전 3개: 결제 계정당 무료 6개 이내

초기 서비스 규모에서는 추가 비용이 사실상 0원에 가깝다. 사용자가 늘면 구매·복원
검증 호출과 Firestore 읽기·쓰기가 함께 증가하므로 Cloud Billing 예산 알림을 설정한다.

## 10. 확인한 테스트와 운영 점검

- 구독 관련 Flutter 테스트 통과
- TypeScript `typecheck` 및 빌드 통과
- `verifyPurchase` 비로그인 호출 HTTP `401`
- 비인증 Firestore 주요 경로 HTTP `403`
- 실제 Firestore 규칙 컴파일 및 릴리스 성공
- 두 Functions의 `ACTIVE` 상태 확인
- 앱과 서버의 상품 ID, 리전, iOS 번들 ID 일치 확인
- App Store Secret 3개가 함수의 secret environment variable로 연결된 것 확인

실제 결제 종단 검증은 시뮬레이터의 로컬 StoreKit 설정이 아니라 실제 기기의
Sandbox 계정 또는 TestFlight에서 수행한다. 로컬 StoreKit 거래는 Apple 서버에
존재하지 않으므로 App Store Server API에서 조회할 수 없다.

## 11. 남은 보안 작업

### App Check

callable 함수는 Firebase Auth를 강제하지만 App Check는 아직 강제하지 않는다.
App Attest/DeviceCheck 및 Android Play Integrity를 Firebase 콘솔에 등록한 뒤 앱에서
토큰 발급을 확인하고 `enforceAppCheck: true`를 켜야 한다. 제공자 등록 전에 먼저
강제하면 정상 앱의 결제 검증까지 모두 차단되므로 순서를 지킨다.

### 런타임과 의존성

현재 함수 런타임은 Node.js 20이며 지원 종료 일정 전에 Node.js 22 이상으로 옮겨야
한다. `firebase-functions`, `firebase-admin`, Google API 의존성도 함께 올리고 테스트한
뒤 배포한다. `npm audit`에서 확인된 중간 등급 전이 의존성은 이 업그레이드 때 함께
정리한다.

### 스토어 서버 알림

환불·갱신·결제 실패를 더 빠르게 반영하려면 다음을 추가한다.

- Apple: App Store Server Notifications V2 HTTPS 수신 함수
- Google: Real-time Developer Notifications Pub/Sub 수신 함수
- 수신 JWS/메시지 검증 후 기존 `writeEntitlement` 경로 재사용

## 12. 변경 시 체크리스트

- [ ] 앱과 서버의 상품 ID가 같은가?
- [ ] 앱과 Functions 리전이 `asia-northeast3`으로 같은가?
- [ ] Dart/TypeScript `accountTokenFor` 결과가 같은가?
- [ ] 클라이언트가 `subscriptions` 또는 `purchaseReceipts`에 쓸 수 없는가?
- [ ] 규칙을 로컬에서만 수정하지 않고 실제 Firebase에 배포했는가?
- [ ] 시크릿 값이 Git, 로그, 문서, 빌드 설정에 노출되지 않았는가?
- [ ] 구독 상태와 만료 시각을 함께 검사하는가?
- [ ] Functions typecheck/build와 구독 테스트가 통과하는가?
- [ ] Sandbox/TestFlight 실제 기기에서 구매와 복원을 확인했는가?
- [ ] 배포 후 `firebase functions:list`와 함수 로그를 확인했는가?
