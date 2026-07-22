import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/providers/recommendation_provider.dart';
import 'package:aipmb_app/providers/auth_provider.dart';
import 'package:aipmb_app/models/history_today.dart';
import 'package:aipmb_app/pages/moment/widgets/section_header.dart';

class HistoryTodaySection extends ConsumerStatefulWidget {
  const HistoryTodaySection({super.key});

  @override
  ConsumerState<HistoryTodaySection> createState() => _HistoryTodaySectionState();
}

class _HistoryTodaySectionState extends ConsumerState<HistoryTodaySection> {
  bool _activated = false;

  void _activate() {
    if (_activated) return;
    setState(() => _activated = true);
  }

  IconData _benefitIcon(String icon) {
    switch (icon) {
      case 'emoji_events':
        return Icons.emoji_events;
      case 'favorite':
        return Icons.favorite;
      case 'flight':
        return Icons.flight;
      case 'card_giftcard':
        return Icons.card_giftcard;
      default:
        return Icons.auto_awesome;
    }
  }

  Color _benefitColor(String benefitType) {
    switch (benefitType) {
      case 'growth':
        return Colors.blue;
      case 'family':
        return Colors.pink;
      case 'travel':
        return Colors.orange;
      case 'lifestyle':
        return Colors.teal;
      default:
        return Colors.indigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_activated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionHeader(title: '往年今日'),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  final user = ref.read(authProvider).asData?.value?.name ?? '';
                  context.push('/calendar?user=${Uri.encodeComponent(user)}');
                },
                icon: const Icon(Icons.calendar_month, size: 16),
                label: const Text('纪念日历', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _activate,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.withValues(alpha: 0.08),
                      Colors.orange.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 40, color: Colors.amber.shade700),
                    const SizedBox(height: 12),
                    const Text(
                      '回顾你的金融故事',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '查看去年的今天，你做了什么重要的财务决定',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '点击回顾',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 16, color: Colors.amber.shade700),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final historyAsync = ref.watch(historyTodayProvider);

    return historyAsync.when(
      data: (result) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SectionHeader(title: '往年今日'),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    final user = ref.read(authProvider).asData?.value?.name ?? '';
                    context.push('/calendar?user=${Uri.encodeComponent(user)}');
                  },
                  icon: const Icon(Icons.calendar_month, size: 16),
                  label: const Text('纪念日历', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            if (result.hasMemory && result.memory != null) ...[
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              result.memory!.eventTypeLabel,
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${result.memory!.year}年',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        result.memory!.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      if (result.memory!.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          result.memory!.description,
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (result.benefit != null) ...[
                const SizedBox(height: 12),
                _buildBenefitCard(context, result.benefit!),
              ],
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text(
                        '还没有往年今日的记忆',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '生成纪念日历，发现专属的金融回忆',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          final user = ref.read(authProvider).asData?.value?.name ?? '';
                          context.push('/calendar?user=${Uri.encodeComponent(user)}');
                        },
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('生成纪念日历'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (result.yearsSummary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                result.yearsSummary,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ],
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('加载失败: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => ref.invalidate(historyTodayProvider),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitCard(BuildContext context, HistoryTodayBenefit benefit) {
    final color = _benefitColor(benefit.benefitType);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final product = benefit.linkedProduct;
          if (product != null) {
            context.push(
              '/product/detail?product_name=${Uri.encodeComponent(product.productName)}',
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_benefitIcon(benefit.icon), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      benefit.label,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      benefit.description,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (benefit.linkedProduct != null) const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
