// 공통 단어 모델 (앱/관리자 공용)

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