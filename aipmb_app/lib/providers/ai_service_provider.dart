import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_app/services/api_client.dart';
import 'package:aipmb_app/config/api_config.dart';
import 'package:aipmb_app/models/ai_insight.dart';
import 'package:aipmb_app/models/transaction.dart';

final _api = ApiClient();

/// AI 洞察 Provider
final aiInsightProvider = FutureProvider<AiInsight>((ref) async {
  final json = await _api.get(ApiConfig.aiInsight, timeout: const Duration(seconds: 15));
  final data = json['data'] ?? json;
  return AiInsight.fromJson(data is Map<String, dynamic> ? data : {});
});

/// 最近5条交易 Provider (AI服务页专用)
final recentTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final list = await _api.getList(
    ApiConfig.transactions,
    queryParameters: {'limit': '5', 'offset': '0'},
  );
  return list.map((e) => Transaction.fromJson(e as Map<String, dynamic>)).toList();
});

/// 上月消费汇总 Provider
final lastMonthSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final now = DateTime.now();
  final lastMonth = DateTime(now.year, now.month - 1, 1);
  final lastMonthEnd = DateTime(now.year, now.month, 0);
  final dateFrom = '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}-01';
  final dateTo = '${lastMonthEnd.year}-${lastMonthEnd.month.toString().padLeft(2, '0')}-${lastMonthEnd.day}';

  final json = await _api.get(ApiConfig.transactionSummary, queryParameters: {
    'date_from': dateFrom,
    'date_to': dateTo,
    'group_by': 'category',
  });
  return json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : {};
});

/// 资产加密显示状态 (false = 加密, true = 明文)
final assetVisibilityProvider = StateProvider<bool>((ref) => false);
