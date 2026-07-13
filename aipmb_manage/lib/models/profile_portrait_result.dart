class PortraitSection {
  final String title;
  final String content;
  final String detail;

  PortraitSection({required this.title, required this.content, this.detail = ''});

  factory PortraitSection.fromJson(Map<String, dynamic> json) {
    return PortraitSection(
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      detail: json['detail'] ?? '',
    );
  }

  bool get hasDetail => detail.isNotEmpty;
}

class ProfilePortraitResult {
  final String userName;
  final List<PortraitSection> sections;
  final String modelUsed;
  final String generatedAt;
  final bool privacyMasked;
  final String? skillSummary;

  ProfilePortraitResult({
    required this.userName,
    required this.sections,
    required this.modelUsed,
    required this.generatedAt,
    this.privacyMasked = false,
    this.skillSummary,
  });

  factory ProfilePortraitResult.fromJson(Map<String, dynamic> json) {
    final sectionList = (json['sections'] as List<dynamic>?)
            ?.map((e) => PortraitSection.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ProfilePortraitResult(
      userName: json['user_name'] ?? '',
      sections: sectionList,
      modelUsed: json['model_used'] ?? '',
      generatedAt: json['generated_at'] ?? '',
      privacyMasked: json['privacy_masked'] ?? false,
      skillSummary: json['skill_summary'],
    );
  }
}
