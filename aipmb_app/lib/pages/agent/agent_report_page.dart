import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/providers/agent_provider.dart';
import 'package:aipmb_app/models/agent.dart';

class AgentReportPage extends ConsumerWidget {
  final String agentId;
  final String agentName;

  const AgentReportPage({
    super.key,
    required this.agentId,
    required this.agentName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(agentAnalyzeProvider(agentId));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.analytics_outlined, size: 20),
            const SizedBox(width: 8),
            Text('$agentName · 分析报告'),
          ],
        ),
      ),
      body: resultAsync.when(
        data: (result) => _buildReport(context, result),
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在深度分析中，请稍候...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('分析失败: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(agentAnalyzeProvider(agentId)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReport(BuildContext context, AgentResult result) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Agent 信息头
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.smart_toy, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.agentName.isNotEmpty ? result.agentName : agentName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const Text('深度分析报告', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Markdown 分析内容
        MarkdownBlock(
          data: result.content,
          config: MarkdownConfig.defaultConfig,
        ),
        const SizedBox(height: 16),

        // 结构化卡片
        ...result.cards.map((card) => _buildCard(context, card)),

        // 推荐后续智能体
        if (result.suggestedAgents.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('还可以咨询', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: result.suggestedAgents.map((id) {
              final name = _agentDisplayName(id);
              return ActionChip(
                avatar: const Icon(Icons.smart_toy_outlined, size: 16),
                label: Text(name),
                onPressed: () => context.push('/agent/$id?name=${Uri.encodeComponent(name)}'),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildCard(BuildContext context, AgentCard card) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_cardIcon(card.cardType), color: Theme.of(context).colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(card.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
          if (card.data != null) ...[
            const SizedBox(height: 8),
            Text(card.data.toString(), style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ],
      ),
    );
  }

  IconData _cardIcon(String cardType) {
    switch (cardType) {
      case 'wealth_plan':
        return Icons.pie_chart_outline;
      case 'survival_calc':
        return Icons.timer_outlined;
      case 'profile':
        return Icons.person_outline;
      case 'product_recommendation':
        return Icons.star_outline;
      default:
        return Icons.card_giftcard_outlined;
    }
  }

  String _agentDisplayName(String agentId) {
    switch (agentId) {
      case 'financial_planner':
        return '理财专家';
      case 'consumption_analyst':
        return '消费分析师';
      case 'life_assistant':
        return '生活管家';
      case 'user_profiler':
        return '画像分析师';
      default:
        return '小招';
    }
  }
}
