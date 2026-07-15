import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aipmb_app/config/design_tokens.dart';
import 'package:aipmb_app/models/recommendation.dart';

class TodoCard extends StatelessWidget {
  final TodoItem item;
  final VoidCallback? onTap;
  final int? index;

  const TodoCard({
    super.key,
    required this.item,
    this.onTap,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _buildTypeIcon(item.type),
        title: Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: item.actionText != null
            ? TextButton(
                onPressed: onTap,
                child: Text(item.actionText!, style: const TextStyle(fontSize: 12)),
              )
            : const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );

    final delay = index != null ? DesignTokens.staggerDelay(index!) : DesignTokens.staggerBase;
    return card
        .animate(delay: delay, autoPlay: true)
        .fadeIn(
          duration: DesignTokens.durationEntrance,
          curve: DesignTokens.curveEntrance,
        )
        .slideX(
          begin: 0.04,
          end: 0,
          duration: DesignTokens.durationEntrance,
          curve: DesignTokens.curveEntrance,
        );
  }

  Widget _buildTypeIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'payment':
        icon = Icons.payment;
        color = Colors.orange;
        break;
      case 'payment_due':
        icon = Icons.receipt_long;
        color = Colors.orange;
        break;
      case 'investment':
        icon = Icons.trending_up;
        color = Colors.green;
        break;
      case 'bill':
        icon = Icons.receipt_long;
        color = Colors.blue;
        break;
      default:
        icon = Icons.task_alt;
        color = Colors.purple;
    }
    return CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20));
  }
}
