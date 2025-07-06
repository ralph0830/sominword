import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin/widgets/word_card.dart';
import '../admin/dialogs.dart' show showEditDialog, showDeleteDialog;

class WordAdminPage extends StatelessWidget {
  final String deviceId;
  final String deviceName;
  const WordAdminPage({super.key, required this.deviceId, required this.deviceName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('단어 관리: $deviceName'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('단어 추가'),
        onPressed: () => showEditDialog(context, deviceId: deviceId),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceId)
            .collection('words')
            .orderBy('createdAt', descending: true)
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
                onEdit: () => showEditDialog(context, deviceId: deviceId, wordId: wordId, word: word),
                onDelete: () => showDeleteDialog(context, deviceId: deviceId, wordId: wordId),
              );
            },
          );
        },
      ),
    );
  }
} 