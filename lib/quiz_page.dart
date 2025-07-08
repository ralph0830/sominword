import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuizPage extends StatefulWidget {
  final bool showAppBar;
  final List<Map<String, dynamic>> words;
  const QuizPage({super.key, this.showAppBar = true, required this.words});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
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
    _initSpeech();
    _initQuizWords();
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (kDebugMode) debugPrint('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (err) {
        if (kDebugMode) debugPrint('Speech error: $err');
        setState(() => _isListening = false);
      },
    );
    setState(() {});
  }

  void _initQuizWords() {
    final allWords = List<Map<String, dynamic>>.from(widget.words);
    if (allWords.isEmpty) {
      setState(() {
        _words = [];
        _isLoading = false;
      });
      return;
    }
    allWords.sort((a, b) {
      final at = a['input_timestamp'];
      final bt = b['input_timestamp'];
      DateTime ad, bd;
      if (at is DateTime) {
        ad = at;
      } else if (at is Timestamp) {
        ad = at.toDate();
      } else {
        ad = DateTime(2000);
      }
      if (bt is DateTime) {
        bd = bt;
      } else if (bt is Timestamp) {
        bd = bt.toDate();
      } else {
        bd = DateTime(2000);
      }
      return bd.compareTo(ad);
    });
    List<Map<String, dynamic>> weighted = [];
    for (int i = 0; i < allWords.length; i++) {
      int weight = 1;
      if (i < 5) {
        weight = 3;
      } else if (i < 10) {
        weight = 2;
      }
      for (int j = 0; j < weight; j++) {
        weighted.add(allWords[i]);
      }
    }
    weighted.shuffle();
    final Set<String> used = {};
    List<Map<String, dynamic>> quizWords = [];
    for (final w in weighted) {
      final key = (w['word'] ?? '') + (w['meaning'] ?? '');
      if (!used.contains(key)) {
        quizWords.add(w);
        used.add(key);
      }
      if (quizWords.length >= 20) break;
    }
    if (quizWords.length < 20) {
      for (final w in allWords) {
        final key = (w['word'] ?? '') + (w['meaning'] ?? '');
        if (!used.contains(key)) {
          quizWords.add(w);
          used.add(key);
        }
        if (quizWords.length >= 20) break;
      }
    }
    setState(() {
      _words = quizWords;
      _isLoading = false;
    });
    if (quizWords.isNotEmpty) {
      _setCurrentWord();
    }
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
    
    if (userAnswer == correctAnswer) {
      isCorrect = true;
    } else {
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

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  bool _checkSimilarity(String userAnswer, String correctAnswer) {
    if (userAnswer.length < 3 || correctAnswer.length < 3) {
      return userAnswer == correctAnswer;
    }
    
    int distance = _levenshteinDistance(userAnswer, correctAnswer);
    int maxLength = userAnswer.length > correctAnswer.length 
        ? userAnswer.length 
        : correctAnswer.length;
    
    double similarity = 1.0 - (distance / maxLength);
    return similarity >= 0.7;
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

  void _submitAnswer() {
    if (_textController.text.trim().isNotEmpty) {
      setState(() {
        _lastWords = _textController.text.trim();
      });
      _checkAnswer();
    }
  }

  void _startListening() async {
    if (!_speechAvailable) return;
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
          _textController.text = _lastWords;
        });
      },
      localeId: 'en_US',
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
      ),
    );
  }

  void _stopListening() async {
    if (!_speechAvailable) return;
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<bool> _checkMicPermissionAndRequest(BuildContext context) async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isDenied || status.isPermanentlyDenied || status.isRestricted) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('마이크 권한 필요'),
            content: const Text('음성 인식 기능을 사용하려면 마이크 권한이 필요합니다.\n설정에서 권한을 허용해 주세요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await openAppSettings();
                },
                child: const Text('설정으로 이동'),
              ),
            ],
          ),
        );
      }
      return false;
    }
    var result = await Permission.microphone.request();
    return result.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final safePadding = MediaQuery.of(context).viewPadding;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final usableHeight = height - safePadding.top - safePadding.bottom - viewInsets.bottom;
    Widget quizBody;
    if (_isLoading) {
      quizBody = const Center(child: CircularProgressIndicator());
    } else if (_words.isEmpty) {
      quizBody = const Center(child: Text('퀴즈할 단어가 없습니다.'));
    } else if (_isQuizComplete) {
      quizBody = Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: usableHeight * 0.8,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: usableHeight * 0.05),
                const Icon(Icons.celebration, size: 80, color: Colors.amber),
                SizedBox(height: usableHeight * 0.03),
                Text(
                  '퀴즈 완료!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                SizedBox(height: usableHeight * 0.02),
                Text(
                  '점수:  [38;5;2m$_score [0m / $_totalQuestions',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: usableHeight * 0.03),
                SizedBox(
                  width: width * 0.7,
                  child: ElevatedButton(
                    onPressed: _restartQuiz,
                    child: const Text('다시 시작'),
                  ),
                ),
                SizedBox(height: usableHeight * 0.02),
                SizedBox(
                  width: width * 0.7,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('돌아가기'),
                  ),
                ),
                SizedBox(height: usableHeight * 0.05),
              ],
            ),
          ),
        ),
      );
    } else {
      quizBody = LayoutBuilder(
        builder: (context, constraints) {
          final maxH = constraints.maxHeight;
          return SingleChildScrollView(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: maxH),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: usableHeight * 0.02),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width * 0.08),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _words.length,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        minHeight: usableHeight * 0.012,
                      ),
                    ),
                    SizedBox(height: usableHeight * 0.02),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width * 0.08),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('점수: $_score', style: TextStyle(fontSize: usableHeight * 0.025)),
                          Text('정답률: ${_totalQuestions > 0 ? ((_score / _totalQuestions) * 100).round() : 0}%',
                              style: TextStyle(fontSize: usableHeight * 0.025)),
                        ],
                      ),
                    ),
                    SizedBox(height: usableHeight * 0.03),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width * 0.04),
                      child: Card(
                        elevation: 8,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: usableHeight * 0.04,
                            horizontal: width * 0.04,
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('이 단어를 입력하세요:', style: TextStyle(fontSize: usableHeight * 0.022)),
                                ],
                              ),
                              SizedBox(height: usableHeight * 0.02),
                              Text(
                                _currentMeaning,
                                style: TextStyle(fontSize: usableHeight * 0.035, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: usableHeight * 0.01),
                              Text(
                                _currentPartOfSpeech,
                                style: TextStyle(fontSize: usableHeight * 0.022, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: usableHeight * 0.03),
                    Center(
                      child: GestureDetector(
                        onTapDown: (_) async {
                          if (await _checkMicPermissionAndRequest(context)) {
                            _startListening();
                          }
                        },
                        onTapUp: (_) => _stopListening(),
                        onTapCancel: () => _stopListening(),
                        child: Container(
                          width: width * 0.18,
                          height: width * 0.18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening ? Colors.red : (_speechAvailable ? Colors.blue : Colors.grey),
                          ),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            size: width * 0.11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: usableHeight * 0.025),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width * 0.08),
                      child: Column(
                        children: [
                          SizedBox(
                            height: usableHeight * 0.07,
                            child: TextField(
                              controller: _textController,
                              decoration: const InputDecoration(
                                labelText: '영어 단어를 입력하거나 마이크로 발음하세요',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                setState(() {
                                  _lastWords = v;
                                });
                              },
                              onTap: () {},
                            ),
                          ),
                          SizedBox(height: usableHeight * 0.015),
                          SizedBox(
                            width: double.infinity,
                            height: usableHeight * 0.065,
                            child: ElevatedButton(
                              onPressed: _textController.text.trim().isEmpty || _showFeedback ? null : _submitAnswer,
                              child: const Text('제출'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: usableHeight * 0.02),
                    if (_showFeedback)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: width * 0.08),
                        child: Container(
                          padding: EdgeInsets.all(usableHeight * 0.018),
                          decoration: BoxDecoration(
                            color: _feedback.contains('정답') ? Colors.green[50] : Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _feedback,
                            style: TextStyle(
                              fontSize: usableHeight * 0.025,
                              fontWeight: FontWeight.bold,
                              color: _feedback.contains('정답') ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ),
                    SizedBox(height: usableHeight * 0.01),
                    if (kIsWeb)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: width * 0.08),
                        child: Container(
                          padding: EdgeInsets.all(usableHeight * 0.018),
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
                      ),
                    SizedBox(height: usableHeight * 0.03),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    if (widget.showAppBar) {
      return Scaffold(
        resizeToAvoidBottomInset: true,
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
    _textController.dispose();
    super.dispose();
  }
} 