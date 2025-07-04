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

// 카드 UI 분리: WordCard 위젯(최상위 레벨)
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
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, anim) {
        // 항상 오른쪽에서 왼쪽으로 슬라이드
        final beginOffset = const Offset(1, 0);
        final endOffset = Offset.zero;
        return SlideTransition(
          position: anim.drive(Tween<Offset>(begin: beginOffset, end: endOffset).chain(CurveTween(curve: Curves.ease))),
          child: child,
        );
      },
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: _buildFront(context),
    );
  }

  Widget _buildFront(BuildContext context) {
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
              width: 320,
              height: 420,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // 상단 아이콘 Row (TTS, 별)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // TTS(발음) 아이콘
                      IconButton(
                        icon: Icon(isSpeaking ? Icons.volume_off : Icons.volume_up, color: Colors.deepPurple),
                        onPressed: isSpeaking ? null : onSpeak,
                        tooltip: isSpeaking ? '발음 중...' : '발음 듣기',
                      ),
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
                  Text(
                    word,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ) ?? const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
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
                          ) ?? const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 한글 뜻
                  Text(
                    meaning,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.black87,
                        ) ?? const TextStyle(fontSize: 20, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  // 플립 안내 아이콘
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
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  await firebaseService.saveDeviceInfoIfNotExists(); // 기기 정보를 Firebase에 저장 (존재하지 않을 때만 등록)
  
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
  int deviceStatus = 0; // 0: 미등록, 1: 승인대기, 2: 정상

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
    
    // 기기 등록 상태 확인
    final status = await firebaseService.getDeviceRegistrationStatus();
    
    if (mounted) {
      setState(() {
        deviceId = id;
        deviceStatus = status;
        isDeviceRegistered = status > 0;
      });
    }

    // 3초 후 처리
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    
    if (status == 2) {
      // 기기가 등록되고 ownerEmail이 있으면 앱으로 이동
      _proceedToApp();
    } else {
      // 기기가 등록되지 않았거나 승인 대기 중이면 기기 ID 화면 표시
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
      deviceStatus: deviceStatus,
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
    required this.deviceStatus,
    required this.onCopyDeviceId,
    required this.onProceedToApp,
  });

  final String? deviceId;
  final int deviceStatus;
  final VoidCallback onCopyDeviceId;
  final VoidCallback onProceedToApp;

  String _getStatusMessage() {
    switch (deviceStatus) {
      case 0:
        return '기기가 등록되지 않았습니다.';
      case 1:
        return '승인 대기 중입니다.';
      case 2:
        return '기기가 정상 등록되었습니다.';
      default:
        return '알 수 없는 상태입니다.';
    }
  }

  Color _getBorderColor() {
    switch (deviceStatus) {
      case 0:
        return Colors.red;
      case 1:
        return Colors.yellow;
      case 2:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getHelpMessage() {
    switch (deviceStatus) {
      case 0:
        return '관리자 페이지에서 기기를 등록해주세요.';
      case 1:
        return '관리자 페이지에서 승인을 기다리고 있습니다.';
      case 2:
        return '관리자 페이지에서 이 번호를 입력하여 단어를 추가/수정할 수 있습니다.';
      default:
        return '도움말을 찾을 수 없습니다.';
    }
  }

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
                Text(
                  _getStatusMessage(),
                  style: const TextStyle(
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
                    border: Border.all(color: _getBorderColor(), width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: _getBorderColor().withValues(alpha: 0.1),
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
                          if (deviceStatus == 2) ...[
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
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _getHelpMessage(),
                  style: const TextStyle(
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
  int prevIndex = 0; // 이전 인덱스 저장
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
  int deviceStatus = 0; // 0: 미등록, 1: 승인대기, 2: 정상
  int _selectedTab = 0; // 0: 단어장, 1: Quiz, 2: 즐겨찾기

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

  IconData _getErrorIcon() {
    switch (deviceStatus) {
      case 0:
        return Icons.device_unknown;
      case 1:
        return Icons.pending;
      default:
        return Icons.error_outline;
    }
  }

  Color _getErrorColor() {
    switch (deviceStatus) {
      case 0:
        return Colors.red;
      case 1:
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.error;
    }
  }

  String _getErrorTitle() {
    switch (deviceStatus) {
      case 0:
        return '기기 등록 필요';
      case 1:
        return '승인 대기 중';
      default:
        return '오류가 발생했습니다';
    }
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
      // 기기 등록 상태 확인
      final status = await firebaseService.getDeviceRegistrationStatus();
      
      if (!mounted) return;
      
      setState(() {
        deviceStatus = status;
      });
      
      // 기기 상태에 따른 처리
      if (status == 0) {
        // 기기가 등록되지 않음
        setState(() {
          isLoading = false;
          errorMsg = '기기 등록이 필요합니다.';
          words = [];
          todayWords = [];
        });
        return;
      } else if (status == 1) {
        // 기기가 등록되었지만 ownerEmail이 없음 (승인 대기 중)
        setState(() {
          isLoading = false;
          errorMsg = '기기 등록이 되었습니다. 관리자 승인이 필요합니다.';
          words = [];
          todayWords = [];
        });
        return;
      }
      
      // status == 2인 경우에만 단어 조회 진행
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
      DateTime? date;
      if (ts is DateTime) {
        date = DateTime(ts.year, ts.month, ts.day);
      } else if (ts is Timestamp) {
        final d = ts.toDate();
        date = DateTime(d.year, d.month, d.day);
      }
      if (date != null) {
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
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final d = DateTime(day.year, day.month, day.day);
                final count = dateMap[d]?.length ?? 0;
                debugPrint('[캘린더] $d: $count개');
                return Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 18, // 날짜 글씨 크게
                            fontWeight: FontWeight.bold,
                            color: count > 0 ? Theme.of(context).colorScheme.primary : null,
                          ),
                        ),
                      ),
                      if (count > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11, // 단어 개수는 작게
                              color: Colors.blueAccent.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (count == 0)
                        const SizedBox(height: 15), // 단어 개수 없을 때도 높이 맞춤
                    ],
                  ),
                );
              },
              selectedBuilder: (context, day, focusedDay) {
                final d = DateTime(day.year, day.month, day.day);
                final count = dateMap[d]?.length ?? 0;
                return Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 18, // 날짜 글씨 크게
                            fontWeight: FontWeight.bold,
                            color: count > 0 ? Theme.of(context).colorScheme.primary : null,
                          ),
                        ),
                      ),
                      if (count > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11, // 단어 개수는 작게
                              color: Colors.blueAccent.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (count == 0)
                        const SizedBox(height: 15), // 단어 개수 없을 때도 높이 맞춤
                    ],
                  ),
                );
              },
              todayBuilder: (context, day, focusedDay) {
                final d = DateTime(day.year, day.month, day.day);
                final count = dateMap[d]?.length ?? 0;
                return Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 18, // 날짜 글씨 크게
                            fontWeight: FontWeight.bold,
                            color: count > 0 ? Theme.of(context).colorScheme.primary : null,
                          ),
                        ),
                      ),
                      if (count > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11, // 단어 개수는 작게
                              color: Colors.blueAccent.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (count == 0)
                        const SizedBox(height: 15), // 단어 개수 없을 때도 높이 맞춤
                    ],
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

  // 단어 추가 다이얼로그
  void _showAddWordDialog() {
    final engController = TextEditingController();
    final posController = TextEditingController();
    final korController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('단어 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: engController,
              decoration: const InputDecoration(labelText: '영어 단어'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: posController,
              decoration: const InputDecoration(labelText: '품사'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: korController,
              decoration: const InputDecoration(labelText: '한글 뜻'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final eng = engController.text.trim();
              final pos = posController.text.trim();
              final kor = korController.text.trim();
              if (eng.isEmpty || pos.isEmpty || kor.isEmpty) return;
              await FirebaseService().addWord(
                englishWord: eng,
                koreanPartOfSpeech: pos,
                koreanMeaning: kor,
              );
              if (!ctx.mounted) return;
              await _fetchWords();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('단어가 추가되었습니다.')),
              );
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  // 필터/정렬 다이얼로그
  void _showFilterDialog() {
    String? selectedPos;
    String? selectedSort = '최신순';
    final posList = words.map((w) => w['partOfSpeech'] as String? ?? '').toSet().toList();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('필터/정렬'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedPos,
                hint: const Text('품사별 필터'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('전체')),
                  ...posList.map((pos) => DropdownMenuItem(value: pos, child: Text(pos))),
                ],
                onChanged: (val) => setState(() => selectedPos = val),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: selectedSort,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: '최신순', child: Text('최신순')),
                  DropdownMenuItem(value: '오래된순', child: Text('오래된순')),
                  DropdownMenuItem(value: '가나다순', child: Text('가나다순')),
                ],
                onChanged: (val) => setState(() => selectedSort = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: () {
                // 필터/정렬 적용 로직 (예시: setState로 words 리스트 재정렬/필터)
                List<Map<String, dynamic>> filtered = [...words];
                final pos = selectedPos;
                if (pos != null && pos.isNotEmpty) {
                  filtered = filtered.where((w) => w['partOfSpeech'] == pos).toList();
                }
                if (selectedSort == '최신순') {
                  filtered.sort((a, b) => (b['input_timestamp'] as Timestamp).compareTo(a['input_timestamp'] as Timestamp));
                } else if (selectedSort == '오래된순') {
                  filtered.sort((a, b) => (a['input_timestamp'] as Timestamp).compareTo(b['input_timestamp'] as Timestamp));
                } else if (selectedSort == '가나다순') {
                  filtered.sort((a, b) => (a['word'] as String).compareTo(b['word'] as String));
                }
                setState(() {
                  if (showTodayWords) {
                    todayWords = filtered;
                  } else {
                    words = filtered;
                  }
                  currentIndex = 0;
                });
                Navigator.pop(ctx);
              },
              child: const Text('적용'),
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
                  _getErrorIcon(),
                  size: 64,
                  color: _getErrorColor(),
                ),
                const SizedBox(height: 16),
                Text(
                  _getErrorTitle(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _getErrorColor(),
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
                if (deviceStatus == 0 || deviceStatus == 1) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: _getErrorColor(), width: 1),
                      borderRadius: BorderRadius.circular(12),
                      color: _getErrorColor().withValues(alpha: 0.1),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '기기 고유번호',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          deviceId ?? '로딩 중...',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('복사'),
                        ),
                      ],
                    ),
                  ),
                ],
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
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddWordDialog,
            tooltip: '단어 추가',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: '필터/정렬',
          ),
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
                  children: [Icon(Icons.visibility), SizedBox(width: 8), Text('일반 모드')],
                ),
              ),
              const PopupMenuItem(
                value: StudyMode.hideMeaning,
                child: Row(
                  children: [Icon(Icons.visibility_off), SizedBox(width: 8), Text('뜻 가리기')],
                ),
              ),
              const PopupMenuItem(
                value: StudyMode.hideWord,
                child: Row(
                  children: [Icon(Icons.visibility_off), SizedBox(width: 8), Text('영단어 가리기')],
                ),
              ),
              const PopupMenuItem(
                value: StudyMode.randomHide,
                child: Row(
                  children: [Icon(Icons.shuffle), SizedBox(width: 8), Text('랜덤 가리기')],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _showCalendarDialog,
            tooltip: '달력',
          ),
          IconButton(
            icon: Icon(showTodayWords ? Icons.list : Icons.today),
            onPressed: _toggleTodayWords,
            tooltip: showTodayWords ? '전체 단어 보기' : '오늘의 단어',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Column(
            children: [
              // 진행률 ProgressBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: list.isNotEmpty ? (currentIndex + 1) / list.length : 0,
                        backgroundColor: Colors.white24,
                        color: Theme.of(context).colorScheme.secondary,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      list.isNotEmpty ? '${currentIndex + 1}/${list.length}' : '0/0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              if (isOffline)
                Container(
                  color: Colors.orange,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '오프라인 모드: 캐시 데이터로 표시 중',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      body: _selectedTab == 0
          ? Align(
              alignment: const Alignment(0, -0.4),
              child: AnimatedSwitcher(
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
                child: GestureDetector(
                  key: ValueKey('$showTodayWords-$currentIndex'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    if (details.primaryDelta == null) return;
                    final listLen = list.length;
                    if (details.primaryDelta! < -20) {
                      if (currentIndex < listLen - 1) {
                        setState(() {
                          prevIndex = currentIndex;
                          currentIndex++;
                        });
                      }
                      revealedWordIndexes.clear();
                      revealedMeaningIndexes.clear();
                    } else if (details.primaryDelta! > 20) {
                      if (currentIndex > 0) {
                        setState(() {
                          prevIndex = currentIndex;
                          currentIndex--;
                        });
                      }
                      revealedWordIndexes.clear();
                      revealedMeaningIndexes.clear();
                    }
                  },
                  child: WordCard(
                    word: word,
                    partOfSpeech: partOfSpeech,
                    meaning: meaning,
                    idx: currentIndex,
                    isSpeaking: isSpeaking,
                    isFavorite: isFavoriteWord(word),
                    hideWord: mode == StudyMode.hideWord,
                    hideMeaning: mode == StudyMode.hideMeaning,
                    revealedWord: revealedWordIndexes.contains(currentIndex),
                    revealedMeaning: revealedMeaningIndexes.contains(currentIndex),
                    onSpeak: () => _speak(word),
                    onToggleFavorite: () => toggleFavorite(word),
                    onRevealWord: () => revealWord(currentIndex),
                    onRevealMeaning: () => revealMeaning(currentIndex),
                  ),
                ),
              ),
            )
          : _selectedTab == 1
              ? Center(child: Text('Quiz 화면 (추후 구현)', style: TextStyle(fontSize: 20)))
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Text('즐겨찾기 단어', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final favoriteWords = words
                                .where((w) => isFavoriteWord(w['word'] as String? ?? ''))
                                .toList();
                            if (favoriteWords.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_border, size: 48, color: Theme.of(context).colorScheme.outline),
                                    const SizedBox(height: 16),
                                    Text('즐겨찾기한 단어가 없습니다.',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ListView.builder(
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
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: (idx) {
            setState(() {
              _selectedTab = idx;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view),
              label: '단어장',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.quiz),
              label: 'Quiz',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.star),
              label: '즐겨찾기',
            ),
          ],
          selectedItemColor: Colors.deepPurple,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}
