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
    final count = _selectedWordIds.length;
    if (count == 0) return;

    // ignore: use_build_context_synchronously
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('선택 삭제'),
        content: Text('$count개 단어를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final futures = _selectedWordIds.map((wordId) =>
      FirebaseFirestore.instance
        .collection('devices')
        .doc(widget.deviceId)
        .collection('words')
        .doc(wordId)
        .delete()
    ).toList();
    await Future.wait(futures);

    if (mounted) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count개 단어가 삭제되었습니다.')),
      );
      _clearSelection();
    }
  }

  // 선택 이동 다이얼로그: 내 devices 목록을 드롭다운으로 보여주고 선택
  Future<void> _moveSelectedWords() async {
    final count = _selectedWordIds.length;
    if (count == 0) return;

    // 내 devices 목록 불러오기 (현재 기기 제외)
    final devicesSnapshot = await FirebaseFirestore.instance
        .collection('devices')
        .where('ownerEmail', isEqualTo: widget.email)
        .get();
    
    if (!mounted) return;

    final deviceOptions = devicesSnapshot.docs
        .where((d) => d.id != widget.deviceId)
        .map((d) => {
              'id': d.id,
              'label': '${d.id} - ${d['nickname'] ?? ''}',
            })
        .toList();
    // ignore: use_build_context_synchronously
    final targetDeviceId = await showDialog<String>(
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
    );

    if (targetDeviceId == null || targetDeviceId.isEmpty) return;
    if (!mounted) return;

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
    final progressNotifier = ValueNotifier<int>(0);
    bool cancelled = false;
    
    if (!mounted) return;
    // 진행 현황 다이얼로그 표시
    // ignore: use_build_context_synchronously
    final progressDialog = _showWordTransferProgressDialog(
      context,
      action: '이동',
      totalCount: _selectedWordIds.length,
      progressNotifier: progressNotifier,
      onCancel: () {
        cancelled = true;
        if(mounted) {
          // ignore: use_build_context_synchronously
          Navigator.of(context, rootNavigator: true).pop();
        }
      },
    );

    for (final wordId in _selectedWordIds) {
      if (cancelled) break;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('devices')
            .doc(widget.deviceId)
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
      progressNotifier.value++;
    }
    _clearSelection();

    if (mounted) {
      // ignore: use_build_context_synchronously
      Navigator.of(context, rootNavigator: true).pop(); // 진행 다이얼로그 닫기
      await progressDialog;
      if (mounted) {
        // ignore: use_build_context_synchronously
        await _showWordTransferResultDialog(context,
          action: '이동',
          successCount: movedCount,
          duplicateCount: duplicateCount,
          failCount: failCount,
          targetDeviceId: targetDeviceId,
        );
      }
    }
  }

  // 선택 복사 다이얼로그: 내 devices 목록을 드롭다운으로 보여주고 선택
  Future<void> _copySelectedWords() async {
    final count = _selectedWordIds.length;
    if (count == 0) return;

    // 내 devices 목록 불러오기 (현재 기기 제외)
    final devicesSnapshot = await FirebaseFirestore.instance
        .collection('devices')
        .where('ownerEmail', isEqualTo: widget.email)
        .get();

    if (!mounted) return;
    final deviceOptions = devicesSnapshot.docs
        .where((d) => d.id != widget.deviceId)
        .map((d) => {
              'id': d.id,
              'label': '${d.id} - ${d['nickname'] ?? ''}',
            })
        .toList();
    // ignore: use_build_context_synchronously
    final targetDeviceId = await showDialog<String>(
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
    );
    
    if (targetDeviceId == null || targetDeviceId.isEmpty) return;
    if (!mounted) return;

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
    final progressNotifier = ValueNotifier<int>(0);
    bool cancelled = false;
    
    if (!mounted) return;
    // 진행 현황 다이얼로그 표시
    // ignore: use_build_context_synchronously
    final progressDialog = _showWordTransferProgressDialog(
      context,
      action: '복사',
      totalCount: _selectedWordIds.length,
      progressNotifier: progressNotifier,
      onCancel: () {
        cancelled = true;
        if(mounted) {
          // ignore: use_build_context_synchronously
          Navigator.of(context, rootNavigator: true).pop();
        }
      },
    );
    for (final wordId in _selectedWordIds) {
      if (cancelled) break;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('devices')
            .doc(widget.deviceId)
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
      progressNotifier.value++;
    }

    if (mounted) {
      // ignore: use_build_context_synchronously
      Navigator.of(context, rootNavigator: true).pop(); // 진행 다이얼로그 닫기
      await progressDialog;
      if (mounted) {
        // ignore: use_build_context_synchronously
        await _showWordTransferResultDialog(context,
          action: '복사',
          successCount: copiedCount,
          duplicateCount: duplicateCount,
          failCount: failCount,
          targetDeviceId: targetDeviceId,
        );
      }
    }
  }

  // 이동/복사 결과 요약 다이얼로그
  Future<void> _showWordTransferResultDialog(BuildContext context, {
    required String action,
    required int successCount,
    required int duplicateCount,
    required int failCount,
    required String targetDeviceId,
  }) async {
    if (!mounted) return;
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

  // 이동/복사 진행 현황 다이얼로그
  Future<void> _showWordTransferProgressDialog(BuildContext context, {
    required String action,
    required int totalCount,
    required ValueNotifier<int> progressNotifier,
    required VoidCallback onCancel,
  }) async {
    if (!mounted) return;
    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (ctx) => ValueListenableBuilder<int>(
        valueListenable: progressNotifier,
        builder: (ctx, progress, _) {
          final percent = totalCount == 0 ? 0.0 : progress / totalCount;
          return AlertDialog(
            title: Text('단어 $action 진행 중'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$progress / $totalCount'),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: percent),
              ],
            ),
            actions: [
              TextButton(
                onPressed: onCancel,
                child: const Text('취소'),
              ),
            ],
          );
        },
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
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('devices')
                  .doc(widget.deviceId)
                  .collection('words')
                  .orderBy('inputTimestamp', descending: true)
                  .get()
                  .then((snapshot) {
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
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  showTsvExportDialog(context, widget.deviceName, tsv);
                }
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('단어 추가'),
        onPressed: () {
          // ignore: use_build_context_synchronously
          showEditWordInputDialog(context).then((result) {
            if (!mounted) return;
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
                Future.wait(futures).then((_) {
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${result.length}개 단어가 추가되었습니다.')),
                    );
                  }
                });
              } else if (result is Map<String, String>) {
                // 단일 추가
                FirebaseFirestore.instance
                    .collection('devices')
                    .doc(widget.deviceId)
                    .collection('words')
                    .add({
                      ...result,
                      'inputTimestamp': FieldValue.serverTimestamp(),
                      'createdAt': FieldValue.serverTimestamp(),
                    }).then((_) {
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('단어가 추가되었습니다.')),
                    );
                  }
                });
              }
            }
          });
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
                      onEdit: () {
                        // ignore: use_build_context_synchronously
                        showEditWordInputDialog(context, word: word).then((input) {
                          if (!mounted) return;
                          if (input != null) {
                            FirebaseFirestore.instance
                                .collection('devices')
                                .doc(widget.deviceId)
                                .collection('words')
                                .doc(wordId)
                                .set({
                                  ...input,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true)).then((_) {
                              if (mounted) {
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('단어가 수정되었습니다.')),
                                );
                              }
                            });
                          }
                        });
                      },
                      onDelete: () {
                        // ignore: use_build_context_synchronously
                        showDeleteWordConfirmDialog(context, word['englishWord']).then((confirm) {
                          if (!mounted) return;
                          if (confirm == true) {
                            FirebaseFirestore.instance
                                .collection('devices')
                                .doc(widget.deviceId)
                                .collection('words')
                                .doc(wordId)
                                .delete().then((_) {
                              if (mounted) {
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('단어가 삭제되었습니다.')),
                                );
                              }
                            });
                          }
                        });
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