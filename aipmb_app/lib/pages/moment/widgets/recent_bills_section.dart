import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/models/transaction.dart';
import 'package:aipmb_app/providers/recommendation_provider.dart';

class RecentBillsSection extends ConsumerWidget {
  const RecentBillsSection({super.key});

  static ({IconData icon, Color color}) _catMeta(String category) {
    const meta = <String, ({IconData icon, Color color})>{
      '餐饮美食':   (icon: Icons.restaurant,        color: Color(0xFFFF7043)),
      '文化休闲':   (icon: Icons.movie,              color: Color(0xFFAB47BC)),
      '交通出行':   (icon: Icons.directions_car,     color: Color(0xFF42A5F5)),
      '网购':       (icon: Icons.shopping_bag,       color: Color(0xFFEC407A)),
      '快捷支付':   (icon: Icons.flash_on,           color: Color(0xFFFFCA28)),
      '银联快捷支付':(icon: Icons.credit_card,        color: Color(0xFF26A69A)),
      '生活缴费':   (icon: Icons.receipt_long,       color: Color(0xFF78909C)),
      '自助缴费':   (icon: Icons.receipt_long,       color: Color(0xFF78909C)),
      '医疗健康':   (icon: Icons.local_hospital,     color: Color(0xFFEF5350)),
      '教育培训':   (icon: Icons.school,             color: Color(0xFF5C6BC0)),
      '通讯软件数码':(icon: Icons.phone_android,      color: Color(0xFF29B6F6)),
    };
    for (final key in meta.keys) {
      if (category.contains(key)) return meta[key]!;
    }
    return (icon: Icons.receipt, color: Colors.grey);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(recentTransactionsProvider);
    final visible = ref.watch(assetVisibilityProvider);

    return txAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) return const SizedBox.shrink();

        // 支出型交易：排除明顯的理財/退款類型
        final expenses = transactions.where((t) {
          final tt = t.transactionType;
          return !tt.contains('收入') &&
                 !tt.contains('退款') &&
                 !tt.contains('理财') &&
                 !tt.contains('赎回');
        }).toList();

        final totalExpense = expenses.fold<double>(0, (s, t) => s + t.amount);
        final topCategories = _topCategories(expenses, 3);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部
            Row(
              children: [
                const Text('消费速览', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/chat?msg=帮我分析最近的消费'),
                  child: const Text('深度分析', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 概览卡片
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 支出总额
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.trending_down, color: Colors.red.shade400, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('近期支出', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(
                              visible ? '¥ ${_formatAmount(totalExpense)}' : '****',
                              style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold,
                                color: Colors.red.shade400,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          '${expenses.length} 笔',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    if (topCategories.isNotEmpty) ...[
                      const Divider(height: 20),
                      ...topCategories.entries.map((e) {
                        final meta = _catMeta(e.key);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(meta.icon, size: 16, color: meta.color),
                              const SizedBox(width: 8),
                              Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                              Text(
                                visible ? '¥${_formatAmount(e.value)}' : '****',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.red.shade400),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 8),
                    // CTA
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/chat?msg=帮我分析最近的消费明细'),
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: const Text('问小易分析消费'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 最近3笔
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('最近账单', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/chat?msg=帮我列出所有账单'),
                  child: const Text('查看全部 >', style: TextStyle(fontSize: 12, color: Colors.blue)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...transactions.take(3).map((t) => _buildMiniRow(context, t, visible)),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMiniRow(BuildContext context, Transaction t, bool visible) {
    final meta = _catMeta(t.category ?? '');
    final isExpense = !t.transactionType.contains('收入');
    final label = t.description.isNotEmpty ? t.description : (t.category ?? t.transactionType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(meta.icon, size: 16, color: meta.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(
            visible
                ? '${isExpense ? "-" : "+"}¥${_formatAmount(t.amount)}'
                : '****',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: isExpense ? Colors.red.shade400 : Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// 按分类汇总支出
  Map<String, double> _topCategories(List<Transaction> expenses, int n) {
    final map = <String, double>{};
    for (final t in expenses) {
      final cat = t.category ?? '其他';
      map[cat] = (map[cat] ?? 0) + t.amount;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted.take(n)) e.key: e.value};
  }

  String _formatAmount(double amount) {
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}万';
    }
    return amount.toStringAsFixed(0);
  }
}
