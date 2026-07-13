/// 持有理财产品
class HeldWealthProduct {
  final String id;
  final String productName;
  final String category;
  final String term;
  final String cardTail;
  final double holdingAmount;
  final double holdingProfit;
  final double principal;
  final double shares;
  final double yieldRate;
  final String redeemDate;
  final double redeemAmount;
  final String redeemStatus;

  HeldWealthProduct({
    required this.id,
    required this.productName,
    required this.category,
    required this.term,
    required this.cardTail,
    required this.holdingAmount,
    required this.holdingProfit,
    required this.principal,
    required this.shares,
    required this.yieldRate,
    required this.redeemDate,
    required this.redeemAmount,
    required this.redeemStatus,
  });

  factory HeldWealthProduct.fromJson(Map<String, dynamic> json) => HeldWealthProduct(
    id: json['id']?.toString() ?? '',
    productName: json['product_name']?.toString() ?? '',
    category: json['category']?.toString() ?? '',
    term: json['term']?.toString() ?? '',
    cardTail: json['card_tail']?.toString() ?? '',
    holdingAmount: _parseDouble(json['holding_amount']),
    holdingProfit: _parseDouble(json['holding_profit']),
    principal: _parseDouble(json['principal']),
    shares: _parseDouble(json['shares']),
    yieldRate: _parseDouble(json['yield_rate']),
    redeemDate: json['redeem_date']?.toString() ?? '',
    redeemAmount: _parseDouble(json['redeem_amount']),
    redeemStatus: json['redeem_status']?.toString() ?? '',
  );
}

/// 持有贷款
class HeldLoan {
  final String id;
  final String loanType;
  final String loanNo;
  final String purpose;
  final String bankBranch;
  final String issueDate;
  final double principal;
  final double remainingPrincipal;
  final double repaidPrincipal;
  final String rateType;
  final String annualRate;
  final String lprAdjust;
  final String nextRepricingDate;
  final String repaymentMethod;
  final String repaymentCard;
  final String notifyPhone;

  HeldLoan({
    required this.id,
    required this.loanType,
    required this.loanNo,
    required this.purpose,
    required this.bankBranch,
    required this.issueDate,
    required this.principal,
    required this.remainingPrincipal,
    required this.repaidPrincipal,
    required this.rateType,
    required this.annualRate,
    required this.lprAdjust,
    required this.nextRepricingDate,
    required this.repaymentMethod,
    required this.repaymentCard,
    required this.notifyPhone,
  });

  factory HeldLoan.fromJson(Map<String, dynamic> json) => HeldLoan(
    id: json['id']?.toString() ?? '',
    loanType: json['loan_type']?.toString() ?? '',
    loanNo: json['loan_no']?.toString() ?? '',
    purpose: json['purpose']?.toString() ?? '',
    bankBranch: json['bank_branch']?.toString() ?? '',
    issueDate: json['issue_date']?.toString() ?? '',
    principal: _parseDouble(json['principal']),
    remainingPrincipal: _parseDouble(json['remaining_principal']),
    repaidPrincipal: _parseDouble(json['repaid_principal']),
    rateType: json['rate_type']?.toString() ?? '',
    annualRate: json['annual_rate']?.toString() ?? '',
    lprAdjust: json['lpr_adjust']?.toString() ?? '',
    nextRepricingDate: json['next_repricing_date']?.toString() ?? '',
    repaymentMethod: json['repayment_method']?.toString() ?? '',
    repaymentCard: json['repayment_card']?.toString() ?? '',
    notifyPhone: json['notify_phone']?.toString() ?? '',
  );
}

/// 养老金账户
class HeldPension {
  final String id;
  final String accountType;
  final double totalAmount;
  final double idleAmount;
  final double annualDepositLimit;
  final double remainingDepositQuota;
  final double depositedAmount;
  final String taxBenefit;
  final String autoDepositStatus;
  final String recommendedPlan;
  final String referenceYield;
  final String yieldCalculation;
  final String remark;

  HeldPension({
    required this.id,
    required this.accountType,
    required this.totalAmount,
    required this.idleAmount,
    required this.annualDepositLimit,
    required this.remainingDepositQuota,
    required this.depositedAmount,
    required this.taxBenefit,
    required this.autoDepositStatus,
    required this.recommendedPlan,
    required this.referenceYield,
    required this.yieldCalculation,
    required this.remark,
  });

  factory HeldPension.fromJson(Map<String, dynamic> json) => HeldPension(
    id: json['id']?.toString() ?? '',
    accountType: json['account_type']?.toString() ?? '',
    totalAmount: _parseDouble(json['total_amount']),
    idleAmount: _parseDouble(json['idle_amount']),
    annualDepositLimit: _parseDouble(json['annual_deposit_limit']),
    remainingDepositQuota: _parseDouble(json['remaining_deposit_quota']),
    depositedAmount: _parseDouble(json['deposited_amount']),
    taxBenefit: json['tax_benefit']?.toString() ?? '',
    autoDepositStatus: json['auto_deposit_status']?.toString() ?? '',
    recommendedPlan: json['recommended_plan']?.toString() ?? '',
    referenceYield: json['reference_yield']?.toString() ?? '',
    yieldCalculation: json['yield_calculation']?.toString() ?? '',
    remark: json['remark']?.toString() ?? '',
  );
}

/// 持有产品汇总
class HeldProductsSummary {
  final int wealthCount;
  final int loanCount;
  final int pensionCount;
  final double totalWealthAmount;
  final double totalLoanAmount;
  final double totalPensionAmount;

  HeldProductsSummary({
    required this.wealthCount,
    required this.loanCount,
    required this.pensionCount,
    required this.totalWealthAmount,
    required this.totalLoanAmount,
    required this.totalPensionAmount,
  });

  factory HeldProductsSummary.fromJson(Map<String, dynamic> json) {
    final wealth = json['wealth'] ?? {};
    final loans = json['loans'] ?? {};
    final pensions = json['pensions'] ?? {};
    return HeldProductsSummary(
      wealthCount: (wealth['count'] ?? 0) as int,
      loanCount: (loans['count'] ?? 0) as int,
      pensionCount: (pensions['count'] ?? 0) as int,
      totalWealthAmount: _parseDouble(wealth['total_holding_amount']),
      totalLoanAmount: _parseDouble(loans['total_remaining_principal']),
      totalPensionAmount: _parseDouble(pensions['total_amount']),
    );
  }
}

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    final cleaned = value.replaceAll('%', '').replaceAll(',', '');
    return double.tryParse(cleaned) ?? 0.0;
  }
  return 0.0;
}
