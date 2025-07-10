# core/ 폴더

- 앱/관리자 공통 서비스, 모델, 유틸, 상수, 타입 등 재사용 가능한 코드 모음
- 예시: services/ (공통 서비스), models/ (공통 데이터 모델), utils/ (공통 유틸리티), constants.dart 등

## 구조 예시
- services/: 파이어베이스, 기기ID 등 공통 서비스
- models/: 단어, 기기, 관리자 등 공통 데이터 모델 (word_model.dart, device_model.dart 등)
- utils/: 날짜, 문자열 등 공통 유틸 함수 (date_utils.dart, string_utils.dart 등)
- constants.dart: 상수/enum/타입 등 