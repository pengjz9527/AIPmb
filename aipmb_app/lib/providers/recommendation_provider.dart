import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_app/models/recommendation.dart';
import 'package:aipmb_app/models/user_profile.dart';
import 'package:aipmb_app/models/history_today.dart';
import 'package:aipmb_app/models/match_progress.dart';
import 'package:aipmb_app/models/transaction.dart';
import 'package:aipmb_app/models/ai_insight.dart';
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

final historyTodayProvider = FutureProvider<HistoryTodayResult>((ref) async {
  final api = ref.read(apiProvider);
  final json = await api.get(ApiConfig.historyToday, timeout: const Duration(seconds: 60));
  final data = json['data'] ?? json;
  return HistoryTodayResult.fromJson(data is Map<String, dynamic> ? data : {});
});

/// 生活圈分析 Provider
final neighborhoodProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiProvider);
  final json = await api.get(ApiConfig.neighborhoodProfile, timeout: const Duration(seconds: 60));
  final data = json['data'] ?? json;
  return data is Map<String, dynamic> ? data : {};
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

// ===== 从 ai_service_provider 迁移 =====

/// AI 洞察 Provider
final aiInsightProvider = FutureProvider<AiInsight>((ref) async {
  final api = ref.read(apiProvider);
  final json = await api.get(ApiConfig.aiInsight, timeout: const Duration(seconds: 15));
  final data = json['data'] ?? json;
  return AiInsight.fromJson(data is Map<String, dynamic> ? data : {});
});

/// 最近5条交易 Provider
final recentTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final api = ref.read(apiProvider);
  final list = await api.getList(
    ApiConfig.transactions,
    queryParameters: {'limit': '5', 'offset': '0'},
  );
  return list.map((e) => Transaction.fromJson(e as Map<String, dynamic>)).toList();
});

/// 资产加密显示状态 (false = 加密, true = 明文)
final assetVisibilityProvider = StateProvider<bool>((ref) => false);
