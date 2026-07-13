import 'package:flutter/material.dart';
import 'package:aipmb_app/services/api_client.dart';
import 'package:aipmb_app/config/api_config.dart';

/// 缴费页面
/// - 展示待缴费账单列表（调用 /api/v1/payments/forecast）
/// - 每项显示缴费类型、上次缴费日期、预估金额、状态（已逾期/即将到期）
/// - "马上缴费"按钮（功能开发中，点击提示）
class PaymentPage extends StatefulWidget {
  final String paymentNo;
  final String paymentType;

  const PaymentPage({
    super.key,
    required this.paymentNo,
    required this.paymentType,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  List<Map<String, dynamic>> _forecastItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  Future<void> _loadForecast() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ApiClient();
      final response = await api.get(ApiConfig.paymentsForecast);
      final data = response['data'];
      if (data is List) {
        setState(() {
          _forecastItems = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _forecastItems = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '加载失败: $e';
      });
    }
  }

  void _onPayNow(Map<String, dynamic> item) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('缴费功能开发中，敬请期待')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('生活缴费',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadForecast,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_forecastItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            const Text('暂无待缴费账单',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 4),
            const Text('所有账单都已结清，干得漂亮！',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadForecast,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _forecastItems.length,
        itemBuilder: (context, index) {
          final item = _forecastItems[index];
          final isOverdue = item['is_overdue'] == true;
          return _buildPaymentCard(item, isOverdue);
        },
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> item, bool isOverdue) {
    final paymentType = item['payment_type'] ?? '缴费';
    final lastDate = item['last_date'] ?? '';
    final estimatedAmount = (item['estimated_amount'] ?? 0).toDouble();
    final daysOverdue = item['days_overdue'] ?? 0;
    final daysUntilDue = item['days_until_due'] ?? 0;
    final confidence = item['confidence'] ?? 'medium';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 图标
            CircleAvatar(
              backgroundColor:
                  isOverdue ? Colors.red.shade50 : Colors.orange.shade50,
              child: Icon(_iconForType(paymentType),
                  color: isOverdue ? Colors.red : Colors.orange),
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(paymentType,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('上次缴费: $lastDate',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12)),
                  Text('预估金额: ¥${estimatedAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12)),
                  if (isOverdue && daysOverdue > 0)
                    Text('已逾期 $daysOverdue 天',
                        style: const TextStyle(
                            color: Colors.red, fontSize: 11)),
                  if (!isOverdue && daysUntilDue > 0)
                    Text('$daysUntilDue 天后到期',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                ],
              ),
            ),
            // 状态 + 按钮
            Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isOverdue ? '已逾期' : '即将到期',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOverdue ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (confidence == 'high')
                  Icon(Icons.verified, size: 14, color: Colors.blue.shade300),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _onPayNow(item),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child:
                      const Text('马上缴费', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    if (type.contains('电费')) return Icons.electric_bolt;
    if (type.contains('水费')) return Icons.water_drop;
    if (type.contains('电视')) return Icons.tv;
    return Icons.receipt_long;
  }
}
