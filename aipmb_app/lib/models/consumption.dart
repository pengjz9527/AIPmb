import 'package:aipmb_app/utils/json_helpers.dart';

class ConsumptionStats {
  final String category;
  final double amount;
  final int count;
  final double percentage;

  const ConsumptionStats({
    required this.category,
    required this.amount,
    required this.count,
    required this.percentage,
  });

  factory ConsumptionStats.fromJson(Map<String, dynamic> json) =>
      ConsumptionStats(
        category: json['category'] ?? '',
        amount: parseDouble(json['amount']),
        count: parseInt(json['count']),
        percentage: parseDouble(json['percentage']),
      );
}