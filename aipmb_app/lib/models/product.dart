import 'package:aipmb_app/utils/json_helpers.dart';

class Product {
  final String productName;
  final String productType;
  final double? annualRate;
  final double? minAmount;
  final int? termDays;
  final double? riskLevel;
  final String? description;

  const Product({
    required this.productName,
    required this.productType,
    this.annualRate,
    this.minAmount,
    this.termDays,
    this.riskLevel,
    this.description,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        productName: json['product_name'] ?? '',
        productType: json['product_type'] ?? '',
        annualRate: json['annual_rate'] != null ? parseDouble(json['annual_rate']) : null,
        minAmount: json['min_amount'] != null ? parseDouble(json['min_amount']) : null,
        termDays: json['term_days'],
        riskLevel: json['risk_level'] != null ? parseDouble(json['risk_level']) : null,
        description: json['description'],
      );
}

class ProductCategory {
  final String name;
  final int count;

  const ProductCategory({required this.name, required this.count});

  factory ProductCategory.fromJson(Map<String, dynamic> json) => ProductCategory(
        name: json['name'] ?? '',
        count: parseInt(json['count']),
      );
}