import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_manage/services/api_client.dart';
import 'package:aipmb_manage/config/api_config.dart';

final marketingLeadsProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userName) async {
  final res = await ApiClient().get(ApiConfig.marketingLeads(userName));
  final data = res.data['data'] as Map<String, dynamic>?;
  if (data != null && data['generated_at'] != null) {
    return data;
  }
  return null;
});
