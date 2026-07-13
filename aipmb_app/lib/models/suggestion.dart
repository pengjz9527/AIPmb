/// AI 下一步建议数据模型
class NextSuggestion {
  final String id;
  final String label;
  final String prompt;
  final String priority; // 'high', 'medium', 'low'
  final String reason;
  final String group; // 'continue' | 'root'

  const NextSuggestion({
    required this.id,
    required this.label,
    required this.prompt,
    this.priority = 'medium',
    this.reason = '',
    this.group = 'root',
  });

  factory NextSuggestion.fromJson(Map<String, dynamic> json) => NextSuggestion(
        id: json['id'] ?? '',
        label: json['label'] ?? '',
        prompt: json['prompt'] ?? '',
        priority: json['priority'] ?? 'medium',
        reason: json['reason'] ?? '',
        group: json['group'] ?? 'root',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'prompt': prompt,
        'priority': priority,
        'reason': reason,
        'group': group,
      };
}
