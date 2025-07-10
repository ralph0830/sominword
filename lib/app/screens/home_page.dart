import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/services/device_id_service.dart';
import '../../core/services/firebase_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

enum StudyMode { normal, hideMeaning, hideWord, randomHide }

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;
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
  int deviceStatus = 0;

  @override
  void initState() {
    super.initState();
    favoritesBox = Hive.box('favorites');
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
      titleClickCount = 0;
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
                color: Theme.of(context).colorScheme.primaryContainer.withAlpha((0.3 * 255).toInt()),
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
                          ),
                        ),
                      ),
                      Text(
                        '$count개',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            ),
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

  @override
  Widget build(BuildContext context) {
    // 로딩 중
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 에러/승인 전 안내
    if (errorMsg != null || deviceStatus == 0 || deviceStatus == 1) {
      return Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: _onTitleTap,
            child: const Text('SominWord'),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getErrorIcon(), size: 64, color: _getErrorColor()),
              const SizedBox(height: 24),
              Text(
                _getErrorTitle(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: _getErrorColor()),
              ),
              const SizedBox(height: 16),
              Text(
                errorMsg ?? '',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (deviceId != null) ...[
                const SizedBox(height: 32),
                Text('기기 고유번호', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                SelectableText(
                  deviceId!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: deviceId!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('기기 고유번호가 클립보드에 복사되었습니다.')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('복사'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // 단어 데이터
    final displayWords = showTodayWords ? todayWords : words;
    final hasWords = displayWords.isNotEmpty;
    final word = hasWords ? displayWords[currentIndex] : null;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onTitleTap,
          child: const Text('SominWord'),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            tooltip: '즐겨찾기',
            onPressed: _showFavoritesDialog,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: '캘린더',
            onPressed: _showCalendarDialog,
          ),
          IconButton(
            icon: Icon(showTodayWords ? Icons.today : Icons.list),
            tooltip: showTodayWords ? '전체 단어 보기' : '오늘의 단어만 보기',
            onPressed: _toggleTodayWords,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: !hasWords
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.book, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        showTodayWords ? '오늘 등록된 단어가 없습니다.' : '등록된 단어가 없습니다.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 상단: 단어/진행 정보
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          showTodayWords ? '오늘의 단어' : '전체 단어',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${currentIndex + 1} / ${displayWords.length}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 단어 카드
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '영어 단어',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.volume_up),
                                  tooltip: '발음 듣기',
                                  onPressed: word == null ? null : () => _speak(word['word'] ?? ''),
                                ),
                                IconButton(
                                  icon: Icon(word != null && isFavoriteWord(word['word'] ?? '') ? Icons.star : Icons.star_border, color: Colors.amber),
                                  tooltip: '즐겨찾기',
                                  onPressed: word == null ? null : () => toggleFavorite(word['word'] ?? ''),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: word == null ? null : () => revealWord(currentIndex),
                              child: AnimatedOpacity(
                                opacity: mode == StudyMode.hideWord && !revealedWordIndexes.contains(currentIndex) ? 0.2 : 1.0,
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  word?['word'] ?? '',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              word?['partOfSpeech'] ?? '',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: word == null ? null : () => revealMeaning(currentIndex),
                              child: AnimatedOpacity(
                                opacity: mode == StudyMode.hideMeaning && !revealedMeaningIndexes.contains(currentIndex) ? 0.2 : 1.0,
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  word?['meaning'] ?? '',
                                  style: Theme.of(context).textTheme.titleLarge,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 학습 모드/네비게이션
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        DropdownButton<StudyMode>(
                          value: mode,
                          onChanged: (m) => setState(() => mode = m!),
                          items: const [
                            DropdownMenuItem(value: StudyMode.normal, child: Text('기본')),
                            DropdownMenuItem(value: StudyMode.hideMeaning, child: Text('뜻 가리기')),
                            DropdownMenuItem(value: StudyMode.hideWord, child: Text('영어 가리기')),
                            DropdownMenuItem(value: StudyMode.randomHide, child: Text('랜덤 가리기')),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              tooltip: '이전 단어',
                              onPressed: currentIndex > 0 ? () => setState(() => currentIndex--) : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward),
                              tooltip: '다음 단어',
                              onPressed: currentIndex < displayWords.length - 1 ? () => setState(() => currentIndex++) : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isOffline)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          '오프라인 캐시 데이터로 표시 중입니다.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
} 