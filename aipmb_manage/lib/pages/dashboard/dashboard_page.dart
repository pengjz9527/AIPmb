import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_manage/widgets/stats_card.dart';
import 'package:aipmb_manage/providers/model_config_provider.dart';
import 'package:aipmb_manage/providers/user_provider.dart';
import 'package:aipmb_manage/providers/tagging_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider(''));
    final activeModelAsync = ref.watch(activeModelConfigProvider);
    final taggedUsersAsync = ref.watch(taggedUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI-Manage 运营管理'),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('运营概览', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: usersAsync.when(
                  data: (users) => StatsCard(
                    title: '用户数',
                    value: '${users.length}',
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                  loading: () => const StatsCard(title: '用户数', value: '...', icon: Icons.people, color: Colors.blue),
                  error: (_, __) => const StatsCard(title: '用户数', value: '-', icon: Icons.people, color: Colors.blue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: taggedUsersAsync.when(
                  data: (tagged) => StatsCard(
                    title: '已标记用户',
                    value: '${tagged.length}',
                    icon: Icons.label,
                    color: Colors.orange,
                  ),
                  loading: () => const StatsCard(title: '已标记用户', value: '...', icon: Icons.label, color: Colors.orange),
                  error: (_, __) => const StatsCard(title: '已标记用户', value: '-', icon: Icons.label, color: Colors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          activeModelAsync.when(
            data: (model) => StatsCard(
              title: '活跃模型',
              value: model?.name ?? '未配置',
              icon: Icons.smart_toy,
              color: Colors.green,
            ),
            loading: () => const StatsCard(title: '活跃模型', value: '...', icon: Icons.smart_toy, color: Colors.green),
            error: (_, __) => const StatsCard(title: '活跃模型', value: '-', icon: Icons.smart_toy, color: Colors.green),
          ),
          const SizedBox(height: 24),
          Text('快捷操作', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.model_training,
            title: '模型配置',
            subtitle: '管理大模型配置，切换活跃模型',
            onTap: () => context.push('/model-configs'),
          ),
          _ActionCard(
            icon: Icons.people_outline,
            title: '用户管理',
            subtitle: '查看用户信息，分析消费数据',
            onTap: () => context.push('/users'),
          ),
          _ActionCard(
            icon: Icons.label_outline,
            title: '标签管理',
            subtitle: '为已标记用户生成个性化标签',
            onTap: () => context.push('/users'),
          ),
          _ActionCard(
            icon: Icons.calendar_today,
            title: '纪念日历',
            subtitle: 'AI 生成用户与银行的纪念日历',
            onTap: () => context.push('/users'),
          ),
          _ActionCard(
            icon: Icons.auto_awesome,
            title: '产品匹配',
            subtitle: '标签与产品智能匹配推荐',
            onTap: () => context.push('/users'),
          ),
          _ActionCard(
            icon: Icons.monitor_heart,
            title: '技能监控',
            subtitle: '查看技能调用日志与执行详情',
            onTap: () => context.push('/skill-monitor'),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}