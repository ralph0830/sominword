import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/device_id_service.dart';
import '../services/firebase_service.dart';
import '../widgets/word_card.dart';
import '../widgets/progress_bar.dart';
import '../widgets/mode_button.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';

enum StudyMode { normal, hideMeaning, hideWord, randomHide }

// --- [무한루프용 커스텀 Physics] ---
class CustomPageViewScrollPhysics extends ScrollPhysics {
  final void Function(ScrollMetrics, double) onOverScroll;
  const CustomPageViewScrollPhysics({required this.onOverScroll, ScrollPhysics? parent}) : super(parent: parent);

  @override
  CustomPageViewScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CustomPageViewScrollPhysics(onOverScroll: onOverScroll, parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // value < position.pixels: 오른쪽(이전) 스와이프
    // value > position.pixels: 왼쪽(다음) 스와이프
    if (value < position.pixels && position.pixels <= position.minScrollExtent) {
      // 맨 앞에서 오른쪽(이전) 스와이프
      onOverScroll(position, value);
      return 0.0;
    }
    if (value > position.pixels && position.pixels >= position.maxScrollExtent) {
      // 맨 뒤에서 왼쪽(다음) 스와이프
      onOverScroll(position, value);
      return 0.0;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

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
  int titleClickCount = 0;
  String? deviceId;
  int deviceStatus = 0; // 0: 미등록, 1: 승인대기, 2: 정상
  int _selectedTab = 0; // 0: 단어장, 1: Quiz, 2: 즐겨찾기
  bool showHint = false;
  bool filterTodayOnly = false;
  PageController? _pageController;
  bool infiniteLoop = false;
  bool isLoopJumping = false; // 무한루프 jump 중인지 플래그

  @override
  void initState() {
    super.initState();
    favoritesBox = Hive.box('favorites');
    flutterTts.setLanguage('en-US');
    flutterTts.setPitch(1.0);
    _loadDeviceId();
    _fetchWords();
    _loadHintState();
    _pageController = PageController(initialPage: currentIndex);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
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
      final status = await firebaseService.getDeviceRegistrationStatus();
      if (!mounted) return;
      setState(() {
        deviceStatus = status;
      });
      if (status == 0) {
        setState(() {
          isLoading = false;
          errorMsg = '기기 등록이 필요합니다.';
          words = [];
          todayWords = [];
        });
        return;
      } else if (status == 1) {
        setState(() {
          isLoading = false;
          errorMsg = '기기 등록이 되었습니다. 관리자 승인이 필요합니다.';
          words = [];
          todayWords = [];
        });
        return;
      }
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
      await flutterTts.stop();
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
                            fontSize: 18,
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
                              fontSize: 11,
                              color: Colors.blueAccent.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (count == 0)
                        const SizedBox(height: 15),
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
                            fontSize: 18,
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
                              fontSize: 11,
                              color: Colors.blueAccent.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (count == 0)
                        const SizedBox(height: 15),
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
                            fontSize: 18,
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
                              fontSize: 11,
                              color: Colors.blueAccent.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (count == 0)
                        const SizedBox(height: 15),
                    ],
                  ),
                );
              },
            ),
            onDaySelected: (selectedDay, focusedDay) {
              final d = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
              if (dateMap[d] != null && dateMap[d]!.isNotEmpty) {
                setState(() {
                  currentIndex = dateMap[d]!.last;
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

  Future<void> _loadHintState() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('hint_seen') ?? false;
    setState(() {
      showHint = !seen;
    });
  }

  void _hideHint() {
    setState(() {
      showHint = false;
    });
  }

  void _showAddWordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('단어 추가'),
        content: const Text('단어 추가 기능은 추후 구현 예정입니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('필터/정렬'),
        content: const Text('필터/정렬 기능은 추후 구현 예정입니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // 무한루프 경계 스와이프 시 jumpToPage
  void jumpToEdgePage(ScrollMetrics position, double value) {
    final list = filterTodayOnly ? todayWords : words;
    if (!infiniteLoop || list.length <= 1 || _pageController == null) return;
    if (position.pixels <= position.minScrollExtent && value < position.pixels) {
      // 맨 앞에서 오른쪽(이전) 스와이프 → 마지막 페이지로 animate
      Future.microtask(() {
        _pageController?.animateToPage(
          list.length - 1,
          duration: const Duration(milliseconds: 350),
          curve: Curves.ease,
        );
      });
    } else if (position.pixels >= position.maxScrollExtent && value > position.pixels) {
      // 맨 뒤에서 왼쪽(다음) 스와이프 → 첫 페이지로 animate
      Future.microtask(() {
        _pageController?.animateToPage(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.ease,
        );
      });
    }
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
    final list = filterTodayOnly ? todayWords : words;
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
                filterTodayOnly ? Icons.today : Icons.book,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                filterTodayOnly ? '오늘의 단어가 없습니다.' : '등록된 단어가 없습니다.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                filterTodayOnly 
                    ? '관리자 페이지에서 오늘의 단어를 추가해보세요.'
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
        ],
        bottom: null,
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedTab == 0)
            ProgressIndicatorBar(
              currentIndex: currentIndex,
              total: list.length,
              color: Theme.of(context).colorScheme.primary,
            ),
          Expanded(
            child: _selectedTab == 0
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),
                      Align(
                        alignment: const Alignment(0, -0.4),
                        child: SizedBox(
                          width: 340,
                          height: 440,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: list.length,
                            physics: CustomPageViewScrollPhysics(onOverScroll: jumpToEdgePage),
                            onPageChanged: (idx) {
                              setState(() {
                                prevIndex = currentIndex;
                                currentIndex = idx;
                                revealedWordIndexes.clear();
                                revealedMeaningIndexes.clear();
                              });
                              _hideHint();
                            },
                            itemBuilder: (context, idx) {
                              final word = list[idx]['word'] as String? ?? '';
                              final partOfSpeech = list[idx]['partOfSpeech'] as String? ?? '';
                              final meaning = list[idx]['meaning'] as String? ?? '';
                              return WordCard(
                                word: word,
                                partOfSpeech: partOfSpeech,
                                meaning: meaning,
                                idx: idx,
                                isSpeaking: isSpeaking,
                                isFavorite: isFavoriteWord(word),
                                hideWord: mode == StudyMode.hideWord || mode == StudyMode.randomHide,
                                hideMeaning: mode == StudyMode.hideMeaning || mode == StudyMode.randomHide,
                                revealedWord: revealedWordIndexes.contains(idx),
                                revealedMeaning: revealedMeaningIndexes.contains(idx),
                                onSpeak: () => _speak(word),
                                onToggleFavorite: () => toggleFavorite(word),
                                onRevealWord: () => revealWord(idx),
                                onRevealMeaning: () => revealMeaning(idx),
                                showHint: showHint && idx == currentIndex,
                                infiniteLoop: infiniteLoop,
                                onToggleInfiniteLoop: () {
                                  setState(() {
                                    infiniteLoop = !infiniteLoop;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ModeButton(
                              icon: Icons.visibility,
                              label: '일반',
                              selected: mode == StudyMode.normal,
                              onTap: () => setState(() => mode = StudyMode.normal),
                            ),
                            ModeButton(
                              icon: Icons.visibility_off,
                              label: '뜻 가리기',
                              selected: mode == StudyMode.hideMeaning,
                              onTap: () => setState(() => mode = StudyMode.hideMeaning),
                            ),
                            ModeButton(
                              icon: Icons.text_fields,
                              label: '영단어',
                              selected: mode == StudyMode.hideWord,
                              onTap: () => setState(() => mode = StudyMode.hideWord),
                            ),
                            ModeButton(
                              icon: Icons.shuffle,
                              label: '랜덤',
                              selected: mode == StudyMode.randomHide,
                              onTap: () => setState(() => mode = StudyMode.randomHide),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 3),
                    ],
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
          ),
        ],
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
