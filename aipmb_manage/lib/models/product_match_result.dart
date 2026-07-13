/// AI 产品匹配结果
class ProductMatchResult {
  final String userName;
  final List<String> tagsUsed;
  final bool hasRiskAssessment;
  final String? riskLevel;
  final String? riskWarning;
  final List<MatchedProduct> matchedProducts;
  final int totalMatched;
  final String modelUsed;
  final String generatedAt;

  const ProductMatchResult({
    required this.userName,
    required this.tagsUsed,
    required this.hasRiskAssessment,
    this.riskLevel,
    this.riskWarning,
    required this.matchedProducts,
    required this.totalMatched,
    required this.modelUsed,
    required this.generatedAt,
  });

  factory ProductMatchResult.fromJson(Map<String, dynamic> json) {
    return ProductMatchResult(
      userName: json['user_name'] ?? '',
      tagsUsed: (json['tags_used'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      hasRiskAssessment: json['has_risk_assessment'] ?? false,
      riskLevel: json['risk_level'],
      riskWarning: json['risk_warning'],
      matchedProducts: (json['matched_products'] as List<dynamic>?)
              ?.map((e) =>
                  MatchedProduct.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalMatched: json['total_matched'] ?? 0,
      modelUsed: json['model_used'] ?? '',
      generatedAt: json['generated_at'] ?? '',
    );
  }
}

/// 单款匹配产品
class MatchedProduct {
  final String productName;
  final String bank;
  final String category;
  final String typeLabel;
  final String description;
  final String riskLevel;
  final double matchScore;
  final String matchReason;
  final String detailLink;

  const MatchedProduct({
    required this.productName,
    required this.bank,
    required this.category,
    required this.typeLabel,
    required this.description,
    required this.riskLevel,
    required this.matchScore,
    required this.matchReason,
    required this.detailLink,
  });

  factory MatchedProduct.fromJson(Map<String, dynamic> json) {
    return MatchedProduct(
      productName: json['product_name'] ?? '',
      bank: json['bank'] ?? '',
      category: json['category'] ?? '',
      typeLabel: json['type_label'] ?? '',
      description: json['description'] ?? '',
      riskLevel: json['risk_level'] ?? '',
      matchScore: (json['match_score'] ?? 0).toDouble(),
      matchReason: json['match_reason'] ?? '',
      detailLink: json['detail_link'] ?? '',
    );
  }

  /// 匹配百分比（整数）
  int get matchPercent => (matchScore * 100).round();
}
