class ConversationItem {
  final String sessionId;
  final String userName;
  final String startedAt;
  final String endedAt;
  final int messageCount;
  final String preview;
  final List<String> businessTypes;
  final String timeRange;
  final String source;
  final bool compressed;
  final bool hasSummary;

  ConversationItem({
    required this.sessionId,
    required this.userName,
    required this.startedAt,
    required this.endedAt,
    required this.messageCount,
    required this.preview,
    required this.businessTypes,
    required this.timeRange,
    required this.source,
    required this.compressed,
    required this.hasSummary,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    return ConversationItem(
      sessionId: json['session_id'] ?? '',
      userName: json['user_name'] ?? '',
      startedAt: json['started_at'] ?? '',
      endedAt: json['ended_at'] ?? '',
      messageCount: json['message_count'] ?? 0,
      preview: json['preview'] ?? '',
      businessTypes: List<String>.from(json['business_types'] ?? []),
      timeRange: json['time_range'] ?? 'older',
      source: json['source'] ?? 'memory',
      compressed: json['compressed'] ?? false,
      hasSummary: json['has_summary'] ?? false,
    );
  }

  String get timeRangeLabel {
    switch (timeRange) {
      case 'today':
        return '今天';
      case 'week':
        return '本周';
      case 'month':
        return '本月';
      default:
        return '更早';
    }
  }

  String get sourceLabel => source == 'realtime' ? '实时' : '历史';
}

class ConversationMessage {
  final String role;
  final String content;

  ConversationMessage({required this.role, required this.content});

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      role: json['role'] ?? '',
      content: json['content'] ?? '',
    );
  }
}

class ConversationDetail {
  final String sessionId;
  final String userName;
  final String startedAt;
  final String endedAt;
  final List<ConversationMessage> messages;
  final String summary;
  final bool compressed;
  final List<String> businessTypes;
  final String source;

  ConversationDetail({
    required this.sessionId,
    required this.userName,
    required this.startedAt,
    required this.endedAt,
    required this.messages,
    required this.summary,
    required this.compressed,
    required this.businessTypes,
    required this.source,
  });

  factory ConversationDetail.fromJson(Map<String, dynamic> json) {
    return ConversationDetail(
      sessionId: json['session_id'] ?? '',
      userName: json['user_name'] ?? '',
      startedAt: json['started_at'] ?? '',
      endedAt: json['ended_at'] ?? '',
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => ConversationMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      summary: json['summary'] ?? '',
      compressed: json['compressed'] ?? false,
      businessTypes: List<String>.from(json['business_types'] ?? []),
      source: json['source'] ?? 'memory',
    );
  }
}

class ConversationQuery {
  final String userName;
  final String keyword;
  final String businessType;
  final String timeRange;
  final int limit;
  final int offset;

  ConversationQuery({
    required this.userName,
    this.keyword = '',
    this.businessType = '',
    this.timeRange = '',
    this.limit = 20,
    this.offset = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationQuery &&
          runtimeType == other.runtimeType &&
          userName == other.userName &&
          keyword == other.keyword &&
          businessType == other.businessType &&
          timeRange == other.timeRange &&
          limit == other.limit &&
          offset == other.offset;

  @override
  int get hashCode =>
      userName.hashCode ^
      keyword.hashCode ^
      businessType.hashCode ^
      timeRange.hashCode ^
      limit.hashCode ^
      offset.hashCode;
}

class ConversationDetailQuery {
  final String userName;
  final String sessionId;

  ConversationDetailQuery({required this.userName, required this.sessionId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationDetailQuery &&
          runtimeType == other.runtimeType &&
          userName == other.userName &&
          sessionId == other.sessionId;

  @override
  int get hashCode => userName.hashCode ^ sessionId.hashCode;
}

class ConversationListResult {
  final List<ConversationItem> items;
  final int total;

  ConversationListResult({required this.items, required this.total});
}


