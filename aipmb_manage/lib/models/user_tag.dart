class UserTag {
  final String userName;
  final List<TagItem> tags;
  final String generatedAt;
  final String modelUsed;

  UserTag({
    required this.userName,
    required this.tags,
    required this.generatedAt,
    required this.modelUsed,
  });

  factory UserTag.fromJson(Map<String, dynamic> json) {
    return UserTag(
      userName: json['user_name'] ?? '',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((t) => TagItem.fromJson(t))
              .toList() ??
          [],
      generatedAt: json['generated_at'] ?? '',
      modelUsed: json['model_used'] ?? '',
    );
  }
}

class TagItem {
  final String name;
  final String reasoning;

  TagItem({required this.name, required this.reasoning});

  factory TagItem.fromJson(Map<String, dynamic> json) {
    return TagItem(
      name: json['name'] ?? '',
      reasoning: json['reasoning'] ?? '',
    );
  }
}