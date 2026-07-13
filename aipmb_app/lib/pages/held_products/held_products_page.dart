import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/models/held_product.dart';
import 'package:aipmb_app/providers/held_product_provider.dart';
import 'package:aipmb_app/widgets/cards/held_product_card.dart';

class HeldProductsPage extends ConsumerStatefulWidget {
  const HeldProductsPage({super.key});

  @override
  ConsumerState<HeldProductsPage> createState() => _HeldProductsPageState();
}

class _HeldProductsPageState extends ConsumerState<HeldProductsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的持有产品'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.savings), text: '理财'),
            Tab(icon: Icon(Icons.account_balance), text: '贷款'),
            Tab(icon: Icon(Icons.elderly), text: '养老金'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWealthTab(),
          _buildLoanTab(),
          _buildPensionTab(),
        ],
      ),
    );
  }

  Widget _buildWealthTab() {
    final async = ref.watch(heldWealthProductsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(heldWealthProductsProvider),
      child: async.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('暂无持有理财产品'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (_, i) => HeldWealthCard(
              product: products[i],
              onDetail: () => context.push('/held-products/detail', extra: {
                'type': 'wealth',
                'data': products[i],
              }),
              onRedeem: () => _showRedeemDialog(products[i]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Widget _buildLoanTab() {
    final async = ref.watch(heldLoansProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(heldLoansProvider),
      child: async.when(
        data: (loans) {
          if (loans.isEmpty) {
            return const Center(child: Text('暂无持有贷款'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: loans.length,
            itemBuilder: (_, i) => HeldLoanCard(
              loan: loans[i],
              onRepaymentPlan: () => context.push(
                '/held-products/repayment-plan',
                extra: {'loanId': loans[i].id},
              ),
              onPrepay: () => _showPrepayDialog(loans[i]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Widget _buildPensionTab() {
    final async = ref.watch(heldPensionsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(heldPensionsProvider),
      child: async.when(
        data: (pensions) {
          if (pensions.isEmpty) {
            return const Center(child: Text('暂无养老金账户'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pensions.length,
            itemBuilder: (_, i) => HeldPensionCard(
              pension: pensions[i],
              onDetail: () => context.push('/held-products/detail', extra: {
                'type': 'pension',
                'data': pensions[i],
              }),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  void _showRedeemDialog(HeldWealthProduct product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('赎回确认'),
        content: Text('确认赎回「${product.productName}」？\n可赎回金额: ¥${product.redeemAmount.toStringAsFixed(2)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('赎回申请已提交，预计T+1到账')),
              );
            },
            child: const Text('确认赎回'),
          ),
        ],
      ),
    );
  }

  void _showPrepayDialog(HeldLoan loan) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('提前还款'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('贷款: ${loan.loanType}'),
            Text('未还本金: ¥${loan.remainingPrincipal.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '还款金额',
                prefixText: '¥',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('提前还款申请已提交，预计下一个扣款日执行')),
              );
            },
            child: const Text('确认还款'),
          ),
        ],
      ),
    );
  }
}
