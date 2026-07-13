import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_manage/models/held_product.dart';
import 'package:aipmb_manage/services/api_client.dart';

final heldSummaryProvider = FutureProvider.family<ManageHeldSummary, String>(
  (ref, userName) async {
    final res = await ApiClient().get('/api/v1/held-products/summary/$userName');
    return ManageHeldSummary.fromJson(res.data['data'] as Map<String, dynamic>);
  },
);

final heldWealthByUserProvider = FutureProvider.family<List<ManageHeldWealth>, String>(
  (ref, userName) async {
    final res = await ApiClient().get(
      '/api/v1/held-products/wealth',
      params: {'user_name': userName},
    );
    final data = res.data['data'] as List<dynamic>? ?? [];
    return data.map((e) => ManageHeldWealth.fromJson(e as Map<String, dynamic>)).toList();
  },
);

final heldLoansByUserProvider = FutureProvider.family<List<ManageHeldLoan>, String>(
  (ref, userName) async {
    final res = await ApiClient().get(
      '/api/v1/held-products/loans',
      params: {'user_name': userName},
    );
    final data = res.data['data'] as List<dynamic>? ?? [];
    return data.map((e) => ManageHeldLoan.fromJson(e as Map<String, dynamic>)).toList();
  },
);

final heldPensionsByUserProvider = FutureProvider.family<List<ManageHeldPension>, String>(
  (ref, userName) async {
    final res = await ApiClient().get(
      '/api/v1/held-products/pensions',
      params: {'user_name': userName},
    );
    final data = res.data['data'] as List<dynamic>? ?? [];
    return data.map((e) => ManageHeldPension.fromJson(e as Map<String, dynamic>)).toList();
  },
);
