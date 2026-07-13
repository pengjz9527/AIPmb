/// AI 洞察数据模型
class AiInsight {
  final String insight;
  final String insightType;
  final String generatedAt;

  const AiInsight({
    required this.insight,
    required this.insightType,
    required this.generatedAt,
  });

  factory AiInsight.fromJson(Map<String, dynamic> json) => AiInsight(
        insight: json['insight'] ?? '',
        insightType: json['insight_type'] ?? 'general',
        generatedAt: json['generated_at'] ?? '',
      );
}
