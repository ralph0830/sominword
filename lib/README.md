# lib/ 폴더 구조 및 역할 (모듈화 전/중)

- main.dart: 앱/관리자 진입점 및 전체 라우팅, SplashScreen, HomePage 등 주요 화면 포함
- firebase_options.dart: Firebase 초기화 옵션
- quiz_page.dart: 퀴즈(학습) 관련 화면/로직
- core/: 공통 서비스, 모델, 유틸, 상수 등 (앱/관리자 공용)
  - services/: 파이어베이스, 기기ID 등 공통 서비스

---

## 모듈화 분리 기준(초안)
- **core/**: 공통 서비스, 모델, 유틸, 상수 등(앱/관리자 공용)
- **app/**: 사용자 앱 전용 화면, 위젯, 상태관리, 라우팅 등
- **admin/**: 관리자 웹 전용 화면, 위젯, 상태관리, 라우팅 등 