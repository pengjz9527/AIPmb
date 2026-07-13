import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_app/providers/account_provider.dart';
import 'package:aipmb_app/models/account.dart';
import 'package:intl/intl.dart';

class AccountListSection extends ConsumerWidget {
  const AccountListSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return accountsAsync.when(
      data: (accounts) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('我的账户', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text('${accounts.length}个账户', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          ...accounts.map((account) => _AccountCard(account: account)),
        ],
      ),
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
      error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('加载失败: $e')),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;
  const _AccountCard({required this.account});

  bool get _isCreditCard {
    final t = account.accountType;
    return t.contains('信用') || t.contains('贷记');
  }

  bool get _isDebitCard {
    final t = account.accountType;
    return t.contains('储蓄') || t.contains('借记');
  }

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat('#,##0.00', 'zh_CN');
    final iconData = _getIconForType(account.accountType);
    final color = _getColorForType(account.accountType);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 账户信息行
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.1),
                  radius: 20,
                  child: Icon(iconData, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(account.accountName,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text('${account.accountType} · ${account.accountId}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Text(
                  '¥${format.format(account.balance)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: account.balance >= 0 ? Colors.black87 : Colors.red,
                  ),
                ),
              ],
            ),
            // 快捷按钮区域
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),
            _buildQuickActions(context, color),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    if (type.contains('储蓄') || type.contains('借记')) return Icons.account_balance_wallet;
    if (type.contains('信用') || type.contains('贷记')) return Icons.credit_card;
    if (type.contains('基金') || type.contains('理财')) return Icons.trending_up;
    if (type.contains('贷款')) return Icons.home;
    return Icons.account_balance;
  }

  Color _getColorForType(String type) {
    if (type.contains('储蓄') || type.contains('借记')) return Colors.blue;
    if (type.contains('信用') || type.contains('贷记')) return Colors.orange;
    if (type.contains('基金') || type.contains('理财')) return Colors.green;
    if (type.contains('贷款')) return Colors.red;
    return Colors.grey;
  }

  Widget _buildQuickActions(BuildContext context, Color accentColor) {
    final List<_QuickAction> actions;
    if (_isCreditCard) {
      actions = const [
        _QuickAction(icon: Icons.receipt_long, label: '账单查询'),
        _QuickAction(icon: Icons.payment, label: '一键还款'),
        _QuickAction(icon: Icons.schedule, label: '自动还款'),
      ];
    } else if (_isDebitCard) {
      actions = const [
        _QuickAction(icon: Icons.swap_horiz, label: '转账'),
        _QuickAction(icon: Icons.list_alt, label: '交易明细'),
        _QuickAction(icon: Icons.calendar_month, label: '转账计划'),
      ];
    } else {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: actions.map((action) {
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${account.accountName} - ${action.label}'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(action.icon, size: 20, color: accentColor),
                const SizedBox(height: 2),
                Text(
                  action.label,
                  style: TextStyle(fontSize: 11, color: accentColor),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  const _QuickAction({required this.icon, required this.label});
}
