# SominWord 프로젝트 모듈화 계획 및 상세 TODO 리스트 (세부 분해)

## 1. 모듈화 목표
- 앱/웹/공통 코드의 명확한 분리
- 유지보수성, 확장성, 테스트 용이성 향상
- 기능별 책임 분리 및 재사용성 강화

---

## 2. 주요 모듈 설계 방향

### 2.1. 공통(Core) 모듈
- **공통 유틸리티, 모델, 서비스, 상수, 타입**
- 예: device_id_service.dart, firebase_service.dart, models/, utils/, constants/

### 2.2. 사용자 앱(App) 모듈
- **모바일/태블릿 전용 UI, 사용자 기능**
- 예: 단어 카드, 학습, TTS, 즐겨찾기, 캘린더, 기기 등록 등

### 2.3. 관리자(Admin) 모듈
- **관리자 웹 전용 UI, 관리 기능**
- 예: 단어 CRUD, 기기 승인, 관리자 권한 관리 등

### 2.4. 테스트/샘플/스토리북
- **각 모듈별 단위 테스트, 위젯 테스트, 샘플 코드**

---

## 3. 예상 파일/폴더 구조

```
lib/
  core/           # 공통 서비스, 모델, 유틸, 상수 등
    services/
    models/
    utils/
    constants.dart
  app/            # 사용자 앱 전용 코드
    screens/
    widgets/
    ...
  admin/          # 관리자 웹 전용 코드
    screens/
    widgets/
    ...
  main.dart       # 앱 진입점 (app, admin 분기)
  firebase_options.dart
```

---

## 4. 단계별 세부 TODO 리스트

### [1단계] 모듈 구조 설계 및 폴더 분리
- [ ] 기존 lib/ 내 모든 파일/폴더 목록 작성 및 역할 분류
- [ ] 공통(core), 사용자(app), 관리자(admin) 코드 구분 기준 문서화
- [ ] core/, app/, admin/ 폴더 생성
- [ ] 각 폴더에 README.md(역할/구성 설명) 작성
- [ ] 기존 main.dart, firebase_options.dart 등 진입점/공통 파일 위치 결정
- [ ] 기존 코드에서 임시로 분리 대상 파일/클래스/함수 목록화

### [2단계] 공통(Core) 모듈 분리
- [x] device_id_service.dart → core/services/로 이동
- [x] firebase_service.dart → core/services/로 이동
- [x] 공통 모델(예: 단어, 기기, 관리자 등) → core/models/로 이동 및 통합
- [x] 공통 유틸 함수(예: 날짜, 문자열, 변환 등) → core/utils/로 이동
- [x] 상수/enum/타입 → core/constants.dart, core/types.dart 등으로 분리
- [x] 각 파일/클래스/함수별 주석 및 타입 명확화
- [x] core 내 모든 import 경로 일괄 수정 (상대→절대/별칭 등)
- [x] core 내 의존성(외부 패키지, 내부 모듈) 명확히 정리
- [x] core 모듈 단독 테스트(예: 서비스/유틸 단위 테스트) 작성 및 실행

### [3단계] 사용자 앱(App) 코드 분리
- [ ] 기존 사용자 앱 관련 화면/위젯/로직 → app/screens, app/widgets 등으로 이동
- [ ] SplashScreen, HomePage, 단어 카드, TTS, 즐겨찾기, 캘린더 등 기능별로 세부 파일 분리
- [ ] app 내 상태관리 코드(Provider, Bloc 등) 별도 디렉토리로 이동
- [ ] app 내 라우팅/네비게이션 구조 정리
- [ ] app 내에서 core 모듈 import 경로 일괄 수정
- [ ] app 내 임시/중복 코드 제거 및 리팩토링
- [ ] app 전용 main.dart 진입점 분리/정리
- [ ] 앱 빌드/실행 테스트 및 주요 화면 동작 확인

### [4단계] 관리자(Admin) 코드 분리
- [ ] 기존 관리자 페이지 관련 화면/위젯/로직 → admin/screens, admin/widgets 등으로 이동
- [ ] 단어 CRUD, 기기 승인, 관리자 권한 관리 등 기능별로 세부 파일 분리
- [ ] admin 내 상태관리 코드 별도 디렉토리로 이동
- [ ] admin 내 라우팅/네비게이션 구조 정리
- [ ] admin 내에서 core 모듈 import 경로 일괄 수정
- [ ] admin 내 임시/중복 코드 제거 및 리팩토링
- [ ] admin 전용 main.dart 진입점 분리/정리
- [ ] 관리자 페이지 빌드/실행 테스트 및 주요 화면 동작 확인

### [5단계] 테스트/샘플 코드 정리
- [ ] core, app, admin 각 모듈별 단위 테스트 파일 분리
- [ ] 테스트 커버리지 측정 및 미달 영역 보완
- [ ] 주요 기능(단어 추가/수정/삭제, 기기 승인 등) 시나리오 테스트 작성
- [ ] 위젯/화면 테스트 코드 작성 및 실행
- [ ] 샘플/스토리북 코드 별도 디렉토리로 이동
- [ ] 테스트 자동화 스크립트/워크플로우 작성

### [6단계] 빌드/배포 스크립트 및 문서화
- [ ] core, app, admin 각 모듈별 빌드/배포 방법 정리 (README, deploy_admin.sh 등)
- [ ] 환경별(firebase, .env 등) 설정 파일 분리 및 관리
- [ ] 개발/운영 가이드 문서화(폴더 구조, 빌드, 배포, 테스트, 기여 가이드 등)
- [ ] 모듈화 전/후 변경점 및 마이그레이션 가이드 작성
- [ ] PR/커밋/리뷰 규칙 문서화

---

## 5. 추가 고려사항
- 의존성 루프/중복 방지
- 공통 모듈의 순수성 유지(앱/관리자 코드 혼입 금지)
- 향후 패키지화/외부 배포 가능성 고려
- 각 단계별 커밋 및 PR 관리

---

## 6. 진행상황 체크리스트(예시)
- [x] 1단계: 구조 설계/분리 기준/폴더 생성/README (lib/README.md 작성 완료)
- [x] 2단계: core 분리/이동/테스트 (services/ → core/services/ 이동, core/README.md 작성, 모델/유틸/상수 분리, 의존성/임포트 정리)
- [ ] 3단계: app 분리/이동/테스트
- [ ] 4단계: admin 분리/이동/테스트
- [ ] 5단계: 테스트/샘플/자동화
- [ ] 6단계: 빌드/배포/문서화

---

### [3단계] 추가 세부 작업
- [ ] main.dart, quiz_page.dart 등 사용자 앱 관련 화면/위젯/로직 app/screens, app/widgets 등으로 이동
- [ ] SplashScreen, HomePage, 단어 카드, TTS, 즐겨찾기, 캘린더 등 기능별로 세부 파일 분리
- [ ] app 내 상태관리 코드(Provider, Bloc 등) 별도 디렉토리로 이동
- [ ] app 내 라우팅/네비게이션 구조 정리
- [ ] app 내에서 core 모듈 import 경로 일괄 수정
- [ ] app 내 임시/중복 코드 제거 및 리팩토링
- [ ] app 전용 main.dart 진입점 분리/정리
- [ ] 앱 빌드/실행 테스트 및 주요 화면 동작 확인

#### [목록화 결과]

- main.dart
  - MyApp: 전체 앱 진입점(MaterialApp)
  - SplashScreen, _SplashLoadingView, _DeviceIdView: 초기 로딩/기기 등록/승인 화면
  - HomePage, _HomePageState: 단어장 메인 화면, 상태관리, 단어/기기 상태/즐겨찾기 등
  - 기타: 상태관리, TTS, 단어 CRUD, 기기 등록/승인 등
- quiz_page.dart
  - QuizPage, _QuizPageState: 퀴즈(학습) 메인 화면, 상태관리, TTS, 정답 체크, 점수 등
  - 주요 함수: _loadWords, _checkAnswer, _levenshteinDistance, _playWord 등
- services/
  - device_id_service.dart: 기기 고유번호/이름 생성, 저장, 캐싱, 플랫폼별 처리
  - firebase_service.dart: Firestore 연동, 기기/단어 CRUD, 승인 상태, 통계, 단어 스트림 등

---

(이 목록을 기반으로 2단계 분리/이동 작업을 진행) 