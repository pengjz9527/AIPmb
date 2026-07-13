import 'package:flutter/material.dart';
import 'package:aipmb_app/config/design_tokens.dart';
import 'package:aipmb_app/models/user_profile.dart';

/// 用户画像标签卡片 — 展示消费人格标签和画像描述
class ProfileCard extends StatelessWidget {
  final List<String> tags;
  final String? description;
  final List<AITagItem> aiTags;

  const ProfileCard({
    super.key,
    required this.tags,
    this.description,
    this.aiTags = const [],
  });

  @override
  Widget build(BuildContext context) {
    final hasAiTags = aiTags.isNotEmpty;
    final displayLabels = hasAiTags ? aiTags.map((t) => t.name).toList() : tags;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                ),
                child: Icon(Icons.person_outline,
                    color: Theme.of(context).colorScheme.primary, size: 18),
              ),
              const SizedBox(width: 8),
              const Text('我的画像', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(displayLabels.length, (index) {
              final label = displayLabels[index];
              final hasDetail = hasAiTags && index < aiTags.length;
              return ActionChip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.5),
                side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.15)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSM)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onPressed: hasDetail
                    ? () => _showTagDetail(context, aiTags[index])
                    : null,
              );
            }),
          ),
          if (description != null && description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(description!, style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5)),
          ],
        ],
      ),
    );
  }

  void _showTagDetail(BuildContext context, AITagItem tag) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(tag.name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(tag.description,
                style: TextStyle(
                    fontSize: 15, color: Colors.grey[700], height: 1.5)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
