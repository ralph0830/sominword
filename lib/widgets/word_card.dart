import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'dart:math' as math;

/// 3D Flip 애니메이션이 적용된 단어 카드 위젯
/// 
/// 카드를 탭하면 3D Flip 애니메이션으로 앞면(영단어/뜻)과 뒷면(예문)을 전환합니다.
/// 앞면: 영단어, 품사, 한글 뜻, TTS 버튼, 즐겨찾기 버튼
/// 뒷면: 영어 예문, 한글 번역, 예문 TTS 버튼, 즐겨찾기 버튼
class WordCard extends StatefulWidget {
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
  final String? sentence;
  final String? sentenceKor;
  final VoidCallback? onSpeakSentence;

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
    this.sentence,
    this.sentenceKor,
    this.onSpeakSentence,
  });

  @override
  State<WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<WordCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isFront = true;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    // 3D Flip 애니메이션 컨트롤러 초기화
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // 애니메이션 완료 리스너 추가
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        setState(() {
          _isAnimating = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 카드 뒤집기 애니메이션 실행
  void _flipCard() {
    if (_isAnimating) return; // 애니메이션 중이면 무시
    
    setState(() {
      _isAnimating = true;
    });
    
    if (_isFront) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    
    // 애니메이션 중간에 상태 변경 (0.5 지점에서)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isFront = !_isFront;
        });
      }
    });
  }

  /// 예문에서 해당 단어를 찾아 빨간색으로 강조하는 함수
  /// 
  /// [sentence] 전체 예문 텍스트
  /// [word] 강조할 단어
  /// Returns: RichText에서 사용할 InlineSpan 리스트
  List<InlineSpan> _highlightWord(String sentence, String word) {
    final spans = <InlineSpan>[];
    final lowerSentence = sentence.toLowerCase();
    final lowerWord = word.toLowerCase();
    int startIndex = 0;
    
    while (true) {
      final index = lowerSentence.indexOf(lowerWord, startIndex);
      if (index == -1) {
        // 남은 부분 추가
        spans.add(TextSpan(text: sentence.substring(startIndex)));
        break;
      }
      
      // 단어 앞부분 추가
      if (index > startIndex) {
        spans.add(TextSpan(text: sentence.substring(startIndex, index)));
      }
      
      // 하이라이트된 단어 추가 (빨간색, 굵게)
      spans.add(TextSpan(
        text: sentence.substring(index, index + word.length),
        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      ));
      
      startIndex = index + word.length;
    }
    
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    // randomHide 모드일 때만 idx 분기 적용
    final bool isRandom = widget.hideWord && widget.hideMeaning;
    final bool shouldHideWord = isRandom ? widget.idx % 2 == 0 : widget.hideWord;
    final bool shouldHideMeaning = isRandom ? widget.idx % 2 == 1 : widget.hideMeaning;
    
    return GestureDetector(
      onTap: _flipCard,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          // 3D Flip 변환 행렬 생성
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // 원근감 추가
            ..rotateY(_animation.value * math.pi);
          
          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: _animation.value < 0.5
                ? _buildFront(context, shouldHideWord, shouldHideMeaning)
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi), // 뒷면 텍스트 뒤집기 방지
                    child: _buildBack(context),
                  ),
          );
        },
      ),
    );
  }

  /// 카드 앞면 UI (영단어, 품사, 한글 뜻)
  Widget _buildFront(BuildContext context, bool shouldHideWord, bool shouldHideMeaning) {
    final cardWidth = 320.0;
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
                        icon: Icon(widget.isSpeaking ? Icons.volume_off : Icons.volume_up, color: Colors.deepPurple),
                        onPressed: widget.isSpeaking ? null : widget.onSpeak,
                        tooltip: widget.isSpeaking ? '발음 중...' : '발음 듣기',
                      ),
                      // LOOP(무한반복) 버튼 (가운데)
                      widget.loopButton,
                      // 즐겨찾기(별) 아이콘
                      GestureDetector(
                        onTap: widget.onToggleFavorite,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.deepPurple[50],
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            widget.isFavorite ? Icons.star : Icons.star_border,
                            color: widget.isFavorite ? Colors.amber : Colors.deepPurple[200],
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // 영어단어(중앙) - 항상 검은색으로 표시
                  shouldHideWord && !widget.revealedWord
                      ? GestureDetector(
                          onTap: widget.onRevealWord,
                          child: Center(
                            child: SizedBox(
                              width: double.infinity,
                              height: wordFontSize * 1.15,
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
                            child: AutoSizeText(
                              widget.word,
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87, // 항상 검은색
                                    fontSize: wordFontSize,
                                    fontFamily: Theme.of(context).textTheme.displaySmall?.fontFamily,
                                  ) ?? TextStyle(fontSize: wordFontSize, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              minFontSize: 16,
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
                      widget.partOfSpeech,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.w600,
                            fontSize: posFontSize,
                          ) ?? TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600, fontSize: posFontSize),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 한글 뜻 - AutoSizeText 적용으로 긴 뜻도 한 줄에 표시
                  shouldHideMeaning && !widget.revealedMeaning
                      ? GestureDetector(
                          onTap: widget.onRevealMeaning,
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
                            child: AutoSizeText(
                              widget.meaning,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.black87,
                                    fontSize: meaningFontSize,
                                    fontFamily: Theme.of(context).textTheme.titleLarge?.fontFamily,
                                  ) ?? TextStyle(fontSize: meaningFontSize, color: Colors.black87),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              minFontSize: 12,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                  const Spacer(),
                  // 힌트(손가락+문구)
                  if (widget.showHint)
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
                  if (widget.showHint) const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 카드 뒷면 UI (예문, 한글 번역)
  Widget _buildBack(BuildContext context) {
    final cardWidth = 320.0;
    final wordFontSize = cardWidth * 0.15;
    final exampleFontSize = wordFontSize * 0.6; // 더 작게 조정
    final translationFontSize = exampleFontSize * 0.6; // 더 작게 조정
    
    return Container(
      key: const ValueKey(true),
      child: Stack(
        children: [
          Card(
            elevation: 8,
            margin: const EdgeInsets.all(0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            color: Colors.white.withValues(alpha: 0.97), // 거의 흰색에 가깝게
            child: Container(
              width: cardWidth,
              height: 420,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: Colors.deepPurple.withValues(alpha: 0.02), // 매우 연한 보라색
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // 상단 TTS 버튼 (예문 읽기)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // TTS(예문 읽기) 아이콘
                      IconButton(
                        icon: Icon(Icons.volume_up, color: Colors.deepPurple),
                        onPressed: widget.onSpeakSentence,
                        tooltip: '예문 듣기',
                      ),
                      const Spacer(),
                      // 즐겨찾기(별) 아이콘
                      GestureDetector(
                        onTap: widget.onToggleFavorite,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha: 0.1), // 더 연한 색상
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            widget.isFavorite ? Icons.star : Icons.star_border,
                            color: widget.isFavorite ? Colors.amber : Colors.deepPurple[200],
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 예문 표시 영역 (상단 60%)
                  Expanded(
                    flex: 6,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 영어 예문 - 단어 하이라이트 포함
                          if (widget.sentence != null && widget.sentence!.isNotEmpty)
                            SizedBox(
                              width: double.infinity,
                              child: AutoSizeText.rich(
                                TextSpan(children: _highlightWord(widget.sentence!, widget.word)),
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.black87,
                                      fontSize: exampleFontSize,
                                      fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
                                    ) ?? TextStyle(fontSize: exampleFontSize, color: Colors.black87),
                                textAlign: TextAlign.center,
                                maxLines: 4,
                                minFontSize: 8,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          else
                            Text(
                              '예문이 없습니다',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey[600],
                                    fontSize: exampleFontSize,
                                  ) ?? TextStyle(fontSize: exampleFontSize, color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 한글 번역 영역 (하단 40%)
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 한글 번역
                          if (widget.sentenceKor != null && widget.sentenceKor!.isNotEmpty)
                            SizedBox(
                              width: double.infinity,
                              child: AutoSizeText(
                                widget.sentenceKor!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.deepPurple,
                                      fontSize: translationFontSize,
                                      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                                    ) ?? TextStyle(fontSize: translationFontSize, color: Colors.deepPurple),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                minFontSize: 8,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 힌트(손가락+문구)
                  if (widget.showHint)
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
                  if (widget.showHint) const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 