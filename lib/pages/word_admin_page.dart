import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin/widgets/word_card.dart';
import 'package:admin/admin/dialogs.dart' show showEditWordInputDialog, showDeleteWordConfirmDialog, showTsvExportDialog;

class WordAdminPage extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final String email; // email 파라미터 추가
  const WordAdminPage({super.key, required this.deviceId, required this.deviceName, required this.email});

  @override
  State<WordAdminPage> createState() => _WordAdminPageState();
}

class _WordAdminPageState extends State<WordAdminPage> {
  final Set<String> _selectedWordIds = {};

  void _toggleSelect(String wordId, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedWordIds.add(wordId);
      } else {
        _selectedWordIds.remove(wordId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedWordIds.clear();
    });
  }

  Future<void> _deleteSelectedWords() async {
    final deviceId = widget.deviceId;
    final count = _selectedWordIds.length;
    if (count == 0) return;
    bool confirm = false;
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('선택 삭제'),
        content: Text('$count개 단어를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    ).then((value) => confirm = value == true);
    if (!mounted || !confirm) return;
    final futures = _selectedWordIds.map((wordId) =>
      FirebaseFirestore.instance
        .collection('devices')
        .doc(deviceId)
        .collection('words')
        .doc(wordId)
        .delete()
    ).toList();
    await Future.wait(futures);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count개 단어가 삭제되었습니다.')),
    );
    _clearSelection();
  }

  // 선택 이동 다이얼로그: 내 devices 목록을 드롭다운으로 보여주고 선택
  Future<void> _moveSelectedWords() async {
    final deviceId = widget.deviceId;
    final count = _selectedWordIds.length;
    if (count == 0) return;
    // 내 devices 목록 불러오기 (현재 기기 제외)
    final devicesSnapshot = await FirebaseFirestore.instance
        .collection('devices')
        .where('ownerEmail', isEqualTo: widget.email)
        .get();
    final deviceOptions = devicesSnapshot.docs
        .where((d) => d.id != deviceId)
        .map((d) => {
              'id': d.id,
              'label': '${d.id} - ${d['nickname'] ?? ''}',
            })
        .toList();
    String? targetDeviceId;
    await showDialog<String>(
      context: context,
      builder: (ctx) {
        String? selectedId;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('선택 이동'),
            content: DropdownButtonFormField<String>(
              value: selectedId,
              items: deviceOptions
                  .map((d) => DropdownMenuItem<String>(
                        value: d['id'] as String,
                        child: Text(d['label'] as String),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => selectedId = v),
              decoration: const InputDecoration(labelText: '이동할 기기'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              ElevatedButton(
                onPressed: selectedId == null ? null : () => Navigator.pop(ctx, selectedId),
                child: const Text('이동'),
              ),
            ],
          ),
        );
      },
    ).then((value) => targetDeviceId = value);
    if (!mounted || targetDeviceId == null || targetDeviceId!.isEmpty) return;
    // 이동 대상 기기의 기존 단어(영어 단어 기준) 목록 조회
    final targetWordsSnapshot = await FirebaseFirestore.instance
        .collection('devices')
        .doc(targetDeviceId)
        .collection('words')
        .get();
    final targetEnglishWords = targetWordsSnapshot.docs
        .map((doc) => (doc.data()['englishWord'] ?? '').toString().trim().toLowerCase())
        .toSet();
    int movedCount = 0;
    int duplicateCount = 0;
    int failCount = 0;
    for (final wordId in _selectedWordIds) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceId)
            .collection('words')
            .doc(wordId)
            .get();
        final data = doc.data();
        if (data != null) {
          final englishWord = (data['englishWord'] ?? '').toString().trim().toLowerCase();
          if (!targetEnglishWords.contains(englishWord)) {
            await FirebaseFirestore.instance
                .collection('devices')
                .doc(targetDeviceId)
                .collection('words')
                .add({
                  ...data,
                  'inputTimestamp': FieldValue.serverTimestamp(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
            await doc.reference.delete();
            movedCount++;
          } else {
            duplicateCount++;
          }
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }
    _clearSelection();
    if (!mounted) return;
    await _showWordTransferResultDialog(context,
      action: '이동',
      successCount: movedCount,
      duplicateCount: duplicateCount,
      failCount: failCount,
      targetDeviceId: targetDeviceId!,
    );
  }

  // 선택 복사 다이얼로그: 내 devices 목록을 드롭다운으로 보여주고 선택
  Future<void> _copySelectedWords() async {
    final deviceId = widget.deviceId;
    final count = _selectedWordIds.length;
    if (count == 0) return;
    // 내 devices 목록 불러오기 (현재 기기 제외)
    final devicesSnapshot = await FirebaseFirestore.instance
        .collection('devices')
        .where('ownerEmail', isEqualTo: widget.email)
        .get();
    final deviceOptions = devicesSnapshot.docs
        .where((d) => d.id != deviceId)
        .map((d) => {
              'id': d.id,
              'label': '${d.id} - ${d['nickname'] ?? ''}',
            })
        .toList();
    String? targetDeviceId;
    await showDialog<String>(
      context: context,
      builder: (ctx) {
        String? selectedId;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('선택 복사'),
            content: DropdownButtonFormField<String>(
              value: selectedId,
              items: deviceOptions
                  .map((d) => DropdownMenuItem<String>(
                        value: d['id'] as String,
                        child: Text(d['label'] as String),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => selectedId = v),
              decoration: const InputDecoration(labelText: '복사할 기기'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              ElevatedButton(
                onPressed: selectedId == null ? null : () => Navigator.pop(ctx, selectedId),
                child: const Text('복사'),
              ),
            ],
          ),
        );
      },
    ).then((value) => targetDeviceId = value);
    if (!mounted || targetDeviceId == null || targetDeviceId!.isEmpty) return;
    // 복사 대상 기기의 기존 단어(영어 단어 기준) 목록 조회
    final targetWordsSnapshot = await FirebaseFirestore.instance
        .collection('devices')
        .doc(targetDeviceId)
        .collection('words')
        .get();
    final targetEnglishWords = targetWordsSnapshot.docs
        .map((doc) => (doc.data()['englishWord'] ?? '').toString().trim().toLowerCase())
        .toSet();
    int copiedCount = 0;
    int duplicateCount = 0;
    int failCount = 0;
    for (final wordId in _selectedWordIds) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceId)
            .collection('words')
            .doc(wordId)
            .get();
        final data = doc.data();
        if (data != null) {
          final englishWord = (data['englishWord'] ?? '').toString().trim().toLowerCase();
          if (!targetEnglishWords.contains(englishWord)) {
            await FirebaseFirestore.instance
                .collection('devices')
                .doc(targetDeviceId)
                .collection('words')
                .add({
                  ...data,
                  'inputTimestamp': FieldValue.serverTimestamp(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
            copiedCount++;
          } else {
            duplicateCount++;
          }
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }
    if (!mounted) return;
    await _showWordTransferResultDialog(context,
      action: '복사',
      successCount: copiedCount,
      duplicateCount: duplicateCount,
      failCount: failCount,
      targetDeviceId: targetDeviceId!,
    );
  }

  // 이동/복사 결과 요약 다이얼로그
  Future<void> _showWordTransferResultDialog(BuildContext context, {
    required String action,
    required int successCount,
    required int duplicateCount,
    required int failCount,
    required String targetDeviceId,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('단어 $action 결과'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('대상 기기: $targetDeviceId'),
            const SizedBox(height: 8),
            Text('성공: $successCount개'),
            Text('중복: $duplicateCount개'),
            Text('실패: $failCount개'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('단어 관리: ${widget.deviceName}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_selectedWordIds.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '선택 삭제',
              onPressed: _deleteSelectedWords,
            ),
            IconButton(
              icon: const Icon(Icons.drive_file_move),
              tooltip: '선택 이동',
              onPressed: _moveSelectedWords,
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: '선택 복사',
              onPressed: _copySelectedWords, // 복사 기능 추가
            ),
          ],
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'TSV로 추출',
            onPressed: () async {
              // Firestore에서 단어 리스트를 읽어와 TSV로 변환
              final snapshot = await FirebaseFirestore.instance
                  .collection('devices')
                  .doc(widget.deviceId)
                  .collection('words')
                  .orderBy('inputTimestamp', descending: true)
                  .get();
              final words = snapshot.docs;
              final tsv = words.map((doc) {
                final w = doc.data();
                return [
                  w['englishWord'] ?? '',
                  w['koreanPartOfSpeech'] ?? '',
                  w['koreanMeaning'] ?? '',
                  w['sentence'] ?? '',
                  w['sentenceKor'] ?? '',
                ].join('\t');
              }).join('\n');
              await showTsvExportDialog(context, widget.deviceName, tsv);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('단어 추가'),
        onPressed: () async {
          final result = await showEditWordInputDialog(context);
          if (!context.mounted) return;
          if (result != null) {
            if (result is List<Map<String, String>>) {
              // TSV 대량 추가
              final futures = result.map((input) =>
                FirebaseFirestore.instance
                  .collection('devices')
                  .doc(widget.deviceId)
                  .collection('words')
                  .add({
                    ...input,
                    'inputTimestamp': FieldValue.serverTimestamp(),
                    'createdAt': FieldValue.serverTimestamp(),
                  })
              ).toList();
              await Future.wait(futures);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${result.length}개 단어가 추가되었습니다.')),
              );
            } else if (result is Map<String, String>) {
              // 단일 추가
              await FirebaseFirestore.instance
                  .collection('devices')
                  .doc(widget.deviceId)
                  .collection('words')
                  .add({
                    ...result,
                    'inputTimestamp': FieldValue.serverTimestamp(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('단어가 추가되었습니다.')),
              );
            }
          }
        },
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('devices')
            .doc(widget.deviceId)
            .collection('words')
            .orderBy('inputTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }
          final words = snapshot.data?.docs ?? [];
          if (words.isEmpty) {
            return const Center(child: Text('등록된 단어가 없습니다.'));
          }
          // 전체 선택 체크박스 + 단어 리스트
          return Column(
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _selectedWordIds.length == words.length && words.isNotEmpty,
                    tristate: false,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedWordIds.addAll(words.map((w) => w.id));
                        } else {
                          _selectedWordIds.clear();
                        }
                      });
                    },
                  ),
                  const Text('전체 선택'),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    final word = words[index].data() as Map<String, dynamic>;
                    final wordId = words[index].id;
                    return WordCard(
                      word: word,
                      wordId: wordId,
                      selected: _selectedWordIds.contains(wordId),
                      onSelected: (selected) => _toggleSelect(wordId, selected),
                      onEdit: () async {
                        final input = await showEditWordInputDialog(context, word: word);
                        if (!context.mounted) return;
                        if (input != null) {
                          await FirebaseFirestore.instance
                              .collection('devices')
                              .doc(widget.deviceId)
                              .collection('words')
                              .doc(wordId)
                              .set({
                                ...input,
                                'updatedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('단어가 수정되었습니다.')),
                          );
                        }
                      },
                      onDelete: () async {
                        final confirm = await showDeleteWordConfirmDialog(context, word['englishWord']);
                        if (!context.mounted) return;
                        if (confirm) {
                          await FirebaseFirestore.instance
                              .collection('devices')
                              .doc(widget.deviceId)
                              .collection('words')
                              .doc(wordId)
                              .delete();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('단어가 삭제되었습니다.')),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} 