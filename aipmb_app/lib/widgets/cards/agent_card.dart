import 'package:flutter/material.dart';
import 'package:aipmb_app/models/agent.dart';

/// 智能体图标入口卡片
class AgentEntryCard extends StatelessWidget {
  final AgentInfo agent;
  final VoidCallback onTap;

  const AgentEntryCard({super.key, required this.agent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(_agentIcon(agent.agentId), size: 24, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(
              agent.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  IconData _agentIcon(String agentId) {
    switch (agentId) {
      case 'financial_planner':
        return Icons.trending_up;
      case 'income_expense_analyst':
        return Icons.analytics;
      case 'user_profiler':
        return Icons.person_search;
      default:
        return Icons.smart_toy;
    }
  }
}
