import 'package:flutter/material.dart';
import 'package:aipmb_app/models/held_product.dart';

class ProductDetailPage extends StatelessWidget {
  final String type;
  final dynamic data;

  const ProductDetailPage({super.key, required this.type, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('产品详情')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    switch (type) {
      case 'wealth':
        return _buildWealthDetail(data as HeldWealthProduct);
      case 'loan':
        return _buildLoanDetail(data as HeldLoan);
      case 'pension':
        return _buildPensionDetail(data as HeldPension);
      default:
        return const Center(child: Text('未知产品类型'));
    }
  }

  Widget _buildWealthDetail(HeldWealthProduct p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(p.productName, p.category, Icons.savings, Colors.blue),
        const SizedBox(height: 16),
        _buildInfoCard('基本信息', [
          _infoRow('产品名称', p.productName),
          _infoRow('产品分类', p.category),
          _infoRow('产品期限', p.term),
          _infoRow('关联卡号尾号', p.cardTail),
        ]),
        const SizedBox(height: 12),
        _buildInfoCard('持仓信息', [
          _infoRow('持仓金额', '¥${p.holdingAmount.toStringAsFixed(2)}'),
          _infoRow('持仓收益', '¥${p.holdingProfit.toStringAsFixed(2)}'),
          _infoRow('投入本金', '¥${p.principal.toStringAsFixed(2)}'),
          _infoRow('持有份额', p.shares.toStringAsFixed(2)),
          _infoRow('收益率', '${p.yieldRate}%'),
        ]),
        const SizedBox(height: 12),
        _buildInfoCard('赎回信息', [
          _infoRow('可赎回日期', p.redeemDate),
          _infoRow('可赎回金额', '¥${p.redeemAmount.toStringAsFixed(2)}'),
          _infoRow('赎回状态', p.redeemStatus),
        ]),
      ],
    );
  }

  Widget _buildLoanDetail(HeldLoan l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(l.loanType, l.purpose, Icons.account_balance, Colors.orange),
        const SizedBox(height: 16),
        _buildInfoCard('基本信息', [
          _infoRow('贷款类型', l.loanType),
          _infoRow('贷款编号', l.loanNo),
          _infoRow('贷款用途', l.purpose),
          _infoRow('贷款行', l.bankBranch),
          _infoRow('发放日', l.issueDate),
        ]),
        const SizedBox(height: 12),
        _buildInfoCard('还款信息', [
          _infoRow('贷款本金', '¥${l.principal.toStringAsFixed(2)}'),
          _infoRow('未还本金', '¥${l.remainingPrincipal.toStringAsFixed(2)}'),
          _infoRow('已还本金', '¥${l.repaidPrincipal.toStringAsFixed(2)}'),
          _infoRow('还款方式', l.repaymentMethod),
          _infoRow('还款卡号', l.repaymentCard),
        ]),
        const SizedBox(height: 12),
        _buildInfoCard('利率信息', [
          _infoRow('利率定价方式', l.rateType),
          _infoRow('年利率', l.annualRate),
          _infoRow('LPR调整', l.lprAdjust),
          _infoRow('下一个重定价日', l.nextRepricingDate),
        ]),
        const SizedBox(height: 12),
        _buildInfoCard('联系信息', [
          _infoRow('通知手机号', l.notifyPhone),
        ]),
      ],
    );
  }

  Widget _buildPensionDetail(HeldPension p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(p.accountType, '养老金账户', Icons.elderly, Colors.teal),
        const SizedBox(height: 16),
        _buildInfoCard('账户信息', [
          _infoRow('账户类型', p.accountType),
          _infoRow('总金额', '¥${p.totalAmount.toStringAsFixed(2)}'),
          _infoRow('闲置金额', '¥${p.idleAmount.toStringAsFixed(2)}'),
          _infoRow('已缴存金额', '¥${p.depositedAmount.toStringAsFixed(2)}'),
        ]),
        const SizedBox(height: 12),
        _buildInfoCard('缴存信息', [
          _infoRow('年度缴存上限', '¥${p.annualDepositLimit.toStringAsFixed(2)}'),
          _infoRow('剩余缴存额度', '¥${p.remainingDepositQuota.toStringAsFixed(2)}'),
          _infoRow('自动缴存状态', p.autoDepositStatus),
        ]),
        const SizedBox(height: 12),
        _buildInfoCard('收益信息', [
          _infoRow('税收优惠', p.taxBenefit),
          _infoRow('推荐投资方案', p.recommendedPlan),
          _infoRow('参考收益率', p.referenceYield),
          _infoRow('收益测算功能', p.yieldCalculation),
        ]),
        if (p.remark.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildInfoCard('备注', [
            _infoRow('备注', p.remark),
          ]),
        ],
      ],
    );
  }

  Widget _buildHeader(String title, String subtitle, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
