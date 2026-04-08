import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../core/app_config.dart';
import '../services/wallet_service.dart';
import '../services/models/wallet_model.dart';

class WalletProvider extends ChangeNotifier {
  final WalletService _walletService = WalletService();
  late Razorpay _razorpay;
  Completer<PaymentSuccessResponse?>? _paymentCompleter;
  
  Wallet? _wallet;
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  WalletProvider() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('Payment Success: ${response.paymentId}');
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(response);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Payment Error: ${response.code} - ${response.message}');
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(null);
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
       _paymentCompleter!.complete(null);
    }
  }

  Wallet? get wallet => _wallet;
  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get balance => _wallet?.balance ?? 0.0;

  Future<void> refreshWallet() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token == null) {
        _errorMessage = 'Authentication token not found. Please log in again.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final results = await Future.wait([
        _walletService.fetchWalletBalance(token),
        _walletService.fetchTransactionHistory(token),
      ]);

      _wallet = results[0] as Wallet?;
      _transactions = results[1] as List<Transaction>;
    } catch (e) {
      _errorMessage = 'Failed to load wallet data. Please try again later.';
      debugPrint('WalletProvider Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> topUp(double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) return false;

      final orderData = await _walletService.createTopUpOrder(token, amount);
      if (orderData == null || orderData['status'] != 'success') return false;

      final orderId = orderData['data']['razorpay_order_id'] ?? orderData['data']['id'];
      
      _paymentCompleter = Completer<PaymentSuccessResponse?>();
      
      var options = {
        'key': AppConfig.razorpayKey,
        'amount': (amount * 100).toInt(),
        'name': 'SaaradhiGo',
        'description': 'Wallet Top Up',
        'order_id': orderId,
        'prefill': {
          'contact': '9876543210',
          'email': 'rider@saaradhigo.com'
        }
      };

      try {
         _razorpay.open(options);
         final successResponse = await _paymentCompleter!.future;
         if (successResponse != null && successResponse.paymentId != null && successResponse.signature != null) {
            // Verify payment
            final verifyResult = await _walletService.verifyTopUpPayment(
                token,
                orderId,
                successResponse.paymentId!,
                successResponse.signature!
            );
            
            if (verifyResult != null && verifyResult['status'] == 'success') {
                await refreshWallet();
                return true;
            }
         }
         return false;
      } catch (e) {
         debugPrint(e.toString());
         return false;
      }
    } catch (e) {
      debugPrint('Top Up Error: $e');
      return false;
    }
  }
}
