import 'package:flutter/material.dart';

/// 续航测算卡片 — 展示不同消费标准下的资金续航月数
class SurvivalCard extends StatelessWidget {
  final double normalMonths;
  final double survivalMonths;
  final double availableFunds;

  const SurvivalCard({
    super.key,
    required this.normalMonths,
    required this.survivalMonths,
    required this.availableFunds,
  });

  @override
  Widget build(BuildContext context) {
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
              Icon(Icons.timer_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text('续航测算', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('可用资金: ¥${availableFunds.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildScenario(context, '维持现状', normalMonths, Icons.check_circle_outline, Colors.blue),
              const SizedBox(width: 12),
              _buildScenario(context, '最低生存', survivalMonths, Icons.warning_amber_outlined, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScenario(BuildContext context, String label, double months, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text('${months.toStringAsFixed(1)}个月', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
