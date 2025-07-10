# SominWord 프로젝트 Cursor AI 작업 가이드

이 문서는 **다른 컴퓨터의 Cursor AI(코드 어시스턴트)**에서 이 프로젝트를 이어서 작업할 때, 반드시 학습시켜야 할 핵심 정보를 요약합니다.

---

## 📦 폴더/구조/역할

- **app/**: 사용자 앱(Flutter)
- **admin/**: 관리자 페이지(Flutter Web)
- **core/**: 공통 서비스/모델/유틸/상수
- **db/**, **drizzle/**: DB/ORM 관련
- **components/**, **store/**, **hooks/**, **utils/**: Next.js(웹) 구조 예시(참고)
- **public/**, **styles/**, **types/**: 정적/스타일/타입

---

## 🛠️ 주요 규칙/가이드

- **TypeScript 인터페이스는 I 접두사, types/index.ts에 작성**
- **Flutter: deprecated_member_use 금지, 최신 API만 사용**
- **Next.js: App Router, Route Handler 우선, src 폴더 미사용**
- **Clerk 인증: clerkMiddleware만 사용, authMiddleware 금지**
- **Drizzle ORM만 사용, Prisma 등 금지**
- **ShadCN UI 컴포넌트 우선, npx shadcn@latest add**
- **커밋 메시지: feat/fix/docs 등 타입, 50자 이내, 본문은 -로 구분**

---

## 🗂️ 모듈화/분리 기준

- **core/**: 공통 서비스/모델/유틸/상수만 위치
- **app/**: 사용자 앱 화면/위젯/로직만 위치
- **admin/**: 관리자 페이지 화면/로직만 위치
- **중복/불필요 코드, import, deprecated API 즉시 제거**
- **각 모듈별 README.md, 역할/진입점/분리 기준 명시**

---

## ✅ 진행상황/ToDo 예시

- 1단계: 구조 설계/분리 기준/폴더 생성/README (완료)
- 2단계: core 분리/이동/테스트 (완료)
- 3단계: app 분리/이동/테스트, HomePage build 복원 (완료)
- 4단계: admin 분리/이동/테스트 (완료)
- 5단계: 테스트/샘플/자동화 (완료)
- 6단계: 빌드/배포/문서화 (완료)

---

## 📝 운영/배포/보안/자동화

- **Flutter Web 빌드:** `flutter build web` (admin/build/web)
- **배포:** Firebase Hosting, Netlify, Vercel 등 build/web 업로드
- **Firestore 보안:** ownerEmail, isApproved 등 권한 체크 필수
- **정기 백업:** Firestore 콘솔/gcloud CLI
- **CI/CD:** GitHub Actions 예시, PR마다 테스트/배포 자동화

---

## 🤖 Cursor AI에게 반드시 알려줘야 할 것

- **이 md 파일 전체를 학습시켜야 함**
- **폴더/역할/분리 기준/코딩 규칙/운영 가이드/진행상황을 반드시 인식해야 함**
- **추가 작업 시, 기존 규칙/구조/분리 기준을 반드시 준수해야 함**
- **모든 커밋/문서/코드/운영 자동화도 위 기준에 맞춰야 함**

---

> **이 파일을 Cursor AI에 학습시키면, 어디서든 동일한 품질/규칙/구조로 이어서 작업할 수 있습니다.** 