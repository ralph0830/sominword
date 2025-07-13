# 소민단어 어드민(sominword_admin) 프로젝트 PRD

## 1. 개요
- 초등학생 영어 단어장 앱의 **관리자 웹 패널** (Flutter Web)
- 단어/기기/관리자 계정 관리, 실시간 Firestore 연동

## 2. 주요 기능
- **단어 관리**: 단어 추가/수정/삭제, 체크박스 선택 후 일괄 삭제/이동, TSV 추출
- **기기 관리**: 기기별 단어 관리, 기기 추가 신청/승인/거부, 닉네임 수정
- **관리자 관리**: 관리자 계정 신청/승인/거부, 슈퍼관리자 권한 분리
- **인증**: Firebase Auth 이메일/비밀번호 기반, Firestore account 컬렉션 연동
- **보안**: 승인된 관리자/기기만 접근, Firestore 규칙(실서비스 시 강화 필요)
- **마이그레이션/유틸**: Python 스크립트로 Firestore 데이터 구조 변경 지원

## 3. 데이터 구조 (Firestore)
- **devices/{deviceId}/words/{wordId}**
  - englishWord, koreanPartOfSpeech, koreanMeaning, sentence, sentenceKor, inputTimestamp, createdAt, updatedAt
- **account/{email}**
  - email, uid, isSuperAdmin, isApproved, deviceId, deviceName, requestedAt, approvedAt, approvedBy
- **pendingDevices/**: 기기 승인 대기

## 4. 기술 스택
- Flutter 3.32.5, Dart 3.8.1
- Firebase Core/Firestore/Auth/Storage
- 주요 패키지: cloud_firestore, firebase_auth, hive, flutter_tts, table_calendar 등
- WSL2(Ubuntu 22.04) + VSCode + Chrome

## 5. 정책/UX
- **isFavorite 필드 완전 제거**: 즐겨찾기 기능 삭제, 체크박스 기반 일괄 처리로 대체
- **use_build_context_synchronously 경고**: 모든 비동기 후 context 사용 전 mounted 체크
- **TSV 추출**: Firestore 쿼리 후 변환, 다이얼로그에서 복사 지원
- **폰트/에셋**: NotoSansKR 폰트 정상 등록, assets/fonts/ 실제 파일 존재
- **민감 정보 보호**: sominword-firebase-admin.json git 기록 완전 삭제, .gitignore 등록

## 6. 향후 과제
- 단위/통합 테스트 강화, QA, 앱스토어 등록, 사용자별 진도/게임/예문 등 확장

---
