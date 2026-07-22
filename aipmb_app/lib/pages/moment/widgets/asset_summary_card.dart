import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:aipmb_app/providers/account_provider.dart';
import 'package:aipmb_app/providers/recommendation_provider.dart';
import 'package:aipmb_app/models/account.dart';

class AssetSummaryCard extends ConsumerWidget {
  const AssetSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wealthAsync = ref.watch(wealthOverviewProvider);
    final isVisible = ref.watch(assetVisibilityProvider);
    final theme = Theme.of(context);

    return wealthAsync.when(
      data: (wealth) => GestureDetector(
        onTap: () => context.push('/chat?msg=${Uri.encodeComponent('帮我分析一下我的财务状况')}'),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部指标
              _buildHeaderRow(context, wealth, isVisible, ref),
              const SizedBox(height: 16),
              // 月度收支
              _buildMonthlyRow(context, wealth, isVisible),
              const SizedBox(height: 12),
              // 资产构成饼图
              if (wealth.breakdown.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                _buildPieSection(context, wealth),
              ],
              // AI 洞察
              const SizedBox(height: 12),
              _buildAiInsight(context, ref),
            ],
          ),
        ),
      ),
      loading: () => _buildSkeleton(context),
      error: (_, __) => _buildSkeleton(context),
    );
  }

  Widget _buildHeaderRow(BuildContext context, WealthOverview wealth, bool isVisible, WidgetRef ref) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('总资产', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(
                isVisible ? _fmt(wealth.totalAssets) : '****',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => ref.read(assetVisibilityProvider.notifier).state = !isVisible,
          child: Icon(
            isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('净资产', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(
                isVisible ? _fmt(wealth.netWorth) : '****',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyRow(BuildContext context, WealthOverview wealth, bool isVisible) {
    final balance = wealth.monthlyIncome - wealth.monthlyExpense;
    final incTrend = _trendIcon(wealth.monthlyIncome, wealth.lastMonthIncome);
    final expTrend = _trendIcon(wealth.monthlyExpense, wealth.lastMonthExpense);

    return Row(
      children: [
        _buildMetric('本月收入', wealth.monthlyIncome, incTrend, Colors.green, isVisible),
        const SizedBox(width: 16),
        _buildMetric('本月支出', wealth.monthlyExpense, expTrend, Colors.red, isVisible),
        const SizedBox(width: 16),
        _buildMetric('结余', balance, null, Colors.blue.shade700, isVisible),
      ],
    );
  }

  Widget _buildMetric(String label, double amount, Widget? trend, Color color, bool isVisible) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                isVisible ? _fmtShort(amount) : '****',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
              ),
              if (trend != null) ...[const SizedBox(width: 4), trend],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieSection(BuildContext context, WealthOverview wealth) {
    final colors = [
      Colors.blue.shade400,
      Colors.teal.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.green.shade400,
    ];

    return Row(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: PieChart(
            PieChartData(
              sections: wealth.breakdown.asMap().entries.map((e) {
                final pct = wealth.totalAssets > 0 ? e.value.totalBalance / wealth.totalAssets * 100 : 0;
                return PieChartSectionData(
                  value: e.value.totalBalance,
                  color: colors[e.key % colors.length],
                  title: pct > 10 ? '${pct.round()}%' : '',
                  titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                  radius: 30,
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 25,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: wealth.breakdown.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: colors[e.key % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(e.value.accountType,
                        style: const TextStyle(fontSize: 11)),
                  ),
                  Text(_fmtShort(e.value.totalBalance),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAiInsight(BuildContext context, WidgetRef ref) {
    final insightAsync = ref.watch(aiInsightProvider);
    return insightAsync.when(
      data: (insight) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                insight.insight.isNotEmpty ? insight.insight : '小易正在分析你的财务数据...',
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
            Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _trendIcon(double current, double previous) {
    if (previous <= 0 || current <= 0) return const SizedBox.shrink();
    final change = ((current - previous) / previous * 100).round();
    if (change.abs() < 1) return const SizedBox.shrink();
    final up = change > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(up ? Icons.trending_up : Icons.trending_down, size: 12, color: up ? Colors.red.shade400 : Colors.green.shade600),
        Text('${change.abs()}%', style: TextStyle(fontSize: 10, color: up ? Colors.red.shade400 : Colors.green.shade600)),
      ],
    );
  }

  String _fmt(double v) => '¥${_format(v)}';
  String _fmtShort(double v) {
    if (v >= 10000) return '¥${(v / 10000).toStringAsFixed(1)}万';
    return '¥${_format(v)}';
  }

  String _format(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final intPart = int.parse(parts[0]).toString();
    final sb = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) sb.write(',');
      sb.write(intPart[i]);
    }
    return '$sb.${parts[1]}';
  }
}
