# 소민단어 어드민(sominword_admin) 프로젝트 TRD

## 1. 시스템 아키텍처
- **Flutter Web** 기반 SPA, Firebase Auth/Firestore/Storage 실시간 연동
- **Firestore**: 단어/기기/관리자 데이터 저장, 실시간 스트림 UI
- **Firebase Auth**: 관리자 인증, Firestore account 컬렉션과 연동
- **로컬 DB**: Hive(일부 로컬 캐싱/테스트용)

## 2. 주요 컴포넌트/모듈
- **lib/main.dart**: 앱 진입점, Firebase 초기화, 인증/라우팅
- **lib/pages/**: 각종 화면(단어, 기기, 관리자, 로그인 등)
- **lib/admin/widgets/**: 재사용 UI 컴포넌트(WordCard, DeviceCard 등)
- **lib/admin/dialogs.dart**: 입력/수정/TSV 추출 등 다이얼로그
- **lib/admin/utils.dart**: 날짜 포맷 등 유틸 함수
- **assets/fonts/**: NotoSansKR 폰트
- **bin/**: Firestore 마이그레이션 스크립트

## 3. 주요 구현/정책
- **단어 관리**
  - 체크박스 기반 다중 선택, 일괄 삭제/이동
  - TSV 추출: Firestore 쿼리 → 문자열 변환 → 다이얼로그 복사
  - 예문(sentence), 예문 해석(sentenceKor) 필드 추가
- **isFavorite 완전 제거**: Firestore/코드에서 관련 필드/로직 삭제
- **use_build_context_synchronously 경고**: 모든 비동기 후 context 사용 전 if (!mounted) return; 패턴 적용
- **폰트/에셋 오류**: pubspec.yaml, assets/fonts/ 폴더, 파일 존재 확인, flutter clean/pub get/서버 재시작 등으로 해결
- **민감 정보 보호**: sominword-firebase-admin.json .gitignore, git 기록 완전 삭제

## 4. 보안/운영
- **Firestore.rules**: 현재 테스트 모드(실서비스 시 관리자/기기별 접근 제어 필요)
- **관리자 승인/권한**: Firestore account 컬렉션, isSuperAdmin, isApproved 필드로 분기
- **기기 승인**: pendingDevices 컬렉션, 승인 시 devices로 이동

## 5. 빌드/배포
- **Flutter Web**: build.sh, flutter build web
- **systemd 서비스**: sominword-admin.service로 자동 실행
- **앱 아이콘/스플래시**: assets/images/, flutter_launcher_icons

## 6. 테스트/품질
- **test/**: 위젯 테스트, 단위 테스트(확장 예정)
- **분석/정적 검사**: flutter analyze, lints 적용

---

(이 문서는 실제 코드/구조/정책을 반영하여 최신화되었습니다. 세부 구현/정책 변경 시 본 문서도 함께 업데이트할 것!)
