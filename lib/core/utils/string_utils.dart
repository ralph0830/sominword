// 공통 문자열 유틸 함수 (앱/관리자 공용)

// import '../models/word_model.dart'; // 예시: 모델과 함께 사용 가능

String capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
} 