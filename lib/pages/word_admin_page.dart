import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin/widgets/word_card.dart';
import 'package:admin/admin/dialogs.dart' show showEditWordInputDialog, showDeleteWordConfirmDialog, showTsvExportDialog;

class WordAdminPage extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  const WordAdminPage({super.key, required this.deviceId, required this.deviceName});

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
    if (!context.mounted) return;
    if (confirm != true) return;
    final futures = _selectedWordIds.map((wordId) =>
      FirebaseFirestore.instance
        .collection('devices')
        .doc(deviceId)
        .collection('words')
        .doc(wordId)
        .delete()
    ).toList();
    await Future.wait(futures);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count개 단어가 삭제되었습니다.')),
    );
    _clearSelection();
  }

  Future<void> _moveSelectedWords() async {
    final deviceId = widget.deviceId;
    final count = _selectedWordIds.length;
    if (count == 0) return;
    // 이동할 기기 ID 입력 다이얼로그
    final targetDeviceId = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('선택 이동'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '이동할 기기 ID'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('이동')),
          ],
        );
      },
    );
    if (!context.mounted) return;
    if (targetDeviceId == null || targetDeviceId.isEmpty) return;
    final moveFutures = _selectedWordIds.map((wordId) async {
      final doc = await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .collection('words')
          .doc(wordId)
          .get();
      final data = doc.data();
      if (data != null) {
        await FirebaseFirestore.instance
            .collection('devices')
            .doc(targetDeviceId)
            .collection('words')
            .add({...data, 'inputTimestamp': FieldValue.serverTimestamp(), 'createdAt': FieldValue.serverTimestamp()});
        await doc.reference.delete();
      }
    }).toList();
    await Future.wait(moveFutures);
    _clearSelection();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count개 단어가 $targetDeviceId로 이동되었습니다.')),
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
          final input = await showEditWordInputDialog(context);
          if (!context.mounted) return;
          if (input != null) {
            await FirebaseFirestore.instance
                .collection('devices')
                .doc(widget.deviceId)
                .collection('words')
                .add({
                  ...input,
                  'inputTimestamp': FieldValue.serverTimestamp(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('단어가 추가되었습니다.')),
            );
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
            return Center(child: Text('오류: \\${snapshot.error}'));
          }
          final words = snapshot.data?.docs ?? [];
          if (words.isEmpty) {
            return const Center(child: Text('등록된 단어가 없습니다.'));
          }
          return ListView.builder(
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
          );
        },
      ),
    );
  }
} 