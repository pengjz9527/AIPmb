import 'package:aipmb_app/utils/json_helpers.dart';

class Transaction {
  final String seqNo;
  final String accountId;
  final String transactionType;
  final double amount;
  final String currency;
  final String description;
  final String date;
  final String? category;

  const Transaction({
    required this.seqNo,
    required this.accountId,
    required this.transactionType,
    required this.amount,
    this.currency = 'CNY',
    required this.description,
    required this.date,
    this.category,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        seqNo: json['seq_no'] ?? '',
        accountId: json['account_id'] ?? '',
        transactionType: json['transaction_type'] ?? '',
        amount: parseDouble(json['amount']),
        currency: json['currency'] ?? 'CNY',
        description: json['description'] ?? '',
        date: json['date'] ?? '',
        category: json['category'],
      );
}

class TransactionSummary {
  final String transactionType;
  final int count;
  final double totalAmount;

  const TransactionSummary({
    required this.transactionType,
    required this.count,
    required this.totalAmount,
  });

  factory TransactionSummary.fromJson(Map<String, dynamic> json) =>
      TransactionSummary(
        transactionType: json['transaction_type'] ?? '',
        count: parseInt(json['count']),
        totalAmount: parseDouble(json['total_amount']),
      );
}