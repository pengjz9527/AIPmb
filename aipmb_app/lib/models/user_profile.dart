class AITagItem {
  final String name;
  final String description;

  const AITagItem({required this.name, required this.description});

  factory AITagItem.fromJson(Map<String, dynamic> json) => AITagItem(
        name: json['name'] ?? '',
        description: json['description'] ?? '',
      );
}


class UserProfileTags {
  final String assetLevel;
  final String consumptionPreference;
  final String consumptionLevel;
  final String riskPreference;
  final String channelPreference;
  final List<AITagItem> aiTags;

  const UserProfileTags({
    required this.assetLevel,
    required this.consumptionPreference,
    required this.consumptionLevel,
    required this.riskPreference,
    required this.channelPreference,
    this.aiTags = const [],
  });

  factory UserProfileTags.fromJson(Map<String, dynamic> json) => UserProfileTags(
        assetLevel: json['asset_level'] ?? '',
        consumptionPreference: json['consumption_preference'] ?? '',
        consumptionLevel: json['consumption_level'] ?? '',
        riskPreference: json['risk_preference'] ?? '',
        channelPreference: json['channel_preference'] ?? '',
        aiTags: (json['ai_tags'] as List<dynamic>?)
                ?.map((t) => AITagItem.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
      );

  List<String> toList() => [
        assetLevel,
        consumptionPreference,
        consumptionLevel,
        riskPreference,
        channelPreference,
      ].where((t) => t.isNotEmpty).toList();

  /// AI 标签是否可用
  bool get hasAiTags => aiTags.isNotEmpty;

  /// 获取显示标签列表（AI 标签优先，回退规则标签）
  List<String> get displayLabels =>
      hasAiTags ? aiTags.map((t) => t.name).toList() : toList();
}
