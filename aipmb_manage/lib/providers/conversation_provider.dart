import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_manage/models/conversation.dart';
import 'package:aipmb_manage/services/api_client.dart';
import 'package:aipmb_manage/config/api_config.dart';

final conversationsProvider =
    FutureProvider.family<ConversationListResult, ConversationQuery>((ref, query) async {
  final res = await ApiClient().get(
    ApiConfig.userConversations(query.userName),
    params: {
      'keyword': query.keyword,
      'business_type': query.businessType,
      'time_range': query.timeRange,
      'limit': query.limit,
      'offset': query.offset,
    },
  );
  final data = res.data['data'] as List<dynamic>;
  final total = res.data['total'] as int? ?? 0;
  final items = data.map((e) => ConversationItem.fromJson(e as Map<String, dynamic>)).toList();
  return ConversationListResult(items: items, total: total);
});

final conversationDetailProvider =
    FutureProvider.family<ConversationDetail?, ConversationDetailQuery>((ref, query) async {
  try {
    final res = await ApiClient().get(
      ApiConfig.conversationDetail(query.userName, query.sessionId),
    );
    return ConversationDetail.fromJson(res.data['data'] as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

final conversationSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, userName) async {
  final res = await ApiClient().get(ApiConfig.conversationSummary(userName));
  return res.data['data'] as Map<String, dynamic>? ?? {};
});
