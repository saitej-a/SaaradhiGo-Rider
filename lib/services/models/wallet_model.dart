import 'package:flutter/material.dart';

class Wallet {
  final double balance;

  Wallet({required this.balance});

  factory Wallet.fromJson(Map<String, dynamic> json) {
    var balanceValue = json['balance'];
    double parsedBalance = 0.0;

    if (balanceValue is num) {
      parsedBalance = balanceValue.toDouble();
    } else if (balanceValue is String) {
      parsedBalance = double.tryParse(balanceValue) ?? 0.0;
    }

    return Wallet(balance: parsedBalance);
  }
}

class Transaction {
  final int id;
  final String title;
  final String amount;
  final bool isCredit;
  final DateTime dateTime;
  final String status;
  final String transactionId;
  final String type; // 'payment', 'recharge', 'refund', 'cashback'

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.isCredit,
    required this.dateTime,
    required this.status,
    required this.transactionId,
    required this.type,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Determine title based on metadata if available, otherwise fallback
    final amountRaw = json['amount'];
    String amountStr = '0.00';

    if (amountRaw is num) {
      amountStr = amountRaw.toStringAsFixed(2);
    } else if (amountRaw is String) {
      amountStr = amountRaw;
    }

    final type =
        json['txn_type'] ?? json['type'] ?? 'payment'; // Default to payment

    return Transaction(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title:
          json['description'] ??
          (type == 'payment' ? 'Ride Payment' : 'Wallet Top-up'),
      amount: amountStr,
      isCredit:
          type == 'credit' ||
          type == 'topup' ||
          type == 'recharge' ||
          type == 'cashback',
      dateTime: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'completed',
      transactionId:
          json['razorpay_order_id'] ??
          json['transaction_id'] ??
          json['id'].toString(),
      type: type,
    );
  }

  String get formattedDate {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String get formattedAmount {
    return '${isCredit ? '+' : '-'}₹$amount';
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class TransactionResponse {
  final List<Transaction> transactions;
  final int currentPage;
  final int totalPages;
  final int totalTransactions;
  final bool hasMore;

  TransactionResponse({
    required this.transactions,
    required this.currentPage,
    required this.totalPages,
    required this.totalTransactions,
    required this.hasMore,
  });

  factory TransactionResponse.fromJson(Map<String, dynamic> json) {
    final transactionsList = (json['transactions'] as List? ?? [])
        .map((item) => Transaction.fromJson(item))
        .toList();

    return TransactionResponse(
      transactions: transactionsList,
      currentPage: json['current_page'] ?? 1,
      totalPages: json['total_pages'] ?? 1,
      totalTransactions: json['total_transactions'] ?? transactionsList.length,
      hasMore: json['has_more'] ?? false,
    );
  }
}
