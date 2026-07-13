class ProductMatch {
  final String tagName;
  final String productName;
  final String productCategory;
  final double matchScore;
  final String reasoning;
  final Map<String, dynamic> productDetail;

  ProductMatch({
    required this.tagName,
    required this.productName,
    required this.productCategory,
    required this.matchScore,
    required this.reasoning,
    required this.productDetail,
  });

  factory ProductMatch.fromJson(Map<String, dynamic> json) {
    return ProductMatch(
      tagName: json['tag_name'] ?? '',
      productName: json['product_name'] ?? '',
      productCategory: json['product_category'] ?? '',
      matchScore: (json['match_score'] ?? 0).toDouble(),
      reasoning: json['reasoning'] ?? '',
      productDetail: json['product_detail'] ?? {},
    );
  }
}

class RecommendationRecord {
  final String userName;
  final List<ProductMatch> matches;
  final String generatedAt;
  final String modelUsed;

  RecommendationRecord({
    required this.userName,
    required this.matches,
    required this.generatedAt,
    required this.modelUsed,
  });

  factory RecommendationRecord.fromJson(Map<String, dynamic> json) {
    return RecommendationRecord(
      userName: json['user_name'] ?? '',
      matches: (json['matches'] as List<dynamic>?)
              ?.map((m) => ProductMatch.fromJson(m))
              .toList() ??
          [],
      generatedAt: json['generated_at'] ?? '',
      modelUsed: json['model_used'] ?? '',
    );
  }
}