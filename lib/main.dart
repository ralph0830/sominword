import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'services/device_id_service.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  await Hive.openBox('favorites');
  // Firestore 오프라인 캐싱(퍼시스턴스) 활성화 (공식 가이드)
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  
  // 기기 ID 초기화 및 기기 정보 저장
  final deviceIdService = DeviceIdService();
  final firebaseService = FirebaseService();
  await deviceIdService.getDeviceId(); // 기기 ID 생성/확인
  await firebaseService.saveDeviceInfo(); // 기기 정보를 Firebase에 저장
  
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
  String? deviceId;
  bool showDeviceId = false;
  bool isDeviceRegistered = false;

  @override
  void initState() {
    super.initState();
    // TTS 옵션 미리 초기화
    flutterTts.setLanguage('en-US');
    flutterTts.setPitch(1.0);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 기기 ID 가져오기
    final deviceIdService = DeviceIdService();
    final firebaseService = FirebaseService();
    final id = await deviceIdService.getDeviceId();
    
    // 기기가 등록되어 있는지 확인
    final isRegistered = await firebaseService.isDeviceRegistered();
    
    setState(() {
      deviceId = id;
      isDeviceRegistered = isRegistered;
    });

    // 3초 후 처리
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    
    if (isRegistered) {
      // 기기가 등록되어 있으면 바로 앱으로 이동
      _proceedToApp();
    } else {
      // 기기가 등록되어 있지 않으면 기기 ID 화면 표시
      setState(() {
        showDeviceId = true;
      });
    }
  }

  void _copyDeviceId() {
    if (deviceId != null) {
      Clipboard.setData(ClipboardData(text: deviceId!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('기기 고유번호가 클립보드에 복사되었습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _proceedToApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!showDeviceId) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue, Colors.purple],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.contain,
                      width: 120,
                      height: 120,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'SominWord',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 2),
                        blurRadius: 4,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '영어 단어 학습 앱',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.purple],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.contain,
                      width: 100,
                      height: 100,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '기기 고유번호',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 2),
                        blurRadius: 4,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '관리자 페이지 접속 시 이 번호가 필요합니다.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.blue.withValues(alpha: 0.1),
                  ),
                  child: Column(
                    children: [
                      Text(
                        deviceId ?? '로딩 중...',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _copyDeviceId,
                            icon: const Icon(Icons.copy),
                            label: const Text('복사'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _proceedToApp,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('앱 시작'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '💡 관리자 페이지에서 이 번호를 입력하여\n단어를 추가/수정할 수 있습니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white60,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
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
  
  // 앱 제목 클릭 관련 변수
  int titleClickCount = 0;
  String? deviceId;

  @override
  void initState() {
    super.initState();
    favoritesBox = Hive.box('favorites');
    // TTS 옵션 미리 초기화
    flutterTts.setLanguage('en-US');
    flutterTts.setPitch(1.0);
    _loadDeviceId();
    _fetchWords();
  }

  Future<void> _loadDeviceId() async {
    final deviceIdService = DeviceIdService();
    final id = await deviceIdService.getDeviceId();
    setState(() {
      deviceId = id;
    });
  }

  void _onTitleTap() {
    setState(() {
      titleClickCount++;
    });
    
    if (titleClickCount >= 5) {
      _showDeviceIdDialog();
      titleClickCount = 0; // 리셋
    }
    
    // 3초 후 클릭 카운트 리셋
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && titleClickCount > 0) {
        setState(() {
          titleClickCount = 0;
        });
      }
    });
  }

  void _showDeviceIdDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기기 고유번호'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('관리자 페이지 접속 시 이 번호가 필요합니다.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 1),
                borderRadius: BorderRadius.circular(8),
                color: Colors.blue.withValues(alpha: 0.1),
              ),
              child: Text(
                deviceId ?? '로딩 중...',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
                      ElevatedButton.icon(
              onPressed: () {
                if (deviceId != null) {
                  Clipboard.setData(ClipboardData(text: deviceId!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('기기 고유번호가 클립보드에 복사되었습니다.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.copy),
              label: const Text('복사'),
            ),
        ],
      ),
    );
  }

  Future<void> _fetchWords() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
      isOffline = false;
    });
    
    final firebaseService = FirebaseService();
    
    try {
      debugPrint('🔍 [DEBUG] 단어 조회 시작...');
      
      // 기기별 단어 조회
      final snapshot = await firebaseService.getWordsStream().first;
      debugPrint('🔍 [DEBUG] Firestore에서 ${snapshot.docs.length}개 문서 조회됨');
      
      words = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        debugPrint('🔍 [DEBUG] 문서 ID: ${doc.id}');
        debugPrint('🔍 [DEBUG] 문서 데이터: $data');
        debugPrint('🔍 [DEBUG] 문서 키들: ${data.keys.toList()}');
        
        final word = data['englishWord'] ?? data['english_word'] ?? '';
        final partOfSpeech = data['koreanPartOfSpeech'] ?? data['korean_part_of_speech'] ?? '';
        final meaning = data['koreanMeaning'] ?? data['korean_meaning'] ?? '';
        final timestamp = data['inputTimestamp'] ?? data['input_timestamp'];
        final isFavorite = data['isFavorite'] ?? data['is_favorite'] ?? false;
        
        debugPrint('🔍 [DEBUG] 파싱 결과 - 영어: "$word", 품사: "$partOfSpeech", 뜻: "$meaning"');
        
        return {
          'id': doc.id,
          'word': word,
          'partOfSpeech': partOfSpeech,
          'meaning': meaning,
          'input_timestamp': timestamp,
          'isFavorite': isFavorite,
        };
      }).toList();
      
      debugPrint('🔍 [DEBUG] 최종 단어 목록: ${words.length}개');
      if (words.isNotEmpty) {
        debugPrint('🔍 [DEBUG] 첫 번째 단어: ${words.first}');
      }
      
      _filterTodayWords();
      currentIndex = 0;
    } catch (e) {
      debugPrint('🔍 [DEBUG] 단어 조회 실패: $e');
      
      // 네트워크 예외 발생 시 캐시 데이터 시도
      try {
        debugPrint('🔍 [DEBUG] 캐시 데이터 시도 중...');
        final snapshot = await firebaseService.getWordsStream().first;
        debugPrint('🔍 [DEBUG] 캐시에서 ${snapshot.docs.length}개 문서 조회됨');
        
        words = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          debugPrint('🔍 [DEBUG] 캐시 문서 ID: ${doc.id}');
          debugPrint('🔍 [DEBUG] 캐시 문서 데이터: $data');
          
          final word = data['englishWord'] ?? data['english_word'] ?? '';
          final partOfSpeech = data['koreanPartOfSpeech'] ?? data['korean_part_of_speech'] ?? '';
          final meaning = data['koreanMeaning'] ?? data['korean_meaning'] ?? '';
          final timestamp = data['inputTimestamp'] ?? data['input_timestamp'];
          final isFavorite = data['isFavorite'] ?? data['is_favorite'] ?? false;
          
          debugPrint('🔍 [DEBUG] 캐시 파싱 결과 - 영어: "$word", 품사: "$partOfSpeech", 뜻: "$meaning"');
          
          return {
            'id': doc.id,
            'word': word,
            'partOfSpeech': partOfSpeech,
            'meaning': meaning,
            'input_timestamp': timestamp,
            'isFavorite': isFavorite,
          };
        }).toList();
        
        debugPrint('🔍 [DEBUG] 캐시 최종 단어 목록: ${words.length}개');
        
        _filterTodayWords();
        currentIndex = 0;
        isOffline = true;
        errorMsg = '네트워크 연결이 불안정하여 오프라인 캐시 데이터로 표시합니다.';
      } catch (e2) {
        debugPrint('🔍 [DEBUG] 캐시 데이터도 실패: $e2');
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
        .where((w) => isFavoriteWord(w['word'] as String? ?? ''))
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
          title: GestureDetector(
            onTap: _onTitleTap,
            child: const Text('SominWord'),
          ),
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
          title: GestureDetector(
            onTap: _onTitleTap,
            child: const Text('SominWord'),
          ),
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
    final word = list[currentIndex]['word'] as String? ?? '';
    final partOfSpeech = list[currentIndex]['partOfSpeech'] as String? ?? '';
    final meaning = list[currentIndex]['meaning'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onTitleTap,
          child: const Text('SominWord'),
        ),
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
