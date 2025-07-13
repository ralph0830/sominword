# 소민단어 어드민(sominword_admin) 프로젝트 분석

## 1. 프로젝트 개요 (Overview)

이 프로젝트는 '소민단어(Sominword)' 애플리케이션의 관리를 위한 **어드민 패널**입니다. Flutter 프레임워크를 사용하여 개발되었으며, 웹, 모바일(iOS, Android), 데스크톱(Windows, macOS, Linux) 등 다양한 플랫폼을 지원하는 크로스플랫폼 애플리케이션입니다.

주요 기능은 단어 데이터 관리, 사용자 기기 승인 및 관리, 다른 관리자 계정 관리 등입니다.

## 2. 기술 스택 (Technology Stack)

- **UI Framework**: [Flutter](https://flutter.dev/)
- **Programming Language**: [Dart](https://dart.dev/)
- **Backend & Database**: [Firebase](https://firebase.google.com/)
  - **Authentication**: Firebase Auth (인증)
  - **Database**: Cloud Firestore (NoSQL 데이터베이스)
  - **Hosting**: Firebase Hosting (웹 호스팅)
- **Local Storage**: [Hive](https://pub.dev/packages/hive) (경량 로컬 데이터베이스)
- **Scripting**: Python, Shell Script (`.py`, `.sh`)
- **Package Management**: Pub (Dart), NPM (Node.js - 개발용 유틸리티)

## 3. 주요 디렉토리 구조 (Key Directory Structure)

- **`/lib`**: 애플리케이션��� 핵심 로직이 담긴 Dart 코드 디렉토리입니다.
  - `main.dart`: 앱의 시작점(entry point)입니다.
  - `pages/`, `admin/`: 각 화면(UI)과 비즈니스 로직을 포함하는 파일들이 위치합니다. (일부 파일이 중복되어 있어 리팩토링이 필요할 수 있습니다.)
    - `word_admin_page.dart`: 단어 관리 페이지
    - `device_list_page.dart`: 등록된 기기 목록 페이지
    - `admin_management_page.dart`: 관리자 계정 관리 페이지
    - `login_page.dart`: 로그인 페이지
  - `firebase_options.dart`: Firebase 프로젝트 설정 파일입니다.

- **`/assets`**: 정적 리소스 파일 디렉토리입니다.
  - `images/`: 앱 아이콘 등 이미지 파일
  - `fonts/`: NotoSansKR 등 커스텀 폰트 파일

- **`/bin`**: 데이터베이스 마이그레이션 등 보조적인 작업을 위한 Python 스크립트가 위치합니다.
  - `add_createdAt_to_words.py`: 'words' 컬렉션에 생성 날짜 필드를 추가하는 스크립트로 추정됩니다.
  - `add_sentence_to_words.py`: 'words' 컬렉션에 예문 필드를 추가하는 스크립트로 추정됩니다.

- **`/ios`, `/android`, `/web`, `/windows`, `/macos`, `/linux`**: 각 플랫폼별 네이티브 코드와 설정 파일이 위치한 디렉토리입니다.

- **Firebase 관련 파일**:
  - `firebase.json`: Firebase Hosting 및 기타 설정을 정의합니다.
  - `firestore.rules`: Firestore 데이터베이스의 보안 규칙을 정의합니다.
  - `firestore.indexes.json`: Firestore 쿼리 성능 향상을 위한 인덱스를 정의합니다.
  - `.firebaserc`: `sominword` Firebase 프로젝트를 기본값으로 설정합니다.

- **루트(Root) 주요 파일**:
  - `pubspec.yaml`: 프로젝트의 의존성(dependencies)과 메타데이터를 정의하는 핵심 설정 파일입니다.
  - `migrate_words.dart`: 단어 데이터 마이그레이션을 위한 Dart 스크립트입니다.
  - `create_superadmin_account.dart`: 최상위 관리자 계정 생성을 위한 Dart 스크립트입니다.
  - `build.sh`: 프로덕션 웹 빌드를 위한 쉘 스크립트입니다.

## 4. 추정 기능 (Inferred Functionality)

파일 이름과 구조를 통해 유추할 수 있는 이 어드민 패널의 주요 기능은 다음과 같습니다.

- **로그인 (Login)**: Firebase Auth를 이용한 관리자 인증 기능
- **단어 관리 (Word Management)**: '소민단어' 앱에서 사용하는 단어(Word)의 추가, 수정, 삭제 기능
- **기기 관리 (Device Management)**: 사용자 기기의 등록 및 승인 상태를 관리하는 기능
- **관리자 관리 (Admin Management)**: 다른 관리자 계정을 생성하고 권한을 관���하는 기능
- **데이터 마이그레이션 (Data Migration)**: 기존 데이터를 새로운 스키마에 맞게 변경하는 기능
