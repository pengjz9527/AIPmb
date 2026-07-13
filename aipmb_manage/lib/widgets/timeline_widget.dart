import 'package:flutter/material.dart';
import 'package:aipmb_manage/models/calendar_event.dart';
import 'package:aipmb_manage/widgets/calendar_event_card.dart';

class TimelineWidget extends StatelessWidget {
  final List<MemorialEvent> events;

  const TimelineWidget({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(child: Text('暂无纪念事件'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        return CalendarEventCard(event: events[index]);
      },
    );
  }
}