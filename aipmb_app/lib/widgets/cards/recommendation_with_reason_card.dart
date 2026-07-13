import 'package:flutter/material.dart';
import 'package:aipmb_app/config/design_tokens.dart';

/// 含推荐原因的推荐卡片 — 基于用户画像的个性化推荐
class RecommendationWithReasonCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String reason;
  final String? tag;
  final VoidCallback? onTap;

  const RecommendationWithReasonCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.reason,
    this.tag,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(DesignTokens.spacingMD),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
          boxShadow: DesignTokens.shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                if (tag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(tag!, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(reason, style: TextStyle(fontSize: 12, color: Colors.amber[900], height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
