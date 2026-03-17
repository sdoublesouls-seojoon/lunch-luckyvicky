# 점심 럭키비키 🍱

팀 점심 메뉴 선택부터 후식 복불복까지 한 번에 해결하는 Flutter 웹 앱

**Live**: [lunch-lucky.vercel.app](https://lunch-lucky.vercel.app)

## 주요 기능

- **식당 랜덤 추천** — 팀이 큐레이션한 식당 풀에서 1곳 자동 추천
- **만장일치 투표** — 1명이라도 거부하면 즉시 재추천 (최대 3라운드)
- **거부 패널티** — 메뉴를 거부할수록 후식 룰렛 당첨 확률 증가
- **후식 룰렛** — 점심 참여자 대상 복불복 룰렛 (거부 페널티 시각화)
- **그룹 관리** — 초대 코드로 팀 합류, 요일별 자동 참여 스케줄
- **식당 평가** — 식사 후 평가, 과반수 불만족 시 자동 비활성화

## 기술 스택

- **Frontend**: Flutter Web (Dart)
- **Backend**: Firebase (Auth, Cloud Firestore)
- **인증**: Google Sign-In
- **배포**: Vercel
- **상태 관리**: Riverpod (StreamProvider)

## 환경 설정

아래 파일들은 API 키 등 민감 정보를 포함하므로 **Git에서 제외**되어 있습니다. 로컬에서 직접 생성해야 합니다.

| 파일 | 설명 |
|------|------|
| `lib/firebase_options.dart` | Firebase 프로젝트 설정 (예제: `firebase_options.example.dart`) |
| `android/app/google-services.json` | Android용 Firebase 설정 |
| `ios/Runner/GoogleService-Info.plist` | iOS용 Firebase 설정 |

또한 아래 파일들에 플레이스홀더로 표시된 API 키를 실제 값으로 교체해야 합니다.

| 파일 | 플레이스홀더 | 용도 |
|------|-------------|------|
| `web/index.html` | `YOUR_GOOGLE_CLIENT_ID` | Google Sign-In |
| `android/app/src/main/AndroidManifest.xml` | `YOUR_GOOGLE_MAPS_API_KEY` | Google Maps (Android) |
| `ios/Runner/AppDelegate.swift` | `YOUR_GOOGLE_MAPS_API_KEY` | Google Maps (iOS) |

## 시작하기

### 사전 요구사항

- Flutter SDK 3.11+
- Firebase 프로젝트
- Google Cloud 프로젝트 (Maps API, OAuth Client ID)

### 설정

1. 레포 클론
   ```bash
   git clone https://github.com/sdoublesouls-seojoon/lunch-luckyvicky.git
   cd lunch-luckyvicky
   ```

2. Firebase 설정
   ```bash
   # 예제 파일을 복사한 후 실제 값으로 교체
   cp lib/firebase_options.example.dart lib/firebase_options.dart
   ```
   또는 FlutterFire CLI로 자동 생성:
   ```bash
   flutterfire configure
   ```

3. Google Maps API 키 설정
   - `android/app/src/main/AndroidManifest.xml` — `YOUR_GOOGLE_MAPS_API_KEY` 교체
   - `ios/Runner/AppDelegate.swift` — `YOUR_GOOGLE_MAPS_API_KEY` 교체

4. Google Sign-In Client ID 설정
   - `web/index.html` — `YOUR_GOOGLE_CLIENT_ID` 교체

5. 의존성 설치 및 실행
   ```bash
   flutter pub get
   flutter run -d chrome
   ```

### 웹 빌드

```bash
flutter build web --release
```

## 프로젝트 구조

```
lib/
├── core/              # 테마, 라우터, 네트워크 체크
├── features/
│   ├── auth/          # Google 로그인
│   ├── group/         # 그룹·멤버·식당 관리
│   ├── roulette/      # 후식 복불복 룰렛
│   └── session/       # 세션 (메뉴 추천·투표)
├── firebase_options.dart  # (gitignored)
└── main.dart
```

## 라이선스

MIT
