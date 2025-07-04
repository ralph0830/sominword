# sominword (최신 PRD)

## 1. 개요 (Introduction)
본 프로젝트는 초등학교 저학년 학생을 위한 영어 단어장 앱입니다. **사용자 앱(모바일)**과 **관리자 페이지(Flutter Web)**로 완전히 분리되어 있으며, Firebase를 통해 실시간 데이터 연동 및 관리가 가능합니다.

- **사용자 앱**: 학생이 단어를 학습, 복습, 테스트할 수 있는 모바일 앱 (Android/iOS)
- **관리자 페이지**: 관리자가 단어를 추가/수정/삭제, 기기 승인, 관리자 권한 관리 등을 수행하는 웹 앱 (Flutter Web)

## 2. 목표 (Goals)
- 초등학생이 쉽고 재미있게 영어 단어를 학습/복습할 수 있는 환경 제공
- 관리자가 간편하게 단어를 추가/관리하고, 기기 및 관리자 권한을 효율적으로 관리
- 다양한 학습 모드, TTS, 즐겨찾기, 캘린더 등 풍부한 학습 지원 기능 제공

## 3. 프로젝트 구조
- **lib/**: 사용자 앱(모바일) 소스
- **admin/**: 관리자 페이지(Flutter Web) 소스
- **공통**: Firebase 프로젝트, Firestore, Storage, Auth 등

## 4. 주요 기능 및 정책
### 4.1 사용자 앱(모바일)
- 카드 뷰 기반 단어 학습, 좌우 스와이프로 단어 이동
- TTS(발음) 기능, 즐겨찾기(로컬 DB)
- 4가지 학습 모드(일반/뜻 가리기/영단어 가리기/랜덤)
- 캘린더로 날짜별 단어 이동, 오늘의 단어 모드
- **기기 등록/승인 정책**: 최초 실행 시 기기 고유번호(deviceId) 생성 및 Firestore 등록, 관리자가 승인해야 앱 사용 가능

### 4.2 관리자 페이지(Flutter Web)
- Firebase Auth 기반 이메일/비밀번호 로그인
- 관리자 계정은 Firestore `account` 컬렉션에 이메일을 문서 ID로 사용
- `isSuperAdmin`, `isApproved` 필드로 권한/승인 관리, 슈퍼관리자만 신규 관리자 승인 가능
- 단어 CRUD, 기기 승인/거부, 관리자 신청/승인, 기기별 단어 관리 등 모든 기능 구현

## 5. Firestore 데이터 구조 (최신)
- **words 컬렉션**
  - 문서ID: 자동
  - 필드: english_word, korean_part_of_speech, korean_meaning, input_timestamp, device_id
- **account 컬렉션**
  - 문서ID: 이메일
  - 필드: email, uid, isSuperAdmin, isApproved, requestedAt, approvedAt, approvedBy
- **devices 컬렉션**
  - 문서ID: device_id
  - 필드: device_id, device_name, owner_email, registered_at, is_approved

## 6. 기술 스택 및 환경
- Flutter 3.32.5, Dart 3.8.1
- Firebase Core/Firestore/Auth/Storage
- 주요 패키지: flutter_tts, table_calendar, hive, device_info_plus 등
- 개발환경: WSL2(Ubuntu 22.04) + VSCode + Chrome(Linux/Windows)

## 7. 완료/진행/향후 과제 (2025년 7월 기준)
### [완료]
- 관리자 페이지/사용자 앱 모든 주요 기능 구현
- Firestore 구조, 기기 승인, TTS, 학습 모드, 캘린더, 즐겨찾기, 보안 정책 등
- git 형상 관리, systemd 서비스로 관리자 페이지 자동 실행

### [진행/향후]
- 주요 기능별 단위/통합 테스트, 실제 기기/에뮬레이터 테스트
- 앱 아이콘/스플래시 이미지 제작, QA 및 버그 수정, 최종 배포 준비
- Google Play Store/Apple App Store 등록
- 사용자별 학습 진도 저장, 단어 게임, 예문/이미지 자료 등 확장 기능

## 8. 기기 고유값(디바이스 ID) 정책
- Android: device_info_plus의 androidInfo.id (Settings.Secure.ANDROID_ID)
- iOS: device_info_plus의 iosInfo.identifierForVendor
- 기타: 최초 실행 시 UUID 생성 후 SharedPreferences에 저장
- Firestore, 관리자 페이지, 사용자 앱 등 모든 경로에서 위 정책에 따라 생성된 deviceId만 사용
- 앱 내에서 deviceId를 사용자에게 안내(복사/백업 등 UX 제공)

## 9. 참고 및 기타
- 모든 소스는 Dart 공식 스타일 가이드 및 Flutter 프로젝트 규칙을 준수
- deprecated API 사용 금지, 코드 품질 및 보안 정책 엄수
- 확장성/유지보수성을 고려한 모듈화 및 주석 작성

---

(이 문서는 실제 코드/구조/정책을 반영하여 최신화되었습니다. 세부 구현 및 정책 변경 시 본 문서도 함께 업데이트할 것!)