class TodoItem {
  final String id;
  final String title;
  final String subtitle;
  final String type;
  final String? actionText;
  // 缴费类型专用字段
  final String? paymentNo;
  final String? paymentTypeLabel;

  const TodoItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    this.actionText,
    this.paymentNo,
    this.paymentTypeLabel,
  });

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        subtitle: json['subtitle'] ?? '',
        type: json['type'] ?? '',
        actionText: json['action_text'],
        paymentNo: json['payment_no'],
        paymentTypeLabel: json['payment_type'],
      );
}

class PromoItem {
  final String id;
  final String title;
  final String description;
  final String? tag;

  const PromoItem({
    required this.id,
    required this.title,
    required this.description,
    this.tag,
  });

  factory PromoItem.fromJson(Map<String, dynamic> json) => PromoItem(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        tag: json['tag'],
      );
}

class ProductRecommendation {
  final String productName;
  final String productType;
  final String category;
  final String description;
  final String riskLevel;
  final String reason;

  const ProductRecommendation({
    required this.productName,
    required this.productType,
    this.category = '',
    this.description = '',
    this.riskLevel = '',
    required this.reason,
  });

  factory ProductRecommendation.fromJson(Map<String, dynamic> json) =>
      ProductRecommendation(
        productName: json['name'] ?? json['product_name'] ?? '',
        productType: json['type_label'] ?? json['product_type'] ?? '',
        category: json['category'] ?? '',
        description: json['description'] ?? '',
        riskLevel: json['risk_level'] ?? '',
        reason: json['reason'] ?? '',
      );
}

class AiMatchedProduct {
  final String productName;
  final String bank;
  final String category;
  final String typeLabel;
  final String description;
  final String riskLevel;
  final double matchScore;
  final String matchReason;

  const AiMatchedProduct({
    required this.productName,
    this.bank = '',
    this.category = '',
    this.typeLabel = '',
    this.description = '',
    this.riskLevel = '',
    this.matchScore = 0.0,
    this.matchReason = '',
  });

  factory AiMatchedProduct.fromJson(Map<String, dynamic> json) =>
      AiMatchedProduct(
        productName: json['product_name'] ?? '',
        bank: json['bank'] ?? '',
        category: json['category'] ?? '',
        typeLabel: json['type_label'] ?? '',
        description: json['description'] ?? '',
        riskLevel: json['risk_level'] ?? '',
        matchScore: (json['match_score'] ?? 0).toDouble(),
        matchReason: json['match_reason'] ?? '',
      );

  /// 转为 ProductRecommendation，用于复用 ProductRecommendationCard
  ProductRecommendation toProductRecommendation() => ProductRecommendation(
        productName: productName,
        productType: typeLabel,
        category: category,
        description: description,
        riskLevel: riskLevel,
        reason: matchReason,
      );
}
