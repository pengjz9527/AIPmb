import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_app/models/recommendation.dart';
import 'package:aipmb_app/models/user_profile.dart';
import 'package:aipmb_app/models/skill_card.dart';
import 'package:aipmb_app/models/history_today.dart';
import 'package:aipmb_app/models/match_progress.dart';
import 'package:aipmb_app/services/api_client.dart';
import 'package:aipmb_app/config/api_config.dart';

final apiProvider = Provider<ApiClient>((ref) => ApiClient());

final todosProvider = FutureProvider<List<TodoItem>>((ref) async {
  final api = ref.read(apiProvider);
  final list = await api.getList(ApiConfig.recommendationsTodos);
  return list.map((e) => TodoItem.fromJson(e as Map<String, dynamic>)).toList();
});

final promosProvider = FutureProvider<List<PromoItem>>((ref) async {
  final api = ref.read(apiProvider);
  final list = await api.getList(ApiConfig.recommendationsPromos);
  return list.map((e) => PromoItem.fromJson(e as Map<String, dynamic>)).toList();
});

final productRecommendationsProvider = FutureProvider<List<ProductRecommendation>>((ref) async {
  final api = ref.read(apiProvider);
  final list = await api.getList(ApiConfig.recommendationsProducts);
  return list.map((e) => ProductRecommendation.fromJson(e as Map<String, dynamic>)).toList();
});

final profileTagsProvider = FutureProvider<UserProfileTags>((ref) async {
  final api = ref.read(apiProvider);
  final json = await api.get(ApiConfig.profileTags);
  final data = json['data'] ?? json;
  return UserProfileTags.fromJson(data is Map<String, dynamic> ? data : {});
});

final domainSkillsProvider = FutureProvider<List<SkillCard>>((ref) async {
  final api = ref.read(apiProvider);
  final json = await api.get(ApiConfig.domainSkills);
  final data = json['data'];
  if (data is List) {
    return data.map((e) => SkillCard.fromJson(e as Map<String, dynamic>)).toList();
  }
  return [];
});

final historyTodayProvider = FutureProvider<HistoryTodayResult>((ref) async {
  final api = ref.read(apiProvider);
  final json = await api.get(ApiConfig.historyToday, timeout: const Duration(seconds: 60));
  final data = json['data'] ?? json;
  return HistoryTodayResult.fromJson(data is Map<String, dynamic> ? data : {});
});

// 纪念日历会话缓存 — 生成后保持在内存中，用户可在本会话随时查看
final calendarCacheProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

// AI 匹配产品列表（此刻页"为你推荐"）
final aiMatchedProductsProvider = FutureProvider<List<AiMatchedProduct>>((ref) async {
  final api = ref.read(apiProvider);
  final json = await api.get(ApiConfig.aiMatchedProducts);
  final data = json['data'];
  if (data is Map && data['status'] == 'generating') {
    return []; // 正在生成中
  }
  final products = data is Map ? (data['products'] as List?) : (data as List?);
  if (products == null || products.isEmpty) return [];
  return products.map((e) => AiMatchedProduct.fromJson(e as Map<String, dynamic>)).toList();
});

/// 拉取 AI 产品匹配进度
Future<MatchProgress> fetchMatchProgress(ApiClient api) async {
  final json = await api.get(ApiConfig.aiMatchedProductsStatus);
  final data = json['data'];
  return MatchProgress.fromJson(data is Map<String, dynamic> ? data : {});
}

/// 强制刷新 AI 产品匹配（换一批）
Future<Map<String, dynamic>> refreshAiProducts(ApiClient api) async {
  return await api.get(
    ApiConfig.aiMatchedProducts,
    queryParameters: {'refresh': 'true'},
  );
}
