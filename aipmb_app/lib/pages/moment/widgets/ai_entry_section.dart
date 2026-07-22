import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/providers/agent_provider.dart';
import 'package:aipmb_app/models/agent.dart';

class AiEntrySection extends ConsumerWidget {
  const AiEntrySection({super.key});

  static IconData _iconForAgent(String agentId) {
    switch (agentId) {
      case 'financial_planner':
        return Icons.trending_up;
      case 'income_expense_analyst':
        return Icons.analytics_outlined;
      case 'user_profiler':
        return Icons.psychology_outlined;
      case 'lifestyle_assistant':
        return Icons.card_giftcard;
      default:
        return Icons.smart_toy;
    }
  }

  static Color _colorForAgent(String agentId) {
    switch (agentId) {
      case 'financial_planner':
        return const Color(0xFF4CAF50);
      case 'income_expense_analyst':
        return const Color(0xFF2196F3);
      case 'user_profiler':
        return const Color(0xFF9C27B0);
      case 'lifestyle_assistant':
        return const Color(0xFFFF9800);
      default:
        return Colors.grey;
    }
  }

  static String _quickMsgForAgent(String agentId) {
    switch (agentId) {
      case 'financial_planner':
        return '帮我制定一份理财方案';
      case 'income_expense_analyst':
        return '帮我分析收支状况';
      case 'user_profiler':
        return '给我画一个消费画像';
      case 'lifestyle_assistant':
        return '帮我看看有什么专属优惠和福利';
      default:
        return '你好';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(agentsProvider);
    final theme = Theme.of(context);

    return agentsAsync.when(
      data: (agents) {
        final filtered = agents.where((a) => a.agentId != 'general_assistant').toList();
        if (filtered.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary,
                  child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('AI 智能助手', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/chat'),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('对话'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: filtered.map((a) {
                return Expanded(child: _buildAgentCard(context, a, theme));
              }).toList(),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildAgentCard(BuildContext context, AgentInfo agent, ThemeData theme) {
    final icon = _iconForAgent(agent.agentId);
    final color = _colorForAgent(agent.agentId);
    final msg = _quickMsgForAgent(agent.agentId);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/chat?msg=${Uri.encodeComponent(msg)}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                agent.name,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
