import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/device_id_service.dart';
import '../services/firebase_service.dart';
import '../widgets/word_card.dart';
import '../widgets/mode_button.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:card_swiper/card_swiper.dart';
import '../widgets/favorite_list.dart';
import 'package:flutter/foundation.dart';
import '../quiz_page.dart';

enum StudyMode { normal, hideMeaning, hideWord, randomHide }

// --- [무한루프용 커스텀 Physics] ---
class CustomPageViewScrollPhysics extends ScrollPhysics {
  final void Function(ScrollMetrics, double) onOverScroll;
  final bool infiniteLoop;
  const CustomPageViewScrollPhysics({required this.onOverScroll, required this.infiniteLoop, super.parent});

  @override
  CustomPageViewScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CustomPageViewScrollPhysics(onOverScroll: onOverScroll, infiniteLoop: infiniteLoop, parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // value < position.pixels: 오른쪽(이전) 스와이프
    // value > position.pixels: 왼쪽(다음) 스와이프
    if (!infiniteLoop) {
      // 무한루프 OFF: 경계(dummy) 페이지로의 스크롤 차단
      if (value < position.pixels && position.pixels <= position.minScrollExtent) {
        // 맨 앞에서 오른쪽(이전) 스와이프 차단
        return value - position.pixels;
      }
      if (value > position.pixels && position.pixels >= position.maxScrollExtent) {
        // 맨 뒤에서 왼쪽(다음) 스와이프 차단
        return value - position.pixels;
      }
    }
    // 무한루프 ON: 기존 동작(overscroll 허용)
    if (value < position.pixels && position.pixels <= position.minScrollExtent) {
      onOverScroll(position, value);
      return 0.0;
    }
    if (value > position.pixels && position.pixels >= position.maxScrollExtent) {
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
  int currentIndex = 0; // 실제 단어 인덱스(0~N-1)
  int prevIndex = 0;
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
  bool infiniteLoop = true; // Default: 항상 무한루프 ON
  String _sortType = '최신순';
  bool _showFavoritesOnly = false;

  // 실제 단어 인덱스 -> PageView 인덱스 변환
  int realToPageIdx(int realIdx, int listLen) => realIdx + 1;
  // PageView 인덱스 -> 실제 단어 인덱스 변환
  int pageToRealIdx(int pageIdx, int listLen) {
    if (pageIdx == 0) return listLen - 1;
    if (pageIdx == listLen + 1) return 0;
    return pageIdx - 1;
  }

  @override
  void initState() {
    super.initState();
    favoritesBox = Hive.box('favorites');
    flutterTts.setLanguage('en-US');
    flutterTts.setPitch(1.0);
    _loadDeviceId();
    _fetchWords();
    _loadHintState();
    _pageController = PageController(initialPage: 1);
    currentIndex = 0;
    // 진단용 로그: 앱 실행 시 words, favoritesBox 상태 출력
    Future.delayed(const Duration(seconds: 2), () {
      if (kDebugMode) {
        debugPrint('==== [앱 실행 시 진단 로그] ====');
        debugPrint('words 리스트:');
        for (final w in words) {
          debugPrint('  word: \'${w['word']}\', partOfSpeech: \'${w['partOfSpeech']}\', meaning: \'${w['meaning']}\'');
        }
        debugPrint('favoritesBox keys: ${favoritesBox.keys}');
        debugPrint('favoritesBox values:');
        for (final k in favoritesBox.keys) {
          debugPrint('  $k: ${favoritesBox.get(k)}');
        }
        debugPrint('============================');
      }
    });
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

  void _onTitleTap() async {
    setState(() {
      titleClickCount++;
    });
    if (titleClickCount >= 5) {
      await _showDeviceIdDialog();
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

  Future<void> _showDeviceIdDialog() async {
    final deviceIdService = DeviceIdService();
    final latestDeviceId = await deviceIdService.getDeviceId();
    if (!mounted) return;
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
                color: Theme.of(context).colorScheme.primaryContainer.withAlpha(77),
              ),
              child: Text(
                latestDeviceId,
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
              if (latestDeviceId.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: latestDeviceId));
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
        return {
          'id': doc.id,
          'word': word,
          'partOfSpeech': partOfSpeech,
          'meaning': meaning,
          'input_timestamp': timestamp,
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
          return {
            'id': doc.id,
            'word': word,
            'partOfSpeech': partOfSpeech,
            'meaning': meaning,
            'input_timestamp': timestamp,
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('CSV 입력 기능은 추후 지원 예정입니다.')),
                    );
                  },
                  child: const Text('CSV 입력'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // 기존 다이얼로그 닫기
                    _showTsvInputDialog();
                  },
                  child: const Text('TSV 입력'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('단일 단어 추가 기능은 추후 구현 예정입니다.'),
          ],
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

  void _showTsvInputDialog() {
    final TextEditingController tsvController = TextEditingController();
    String? errorText;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('TSV 단어 일괄 입력'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('[입력 규칙]'),
                  const SizedBox(height: 4),
                  const Text('1. 영단어\t품사(여러 개면 comma)\t한글뜻(여러 개면 comma)\t예문(선택)\t해석(선택)'),
                  const Text('2. 품사가 2개 이상 + comma면 한글뜻도 comma로 1:1 매칭 (1:다 불가)'),
                  const Text('3. 예문/해석은 비워도 됨'),
                  const SizedBox(height: 8),
                  const Text('예시:'),
                  const Text('apple\t명사\t사과'),
                  const Text('run\t동사,명사\t달리다,운영\tHe can run fast.\t그는 빨리 달릴 수 있다.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tsvController,
                    minLines: 6,
                    maxLines: 12,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'TSV 텍스트 붙여넣기',
                      errorText: errorText,
                    ),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () {
                  final lines = tsvController.text.trim().split('\n');
                  List<Map<String, dynamic>> parsed = [];
                  for (int i = 0; i < lines.length; i++) {
                    final line = lines[i].trim();
                    if (line.isEmpty) continue;
                    final cols = line.split('\t');
                    if (cols.length < 3) {
                      setState(() { errorText = '${i+1}번째 줄: 최소 3개(영단어, 품사, 한글뜻) 필수'; });
                      return;
                    }
                    final word = cols[0].trim();
                    final pos = cols[1].trim();
                    final meaning = cols[2].trim();
                    final example = cols.length > 3 ? cols[3].trim() : null;
                    final exampleKor = cols.length > 4 ? cols[4].trim() : null;
                    // 품사/뜻 comma 처리
                    final posList = pos.split(',').map((e) => e.trim()).toList();
                    final meaningList = meaning.split(',').map((e) => e.trim()).toList();
                    if (posList.length > 1 && meaningList.length > 1) {
                      if (posList.length != meaningList.length) {
                        setState(() { errorText = '${i+1}번째 줄: 품사와 한글뜻의 comma 개수가 다르면 1:1 매칭 불가'; });
                        return;
                      }
                    }
                    parsed.add({
                      'word': word,
                      'partOfSpeech': pos,
                      'meaning': meaning,
                      'example': example,
                      'exampleKor': exampleKor,
                    });
                  }
                  setState(() { errorText = null; });
                  setState(() {
                    words.addAll(parsed);
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('TSV 단어 ${parsed.length}개가 임시로 추가되었습니다. (실제 저장은 추후 구현)')),
                  );
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('필터/정렬'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 정렬 옵션
              Row(
                children: [
                  const Text('정렬: '),
                  DropdownButton<String>(
                    value: _sortType,
                    items: const [
                      DropdownMenuItem(value: '최신순', child: Text('최신순')),
                      DropdownMenuItem(value: '가나다순', child: Text('가나다순')),
                    ],
                    onChanged: (v) {
                      setStateDialog(() => _sortType = v!);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 즐겨찾기만 보기
              CheckboxListTile(
                value: _showFavoritesOnly,
                onChanged: (v) {
                  setStateDialog(() => _showFavoritesOnly = v!);
                },
                title: const Text('즐겨찾기만 보기'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
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
                setState(() {}); // 다이얼로그 닫고 필터 적용
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
    debugPrint('[HomePage] build 호출, _selectedTab=$_selectedTab');
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
                          (deviceId?.isNotEmpty ?? false) ? deviceId! : '로딩 중...',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            if (deviceId?.isNotEmpty ?? false) {
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
    if (_selectedTab == 0) {
      final rawList = filterTodayOnly ? todayWords : words;
      List<Map<String, dynamic>> list = List.from(rawList);
      if (_showFavoritesOnly) {
        list = list.where((w) => isFavoriteWord(w['word'] as String? ?? '')).toList();
      }
      if (_sortType == '가나다순') {
        list.sort((a, b) => (a['word'] as String).compareTo(b['word'] as String));
      } else {
        // 최신순: input_timestamp 내림차순
        list.sort((a, b) {
          final at = a['input_timestamp'];
          final bt = b['input_timestamp'];
          if (at is DateTime && bt is DateTime) return bt.compareTo(at);
          if (at is Timestamp && bt is Timestamp) return bt.toDate().compareTo(at.toDate());
          return 0;
        });
      }
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
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await _fetchWords();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('단어를 새로고침했습니다.')),
                );
              },
              tooltip: '단어 새로고침',
            ),
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
            Expanded(
              child: _selectedTab == 0
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),
                        // INDEX(페이지네이션) 표시: 상단바와 카드 사이
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Builder(
                            builder: (context) {
                              final width = MediaQuery.of(context).size.width;
                              final fontSize = width * 0.07; // 화면 너비의 7%로, 기존보다 약간 더 크게
                              return Text(
                                list.isEmpty ? '' : '${currentIndex + 1} / ${list.length}',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ),
                        Align(
                          alignment: const Alignment(0, -0.4),
                          child: Stack(
                            children: [
                              SizedBox(
                                width: 340,
                                height: 440,
                                child: Swiper(
                                  itemBuilder: (BuildContext context, int idx) {
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
                                      loopButton: IconButton(
                                        icon: Icon(infiniteLoop ? Icons.lock : Icons.lock_open),
                                        tooltip: infiniteLoop ? '무한반복 ON' : '무한반복 OFF',
                                        onPressed: () {
                                          setState(() {
                                            infiniteLoop = !infiniteLoop;
                                          });
                                        },
                                      ),
                                    );
                                  },
                                  itemCount: list.length,
                                  loop: infiniteLoop,
                                  index: currentIndex,
                                  onIndexChanged: (idx) {
                                    setState(() {
                                      prevIndex = currentIndex;
                                      currentIndex = idx;
                                      revealedWordIndexes.clear();
                                      revealedMeaningIndexes.clear();
                                    });
                                    _hideHint();
                                  },
                                  control: const SwiperControl(),
                                ),
                              ),
                            ],
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
                      ? Scaffold(
                          appBar: AppBar(
                            title: const Text('발음 퀴즈'),
                          ),
                          body: QuizPage(showAppBar: false, words: words),
                          bottomNavigationBar: SafeArea(
                            child: BottomNavigationBar(
                              currentIndex: _selectedTab,
                              onTap: (idx) {
                                setState(() {
                                  _selectedTab = idx;
                                  debugPrint('[HomePage] _selectedTab 변경: $_selectedTab');
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
                        )
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
                                    debugPrint('[HomePage] 즐겨찾기 Builder 진입');
                                    List<Map<String, dynamic>> favList = List.from(words);
                                    if (_sortType == '가나다순') {
                                      favList.sort((a, b) => (a['word'] as String).compareTo(b['word'] as String));
                                    } else {
                                      favList.sort((a, b) {
                                        final at = a['input_timestamp'];
                                        final bt = b['input_timestamp'];
                                        if (at is DateTime && bt is DateTime) return bt.compareTo(at);
                                        if (at is Timestamp && bt is Timestamp) return bt.toDate().compareTo(at.toDate());
                                        return 0;
                                      });
                                    }
                                    favList = favList.where((w) => isFavoriteWord(w['word'] as String? ?? '')).toList();
                                    if (kDebugMode) {
                                      debugPrint('==== [즐겨찾기 탭 진입 시 진단 로그] ====');
                                      debugPrint('words 리스트:');
                                      for (final w in words) {
                                        debugPrint('  word: \'${w['word']}\', partOfSpeech: \'${w['partOfSpeech']}\', meaning: \'${w['meaning']}\'');
                                      }
                                      debugPrint('favoritesBox keys:');
                                      debugPrint(favoritesBox.keys.toString());
                                      debugPrint('favoritesBox values:');
                                      for (final k in favoritesBox.keys) {
                                        debugPrint('  $k: ${favoritesBox.get(k)}');
                                      }
                                      debugPrint('즐겨찾기 필터 결과(favList):');
                                      for (final w in favList) {
                                        debugPrint('  word: \'${w['word']}\', partOfSpeech: \'${w['partOfSpeech']}\', meaning: \'${w['meaning']}\'');
                                      }
                                      debugPrint('============================');
                                    }
                                    debugPrint('[HomePage] FavoriteList 반환 직전');
                                    return FavoriteList(
                                      favoriteWords: favList,
                                      isFavoriteWord: isFavoriteWord,
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
                debugPrint('[HomePage] _selectedTab 변경: $_selectedTab');
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
    } else if (_selectedTab == 1) {
      // 퀴즈 탭: QuizPage를 body로, 하단 네비게이션 바 포함 (QuizPage 내부 Scaffold/AppBar 제거)
      return Scaffold(
        appBar: AppBar(
          title: const Text('발음 퀴즈'),
        ),
        body: QuizPage(showAppBar: false, words: words),
        bottomNavigationBar: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _selectedTab,
            onTap: (idx) {
              setState(() {
                _selectedTab = idx;
                debugPrint('[HomePage] _selectedTab 변경: $_selectedTab');
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
    } else {
      // 즐겨찾기 탭
      return Scaffold(
        appBar: AppBar(
          title: const Text('즐겨찾기 단어'),
        ),
        body: Padding(
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
                    debugPrint('[HomePage] 즐겨찾기 Builder 진입');
                    List<Map<String, dynamic>> favList = List.from(words);
                    if (_sortType == '가나다순') {
                      favList.sort((a, b) => (a['word'] as String).compareTo(b['word'] as String));
                    } else {
                      favList.sort((a, b) {
                        final at = a['input_timestamp'];
                        final bt = b['input_timestamp'];
                        if (at is DateTime && bt is DateTime) return bt.compareTo(at);
                        if (at is Timestamp && bt is Timestamp) return bt.toDate().compareTo(at.toDate());
                        return 0;
                      });
                    }
                    favList = favList.where((w) => isFavoriteWord(w['word'] as String? ?? '')).toList();
                    if (kDebugMode) {
                      debugPrint('==== [즐겨찾기 탭 진입 시 진단 로그] ====');
                      debugPrint('words 리스트:');
                      for (final w in words) {
                        debugPrint('  word: \'${w['word']}\', partOfSpeech: \'${w['partOfSpeech']}\', meaning: \'${w['meaning']}\'');
                      }
                      debugPrint('favoritesBox keys:');
                      debugPrint(favoritesBox.keys.toString());
                      debugPrint('favoritesBox values:');
                      for (final k in favoritesBox.keys) {
                        debugPrint('  $k: ${favoritesBox.get(k)}');
                      }
                      debugPrint('즐겨찾기 필터 결과(favList):');
                      for (final w in favList) {
                        debugPrint('  word: \'${w['word']}\', partOfSpeech: \'${w['partOfSpeech']}\', meaning: \'${w['meaning']}\'');
                      }
                      debugPrint('============================');
                    }
                    debugPrint('[HomePage] FavoriteList 반환 직전');
                    return FavoriteList(
                      favoriteWords: favList,
                      isFavoriteWord: isFavoriteWord,
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
                debugPrint('[HomePage] _selectedTab 변경: $_selectedTab');
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
}
