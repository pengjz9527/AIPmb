class MemorialEvent {
  final String date;
  final String eventType;
  final String title;
  final String description;
  final List<Map<String, dynamic>> relatedTransactions;
  final int importance;

  MemorialEvent({
    required this.date,
    required this.eventType,
    required this.title,
    required this.description,
    required this.relatedTransactions,
    required this.importance,
  });

  factory MemorialEvent.fromJson(Map<String, dynamic> json) {
    return MemorialEvent(
      date: json['date'] ?? '',
      eventType: json['event_type'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      relatedTransactions: List<Map<String, dynamic>>.from(json['related_transactions'] ?? []),
      importance: json['importance'] ?? 5,
    );
  }

  String get eventTypeLabel {
    switch (eventType) {
      case 'milestone':
        return '里程碑';
      case 'life_change':
        return '生活变迁';
      case 'major_purchase':
        return '重要消费';
      case 'emotion':
        return '情感记忆';
      case 'growth':
        return '成长轨迹';
      default:
        return '纪念';
    }
  }
}

class MemorialCalendar {
  final String userName;
  final List<MemorialEvent> events;
  final String generatedAt;
  final String modelUsed;

  MemorialCalendar({
    required this.userName,
    required this.events,
    required this.generatedAt,
    required this.modelUsed,
  });

  factory MemorialCalendar.fromJson(Map<String, dynamic> json) {
    return MemorialCalendar(
      userName: json['user_name'] ?? '',
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => MemorialEvent.fromJson(e))
              .toList() ??
          [],
      generatedAt: json['generated_at'] ?? '',
      modelUsed: json['model_used'] ?? '',
    );
  }
}