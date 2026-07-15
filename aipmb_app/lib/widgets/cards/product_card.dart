import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aipmb_app/config/design_tokens.dart';
import 'package:aipmb_app/models/recommendation.dart';

class ProductRecommendationCard extends StatelessWidget {
  final ProductRecommendation item;
  final VoidCallback? onTap;
  final int? index;

  const ProductRecommendationCard({
    super.key,
    required this.item,
    this.onTap,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLG)),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.productName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusXS),
                    ),
                    child: Text(
                      item.productType.isEmpty ? item.category : item.productType,
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ],
              ),
              if (item.riskLevel.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('风险等级', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 8),
                    Text(
                      item.riskLevel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: item.riskLevel.contains('低')
                            ? Colors.green
                            : item.riskLevel.contains('中低')
                                ? Colors.blue
                                : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusSM),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.reason,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onTap != null)
                      Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final delay = index != null ? DesignTokens.staggerDelay(index!) : null;
    return delay != null
        ? card.animate(delay: delay, autoPlay: true).fadeIn(
            duration: DesignTokens.durationEntrance,
            curve: DesignTokens.curveEntrance,
          ).slideY(
            begin: 0.06,
            end: 0,
            duration: DesignTokens.durationEntrance,
            curve: DesignTokens.curveEntrance,
          )
        : card;
  }
}
