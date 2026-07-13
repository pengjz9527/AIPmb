import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_app/services/api_client.dart';

final repaymentPlanProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, loanId) async {
    final api = ApiClient();
    final res = await api.get('/api/v1/held-products/loans/$loanId/repayment-plan');
    final data = res['data'] as List<dynamic>?;
    if (data == null) return [];
    return data.map((e) => e as Map<String, dynamic>).toList();
  },
);

class RepaymentPlanPage extends ConsumerWidget {
  final String loanId;
  const RepaymentPlanPage({super.key, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(repaymentPlanProvider(loanId));

    return Scaffold(
      appBar: AppBar(title: const Text('还款计划')),
      body: planAsync.when(
        data: (plan) {
          if (plan.isEmpty) {
            return const Center(child: Text('暂无还款计划数据'));
          }
          return Column(
            children: [
              _buildSummaryHeader(plan),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: plan.length,
                  itemBuilder: (_, i) => _buildPlanItem(plan[i], i + 1),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Widget _buildSummaryHeader(List<Map<String, dynamic>> plan) {
    final first = plan.first;
    final totalPayment = plan.fold<double>(
      0,
      (sum, p) => sum + ((p['total_payment'] ?? 0) as num).toDouble(),
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade100, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text('未来12期还款概览', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            '¥${totalPayment.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '首期还款日: ${first['payment_date'] ?? ''} · 共 ${plan.length} 期',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanItem(Map<String, dynamic> item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '第 $index 期',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  item['payment_date'] ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildValueColumn('本金', '¥${((item['principal'] ?? 0) as num).toStringAsFixed(2)}'),
                _buildValueColumn('利息', '¥${((item['interest'] ?? 0) as num).toStringAsFixed(2)}'),
                _buildValueColumn('合计', '¥${((item['total_payment'] ?? 0) as num).toStringAsFixed(2)}',
                    valueColor: Colors.blue),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '剩余本金: ¥${((item['remaining_principal'] ?? 0) as num).toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueColumn(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
      ],
    );
  }
}
