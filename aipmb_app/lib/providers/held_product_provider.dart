import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_app/models/held_product.dart';
import 'package:aipmb_app/services/api_client.dart';

final heldProductsSummaryProvider = FutureProvider<HeldProductsSummary>((ref) async {
  final api = ApiClient();
  final res = await api.get('/api/v1/held-products/summary/me');
  return HeldProductsSummary.fromJson(res['data'] as Map<String, dynamic>);
});

final heldWealthProductsProvider = FutureProvider<List<HeldWealthProduct>>((ref) async {
  final api = ApiClient();
  final res = await api.get('/api/v1/held-products/wealth');
  final data = res['data'] as List<dynamic>;
  return data.map((e) => HeldWealthProduct.fromJson(e as Map<String, dynamic>)).toList();
});

final heldLoansProvider = FutureProvider<List<HeldLoan>>((ref) async {
  final api = ApiClient();
  final res = await api.get('/api/v1/held-products/loans');
  final data = res['data'] as List<dynamic>;
  return data.map((e) => HeldLoan.fromJson(e as Map<String, dynamic>)).toList();
});

final heldPensionsProvider = FutureProvider<List<HeldPension>>((ref) async {
  final api = ApiClient();
  final res = await api.get('/api/v1/held-products/pensions');
  final data = res['data'] as List<dynamic>;
  return data.map((e) => HeldPension.fromJson(e as Map<String, dynamic>)).toList();
});
