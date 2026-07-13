import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_manage/providers/user_provider.dart';
import 'package:aipmb_manage/providers/tagging_provider.dart';
import 'package:aipmb_manage/providers/matching_provider.dart';
import 'package:aipmb_manage/providers/calendar_provider.dart';
import 'package:aipmb_manage/providers/conversation_provider.dart';
import 'package:aipmb_manage/widgets/held_product_section.dart';
import 'package:aipmb_manage/widgets/marketing_leads_card.dart';

class UserDetailPage extends ConsumerWidget {
  final String userName;
  const UserDetailPage({super.key, required this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(userDetailProvider(userName));
    final tagsAsync = ref.watch(userTagsProvider(userName));
    final matchesAsync = ref.watch(matchesProvider(userName));
    final calendarAsync = ref.watch(calendarProvider(userName));
    final convSummaryAsync = ref.watch(conversationSummaryProvider(userName));

    return Scaffold(
      appBar: AppBar(title: Text(userName)),
      body: detailAsync.when(
        data: (detail) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _InfoCard(
              title: '资产概览',
              children: [
                _infoRow('总余额', '¥${detail.totalBalance.toStringAsFixed(2)}'),
                _infoRow('总信用额度', '¥${detail.totalCreditLimit.toStringAsFixed(2)}'),
                _infoRow('账户数', '${detail.accountCount}'),
                _infoRow('交易数', '${detail.transactionCount}'),
              ],
            ),
            const SizedBox(height: 16),
            _InfoCard(
              title: '账户列表',
              children: detail.accounts.map((a) => ListTile(
                    title: Text(a['卡种/产品'] ?? ''),
                    subtitle: Text('${a['账户类型']} · ${a['账号/卡号']}'),
                    trailing: Text('余额: ${a['最新余额(元)']}' '额度: ${a['信用额度(元)']}'),
                  )).toList(),
            ),
            const SizedBox(height: 16),
            _InfoCard(
              title: '消费分类 Top5',
              children: detail.consumptionStats.take(5).map((s) => _infoRow(
                    s['name'] ?? '',
                    '¥${(s['total'] as num).toStringAsFixed(0)} (${s['count']}笔)',
                  )).toList(),
            ),
            const SizedBox(height: 16),
            HeldProductSection(userName: userName),
            const SizedBox(height: 24),
            _ActionButton(
              icon: Icons.label,
              label: '标签管理',
              subtitle: tagsAsync.when(
                data: (t) => t != null ? '已有 ${t.tags.length} 个标签' : '暂无标签',
                loading: () => '加载中...',
                error: (_, __) => '加载失败',
              ),
              onTap: () => context.push('/users/$userName/tagging'),
            ),
            _ActionButton(
              icon: Icons.calendar_month,
              label: '纪念日历',
              subtitle: calendarAsync.when(
                data: (c) => c != null ? '已有 ${c.events.length} 个纪念事件' : '暂无日历',
                loading: () => '加载中...',
                error: (_, __) => '加载失败',
              ),
              onTap: () => context.push('/users/$userName/calendar'),
            ),
            _ActionButton(
              icon: Icons.recommend,
              label: '产品匹配',
              subtitle: matchesAsync.when(
                data: (m) => m != null ? '已匹配 ${m.matches.length} 个产品' : '暂无匹配',
                loading: () => '加载中...',
                error: (_, __) => '加载失败',
              ),
              onTap: () => context.push('/users/$userName/matching'),
            ),
            _ActionButton(
              icon: Icons.chat_bubble_outline,
              label: '对话记录',
              subtitle: convSummaryAsync.when(
                data: (s) {
                  final total = s['total_sessions'] ?? 0;
                  return total > 0 ? '共 $total 次对话' : '暂无对话';
                },
                loading: () => '加载中...',
                error: (_, __) => '加载失败',
              ),
              onTap: () => context.push('/users/$userName/conversations'),
            ),
            const SizedBox(height: 16),
            MarketingLeadsCard(userName: userName),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}