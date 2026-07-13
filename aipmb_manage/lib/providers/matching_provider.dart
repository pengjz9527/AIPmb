import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_manage/models/match_result.dart';
import 'package:aipmb_manage/services/api_client.dart';
import 'package:aipmb_manage/config/api_config.dart';

final matchesProvider = FutureProvider.family<RecommendationRecord?, String>((ref, name) async {
  try {
    final res = await ApiClient().get(ApiConfig.userMatches(name));
    return RecommendationRecord.fromJson(res.data['data']);
  } catch (_) {
    return null;
  }
});