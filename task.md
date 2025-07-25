# 초등학교 영어 단어장 앱 개발 To-Do List

## 1. 환경 설정
- [x] Flutter 개발 환경 설치 (Android/iOS/Web)
- [x] Firebase 프로젝트 생성 및 연동
- [x] Firestore 데이터베이스 활성화 및 보안 규칙 설정
- [x] flutter_tts 패키지 설치 및 테스트
- [x] table_calendar 등 캘린더 패키지 설치

## 2. 데이터 모델링 및 구조 설계
- [x] Firestore words 컬렉션 및 문서 구조 설계
- [x] 단어 Document 필드 정의 (english_word, korean_part_of_speech, korean_meaning, input_timestamp)
- [x] is_favorite 필드 로컬 DB 설계 (hive/sqflite 등)
- [x] Firestore 오프라인 캐싱 옵션 활성화

## 3. Admin 페이지(Flutter Web) 개발
- [x] Admin 프로젝트 생성 및 기본 라우팅
- [x] 단어 입력 폼 UI 구현 (영어, 품사, 뜻)
- [x] 단어 저장 시 Timestamp 자동 입력 로직 구현
- [x] Firestore에 단어 저장 기능 구현
- [x] 단어 목록 조회 UI 및 기능 구현 (날짜별/전체)
- [x] 단어 수정/삭제 기능 구현
- [x] 입력/수정/삭제 시 UI 피드백 처리
- [x] Firestore 보안 규칙: Admin 인증/권한 처리

## 4. 사용자 앱 UI 기본 구조
- [x] 스플래시 화면 구현
- [x] 메인 화면(카드 뷰) 레이아웃 설계 및 구현
- [x] 상단 네비게이션(모드 전환, 캘린더, 오늘의 단어) UI 구현
- [x] 카드 내 영어/한글/품사/스피커/즐겨찾기 아이콘 배치

## 5. 카드 스와이프 및 단어 이동 로직
- [x] 단어 리스트 불러오기(최신순 정렬)
- [x] 좌우 스와이프 제스처 구현 (다음/이전 단어 이동)
- [x] 앱 실행 시 최신 단어부터 로드
- [x] 스와이프 시 단어 정보 갱신 및 애니메이션 처리

## 6. TTS(발음) 기능
- [x] flutter_tts 연동 및 초기 설정 (미국/영국식 선택)
- [x] 카드 내 스피커 아이콘 탭 시 TTS 발음 재생
- [x] TTS 반응 속도 최적화

## 7. 즐겨찾기 기능
- [x] 카드 내 별표(★) 아이콘 토글 구현
- [x] 즐겨찾기 단어 로컬 DB 저장/해제 로직 구현
- [x] 즐겨찾기 목록 별도 조회 UI (선택)

## 8. 학습 모드(4가지 TEST 모드)
- [x] 모드 전환 UI(버튼 그룹/드롭다운) 구현
- [x] 일반 모드: 영어/한글/품사 모두 표시
- [x] 뜻 가리기: 영어만 표시, 탭 시 한글/품사 노출
- [x] 영단어 가리기: 한글/품사만 표시, 탭 시 영어 노출
- [x] 랜덤 가리기: 영어/한글 중 무작위 가림, 탭 시 노출
- [x] 각 모드별 카드 UI/로직 분기 처리

## 9. 캘린더 기능
- [x] 상단 캘린더 아이콘 및 진입 UI 구현
- [x] 월별 캘린더 UI 및 단어 추가 날짜 표시
- [x] 날짜 선택 시 해당 날짜 첫 단어로 이동
- [x] 캘린더 이동 후 스와이프 연동 처리

## 10. 오늘의 단어 모드
- [x] 오늘의 단어 탭/버튼 UI 구현
- [x] 오늘 추가된 단어만 필터링 및 표시
- [x] 오늘의 단어 내 스와이프 제한/전체 전환 옵션 구현

## 11. 데이터 연동 및 캐싱
- [x] Firestore 데이터 읽기/쓰기/수정/삭제 연동 (사용자 앱: 읽기 구현, Admin: 쓰기/수정/삭제 일부 구현)
- [x] Firestore 오프라인 캐싱 테스트
- [x] 네트워크 예외/오류 처리 및 사용자 피드백

## 12. 성능/사용성/안정성 개선
- [x] 단어 로딩/스와이프/TTS 반응 속도 최적화
- [x] 직관적 UI/내비게이션/시각적 피드백 강화
- [x] 데이터 일관성 및 오류 처리 로직 강화

## 13. 테스트 및 디버깅
- [ ] 주요 기능별 단위 테스트/통합 테스트 작성
- [ ] 실제 기기/에뮬레이터에서 UI/성능 테스트
- [ ] 버그 수정 및 QA 피드백 반영

## 14. 배포 준비 및 앱스토어 등록
- [x] 앱 아이콘/스플래시 이미지 제작 및 적용
- [x] 타이틀 화면 이미지 개선 및 로딩 화면 타이틀 이미지로 대체
- [ ] Android/iOS/Web 빌드 및 배포 준비
- [ ] Google Play Store/Apple App Store 등록 절차 진행
- [ ] 최종 QA 및 릴리즈 노트 작성

## 15. 관리자 권한 체계 구현
- [x] 슈퍼 관리자와 일반 관리자 권한 분리 설계
- [x] Firebase 보안 규칙에 관리자 권한 체계 추가
- [x] 사용자 앱에 기기 고유번호 표시 및 복사 기능 추가
- [x] 관리자 페이지에 Firebase Auth 인증 시스템 추가
- [x] 관리자 신청 및 승인 시스템 구현
- [x] 슈퍼 관리자 전용 관리자 승인 관리 페이지 구현
- [x] Firebase 보안 규칙 배포 완료
- [x] deprecated_member_use 오류 수정 (withOpacity → withValues)
- [x] flutter-project-rules.mdc 파일에 deprecated 오류 처리 규칙 추가
- [x] unchecked_use_of_nullable_value 오류 수정 (타입 캐스팅 적용)
- [x] invalid_null_aware_operator 오류 수정 (불필요한 null-aware 연산자 제거)
- [x] unused_local_variable 오류 수정 (사용하지 않는 createdAt 변수 제거)
- [x] use_build_context_synchronously 오류 수정 (context.mounted 체크 적용)
- [x] 관리자 페이지 setState after dispose 오류 수정 (mounted 체크 적용)
- [x] 승인되지 않은 관리자 로그인 시 경고 메시지 개선
- [x] use_build_context_synchronously 경고 수정 (context.mounted 체크 적용)
- [x] undefined_identifier 'mounted' 오류 수정 (builder 내부에서 context.mounted 사용)
- [x] use_build_context_synchronously 경고 및 setState after dispose 오류 수정 (mounted 체크 적용)
- [x] avoid_print 경고 수정 (debugPrint와 kDebugMode 사용)
- [x] flutter-project-rules.mdc에 print 함수 사용 금지 규칙 추가
- [x] use_build_context_synchronously 경고 추가 수정 (showDialog builder 내부에서 ctx.mounted 사용)
- [x] flutter-project-rules.mdc에 BuildContext 사용 규칙 세분화 추가

## 16. 향후 고려사항(선택/확장)
- [ ] 사용자별 학습 진도 저장 (Firebase Auth 연동)
- [ ] 단어 게임(스펠링 퀴즈, 짝 맞추기 등) 추가
- [ ] 예문/이미지 자료 연동 및 예문 발음 기능 



변경 설계 요약
1. Firestore 구조
account (컬렉션)
{email} (문서, 예: ralph0830@gmail.com)
isSuperAdmin: true/false
isApproved: true/false
deviceId, deviceName, requestedAt, approvedAt, approvedBy 등
2. 코드 변경 포인트
모든 admins → account로 컬렉션명 변경
문서 ID는 uid → email로 변경(이메일이 고유키)
슈퍼관리자 여부: isSuperAdmin 필드로 판별
승인 여부: isApproved 필드로 판별
관리자 승인/거부, 리스트, 권한 체크 등 모든 로직에서 컬렉션/필드명 일괄 변경
진행 순서
로그인/권한 체크 로직:
admins → account
uid → email
isSuperAdmin 필드로 슈퍼관리자 판별
관리자 승인/거부/목록:
컬렉션/필드명 일괄 변경
신규 관리자 신청/등록:
account 컬렉션에 문서 생성
UI/UX:
슈퍼관리자만 승인/권한 부여 가능하도록 UI 유지