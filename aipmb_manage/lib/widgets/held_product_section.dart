import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_manage/providers/held_product_provider.dart';

class HeldProductSection extends ConsumerWidget {
  final String userName;
  const HeldProductSection({super.key, required this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(heldSummaryProvider(userName));

    return summaryAsync.when(
      data: (summary) {
        if (summary.wealthCount == 0 && summary.loanCount == 0 && summary.pensionCount == 0) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('持有产品', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (summary.wealthCount > 0)
              _buildProductCard(
                context,
                icon: Icons.savings,
                color: Colors.blue,
                title: '理财产品',
                count: summary.wealthCount,
                amount: summary.totalWealthAmount,
                subtitle: summary.wealthProducts.map((p) => p.productName).join("、"),
              ),
            if (summary.loanCount > 0)
              _buildProductCard(
                context,
                icon: Icons.account_balance,
                color: Colors.orange,
                title: '贷款',
                count: summary.loanCount,
                amount: summary.totalLoanAmount,
                subtitle: summary.loans.map((l) => l.loanType).join("、"),
              ),
            if (summary.pensionCount > 0)
              _buildProductCard(
                context,
                icon: Icons.elderly,
                color: Colors.teal,
                title: '养老金',
                count: summary.pensionCount,
                amount: summary.totalPensionAmount,
                subtitle: summary.pensions.map((p) => p.accountType).join("、"),
              ),
          ],
        );
      },
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      )),
      error: (e, _) => Text('加载持有产品失败: $e', style: TextStyle(color: Colors.red.shade400)),
    );
  }

  Widget _buildProductCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required int count,
    required double amount,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      Text(
                        '$count ${title == '贷款' ? '笔' : '个'} · ¥${amount.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
