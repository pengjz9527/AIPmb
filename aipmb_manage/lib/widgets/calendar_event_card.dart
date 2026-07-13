import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aipmb_manage/models/calendar_event.dart';

class CalendarEventCard extends StatelessWidget {
  final MemorialEvent event;

  const CalendarEventCard({super.key, required this.event});

  IconData _eventIcon() {
    switch (event.eventType) {
      case 'milestone':
        return Icons.flag;
      case 'life_change':
        return Icons.home;
      case 'major_purchase':
        return Icons.shopping_cart;
      case 'emotion':
        return Icons.favorite;
      case 'growth':
        return Icons.trending_up;
      default:
        return Icons.star;
    }
  }

  Color _eventColor() {
    switch (event.eventType) {
      case 'milestone':
        return Colors.blue;
      case 'life_change':
        return Colors.orange;
      case 'major_purchase':
        return Colors.purple;
      case 'emotion':
        return Colors.red;
      case 'growth':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = event.date;
    try {
      final dt = DateTime.parse(event.date);
      formattedDate = DateFormat('yyyy年M月d日').format(dt);
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_eventIcon(), color: _eventColor(), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formattedDate, style: Theme.of(context).textTheme.bodySmall),
                      Text(event.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Chip(
                  label: Text(event.eventTypeLabel),
                  backgroundColor: _eventColor().withAlpha(30),
                  labelStyle: TextStyle(color: _eventColor(), fontSize: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(event.description, style: Theme.of(context).textTheme.bodyMedium),
            if (event.relatedTransactions.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              Text('关联交易', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              ...event.relatedTransactions.take(3).map((tx) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${tx['交易日期'] ?? ''}  ${tx['商户名称'] ?? tx['交易摘要'] ?? ''}  ¥${tx['交易金额'] ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}