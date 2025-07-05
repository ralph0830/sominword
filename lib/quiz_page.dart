import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

class QuizPage extends StatefulWidget {
  final bool showAppBar;
  const QuizPage({super.key, this.showAppBar = true});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  String _lastWords = '';
  String _currentWord = '';
  String _currentMeaning = '';
  String _currentPartOfSpeech = '';
  List<Map<String, dynamic>> _words = [];
  int _currentIndex = 0;
  int _score = 0;
  int _totalQuestions = 0;
  bool _isQuizComplete = false;
  bool _isLoading = true;
  String _feedback = '';
  bool _showFeedback = false;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadWords();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.8);
  }

  Future<void> _loadWords() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('words')
          .orderBy('input_timestamp', descending: true)
          .limit(20) // 퀴즈용으로 20개 단어만 로드
          .get(const GetOptions(source: Source.serverAndCache));
      
      _words = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'word': data['english_word'] ?? '',
          'partOfSpeech': data['korean_part_of_speech'] ?? '',
          'meaning': data['korean_meaning'] ?? '',
        };
      }).toList();
      
      if (_words.isNotEmpty) {
        _setCurrentWord();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading words: $e');
      }
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  void _setCurrentWord() {
    if (_currentIndex < _words.length) {
      _currentWord = _words[_currentIndex]['word'];
      _currentMeaning = _words[_currentIndex]['meaning'];
      _currentPartOfSpeech = _words[_currentIndex]['partOfSpeech'];
    }
  }

  void _checkAnswer() {
    final userAnswer = _lastWords.toLowerCase().trim();
    final correctAnswer = _currentWord.toLowerCase().trim();
    
    bool isCorrect = false;
    
    // 정확한 매칭 또는 유사한 발음 허용
    if (userAnswer == correctAnswer) {
      isCorrect = true;
    } else {
      // 유사한 발음 체크 (간단한 유사도 검사)
      isCorrect = _checkSimilarity(userAnswer, correctAnswer);
    }

    setState(() {
      if (isCorrect) {
        _score++;
        _feedback = '정답입니다! 🎉';
      } else {
        _feedback = '틀렸습니다. 정답: $_currentWord';
      }
      _totalQuestions++;
      _showFeedback = true;
    });

    // 2초 후 다음 문제로
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  bool _checkSimilarity(String userAnswer, String correctAnswer) {
    // 간단한 유사도 검사 (실제로는 더 정교한 알고리즘 사용 가능)
    if (userAnswer.length < 3 || correctAnswer.length < 3) {
      return userAnswer == correctAnswer;
    }
    
    // 레벤슈타인 거리 기반 유사도
    int distance = _levenshteinDistance(userAnswer, correctAnswer);
    int maxLength = userAnswer.length > correctAnswer.length 
        ? userAnswer.length 
        : correctAnswer.length;
    
    double similarity = 1.0 - (distance / maxLength);
    return similarity >= 0.7; // 70% 이상 유사하면 정답으로 인정
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.filled(s2.length + 1, 0);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i <= s2.length; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((a, b) => a < b ? a : b);
      }

      List<int> temp = v0;
      v0 = v1;
      v1 = temp;
    }

    return v0[s2.length];
  }

  void _nextQuestion() {
    setState(() {
      _currentIndex++;
      _showFeedback = false;
      _lastWords = '';
      _textController.clear();
    });

    if (_currentIndex >= _words.length) {
      _completeQuiz();
    } else {
      _setCurrentWord();
    }
  }

  void _completeQuiz() {
    setState(() {
      _isQuizComplete = true;
    });
  }

  void _restartQuiz() {
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _totalQuestions = 0;
      _isQuizComplete = false;
      _showFeedback = false;
      _lastWords = '';
      _textController.clear();
    });
    _setCurrentWord();
  }

  Future<void> _playWord() async {
    await _flutterTts.speak(_currentWord);
  }

  void _submitAnswer() {
    if (_textController.text.trim().isNotEmpty) {
      setState(() {
        _lastWords = _textController.text.trim();
      });
      _checkAnswer();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget quizBody;
    if (_isLoading) {
      quizBody = const Center(child: CircularProgressIndicator());
    } else if (_words.isEmpty) {
      quizBody = const Center(child: Text('퀴즈할 단어가 없습니다.'));
    } else if (_isQuizComplete) {
      quizBody = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration, size: 80, color: Colors.amber),
            const SizedBox(height: 24),
            Text(
              '퀴즈 완료!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              '점수: $_score / $_totalQuestions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _restartQuiz,
              child: const Text('다시 시작'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('돌아가기'),
            ),
          ],
        ),
      );
    } else {
      quizBody = Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // 진행률 표시
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _words.length,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 24),
            // 점수 표시
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('점수: $_score', style: const TextStyle(fontSize: 18)),
                Text('정답률: ${_totalQuestions > 0 ? ((_score / _totalQuestions) * 100).round() : 0}%',
                    style: const TextStyle(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 32),
            // 문제 카드
            Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('이 단어를 입력하세요:'),
                        IconButton(
                          icon: const Icon(Icons.volume_up),
                          onPressed: _playWord,
                          tooltip: '정답 발음 듣기',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _currentMeaning,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentPartOfSpeech,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // 웹용 텍스트 입력
            if (kIsWeb) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        labelText: '영어 단어를 입력하세요',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _submitAnswer(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _submitAnswer,
                    child: const Text('정답 확인'),
                  ),
                ],
              ),
            ] else ...[
              // 모바일용 음성 인식 버튼
              GestureDetector(
                onTapDown: (_) => setState(() => _isListening = true),
                onTapUp: (_) => setState(() => _isListening = false),
                onTapCancel: () => setState(() => _isListening = false),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? Colors.red : Colors.blue,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isListening ? '말씀해주세요...' : '마이크를 길게 눌러 발음하세요',
                style: const TextStyle(fontSize: 16),
              ),
            ],
            const SizedBox(height: 16),
            // 입력된 답안 표시
            if (_lastWords.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text('입력한 답안:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      _lastWords,
                      style: const TextStyle(fontSize: 18, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // 피드백 메시지
            if (_showFeedback)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _feedback.contains('정답') ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _feedback,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _feedback.contains('정답') ? Colors.green : Colors.red,
                  ),
                ),
              ),
            const Spacer(),
            // 웹에서는 힌트 표시
            if (kIsWeb)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '💡 웹에서는 텍스트 입력으로 퀴즈를 진행합니다.\n모바일 앱에서는 음성 인식 기능을 사용할 수 있습니다.',
                  style: TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    }

    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('발음 퀴즈'),
          actions: [
            if (!_isLoading && _words.isNotEmpty && !_isQuizComplete)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '${_currentIndex + 1} / ${_words.length}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
        body: quizBody,
      );
    } else {
      return quizBody;
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _textController.dispose();
    super.dispose();
  }
} 