class ManageUser {
  final String name;
  final int accountCount;
  final int debitCount;
  final int creditCount;
  final double totalBalance;
  final double totalCreditLimit;

  ManageUser({
    required this.name,
    required this.accountCount,
    required this.debitCount,
    required this.creditCount,
    required this.totalBalance,
    required this.totalCreditLimit,
  });

  factory ManageUser.fromJson(Map<String, dynamic> json) {
    return ManageUser(
      name: json['name'] ?? '',
      accountCount: json['account_count'] ?? 0,
      debitCount: json['debit_count'] ?? 0,
      creditCount: json['credit_count'] ?? 0,
      totalBalance: (json['total_balance'] ?? 0).toDouble(),
      totalCreditLimit: (json['total_credit_limit'] ?? 0).toDouble(),
    );
  }
}

class UserDetail {
  final String name;
  final int accountCount;
  final double totalBalance;
  final double totalCreditLimit;
  final int transactionCount;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> consumptionStats;

  UserDetail({
    required this.name,
    required this.accountCount,
    required this.totalBalance,
    required this.totalCreditLimit,
    required this.transactionCount,
    required this.accounts,
    required this.consumptionStats,
  });

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    return UserDetail(
      name: json['name'] ?? '',
      accountCount: json['account_count'] ?? 0,
      totalBalance: (json['total_balance'] ?? 0).toDouble(),
      totalCreditLimit: (json['total_credit_limit'] ?? 0).toDouble(),
      transactionCount: json['transaction_count'] ?? 0,
      accounts: List<Map<String, dynamic>>.from(json['accounts'] ?? []),
      consumptionStats: List<Map<String, dynamic>>.from(json['consumption_stats'] ?? []),
    );
  }
}