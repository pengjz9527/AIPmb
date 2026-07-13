import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_app/models/risk_assessment.dart';
import 'package:aipmb_app/services/api_client.dart';
import 'package:aipmb_app/config/api_config.dart';

/// 获取当前用户风险测评结果
final riskAssessmentProvider = FutureProvider<RiskAssessment>((ref) async {
  final api = ApiClient();
  final json = await api.get(ApiConfig.riskAssessment);
  final data = json['data'] as Map<String, dynamic>? ?? {};
  return RiskAssessment.fromJson(data);
});

/// 提交测评结果
Future<Map<String, dynamic>> submitRiskAssessment({
  required String userName,
  required String riskLevel,
  required String expiryDate,
}) async {
  final api = ApiClient();
  return await api.post(ApiConfig.riskAssessment, data: {
    'user_name': userName,
    'risk_level': riskLevel,
    'expiry_date': expiryDate,
  });
}
