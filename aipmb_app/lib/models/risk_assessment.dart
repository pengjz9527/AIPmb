/// 用户投资风险测评结果模型
class RiskAssessment {
  final int id;
  final String userName;
  final String riskLevel; // C1/C2/C3/C4/C5，空字符串表示未评级
  final String expiryDate; // YYYY/MM/DD
  final String createdAt;
  final bool expired;

  const RiskAssessment({
    required this.id,
    required this.userName,
    required this.riskLevel,
    required this.expiryDate,
    required this.createdAt,
    this.expired = false,
  });

  /// 是否已完成有效测评
  bool get isAssessed => riskLevel.isNotEmpty && !expired;

  /// 展示用的等级文本
  String get displayLevel => isAssessed ? riskLevel : '未评级';

  /// 风险等级中文标签
  static String levelLabel(String level) => switch (level) {
        'C1' => '保守型',
        'C2' => '稳健型',
        'C3' => '平衡型',
        'C4' => '成长型',
        'C5' => '进取型',
        _ => '未知',
      };

  factory RiskAssessment.fromJson(Map<String, dynamic> json) => RiskAssessment(
        id: json['id'] as int? ?? 0,
        userName: json['user_name'] as String? ?? '',
        riskLevel: json['risk_level'] as String? ?? '',
        expiryDate: json['expiry_date'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        expired: json['expired'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_name': userName,
        'risk_level': riskLevel,
        'expiry_date': expiryDate,
        'created_at': createdAt,
        'expired': expired,
      };
}
