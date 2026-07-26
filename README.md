# 너두! 도레미!

악기 없이, 부모 없이, 혼자서도 음악을 체험하는 4~8세 유아·아동용 음악 입문 앱.

도·레·미·파·솔·라·시 8음을 **색깔과 도형에 매핑**해서, 글을 못 읽는 아이도 터치로 음을
탐색할 수 있다. 색과 도형을 함께 쓰는 이중 인코딩이라 색맹 아동도 구분할 수 있다.

## 학습 단계

| 단계 | 이름 | 내용 |
|---|---|---|
| 1단계 | 톡톡! 한 음 익히기 | 건반에서 음을 골라 소리와 악보 위치를 익힌다 |
| 2단계 | AR 톡톡! 한 음 만나기 | 카메라 화면 위에서 같은 학습을 진행한다 |
| 3단계 | 음정 챌린지! | 드래그로 음표를 배치하는 첫 악보 경험 |

기획 의도와 화면 설계는 [docs/너두도레미_기획서.md](docs/너두도레미_기획서.md)에 있다.

## 실행

Dart SDK `^3.12.0` (`pubspec.yaml`). Flutter 3.44.8 에서 빌드·테스트를 확인했다.
현재 **Android·iOS만** 설정되어 있다 (기획서에는 Web 이 있지만 `web/` 은 아직 만들지 않았다).

```bash
flutter pub get
```

```bash
flutter run
```

정적 분석과 테스트:

```bash
flutter analyze && flutter test
```

## 프로젝트 구조

```
lib/
├── main.dart          # 앱 진입점, 루트 페이지 전환
├── core/              # 상수, 모델 (NoteSpec, RootPage 등)
├── audio/             # 음 재생 (tone_player)
├── pages/             # 화면 단위 (home, lesson_flow, ar_mode, stage_three)
├── painters/          # CustomPainter — 화면 전체를 그리는 주체
├── drawing/           # 오선지·건반·도형·효과 그리기 함수
├── layout/            # 건반 좌표 계산
└── widgets/           # 배경, 헤더, 다이얼로그 등 재사용 위젯
```

화면은 대부분 `CustomPainter` 로 그린다. 좌표는 `core/constants.dart` 의 `sceneSize`
기준 논리 좌표이며, `SceneView` 가 실제 화면 크기로 변환한다.

## 플랫폼 설정 시 주의사항

카메라 권한 설정에는 **지우면 조용히 깨지는** 부분이 있다. 손대기 전에 아래를 확인할 것.

### iOS — Info.plist 키가 권한 기능을 켠다

`ios/Runner/Info.plist` 의 `NSCameraUsageDescription` 은 두 가지 역할을 한다.

1. 없으면 카메라를 열 때 **앱이 강제 종료된다** (iOS 요구사항)
2. `permission_handler` 의 `PERMISSION_CAMERA` 컴파일 매크로를 켠다

2번이 덜 알려져 있다. Swift Package Manager 로 통합할 때 이 매크로의 **기본값은 `0`**
이고, 앱 Info.plist 에 해당 키가 있을 때만 `1` 이 된다
(`permission_handler_apple/Package.swift` 의 `enabled()`). 즉 이 키를 지우면 권한 상태
조회가 조용히 동작하지 않는다.

이 값은 패키지 해석 시점에 평가되어 **DerivedData 에 캐시된다.** 권한 관련 plist 키를
바꿨다면 한 번 정리해야 반영된다.

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

의도한 컴파일 결과는 카메라만 켜지고 마이크는 꺼진 상태다
(`PERMISSION_CAMERA=1`, `PERMISSION_MICROPHONE=0`).

### Android — 권한 제거 지시를 지우면 되살아난다

`android/app/src/main/AndroidManifest.xml` 의 `tools:node="remove"` 와
`tools:replace` 는 장식이 아니다.

- camera 플러그인이 `RECORD_AUDIO`, `WRITE_EXTERNAL_STORAGE` 를 병합해 온다. 이 앱은
  프리뷰만 쓰고 녹화·저장은 하지 않으므로 제거한다. `READ_EXTERNAL_STORAGE` 는 병합기가
  `WRITE_EXTERNAL_STORAGE` 요청을 보고 **자동으로 덧붙이므로** 함께 제거해야 한다.
- `uses-feature` 의 `required` 는 **OR 로 병합**된다. 플러그인이 속성을 생략하면(=true)
  앱의 `required="false"` 가 덮이므로 `tools:replace` 가 필요하다.
- `CAMERA` 권한만 있어도 `android.hardware.camera` 가 **필수로 암시**된다. 명시적으로
  `required="false"` 를 선언하지 않으면 카메라 없는 기기가 Play 스토어에서 걸러진다.

릴리스 APK 에 실제로 남은 권한은 이렇게 확인한다.

```bash
"$(ls -d "$HOME/Library/Android/sdk/build-tools"/* | tail -1)/aapt2" dump badging build/app/outputs/flutter-apk/app-release.apk | grep -i "uses-permission\|feature"
```

기대값은 아래와 같다. `CAMERA` 외에 나오는 `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` 은
AndroidX 가 자동으로 넣는 것이라 정상이다.

```
uses-permission: name='android.permission.CAMERA'
uses-permission: name='com.example.doremi.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'
  uses-feature-not-required: name='android.hardware.camera'
  uses-feature-not-required: name='android.hardware.camera.any'
  uses-feature-not-required: name='android.hardware.camera.autofocus'
```

`RECORD_AUDIO` 나 저장소 권한이 보이면 매니페스트의 제거 지시가 빠진 것이다.

### 카메라를 못 쓸 때의 동작

톡톡 Lite 는 카메라 없이도 막히지 않는다. 거부·미지원 상황마다 재요청 / 설정 열기 /
다시 시도를 제공하고, 모든 경우에 **카메라 없이 연습하기** 를 함께 둔다. 상태별 판별
방법은 [기획서의 톡톡 Lite 권한 처리](docs/너두도레미_기획서.md) 절에 정리해 두었다.

거부 종류는 `CameraException.code` 만으로 판단할 수 없다. Android 플러그인은 영구 거부와
일시 거부에 같은 코드를 주고, iOS 는 첫 거부에만 그 코드를 준다. 그래서 거부를 받은
**뒤에** `Permission.camera.status` 로 확인한다 — Android 의 영구 거부 판정은
`shouldShowRequestPermissionRationale` 기반이라 '아직 안 물어본 상태'와 구분되지 않으므로
미리 조회하면 첫 사용자를 오판한다.
