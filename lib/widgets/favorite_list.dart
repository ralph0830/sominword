import 'package:flutter/material.dart';

class FavoriteList extends StatelessWidget {
  final List<Map<String, dynamic>> favoriteWords;
  final bool Function(String word) isFavoriteWord;
  const FavoriteList({super.key, required this.favoriteWords, required this.isFavoriteWord});

  @override
  Widget build(BuildContext context) {
    debugPrint('[FavoriteList] build: favoriteWords.length=${favoriteWords.length}, 샘플: ${favoriteWords.isNotEmpty ? favoriteWords.first.toString() : '[]'}');
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
  }
} 