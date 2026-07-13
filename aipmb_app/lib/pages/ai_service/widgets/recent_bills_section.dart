import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_app/providers/ai_service_provider.dart';
import 'package:aipmb_app/models/transaction.dart';

/// 最近账单模块 — 展示最近5条交易，按日期分组，带分类标签
class RecentBillsSection extends ConsumerWidget {
  const RecentBillsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transAsync = ref.watch(recentTransactionsProvider);
    final isVisible = ref.watch(assetVisibilityProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        Row(
          children: [
            const Text('最近账单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(width: 16),
            Text('我的记账', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            const Spacer(),
            TextButton.icon(
              onPressed: () {},
              icon: Icon(Icons.edit_outlined, size: 14, color: theme.colorScheme.primary),
              label: Text('记一笔', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 交易列表
        transAsync.when(
          data: (transactions) => transactions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('暂无交易记录', style: TextStyle(color: Colors.grey))),
                )
              : _buildTransactionList(context, transactions, isVisible),
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('加载失败', style: TextStyle(color: Colors.grey))),
          ),
        ),
        // 底部操作
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {},
                child: Text('查看更多 >', style: TextStyle(fontSize: 13, color: theme.colorScheme.primary)),
              ),
            ],
          ),
        ),
        Center(
          child: TextButton.icon(
            onPressed: () {},
            icon: Icon(Icons.settings_outlined, size: 14, color: Colors.grey.shade500),
            label: Text('更多设置', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(BuildContext context, List<Transaction> transactions, bool isVisible) {
    // 按日期分组
    final Map<String, List<Transaction>> grouped = {};
    for (final tx in transactions) {
      final dateKey = tx.date.length >= 10 ? tx.date.substring(0, 10) : tx.date;
      grouped.putIfAbsent(dateKey, () => []).add(tx);
    }

    return Column(
      children: grouped.entries.map((entry) {
        final dateLabel = _formatDateLabel(entry.key);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期分组头
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                children: [
                  Text(dateLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                  const SizedBox(width: 8),
                  // 卡号掩码（模拟）
                  Text('•• ••••', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ],
              ),
            ),
            // 该日期下的交易
            ...entry.value.map((tx) => _buildTransactionItem(context, tx, isVisible)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction tx, bool isVisible) {
    final category = tx.category ?? '其他';
    final icon = _iconForCategory(category);
    final color = _colorForCategory(category);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          // 分类图标
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          // 描述 + 分类标签
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      _formatShortDate(tx.date),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(fontSize: 10, color: color),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 金额
          Text(
            isVisible
                ? (tx.transactionType == 'income' || tx.amount > 0
                    ? '+¥${tx.amount.abs().toStringAsFixed(2)}'
                    : '-¥${tx.amount.abs().toStringAsFixed(2)}')
                : '****',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tx.transactionType == 'income' ? Colors.green.shade600 : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateLabel(String dateStr) {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (dateStr == today) return '今日';
    // 取 MM-DD
    if (dateStr.length >= 10) {
      return '${dateStr.substring(5, 7)}-${dateStr.substring(8, 10)}';
    }
    return dateStr;
  }

  String _formatShortDate(String dateStr) {
    if (dateStr.length >= 10) {
      return '${dateStr.substring(5, 7)}-${dateStr.substring(8, 10)}';
    }
    return dateStr;
  }

  static IconData _iconForCategory(String category) {
    const map = {
      '餐饮美食': Icons.restaurant,
      '文化休闲': Icons.sports_esports,
      '交通出行': Icons.directions_car,
      '网购': Icons.shopping_cart,
      '生活缴费': Icons.receipt_long,
      '医疗健康': Icons.local_hospital,
      '教育培训': Icons.school,
      '通讯软件数码': Icons.phone_android,
      '其他': Icons.payment,
    };
    for (final entry in map.entries) {
      if (category.contains(entry.key)) return entry.value;
    }
    return Icons.payment;
  }

  static Color _colorForCategory(String category) {
    const map = {
      '餐饮美食': Colors.orange,
      '文化休闲': Colors.purple,
      '交通出行': Colors.blue,
      '网购': Colors.teal,
      '生活缴费': Colors.green,
      '医疗健康': Colors.red,
      '教育培训': Colors.indigo,
      '通讯软件数码': Colors.cyan,
    };
    for (final entry in map.entries) {
      if (category.contains(entry.key)) return entry.value;
    }
    return Colors.grey;
  }
}
