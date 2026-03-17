import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/wallet_service.dart';
import '../services/models/wallet_model.dart';

class WalletProvider extends ChangeNotifier {
  final WalletService _walletService = WalletService();
  
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

      // Fetch balance and history in parallel
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

  Future<Map<String, dynamic>?> topUp(double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) return null;

      return await _walletService.createTopUpOrder(token, amount);
    } catch (e) {
      debugPrint('Top Up Error: $e');
      return null;
    }
  }
}
