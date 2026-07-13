enum ChatRole { user, assistant, system }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final String? agentId;
  final DateTime timestamp;
  final List<dynamic>? thinkingSteps;
  final String? reasoningContent;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.agentId,
    required this.timestamp,
    this.thinkingSteps,
    this.reasoningContent,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] ?? '',
        role: _parseRole(json['role'] ?? 'assistant'),
        content: json['content'] ?? '',
        agentId: json['agent_id'],
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        thinkingSteps: json['thinking_steps'] as List<dynamic>?,
        reasoningContent: json['reasoning_content'] as String?,
      );

  static ChatRole _parseRole(String role) {
    switch (role) {
      case 'user':
        return ChatRole.user;
      case 'system':
        return ChatRole.system;
      default:
        return ChatRole.assistant;
    }
  }
}

class ChatSession {
  final String id;
  final String title;
  final String? agentId;
  final DateTime createdAt;

  const ChatSession({
    required this.id,
    required this.title,
    this.agentId,
    required this.createdAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        agentId: json['agent_id'],
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}
