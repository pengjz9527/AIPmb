import 'package:flutter/material.dart';
import 'package:aipmb_app/models/held_product.dart';

/// 持有理财产品卡片
class HeldWealthCard extends StatelessWidget {
  final HeldWealthProduct product;
  final VoidCallback? onDetail;
  final VoidCallback? onRedeem;

  const HeldWealthCard({
    super.key,
    required this.product,
    this.onDetail,
    this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.savings, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product.productName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    product.category,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildValueColumn('持仓金额', '¥${product.holdingAmount.toStringAsFixed(2)}'),
                _buildValueColumn('持仓收益', '¥${product.holdingProfit.toStringAsFixed(2)}',
                    valueColor: product.holdingProfit >= 0 ? Colors.red : Colors.green),
                _buildValueColumn('收益率', '${product.yieldRate}%',
                    valueColor: product.yieldRate >= 0 ? Colors.red : Colors.green),
              ],
            ),
            const SizedBox(height: 10),
            if (product.redeemStatus.isNotEmpty)
              Text(
                '赎回状态: ${product.redeemStatus} · 可赎回: ¥${product.redeemAmount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDetail,
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('详情'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onRedeem,
                    icon: const Icon(Icons.currency_exchange, size: 16),
                    label: const Text('赎回'),
                  ),
                ),
              ],
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
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor)),
      ],
    );
  }
}

/// 持有贷款卡片
class HeldLoanCard extends StatelessWidget {
  final HeldLoan loan;
  final VoidCallback? onRepaymentPlan;
  final VoidCallback? onPrepay;

  const HeldLoanCard({
    super.key,
    required this.loan,
    this.onRepaymentPlan,
    this.onPrepay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance, color: theme.colorScheme.secondary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loan.loanType,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    loan.purpose,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildValueColumn('贷款本金', '¥${loan.principal.toStringAsFixed(2)}'),
                _buildValueColumn('未还本金', '¥${loan.remainingPrincipal.toStringAsFixed(2)}',
                    valueColor: Colors.orange),
                _buildValueColumn('年利率', loan.annualRate),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${loan.repaymentMethod} · 发放日: ${loan.issueDate} · ${loan.bankBranch}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRepaymentPlan,
                    icon: const Icon(Icons.calendar_month, size: 16),
                    label: const Text('还款计划'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onPrepay,
                    icon: const Icon(Icons.payments, size: 16),
                    label: const Text('提前还款'),
                  ),
                ),
              ],
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
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor)),
      ],
    );
  }
}

/// 养老金账户卡片
class HeldPensionCard extends StatelessWidget {
  final HeldPension pension;
  final VoidCallback? onDetail;

  const HeldPensionCard({
    super.key,
    required this.pension,
    this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.elderly, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pension.accountType,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                if (pension.autoDepositStatus.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      pension.autoDepositStatus,
                      style: TextStyle(fontSize: 11, color: Colors.teal.shade700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildValueColumn('总金额', '¥${pension.totalAmount.toStringAsFixed(2)}'),
                _buildValueColumn('闲置金额', '¥${pension.idleAmount.toStringAsFixed(2)}'),
                _buildValueColumn('已缴存', '¥${pension.depositedAmount.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '年度上限: ¥${pension.annualDepositLimit.toStringAsFixed(2)} · 剩余额度: ¥${pension.remainingDepositQuota.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (pension.referenceYield.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '参考收益率: ${pension.referenceYield}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDetail,
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text('详情'),
              ),
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
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor)),
      ],
    );
  }
}
