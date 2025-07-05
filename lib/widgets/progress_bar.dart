import 'package:flutter/material.dart';

class ProgressIndicatorBar extends StatelessWidget {
  final int currentIndex;
  final int total;
  final Color color;
  const ProgressIndicatorBar({super.key, required this.currentIndex, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    if (total <= 1) {
      return const SizedBox(height: 24);
    }
    final double barAreaWidth = MediaQuery.of(context).size.width * 0.8;
    final double barWidth = (barAreaWidth - (total - 1) * 2) / total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: barAreaWidth,
            height: 18,
            child: Row(
              children: List.generate(total, (idx) {
                final isActive = idx == currentIndex;
                return Container(
                  width: barWidth > 4 ? barWidth : 4,
                  height: 18,
                  margin: EdgeInsets.only(right: idx == total - 1 ? 0 : 2),
                  decoration: BoxDecoration(
                    color: isActive ? color : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: barAreaWidth,
            child: Text(
              '${currentIndex + 1} / $total',
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
} 