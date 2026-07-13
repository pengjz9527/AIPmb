/// 产品详情数据模型（对应后端 GET /api/v1/products/{name} 返回的英文 key）
class ProductDetail {
  final String name;
  final String bank;
  final String typeLabel;
  final String category;
  final String categoryLabel;
  final String description;
  final String riskLevel;

  /// 额外详情字段（投资门槛、收益率、赎回规则等）
  final String? threshold;
  final String? yieldRange;
  final String? redemptionRule;
  final String? feeInfo;

  const ProductDetail({
    required this.name,
    this.bank = '',
    this.typeLabel = '',
    this.category = '',
    this.categoryLabel = '',
    this.description = '',
    this.riskLevel = '',
    this.threshold,
    this.yieldRange,
    this.redemptionRule,
    this.feeInfo,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    return ProductDetail(
      name: json['name'] ?? '',
      bank: json['bank'] ?? '',
      typeLabel: json['type_label'] ?? '',
      category: json['category'] ?? '',
      categoryLabel: json['category_label'] ?? '',
      description: json['description'] ?? '',
      riskLevel: json['risk_level'] ?? '',
      threshold: json['threshold'],
      yieldRange: json['yield_range'],
      redemptionRule: json['redemption_rule'],
      feeInfo: json['fee_info'],
    );
  }
}
