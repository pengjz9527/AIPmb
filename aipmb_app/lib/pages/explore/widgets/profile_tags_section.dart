import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/providers/recommendation_provider.dart';
import 'package:aipmb_app/pages/moment/widgets/section_header.dart';

class ProfileTagsSection extends ConsumerStatefulWidget {
  const ProfileTagsSection({super.key});

  @override
  ConsumerState<ProfileTagsSection> createState() => _ProfileTagsSectionState();
}

class _ProfileTagsSectionState extends ConsumerState<ProfileTagsSection> {
  bool _activated = false;

  void _activate() {
    if (_activated) return;
    setState(() => _activated = true);
  }

  @override
  Widget build(BuildContext context) {
    // 未激活：展示引导卡片
    if (!_activated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '我的画像'),
          _TeaserCard(
            icon: Icons.psychology_outlined,
            gradientColors: const [Color(0xFF7C4DFF), Color(0xFFB388FF)],
            title: '发现你的消费人格',
            description: 'AI 根据你的消费习惯，为你生成专属标签画像',
            actionLabel: '点击探索',
            onTap: _activate,
          ),
        ],
      );
    }

    // 已激活：加载并展示数据
    final tagsAsync = ref.watch(profileTagsProvider);

    return tagsAsync.when(
      data: (profile) {
        final labels = profile.displayLabels;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: '我的画像'),
            if (labels.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('暂无标签数据', style: TextStyle(color: Colors.grey)),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: labels.map((label) {
                  return ActionChip(
                    label: Text(label, style: const TextStyle(fontSize: 13)),
                    avatar: const Icon(Icons.auto_awesome, size: 16),
                    onPressed: () {
                      context.push('/chat?msg=${Uri.encodeComponent('分析我的$label')}');
                    },
                  );
                }).toList(),
              ),
              if (profile.hasAiTags) ...[
                const SizedBox(height: 8),
                ...profile.aiTags.map((tag) {
                  if (tag.description.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${tag.name}：${tag.description}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  );
                }),
              ],
            ],
          ],
        );
      },
      loading: () => const _LoadingCard(),
      error: (e, _) => _ErrorCard(
        message: '加载失败: $e',
        onRetry: () => ref.invalidate(profileTagsProvider),
      ),
    );
  }
}

/// 引导卡片 — 点击前展示
class _TeaserCard extends StatelessWidget {
  final IconData icon;
  final List<Color> gradientColors;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  const _TeaserCard({
    required this.icon,
    required this.gradientColors,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors.map((c) => c.withValues(alpha: 0.06)).toList(),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 40, color: gradientColors.first),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    actionLabel,
                    style: TextStyle(fontSize: 13, color: gradientColors.first, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16, color: gradientColors.first),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 加载中卡片
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

/// 错误卡片
class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(message, style: const TextStyle(color: Colors.red, fontSize: 12)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
