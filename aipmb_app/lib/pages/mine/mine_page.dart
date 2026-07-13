import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/models/risk_assessment.dart';
import 'package:aipmb_app/providers/auth_provider.dart';
import 'package:aipmb_app/providers/theme_provider.dart';
import 'package:aipmb_app/providers/held_product_provider.dart';
import 'package:aipmb_app/providers/risk_assessment_provider.dart';
import 'package:aipmb_app/pages/mine/wealth_overview.dart';
import 'package:aipmb_app/pages/mine/account_list.dart';
import 'package:aipmb_app/widgets/cards/held_product_card.dart';

class MinePage extends ConsumerWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.asData?.value;
    final userName = user?.name ?? '';
    final userPhone = user?.phone ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(heldWealthProductsProvider);
          ref.invalidate(heldLoansProvider);
          ref.invalidate(heldPensionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // 用户信息卡片
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        userName.isNotEmpty ? userName[0] : '?',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName.isNotEmpty ? userName : '未登录',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.phone_android, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                userPhone.isNotEmpty ? userPhone : '---',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 退出登录
                    TextButton(
                      onPressed: () => _showLogoutDialog(context, ref),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                      ),
                      child: const Text('退出'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 风险测评卡片
            Consumer(
              builder: (context, ref, _) {
                final assessmentAsync = ref.watch(riskAssessmentProvider);
                return assessmentAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                  data: (assessment) => _buildRiskCard(context, assessment, userName),
                );
              },
            ),
            const SizedBox(height: 16),
            const WealthOverviewCard(),
            const SizedBox(height: 16),
            const AccountListSection(),
            const SizedBox(height: 20),

            // 持有产品列表
            _buildHeldProductsSection(context),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildHeldProductsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('我的持有产品', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        Consumer(
          builder: (context, ref, _) {
            final wealthAsync = ref.watch(heldWealthProductsProvider);
            final loanAsync = ref.watch(heldLoansProvider);
            final pensionAsync = ref.watch(heldPensionsProvider);

            final allLoading = wealthAsync.isLoading && loanAsync.isLoading && pensionAsync.isLoading;
            if (allLoading) {
              return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
            }

            final children = <Widget>[];

            // 理财产品
            wealthAsync.whenData((products) {
              if (products.isNotEmpty) {
                children.add(_buildSubSectionHeader(Icons.savings, const Color(0xFF6C4DFF), '理财产品', '${products.length} 个产品'));
                for (final p in products) {
                  children.add(HeldWealthCard(
                    product: p,
                    onDetail: () => context.push('/held-products/detail', extra: {'type': 'wealth', 'data': p}),
                    onRedeem: () {},
                  ));
                }
              }
            });

            // 贷款
            loanAsync.whenData((loans) {
              if (loans.isNotEmpty) {
                children.add(_buildSubSectionHeader(Icons.account_balance, Colors.orange, '贷款', '${loans.length} 笔贷款'));
                for (final l in loans) {
                  children.add(HeldLoanCard(
                    loan: l,
                    onRepaymentPlan: () {},
                    onPrepay: () {},
                  ));
                }
              }
            });

            // 养老金
            pensionAsync.whenData((pensions) {
              if (pensions.isNotEmpty) {
                children.add(_buildSubSectionHeader(Icons.elderly, Colors.teal, '养老金', '${pensions.length} 个账户'));
                for (final p in pensions) {
                  children.add(HeldPensionCard(
                    pension: p,
                    onDetail: () => context.push('/held-products/detail', extra: {'type': 'pension', 'data': p}),
                  ));
                }
              }
            });

            if (children.isEmpty) {
              return const Padding(padding: EdgeInsets.all(16), child: Text('暂无持有产品', style: TextStyle(color: Colors.grey)));
            }

            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
          },
        ),
      ],
    );
  }

  Widget _buildRiskCard(BuildContext context, RiskAssessment assessment, String userName) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              assessment.isAssessed ? Icons.shield_outlined : Icons.warning_amber_outlined,
              color: assessment.isAssessed ? Colors.green : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '风险测评',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    assessment.isAssessed
                        ? '风险等级：${assessment.displayLevel} ${RiskAssessment.levelLabel(assessment.riskLevel)}（有效期至 ${assessment.expiryDate}）'
                        : '尚未进行风险测评',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (!assessment.isAssessed)
              FilledButton.tonal(
                onPressed: () {
                  context.push('/risk-assessment', extra: {'user': userName});
                },
                child: const Text('马上评级'),
              )
            else
              TextButton(
                onPressed: () {
                  context.push('/risk-assessment', extra: {'user': userName});
                },
                child: const Text('重新测评'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubSectionHeader(IconData icon, Color color, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
            ),
            child: const Text('确认退出'),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // ---- 主题选择 ----
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('主题选择',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
          ),
          ...AppThemeMode.values.map((mode) {
            final isSelected = currentTheme == mode;
            return ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _previewGradient(mode),
                  border: isSelected
                      ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2.5)
                      : null,
                ),
              ),
              title: Text(
                '${mode.emoji} ${mode.label}',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () => ref.read(themeModeProvider.notifier).state = mode,
            );
          }),
          const Divider(),
          // ---- 其他设置 ----
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('个人信息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('安全设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('消息通知'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('语言设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  /// 预览渐变圆
  static LinearGradient _previewGradient(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.sciFi:
        return const LinearGradient(colors: [Color(0xFF6C4DFF), Color(0xFF3B82F6)]);
      case AppThemeMode.anime:
        return const LinearGradient(colors: [Color(0xFFFF6B9D), Color(0xFF7C4DFF)]);
      case AppThemeMode.vibrant:
        return const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFF59E0B)]);
    }
  }
}
