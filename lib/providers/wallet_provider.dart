import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/wallet_service.dart';
import '../services/payment_service.dart';
import '../services/models/wallet_model.dart';

class WalletProvider extends ChangeNotifier {
  final WalletService _walletService = WalletService();
  final PaymentService _paymentService = PaymentService();
  
  Wallet? _wallet;
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

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

  Future<bool> topUp(double amount, BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) return false;

      final orderData = await _walletService.createTopUpOrder(token, amount);
      
      // Extract order ID with robust fallback paths
      final orderId = orderData?['razorpay_order_id']?.toString() ?? 
                     orderData?['id']?.toString() ??
                     orderData?['data']?['razorpay_order_id']?.toString() ??
                     orderData?['data']?['id']?.toString();
 
      if (orderId == null || orderId.isEmpty) {
          final backendError = orderData?['error'];
          _errorMessage = (backendError != null && backendError['message'] != null)
              ? backendError['message']
              : (orderData?['message'] ?? 'Failed to create top-up order.');
          notifyListeners();
          return false;
      }

      // Use server-provided prefill if available (handle data wrapper)
      final serverPrefill = (orderData?['data']?['prefill'] ?? orderData?['prefill']) as Map<String, dynamic>?;
      final prefill = {
        'name': serverPrefill?['name']?.toString() ?? 'Rider',
        'contact': serverPrefill?['contact']?.toString() ?? '9876543210',
        'email': serverPrefill?['email']?.toString() ?? 'rider@saaradhigo.com'
      };

      // Extract description with data wrapper fallback
      final description = orderData?['data']?['description']?.toString() ?? 
                         orderData?['description']?.toString() ?? 
                         'Wallet Top Up';

      try {
          final successResponse = await _paymentService.startPayment(
            amount: amount,
            name: 'SaaradhiGo',
            description: description,
            orderId: orderId,
            prefill: prefill,
            context: context,
          );

         if (successResponse != null && successResponse.paymentId != null && successResponse.signature != null) {
            // Verify payment
            final verifyResult = await _walletService.verifyTopUpPayment(
                token,
                orderId,
                successResponse.paymentId!,
                successResponse.signature!
            );
            
            if (verifyResult != null && (verifyResult['status'] == 'success' || verifyResult['status'] == 'paid')) {
                await refreshWallet();
                return true;
            }
         }
         return false;
      } catch (e) {
         debugPrint('Top Up Payment Error: $e');
         return false;
      }
    } catch (e) {
      debugPrint('Top Up Order Error: $e');
      return false;
    }
  }
}
