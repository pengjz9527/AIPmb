import 'package:aipmb_app/utils/json_helpers.dart';

class Account {
  final String accountId;
  final String accountName;
  final String accountType;
  final double balance;
  final String currency;
  final String status;

  const Account({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.balance,
    this.currency = 'CNY',
    this.status = 'active',
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        accountId: json['account_number'] ?? json['account_id'] ?? '',
        accountName: json['name'] ?? json['account_name'] ?? '',
        accountType: json['account_type'] ?? '',
        balance: parseDouble(json['balance']),
        currency: json['currency'] ?? 'CNY',
        status: json['status'] ?? 'active',
      );
}

class AccountSummaryItem {
  final String accountType;
  final int count;
  final double totalBalance;

  const AccountSummaryItem({
    required this.accountType,
    required this.count,
    required this.totalBalance,
  });

  factory AccountSummaryItem.fromJson(Map<String, dynamic> json) =>
      AccountSummaryItem(
        accountType: json['type'] ?? json['account_type'] ?? '',
        count: parseInt(json['count']),
        totalBalance: parseDouble(json['amount'] ?? json['total_balance']),
      );
}

class WealthOverview {
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final List<AccountSummaryItem> breakdown;
  final double monthlyIncome;
  final double monthlyExpense;
  final double lastMonthIncome;
  final double lastMonthExpense;

  const WealthOverview({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    this.breakdown = const [],
    this.monthlyIncome = 0,
    this.monthlyExpense = 0,
    this.lastMonthIncome = 0,
    this.lastMonthExpense = 0,
  });

  factory WealthOverview.fromJson(Map<String, dynamic> json) {
    final rawList = json['asset_breakdown'] ?? json['breakdown'];
    final List<AccountSummaryItem> breakdown;
    if (rawList is List) {
      breakdown = rawList
          .map((e) => AccountSummaryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      breakdown = [];
    }
    return WealthOverview(
      totalAssets: parseDouble(json['total_assets']),
      totalLiabilities: parseDouble(json['total_liabilities']),
      netWorth: parseDouble(json['net_worth']),
      breakdown: breakdown,
      monthlyIncome: parseDouble(json['monthly_income']),
      monthlyExpense: parseDouble(json['monthly_expense']),
      lastMonthIncome: parseDouble(json['last_month_income']),
      lastMonthExpense: parseDouble(json['last_month_expense']),
    );
  }
}