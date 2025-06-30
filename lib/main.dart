import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  await Hive.openBox('favorites');
  // Firestore 오프라인 캐싱(퍼시스턴스) 활성화 (공식 가이드)
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SominWord',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    // TTS 옵션 미리 초기화
    flutterTts.setLanguage('en-US');
    flutterTts.setPitch(1.0);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterLogo(size: 80),
            SizedBox(height: 24),
            Text('SominWord', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

enum StudyMode { normal, hideMeaning, hideWord, randomHide }

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;
  List<Map<String, dynamic>> words = [];
  List<Map<String, dynamic>> todayWords = [];
  bool isLoading = true;
  String? errorMsg;
  final FlutterTts flutterTts = FlutterTts();
  late Box favoritesBox;
  StudyMode mode = StudyMode.normal;
  Set<int> revealedWordIndexes = {};
  Set<int> revealedMeaningIndexes = {};
  bool showTodayWords = false;
  bool isOffline = false;
  bool isSpeaking = false;

  @override
  void initState() {
    super.initState();
    favoritesBox = Hive.box('favorites');
    // TTS 옵션 미리 초기화
    flutterTts.setLanguage('en-US');
    flutterTts.setPitch(1.0);
    _fetchWords();
  }

  Future<void> _fetchWords() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
      isOffline = false;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('words')
          .orderBy('input_timestamp', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));
      words = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'word': data['english_word'] ?? '',
          'partOfSpeech': data['korean_part_of_speech'] ?? '',
          'meaning': data['korean_meaning'] ?? '',
          'input_timestamp': data['input_timestamp'],
        };
      }).toList();
      _filterTodayWords();
      currentIndex = 0;
    } catch (e) {
      // 네트워크 예외 발생 시 캐시 데이터 시도
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('words')
            .orderBy('input_timestamp', descending: true)
            .get(const GetOptions(source: Source.cache));
        words = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'word': data['english_word'] ?? '',
            'partOfSpeech': data['korean_part_of_speech'] ?? '',
            'meaning': data['korean_meaning'] ?? '',
            'input_timestamp': data['input_timestamp'],
          };
        }).toList();
        _filterTodayWords();
        currentIndex = 0;
        isOffline = true;
        errorMsg = '네트워크 연결이 불안정하여 오프라인 캐시 데이터로 표시합니다.';
      } catch (e2) {
        errorMsg = '단어 불러오기 실패(네트워크/캐시 모두 불가): $e';
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  void _filterTodayWords() {
    final now = DateTime.now();
    todayWords = words.where((w) {
      final ts = w['input_timestamp'];
      if (ts is Timestamp) {
        final d = ts.toDate();
        return d.year == now.year && d.month == now.month && d.day == now.day;
      } else if (ts is DateTime) {
        return ts.year == now.year && ts.month == now.month && ts.day == now.day;
      }
      return false;
    }).toList();
  }

  void _toggleTodayWords() {
    setState(() {
      showTodayWords = !showTodayWords;
      currentIndex = 0;
      revealedWordIndexes.clear();
      revealedMeaningIndexes.clear();
    });
  }

  Future<void> _speak(String text) async {
    if (isSpeaking) return;
    setState(() { isSpeaking = true; });
    try {
      await flutterTts.stop(); // 이전 발음 중지
      await flutterTts.speak(text);
    } finally {
      setState(() { isSpeaking = false; });
    }
  }

  bool isFavoriteWord(String word) {
    return favoritesBox.get(word, defaultValue: false) as bool;
  }

  void toggleFavorite(String word) {
    final current = isFavoriteWord(word);
    favoritesBox.put(word, !current);
    setState(() {});
  }

  void _showFavoritesDialog() {
    final favoriteWords = words
        .where((w) => isFavoriteWord(w['word'] as String))
        .toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('즐겨찾기 단어'),
        content: favoriteWords.isEmpty
            ? const Text('즐겨찾기한 단어가 없습니다.')
            : SizedBox(
                width: 250,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: favoriteWords.length,
                  itemBuilder: (context, idx) {
                    final w = favoriteWords[idx];
                    return ListTile(
                      title: Text(w['word'] ?? ''),
                      subtitle: Text('${w['partOfSpeech']} / ${w['meaning']}'),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void revealWord(int idx) {
    setState(() {
      revealedWordIndexes.add(idx);
    });
  }

  void revealMeaning(int idx) {
    setState(() {
      revealedMeaningIndexes.add(idx);
    });
  }

  void _showCalendarDialog() {
    // 단어별 날짜 추출
    final dateMap = <DateTime, List<int>>{};
    for (int i = 0; i < words.length; i++) {
      final ts = words[i]['input_timestamp'];
      if (ts is DateTime) {
        final date = DateTime(ts.year, ts.month, ts.day);
        dateMap.putIfAbsent(date, () => []).add(i);
      }
    }
    DateTime focusedDay = DateTime.now();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('날짜별 단어 이동'),
        content: SizedBox(
          width: 350,
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: focusedDay,
            calendarFormat: CalendarFormat.month,
            eventLoader: (day) {
              final d = DateTime(day.year, day.month, day.day);
              return dateMap[d] ?? [];
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
            onDaySelected: (selectedDay, focusedDay) {
              final d = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
              if (dateMap[d] != null && dateMap[d]!.isNotEmpty) {
                setState(() {
                  currentIndex = dateMap[d]!.last; // 최신 단어로 이동
                  revealedWordIndexes.clear();
                  revealedMeaningIndexes.clear();
                });
                Navigator.pop(ctx);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String word, String partOfSpeech, String meaning, int idx) {
    bool hideWord = false;
    bool hideMeaning = false;
    if (mode == StudyMode.hideMeaning) {
      hideMeaning = true;
    } else if (mode == StudyMode.hideWord) {
      hideWord = true;
    } else if (mode == StudyMode.randomHide) {
      final hide = (DateTime.now().millisecondsSinceEpoch % 2 == 0);
      if (hide) {
        hideWord = true;
      } else {
        hideMeaning = true;
      }
    }
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  onPressed: isSpeaking ? null : () => _speak(word),
                  tooltip: isSpeaking ? '발음 중...' : '발음 듣기',
                ),
                IconButton(
                  icon: Icon(isFavoriteWord(word) ? Icons.star : Icons.star_border),
                  color: isFavoriteWord(word) ? Colors.amber : Colors.grey,
                  onPressed: () => toggleFavorite(word),
                  tooltip: '즐겨찾기',
                ),
              ],
            ),
            const SizedBox(height: 16),
            hideWord && !revealedWordIndexes.contains(idx)
                ? GestureDetector(
                    onTap: () => revealWord(idx),
                    child: Container(
                      width: 120,
                      height: 48,
                      color: Colors.grey[300],
                      alignment: Alignment.center,
                      child: const Text('영단어 가림', style: TextStyle(fontSize: 20, color: Colors.grey)),
                    ),
                  )
                : Text(
                    word,
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                  ),
            const SizedBox(height: 12),
            Text(
              partOfSpeech,
              style: const TextStyle(fontSize: 18, color: Colors.blueGrey),
            ),
            const SizedBox(height: 8),
            hideMeaning && !revealedMeaningIndexes.contains(idx)
                ? GestureDetector(
                    onTap: () => revealMeaning(idx),
                    child: Container(
                      width: 120,
                      height: 32,
                      color: Colors.grey[300],
                      alignment: Alignment.center,
                      child: const Text('뜻 가림', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ),
                  )
                : Text(
                    meaning,
                    style: const TextStyle(fontSize: 24),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (errorMsg != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('SominWord'),
          actions: [
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: _toggleTodayWords,
              tooltip: '오늘의 단어',
            ),
          ],
        ),
        body: Center(child: Text(errorMsg!)),
      );
    }
    final list = showTodayWords ? todayWords : words;
    if (list.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('SominWord'),
          actions: [
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: _toggleTodayWords,
              tooltip: '오늘의 단어',
            ),
          ],
        ),
        body: Center(
          child: Text(showTodayWords ? '오늘 추가된 단어가 없습니다.' : '등록된 단어가 없습니다.'),
        ),
      );
    }
    final word = list[currentIndex]['word'] as String;
    final partOfSpeech = list[currentIndex]['partOfSpeech'] as String;
    final meaning = list[currentIndex]['meaning'] as String;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SominWord'),
        actions: [
          DropdownButton<StudyMode>(
            value: mode,
            underline: const SizedBox(),
            icon: const Icon(Icons.menu_book, color: Colors.white),
            dropdownColor: Colors.white,
            onChanged: (StudyMode? newMode) {
              if (newMode != null) setState(() => mode = newMode);
            },
            items: const [
              DropdownMenuItem(
                value: StudyMode.normal,
                child: Text('일반 모드'),
              ),
              DropdownMenuItem(
                value: StudyMode.hideMeaning,
                child: Text('뜻 가리기'),
              ),
              DropdownMenuItem(
                value: StudyMode.hideWord,
                child: Text('영단어 가리기'),
              ),
              DropdownMenuItem(
                value: StudyMode.randomHide,
                child: Text('랜덤 가리기'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _showCalendarDialog,
            tooltip: '캘린더',
          ),
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: _showFavoritesDialog,
            tooltip: '즐겨찾기 목록',
          ),
          IconButton(
            icon: Icon(showTodayWords ? Icons.list : Icons.today),
            onPressed: _toggleTodayWords,
            tooltip: showTodayWords ? '전체 단어 보기' : '오늘의 단어',
          ),
        ],
        bottom: isOffline
            ? PreferredSize(
                preferredSize: const Size.fromHeight(32),
                child: Container(
                  color: Colors.orange,
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  child: const Text(
                    '오프라인 모드: 캐시 데이터로 표시 중',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : null,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                child: GestureDetector(
                  key: ValueKey('$showTodayWords-$currentIndex'),
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity == null) return;
                    if (details.primaryVelocity! < 0) {
                      if (currentIndex < list.length - 1) setState(() => currentIndex++);
                    } else if (details.primaryVelocity! > 0) {
                      if (currentIndex > 0) setState(() => currentIndex--);
                    }
                    revealedWordIndexes.clear();
                    revealedMeaningIndexes.clear();
                  },
                  child: _buildCard(word, partOfSpeech, meaning, currentIndex),
                ),
              ),
            ),
            if (showTodayWords && list.length <= 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('오늘의 단어가 1개일 때는 스와이프가 제한됩니다.', style: TextStyle(color: Colors.grey)),
              ),
            if (showTodayWords)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.list),
                  label: const Text('전체 단어로 돌아가기'),
                  onPressed: _toggleTodayWords,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
