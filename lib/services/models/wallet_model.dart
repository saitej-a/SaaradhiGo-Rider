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

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.isCredit,
    required this.dateTime,
    required this.status,
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
    
    final type = json['type'] ?? 'payment'; // Default to payment
    
    return Transaction(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['description'] ?? (type == 'payment' ? 'Ride Payment' : 'Wallet Top-up'),
      amount: amountStr,
      isCredit: type == 'credit' || type == 'topup',
      dateTime: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'completed',
    );
  }
}
