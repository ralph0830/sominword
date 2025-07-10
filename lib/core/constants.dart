// 공통 상수, enum, 타입 정의 (앱/관리자 공용)

// 예시: 기기 상태
enum DeviceStatus {
  unregistered, // 0
  pending,      // 1
  approved      // 2
}

// 예시: 단어 모델 타입
class Word {
  final String id;
  final String englishWord;
  final String koreanMeaning;
  final String partOfSpeech;
  final bool isFavorite;

  Word({
    required this.id,
    required this.englishWord,
    required this.koreanMeaning,
    required this.partOfSpeech,
    required this.isFavorite,
  });
}

// 기타 공통 상수/enum/타입은 필요시 추가 