import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_app/models/account.dart';
import 'package:aipmb_app/services/api_client.dart';
import 'package:aipmb_app/config/api_config.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final api = ref.read(apiClientProvider);
  final list = await api.getList(ApiConfig.accounts);
  return list.map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
});

final wealthOverviewProvider = FutureProvider<WealthOverview>((ref) async {
  final api = ref.read(apiClientProvider);
  final json = await api.get(ApiConfig.wealthOverview);
  final data = json['data'] ?? json;
  return WealthOverview.fromJson(data is Map<String, dynamic> ? data : {});
});

final accountSummaryProvider = FutureProvider<List<AccountSummaryItem>>((ref) async {
  final api = ref.read(apiClientProvider);
  final list = await api.getList(ApiConfig.accountSummary);
  return list.map((e) => AccountSummaryItem.fromJson(e as Map<String, dynamic>)).toList();
});
