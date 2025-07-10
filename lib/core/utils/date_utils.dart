// 공통 날짜 유틸 함수 (앱/관리자 공용)

// import '../models/word_model.dart'; // 예시: 모델과 함께 사용 가능

String formatDate(DateTime date) {
  return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
} 