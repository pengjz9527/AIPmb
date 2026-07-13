import 'package:flutter/material.dart';
import 'package:aipmb_app/services/api_client.dart';
import 'package:aipmb_app/models/product_detail.dart';

/// 购买申请页面 - 展示完整产品信息，用户填写购买金额并提交
class PurchasePage extends StatefulWidget {
  final String productName;

  const PurchasePage({super.key, required this.productName});

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  ProductDetail? _product;
  bool _isLoadingProduct = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _isLoadingProduct = true;
      _loadError = null;
    });

    try {
      final api = ApiClient();
      final encoded = Uri.encodeComponent(widget.productName);
      final response = await api.get('/api/v1/products/$encoded');
      final data = response['data'];
      if (data != null && data is Map<String, dynamic>) {
        if (mounted) {
          setState(() {
            _product = ProductDetail.fromJson(data);
            _isLoadingProduct = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loadError = '产品信息加载失败';
            _isLoadingProduct = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = '网络错误: $e';
          _isLoadingProduct = false;
        });
      }
    }
  }

  Future<void> _submitPurchase() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _isSubmitting = true);

    try {
      final api = ApiClient();
      final response = await api.post('/api/v1/purchases', data: {
        'product_name': widget.productName,
        'amount': amount,
      });

      if (!mounted) return;

      final code = response['code'] ?? 0;
      if (code == 0) {
        _showSuccessDialog();
      } else {
        final message = response['message'] ?? '提交失败';
        _showError(message);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('网络错误: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('提交成功', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: const Text(
          '购买申请已提交，请等待审核。\n您可以在"我的"页面查看申请状态。',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // 关闭购买页
            },
            child: const Text('完成', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('购买申请', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingProduct) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_loadError!, style: const TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadProduct, child: const Text('重试')),
          ],
        ),
      );
    }

    final product = _product!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 产品信息卡片（全量详情）
            _buildProductCard(product),
            const SizedBox(height: 28),

            // 购买金额
            _buildSectionTitle('购买金额'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                hintText: '请输入购买金额',
                prefixIcon: const Icon(Icons.attach_money),
                suffixText: '元',
                suffixStyle: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入购买金额';
                }
                final amount = double.tryParse(value.trim());
                if (amount == null || amount <= 0) {
                  return '请输入有效的购买金额';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // 提交按钮
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitPurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '确认购买',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // 底部说明
            Center(
              child: Text(
                '提交后需要银行审核，预计 1-2 个工作日完成',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductDetail product) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(Icons.shopping_bag_outlined,
                  color: Theme.of(context).colorScheme.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                '您要购买的产品',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 产品名称
          Text(
            product.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          // 标签行
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (product.bank.isNotEmpty) _buildTag(product.bank, Colors.blue),
              if (product.typeLabel.isNotEmpty) _buildTag(product.typeLabel, Colors.teal),
              if (product.categoryLabel.isNotEmpty)
                _buildTag(product.categoryLabel, Colors.indigo),
              if (product.riskLevel.isNotEmpty)
                _buildTag(
                  product.riskLevel,
                  product.riskLevel.contains('低') ? Colors.green : Colors.orange,
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 14),

          // 关键信息网格（2列自适应，确保信息完整展示）
          _buildDetailGrid(product),

          // 产品描述
          if (product.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              '产品描述',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              product.description,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
            ),
          ],

          // 额外信息
          if (product.threshold != null && product.threshold!.isNotEmpty ||
              product.yieldRange != null && product.yieldRange!.isNotEmpty ||
              product.redemptionRule != null && product.redemptionRule!.isNotEmpty ||
              product.feeInfo != null && product.feeInfo!.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              '更多信息',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            if (product.threshold != null && product.threshold!.isNotEmpty)
              _buildExtraRow('投资门槛', product.threshold!, Icons.attach_money),
            if (product.yieldRange != null && product.yieldRange!.isNotEmpty)
              _buildExtraRow('预期收益', product.yieldRange!, Icons.trending_up),
            if (product.redemptionRule != null && product.redemptionRule!.isNotEmpty)
              _buildExtraRow('赎回规则', product.redemptionRule!, Icons.schedule),
            if (product.feeInfo != null && product.feeInfo!.isNotEmpty)
              _buildExtraRow('费用说明', product.feeInfo!, Icons.receipt_long),
          ],
        ],
      ),
    );
  }

  /// 基本信息网格 — 每行两列，确保内容不截断
  Widget _buildDetailGrid(ProductDetail product) {
    final items = <_InfoItem>[
      if (product.bank.isNotEmpty)
        _InfoItem('发售银行', product.bank, Icons.account_balance),
      if (product.typeLabel.isNotEmpty)
        _InfoItem('产品类型', product.typeLabel, Icons.category_outlined),
      if (product.categoryLabel.isNotEmpty)
        _InfoItem('产品类别', product.categoryLabel, Icons.label_outline),
      if (product.riskLevel.isNotEmpty)
        _InfoItem('风险等级', product.riskLevel, Icons.shield_outlined),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 72) / 2, // 减去 padding(40) + 间距(8) / 2
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.value,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildExtraRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade800,
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  final IconData icon;

  const _InfoItem(this.label, this.value, this.icon);
}
