class AgentInfo {
  final String agentId;
  final String name;
  final String description;
  final String avatar;

  const AgentInfo({
    required this.agentId,
    required this.name,
    required this.description,
    required this.avatar,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) => AgentInfo(
        agentId: json['agent_id'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        avatar: json['avatar'] ?? '🤖',
      );
}

class AgentCard {
  final String cardType;
  final String title;
  final dynamic data;

  const AgentCard({
    required this.cardType,
    required this.title,
    this.data,
  });

  factory AgentCard.fromJson(Map<String, dynamic> json) => AgentCard(
        cardType: json['card_type'] ?? '',
        title: json['title'] ?? '',
        data: json['data'],
      );
}

class AgentResult {
  final String agentId;
  final String agentName;
  final String content;
  final List<AgentCard> cards;
  final List<String> suggestedAgents;

  const AgentResult({
    required this.agentId,
    this.agentName = '',
    required this.content,
    this.cards = const [],
    this.suggestedAgents = const [],
  });

  factory AgentResult.fromJson(Map<String, dynamic> json) => AgentResult(
        agentId: json['agent_id'] ?? '',
        agentName: json['agent_name'] ?? '',
        content: json['content'] ?? '',
        cards: (json['cards'] as List<dynamic>?)
                ?.map((e) => AgentCard.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        suggestedAgents: (json['suggested_agents'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}
