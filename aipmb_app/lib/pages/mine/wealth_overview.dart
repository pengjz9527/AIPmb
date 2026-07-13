import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_app/providers/account_provider.dart';
import 'package:intl/intl.dart';

class WealthOverviewCard extends ConsumerWidget {
  const WealthOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wealthAsync = ref.watch(wealthOverviewProvider);

    return wealthAsync.when(
      data: (wealth) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('财富总览', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              _buildAmountRow(context, '总资产', wealth.totalAssets, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              _buildAmountRow(context, '总负债', wealth.totalLiabilities, color: Colors.red),
              const Divider(height: 24),
              _buildAmountRow(context, '净资产', wealth.netWorth, color: Theme.of(context).colorScheme.primary, isBold: true),
              if (wealth.breakdown.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('资产分布', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                ...wealth.breakdown.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(item.accountType, style: const TextStyle(fontSize: 13)),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: wealth.totalAssets > 0 ? item.totalBalance / wealth.totalAssets : 0,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: Text(
                          _formatAmount(item.totalBalance),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
      loading: () => const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Text('加载失败: $e'))),
    );
  }

  Widget _buildAmountRow(BuildContext context, String label, double amount, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        Text(
          _formatAmount(amount),
          style: TextStyle(
            fontSize: isBold ? 20 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    final format = NumberFormat('#,##0.00', 'zh_CN');
    return '¥${format.format(amount)}';
  }
}
