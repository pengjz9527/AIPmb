import 'package:flutter/material.dart';
import 'package:aipmb_manage/models/match_result.dart';

class MatchProductCard extends StatelessWidget {
  final ProductMatch match;

  const MatchProductCard({super.key, required this.match});

  Color _scoreColor() {
    if (match.matchScore >= 0.8) return Colors.green;
    if (match.matchScore >= 0.6) return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(match.productName, style: Theme.of(context).textTheme.titleMedium),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _scoreColor().withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(match.matchScore * 100).toInt()}%',
                    style: TextStyle(color: _scoreColor(), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(label: Text(match.productCategory), visualDensity: VisualDensity.compact),
                const SizedBox(width: 8),
                Chip(label: Text(match.tagName), visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 8),
            Text(match.reasoning, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}