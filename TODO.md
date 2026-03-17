# 🚀 Lunch-Luckvicky 개발 진행 현황 (Checklist)

> 전체 PRD(요구사항 정의서)를 기반으로 구현해야 할 작업들을 단계별로 나눈 체크리스트입니다. 본 문서를 통해 현재 어디까지 작업되었고 다음에는 무엇을 해야할지 한눈에 파악할 수 있습니다.

## 🟩 Phase 0: 프로젝트 초기 환경 세팅 (완료)
- [x] Flutter 프로젝트 생성 및 패키지명 적용 (`com.doublesouls.lunchluckyvicky`)
- [x] 필수 패키지 설치 (`flutter_riverpod`, `go_router`, `firebase_core`, `google_maps_flutter` 등)
- [x] 기본 디렉토리 구조(Feature-based) 및 화면 목업 생성
- [x] 앱 테마(Monotone) 및 프로젝트 이름 적용
- [x] Google Maps & Places API 키 발급 및 Android/iOS 네이티브 프로젝트에 주입 완료
- [x] Firebase 프로젝트 설정 연동 (`google-services.json`, `GoogleService-Info.plist`, `Firebase.initializeApp()`)

---

## 🟨 Phase 1: 인증 및 사용자 관리 (Auth) (완료)
- [x] Firebase Auth 기반 구글 로그인 로직 구현 (`login_screen.dart`)
- [x] Riverpod을 활용한 전역 인증 상태(Auth State) 관리 세팅
- [x] Firestore에 최초 등록 유저 정보 저장 (UID, 이름, 프로필 사진)

## 🟩 Phase 2: 그룹/멤버 관리 (Group) (완료)
- [x] **데이터 모델링**: Firestore에 `users` 및 `groups` 컬렉션/문서 설계
- [x] 새 그룹(점심 팟) 생성 및 초대 코드 발급 로직
- [x] 초대 코드를 통한 그룹 조인 기능
- [x] 메인 홈 화면(`group_home_screen.dart`)에서 '오늘 점심 참석/불참' 상태 토글 기능 구현

## 🟩 Phase 3: 그룹 내부 식당 리스트 관리 및 맵 연동 (완료)
- [x] **데이터 모델링**: `groups/{groupId}/restaurants` 컬렉션 설계 설계 (메뉴 종류, 최근 방문일 기록 포함)
- [x] Google Places Autocomplete API를 붙여서 식당 검색 후 원터치로 등록하는 화면 구현 (수동 등록으로 우선 구현)
- [x] 메인 홈 화면에서 우리 팀이 보유한 전체 식당 리스트 조회
- [x] 특정 식당 방문 비활성화(제외) 또는 즐겨찾기(가중치) 상태 토글 기능

## 🟩 Phase 4: 추천 엔진 및 수락/거부(Veto) 세션 흐름 (완료)
- [x] **데이터 로직**: 당일 출석 인원 및 가용 식당 풀 기반 1건 무작위 추천 알고리즘 작성 (최근 방문 필터링 포함)
- [x] 세션(`sessions`) 문서 생성 실시간 동기화
- [x] 제안 화면 (`suggestion_screen.dart`)에서 '1명이라도 거부(Veto)' 시 다른 식당으로 즉시 재추천되도록 로직 연계
- [x] 모두가 수락하거나 무응답 시간 만료 시 '식당 확정' 처리
- [x] 메뉴를 '거부'한 사용자에게 패널티 마일리지 누적 기록

## 🟩 Phase 5: 하이라이트 — 후식 복불복 룰렛 (완료)
- [x] 그룹 설정에서 모드(균등 확률 vs 연차 차등 확률) 읽어오기 (현재 공통 거부 이력 횟수에 비례 적용)
- [x] Phase 4에서 넘어온 이번 세션 참석자 + 각자의 거부(Veto) 횟수에 비례하여 룰렛 지분(조각 크기) 계산 알고리즘 구현
- [x] 시각적으로 재미있는 룰렛 돌아가는 UI/UX 애니메이션 개발 (`roulette_screen.dart`)
- [x] 당첨 결과 확정 팝업 표시 및 이력 기록 (결과 팝업까지만 구현)

---

## 기타 ( MVP 이후 후속 진행 )
- [ ] 점심 통계 / 차트 대시보드 (우리가 가장 많이 간 식당, 이번달 가장 커피 많이 산 요정 등)
- [ ] 사용자 프로필 및 알림(Push) 설정
