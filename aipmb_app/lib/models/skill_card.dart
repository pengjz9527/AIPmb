/// 领域层 Skill 快捷卡片模型
class SkillCard {
  final String name;
  final String description;
  final String label;

  const SkillCard({
    required this.name,
    required this.description,
    required this.label,
  });

  factory SkillCard.fromJson(Map<String, dynamic> json) => SkillCard(
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        label: json['label'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'label': label,
      };
}
