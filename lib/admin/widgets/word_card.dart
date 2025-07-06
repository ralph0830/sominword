import 'package:flutter/material.dart';

class WordCard extends StatelessWidget {
  final Map<String, dynamic> word;
  final String wordId;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const WordCard({
    super.key,
    required this.word,
    required this.wordId,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final englishWord = word['englishWord'] ?? '';
    final koreanPartOfSpeech = word['koreanPartOfSpeech'] ?? '';
    final koreanMeaning = word['koreanMeaning'] ?? '';
    final sentence = word['sentence'] ?? '';
    final sentenceKor = word['sentenceKor'] ?? '';
    final inputTimestamp = word['inputTimestamp'];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.book, size: 32),
        title: Text(
          englishWord,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$koreanPartOfSpeech $koreanMeaning'),
            if (sentence.isNotEmpty) Text('예문: $sentence'),
            if (sentenceKor.isNotEmpty) Text('예문해석: $sentenceKor'),
            if (inputTimestamp != null && inputTimestamp is DateTime)
              Text(
                '${inputTimestamp.year}-${inputTimestamp.month.toString().padLeft(2, '0')}-${inputTimestamp.day.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit' && onEdit != null) {
              onEdit!();
            } else if (value == 'delete' && onDelete != null) {
              onDelete!();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('수정'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('삭제', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 