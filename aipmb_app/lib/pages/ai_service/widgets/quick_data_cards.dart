import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/providers/ai_service_provider.dart';
import 'package:aipmb_app/providers/account_provider.dart';

/// 快捷数据卡片区 — 2列: 盯收支·上月 / 盯收益
class QuickDataCards extends ConsumerWidget {
  const QuickDataCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastMonthAsync = ref.watch(lastMonthSummaryProvider);
    final wealthAsync = ref.watch(wealthOverviewProvider);
    final isVisible = ref.watch(assetVisibilityProvider);

    const double cardHeight = 120;
    return Row(
      children: [
        // 盯收支·上月
        Expanded(
          child: SizedBox(
            height: cardHeight,
            child: _QuickCard(
              icon: Icons.receipt_long,
              title: '盯收支 | 上月',
              content: lastMonthAsync.when(
                data: (summary) => _buildExpenseSummary(summary, isVisible),
                loading: () => const Text('加载中...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                error: (_, _) => const Text('暂无数据', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              onTap: () => context.push('/chat?msg=${Uri.encodeComponent('帮我分析上月收支情况')}'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 盯收益
        Expanded(
          child: SizedBox(
            height: cardHeight,
            child: _QuickCard(
              icon: Icons.trending_up,
              title: '盯收益',
              content: wealthAsync.when(
                data: (wealth) => _buildYieldSummary(wealth, isVisible),
                loading: () => const Text('加载中...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                error: (_, _) => const Text('暂无数据', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              onTap: () => context.push('/chat?msg=${Uri.encodeComponent('帮我看看收益情况')}'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseSummary(Map<String, dynamic> summary, bool isVisible) {
    // summary 可能包含 items 列表或总计
    final items = summary['items'];
    if (items is List && items.isNotEmpty) {
      // 取 top1 分类
      final top = items[0];
      final name = top['name'] ?? '未知';
      final total = (top['total'] ?? 0).toDouble();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVisible ? '¥${total.toStringAsFixed(0)}' : '****',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            '$name消费占比最高',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isVisible ? '--' : '****',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text('暂无上月消费数据', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildYieldSummary(dynamic wealth, bool isVisible) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '上月收益',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          isVisible
              ? (wealth.netWorth > 0 ? '¥${(wealth.netWorth * 0.003).toStringAsFixed(2)}' : '--')
              : '****',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          wealth.totalAssets > 0 ? '当前有持仓' : '当前无持仓',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget content;
  final VoidCallback? onTap;

  const _QuickCard({
    required this.icon,
    required this.title,
    required this.content,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              content,
            ],
          ),
        ),
      ),
    );
  }
}
