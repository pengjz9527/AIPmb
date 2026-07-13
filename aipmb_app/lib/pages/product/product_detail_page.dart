import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/models/product_detail.dart';
import 'package:aipmb_app/services/api_client.dart';

/// 产品详情页面 - 从聊天链接 /product?product_name=xxx 进入
class ProductInfoPage extends StatefulWidget {
  final String productName;

  const ProductInfoPage({super.key, required this.productName});

  @override
  State<ProductInfoPage> createState() => _ProductInfoPageState();
}

class _ProductInfoPageState extends State<ProductInfoPage> {
  ProductDetail? _product;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ApiClient();
      final encoded = Uri.encodeComponent(widget.productName);
      final response = await api.get('/api/v1/products/$encoded');
      final data = response['data'];
      if (data != null && data is Map<String, dynamic>) {
        setState(() {
          _product = ProductDetail.fromJson(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? '产品不存在';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _product?.name ?? widget.productName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _product != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProduct,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final product = _product!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 产品头部
          _buildHeader(product),
          const SizedBox(height: 24),

          // 基本信息
          _buildSectionTitle('基本信息'),
          const SizedBox(height: 12),
          _buildInfoGrid(product),
          const SizedBox(height: 24),

          // 产品描述
          if (product.description.isNotEmpty) ...[
            _buildSectionTitle('产品描述'),
            const SizedBox(height: 8),
            Text(
              product.description,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.6),
            ),
            const SizedBox(height: 24),
          ],

          // 额外详情
          if (product.threshold != null ||
              product.yieldRange != null ||
              product.redemptionRule != null ||
              product.feeInfo != null) ...[
            _buildSectionTitle('更多信息'),
            const SizedBox(height: 12),
            ..._buildExtraInfo(product),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ProductDetail product) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
            Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (product.bank.isNotEmpty) _buildTag(product.bank, Colors.blue),
              const SizedBox(width: 8),
              if (product.typeLabel.isNotEmpty) _buildTag(product.typeLabel, Colors.teal),
              const SizedBox(width: 8),
              if (product.riskLevel.isNotEmpty)
                _buildTag(
                  product.riskLevel,
                  product.riskLevel.contains('低') ? Colors.green : Colors.orange,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildInfoGrid(ProductDetail product) {
    final items = <MapEntry<String, String>>[];
    if (product.bank.isNotEmpty) items.add(const MapEntry('发售银行', ''));
    if (product.typeLabel.isNotEmpty) items.add(const MapEntry('产品类型', ''));
    if (product.categoryLabel.isNotEmpty) items.add(const MapEntry('产品类别', ''));
    if (product.riskLevel.isNotEmpty) items.add(const MapEntry('风险等级', ''));

    // 填充实际值
    final filledItems = <_InfoItem>[];
    for (final item in items) {
      switch (item.key) {
        case '发售银行':
          filledItems.add(_InfoItem(item.key, product.bank, Icons.account_balance));
        case '产品类型':
          filledItems.add(_InfoItem(item.key, product.typeLabel, Icons.category_outlined));
        case '产品类别':
          filledItems.add(_InfoItem(item.key, product.categoryLabel, Icons.label_outline));
        case '风险等级':
          filledItems.add(_InfoItem(item.key, product.riskLevel, Icons.shield_outlined));
      }
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 80,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: filledItems.length,
      itemBuilder: (context, index) {
        final item = filledItems[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.value,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildExtraInfo(ProductDetail product) {
    final items = <Widget>[];
    if (product.threshold != null && product.threshold!.isNotEmpty) {
      items.add(_buildExtraRow('投资门槛', product.threshold!, Icons.attach_money));
    }
    if (product.yieldRange != null && product.yieldRange!.isNotEmpty) {
      items.add(_buildExtraRow('预期收益', product.yieldRange!, Icons.trending_up));
    }
    if (product.redemptionRule != null && product.redemptionRule!.isNotEmpty) {
      items.add(_buildExtraRow('赎回规则', product.redemptionRule!, Icons.schedule));
    }
    if (product.feeInfo != null && product.feeInfo!.isNotEmpty) {
      items.add(_buildExtraRow('费用说明', product.feeInfo!, Icons.receipt_long));
    }
    return items;
  }

  Widget _buildExtraRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              context.push(
                '/purchase?product_name=${Uri.encodeComponent(_product!.name)}',
              );
            },
            icon: const Icon(Icons.shopping_cart_outlined),
            label: const Text('马上购买', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
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
