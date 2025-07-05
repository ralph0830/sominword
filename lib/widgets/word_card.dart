import 'package:flutter/material.dart';

class WordCard extends StatelessWidget {
  final String word;
  final String partOfSpeech;
  final String meaning;
  final int idx;
  final bool isSpeaking;
  final bool isFavorite;
  final bool hideWord;
  final bool hideMeaning;
  final bool revealedWord;
  final bool revealedMeaning;
  final VoidCallback onSpeak;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRevealWord;
  final VoidCallback onRevealMeaning;
  final bool showHint;
  final Widget loopButton;

  const WordCard({
    super.key,
    required this.word,
    required this.partOfSpeech,
    required this.meaning,
    required this.idx,
    required this.isSpeaking,
    required this.isFavorite,
    required this.hideWord,
    required this.hideMeaning,
    required this.revealedWord,
    required this.revealedMeaning,
    required this.onSpeak,
    required this.onToggleFavorite,
    required this.onRevealWord,
    required this.onRevealMeaning,
    required this.showHint,
    required this.loopButton,
  });

  @override
  Widget build(BuildContext context) {
    // randomHide 모드일 때만 idx 분기 적용
    final bool isRandom = hideWord && hideMeaning;
    final bool shouldHideWord = isRandom ? idx % 2 == 0 : hideWord;
    final bool shouldHideMeaning = isRandom ? idx % 2 == 1 : hideMeaning;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, anim) {
        final beginOffset = const Offset(1, 0);
        final endOffset = Offset.zero;
        return SlideTransition(
          position: anim.drive(Tween<Offset>(begin: beginOffset, end: endOffset).chain(CurveTween(curve: Curves.ease))),
          child: child,
        );
      },
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: _buildFront(context, shouldHideWord, shouldHideMeaning),
    );
  }

  Widget _buildFront(BuildContext context, bool shouldHideWord, bool shouldHideMeaning) {
    final cardWidth = 320.0; // 카드 width 고정값(혹은 Container width 사용)
    final wordFontSize = cardWidth * 0.15; // 15%
    final meaningFontSize = cardWidth * 0.09; // 9%
    final posFontSize = cardWidth * 0.06; // 6%
    return Container(
      key: const ValueKey(false),
      child: Stack(
        children: [
          Card(
            elevation: 8,
            margin: const EdgeInsets.all(0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            color: Colors.white,
            child: Container(
              width: cardWidth,
              height: 420,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // 상단 아이콘 Row (TTS, LOOP, 즐겨찾기)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // TTS(발음) 아이콘
                      IconButton(
                        icon: Icon(isSpeaking ? Icons.volume_off : Icons.volume_up, color: Colors.deepPurple),
                        onPressed: isSpeaking ? null : onSpeak,
                        tooltip: isSpeaking ? '발음 중...' : '발음 듣기',
                      ),
                      // LOOP(무한반복) 버튼 (가운데)
                      loopButton,
                      // 즐겨찾기(별) 아이콘
                      GestureDetector(
                        onTap: onToggleFavorite,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.deepPurple[50],
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            isFavorite ? Icons.star : Icons.star_border,
                            color: isFavorite ? Colors.amber : Colors.deepPurple[200],
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // 영어단어(중앙)
                  shouldHideWord && !revealedWord
                      ? GestureDetector(
                          onTap: onRevealWord,
                          child: Center(
                            child: SizedBox(
                              width: double.infinity,
                              height: wordFontSize * 1.15, // 텍스트 높이와 유사하게
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: SizedBox(
                            width: double.infinity,
                            child: Text(
                              word,
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    fontSize: wordFontSize,
                                    fontFamily: Theme.of(context).textTheme.displaySmall?.fontFamily,
                                  ) ?? TextStyle(fontSize: wordFontSize, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                  const SizedBox(height: 32),
                  // 품사(라벨)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      partOfSpeech,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.w600,
                            fontSize: posFontSize,
                          ) ?? TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600, fontSize: posFontSize),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 한글 뜻
                  shouldHideMeaning && !revealedMeaning
                      ? GestureDetector(
                          onTap: onRevealMeaning,
                          child: Center(
                            child: SizedBox(
                              width: double.infinity,
                              height: meaningFontSize * 1.15,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: SizedBox(
                            width: double.infinity,
                            child: Text(
                              meaning,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.black87,
                                    fontSize: meaningFontSize,
                                    fontFamily: Theme.of(context).textTheme.titleLarge?.fontFamily,
                                  ) ?? TextStyle(fontSize: meaningFontSize, color: Colors.black87),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                  const Spacer(),
                  // 힌트(손가락+문구)
                  if (showHint)
                    Opacity(
                      opacity: 0.25,
                      child: Column(
                        children: [
                          Icon(Icons.swipe, size: 40),
                          const SizedBox(height: 4),
                          Text('카드를 탭하거나 스와이프하세요', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  if (showHint) const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 