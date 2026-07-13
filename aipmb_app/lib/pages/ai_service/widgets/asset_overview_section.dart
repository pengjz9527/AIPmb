import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aipmb_app/providers/account_provider.dart';
import 'package:aipmb_app/providers/ai_service_provider.dart';

/// 资产总览区 — 总资产(加密/明文) + 四列分类资产(横向滑动)
class AssetOverviewSection extends ConsumerWidget {
  const AssetOverviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wealthAsync = ref.watch(wealthOverviewProvider);
    final isVisible = ref.watch(assetVisibilityProvider);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: wealthAsync.when(
        data: (wealth) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 总资产行
            Row(
              children: [
                Text('总资产', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(width: 4),
                Icon(Icons.trending_up, size: 14, color: Colors.grey.shade500),
                const Spacer(),
                Text(
                  '昨日收益(元)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(width: 4),
                Text(
                  isVisible ? '--' : '****',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 总资产金额 + 眼睛切换
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  isVisible ? _formatAmount(wealth.totalAssets) : '******',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: isVisible ? 0 : 2,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => ref.read(assetVisibilityProvider.notifier).state = !isVisible,
                  child: Icon(
                    isVisible ? Icons.visibility : Icons.visibility_off,
                    size: 20,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 三列分类资产
            _buildAssetCategories(context, wealth, isVisible),
          ],
        ),
        loading: () => const SizedBox(
          height: 140,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => SizedBox(
          height: 140,
          child: Center(child: Text('加载失败', style: TextStyle(color: Colors.grey.shade500))),
        ),
      ),
    );
  }

  Widget _buildAssetCategories(BuildContext context, dynamic wealth, bool isVisible) {
    // 从 breakdown 中提取分类
    double liquidAssets = 0; // 流动资产(借记卡)
    double wealthMgmt = 0;  // 理财资产(理财产品)
    double protectAssets = 0; // 保障资产(保险/养老金)
    double creditAssets = 0; // 信用资产(信用卡)

    if (wealth.breakdown != null) {
      for (final item in wealth.breakdown) {
        final type = item.accountType.toLowerCase();
        if (type.contains('信用') || type.contains('credit')) {
          creditAssets += item.totalBalance;
        } else if (type.contains('理财') || type.contains('基金') || type.contains('wealth')) {
          wealthMgmt += item.totalBalance;
        } else if (type.contains('保险') || type.contains('养老') || type.contains('保障') || type.contains('pension')) {
          protectAssets += item.totalBalance;
        } else {
          liquidAssets += item.totalBalance;
        }
      }
    }
    // 如果没有分类数据，用总资产/负债兜底
    if (liquidAssets == 0 && wealthMgmt == 0 && protectAssets == 0 && creditAssets == 0) {
      liquidAssets = wealth.totalAssets;
      creditAssets = wealth.totalLiabilities;
    }

    return SizedBox(
      height: 135,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        child: Row(
          children: [
            _assetCard(context, '流动资产', liquidAssets, isVisible, Colors.blue.shade700, Icons.account_balance_wallet),
            const SizedBox(width: 12),
            _assetCard(context, '理财资产', wealthMgmt, isVisible, Colors.purple.shade600, Icons.pie_chart_outline),
            const SizedBox(width: 12),
            _assetCard(context, '保障资产', protectAssets, isVisible, Colors.green.shade700, Icons.shield_outlined),
            const SizedBox(width: 12),
            _assetCard(context, '信用资产', creditAssets, isVisible, Colors.orange.shade700, Icons.credit_card),
          ],
        ),
      ),
    );
  }

  Widget _assetCard(BuildContext context, String label, double amount, bool isVisible, Color color, IconData icon) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isVisible ? _formatAmountShort(amount) : '****',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    final format = NumberFormat('#,##0.00', 'zh_CN');
    return '¥${format.format(amount)}';
  }

  String _formatAmountShort(double amount) {
    if (amount == 0) return '--';
    if (amount >= 10000) {
      return '¥${(amount / 10000).toStringAsFixed(2)}万';
    }
    return '¥${amount.toStringAsFixed(0)}';
  }
}
