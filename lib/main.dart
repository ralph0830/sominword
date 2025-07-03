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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SominWord',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        // Material 3 디자인 시스템 적용
        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // 접근성 개선
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
        ),
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
    
    if (mounted) {
      setState(() {
        deviceId = id;
        isDeviceRegistered = isRegistered;
      });
    }

    // 3초 후 처리
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    
    if (isRegistered) {
      // 기기가 등록되어 있으면 ownerEmail 체크 수행
      final hasValidOwner = await firebaseService.checkAndCleanupWordsIfNoOwner();
      
      if (hasValidOwner) {
        // ownerEmail이 있으면 앱으로 이동
        _proceedToApp();
      } else {
        // ownerEmail이 없으면 기기 ID 화면 표시 (승인 대기 중)
        if (mounted) {
          setState(() {
            showDeviceId = true;
          });
        }
      }
    } else {
      // 기기가 등록되어 있지 않으면 기기 ID 화면 표시
      if (mounted) {
        setState(() {
          showDeviceId = true;
        });
      }
    }
  }

  void _copyDeviceId() {
    if (deviceId != null) {
      Clipboard.setData(ClipboardData(text: deviceId!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('기기 고유번호가 클립보드에 복사되었습니다.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
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
      return const _SplashLoadingView();
    }

    return _DeviceIdView(
      deviceId: deviceId,
      onCopyDeviceId: _copyDeviceId,
      onProceedToApp: _proceedToApp,
    );
  }
}

class _SplashLoadingView extends StatelessWidget {
  const _SplashLoadingView();

  @override
  Widget build(BuildContext context) {
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
              Text(
                'SominWord',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '영어 단어 학습 앱',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                  shadows: const [
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
}

class _DeviceIdView extends StatelessWidget {
  const _DeviceIdView({
    required this.deviceId,
    required this.onCopyDeviceId,
    required this.onProceedToApp,
  });

  final String? deviceId;
  final VoidCallback onCopyDeviceId;
  final VoidCallback onProceedToApp;

  @override
  Widget build(BuildContext context) {
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
                Text(
                  '기기 고유번호',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    shadows: const [
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
                          FilledButton.icon(
                            onPressed: onCopyDeviceId,
                            icon: const Icon(Icons.copy),
                            label: const Text('복사'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: onProceedToApp,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('앱 시작'),
                            style: FilledButton.styleFrom(
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              ),
              child: Text(
                deviceId ?? '로딩 중...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
          FilledButton.icon(
            onPressed: () {
              if (deviceId != null) {
                Clipboard.setData(ClipboardData(text: deviceId!));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('기기 고유번호가 클립보드에 복사되었습니다.'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
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
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      errorMsg = null;
      isOffline = false;
    });
    
    final firebaseService = FirebaseService();
    
    try {
      // 기기별 단어 조회
      final snapshot = await firebaseService.getWordsStream().first;
      
      if (!mounted) return;
      
      words = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        final word = data['englishWord'] ?? data['english_word'] ?? '';
        final partOfSpeech = data['koreanPartOfSpeech'] ?? data['korean_part_of_speech'] ?? '';
        final meaning = data['koreanMeaning'] ?? data['korean_meaning'] ?? '';
        final timestamp = data['inputTimestamp'] ?? data['input_timestamp'];
        final isFavorite = data['isFavorite'] ?? data['is_favorite'] ?? false;
        
        return {
          'id': doc.id,
          'word': word,
          'partOfSpeech': partOfSpeech,
          'meaning': meaning,
          'input_timestamp': timestamp,
          'isFavorite': isFavorite,
        };
      }).toList();
      
      _filterTodayWords();
      currentIndex = 0;
    } catch (e) {
      // 네트워크 예외 발생 시 캐시 데이터 시도
      try {
        final snapshot = await firebaseService.getWordsStream().first;
        
        if (!mounted) return;
        
        words = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          final word = data['englishWord'] ?? data['english_word'] ?? '';
          final partOfSpeech = data['koreanPartOfSpeech'] ?? data['korean_part_of_speech'] ?? '';
          final meaning = data['koreanMeaning'] ?? data['korean_meaning'] ?? '';
          final timestamp = data['inputTimestamp'] ?? data['input_timestamp'];
          final isFavorite = data['isFavorite'] ?? data['is_favorite'] ?? false;
          
          return {
            'id': doc.id,
            'word': word,
            'partOfSpeech': partOfSpeech,
            'meaning': meaning,
            'input_timestamp': timestamp,
            'isFavorite': isFavorite,
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
    
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
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
    if (isSpeaking || !mounted) return;
    
    setState(() { isSpeaking = true; });
    
    try {
      await flutterTts.stop(); // 이전 발음 중지
      await flutterTts.speak(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('발음 재생 중 오류가 발생했습니다.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { isSpeaking = false; });
      }
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
        content: SizedBox(
          width: 300,
          child: favoriteWords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_border,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '즐겨찾기한 단어가 없습니다.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: favoriteWords.length,
                  itemBuilder: (context, idx) {
                    final w = favoriteWords[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.star, color: Colors.amber),
                        title: Text(
                          w['word'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${w['partOfSpeech']} / ${w['meaning']}'),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          FilledButton(
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
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
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
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                }
                return null;
              },
              selectedBuilder: (context, day, focusedDay) {
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
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
          FilledButton(
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
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  icon: Icon(isSpeaking ? Icons.volume_off : Icons.volume_up),
                  onPressed: isSpeaking ? null : () => _speak(word),
                  tooltip: isSpeaking ? '발음 중...' : '발음 듣기',
                ),
                IconButton.filledTonal(
                  icon: Icon(isFavoriteWord(word) ? Icons.star : Icons.star_border),
                  onPressed: () => toggleFavorite(word),
                  tooltip: '즐겨찾기',
                  style: IconButton.styleFrom(
                    foregroundColor: isFavoriteWord(word) ? Colors.amber : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            hideWord && !revealedWordIndexes.contains(idx)
                ? GestureDetector(
                    onTap: () => revealWord(idx),
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '영단어 가림',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : Semantics(
                    label: '영어 단어: $word',
                    child: Text(
                      word,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                partOfSpeech,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            hideMeaning && !revealedMeaningIndexes.contains(idx)
                ? GestureDetector(
                    onTap: () => revealMeaning(idx),
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '뜻 가림',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : Semantics(
                    label: '한글 뜻: $meaning',
                    child: Text(
                      meaning,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '단어를 불러오는 중...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (errorMsg != null) {
      return Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: _onTitleTap,
            child: Text(
              'SominWord',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: _toggleTodayWords,
              tooltip: '오늘의 단어',
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  '오류가 발생했습니다',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMsg!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _fetchWords,
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final list = showTodayWords ? todayWords : words;
    if (list.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: _onTitleTap,
            child: Text(
              'SominWord',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: _toggleTodayWords,
              tooltip: '오늘의 단어',
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                showTodayWords ? Icons.today : Icons.book,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                showTodayWords ? '오늘 추가된 단어가 없습니다.' : '등록된 단어가 없습니다.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                showTodayWords 
                    ? '관리자 페이지에서 오늘 단어를 추가해보세요.'
                    : '관리자 페이지에서 단어를 추가해보세요.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
          child: Text(
            'SominWord',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        actions: [
          PopupMenuButton<StudyMode>(
            icon: const Icon(Icons.menu_book),
            tooltip: '학습 모드',
            onSelected: (StudyMode newMode) {
              setState(() => mode = newMode);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: StudyMode.normal,
                child: Row(
                  children: [
                    Icon(Icons.visibility),
                    SizedBox(width: 8),
                    Text('일반 모드'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: StudyMode.hideMeaning,
                child: Row(
                  children: [
                    Icon(Icons.visibility_off),
                    SizedBox(width: 8),
                    Text('뜻 가리기'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: StudyMode.hideWord,
                child: Row(
                  children: [
                    Icon(Icons.visibility_off),
                    SizedBox(width: 8),
                    Text('영단어 가리기'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: StudyMode.randomHide,
                child: Row(
                  children: [
                    Icon(Icons.shuffle),
                    SizedBox(width: 8),
                    Text('랜덤 가리기'),
                  ],
                ),
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
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '오프라인 모드: 캐시 데이터로 표시 중',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
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
                child: FilledButton.icon(
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
