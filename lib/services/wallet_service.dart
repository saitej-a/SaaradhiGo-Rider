import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'models/wallet_model.dart';
import '../core/app_config.dart';

class WalletService {
  final String baseUrl = AppConfig.baseUrl;

  Future<Wallet?> fetchWalletBalance(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rider/wallet/balance/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final walletData = data['data'];
          if (walletData != null) {
            return Wallet.fromJson(walletData);
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Fetch Wallet Balance error: $e');
      return null;
    }
  }

  Future<List<Transaction>> fetchTransactionHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payments/history/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic>? results;
        
        if (data is Map<String, dynamic>) {
          if (data['results'] != null) {
            results = data['results'];
          } else if (data['status'] == 'success' && data['data'] != null) {
            if (data['data'] is List) {
              results = data['data'];
            } else if (data['data']['results'] != null) {
              results = data['data']['results'];
            }
          }
        }

        if (results != null) {
          return results.map((json) => Transaction.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Fetch Transaction History error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createTopUpOrder(String token, double amount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rider/wallet/create-order/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount.toStringAsFixed(2),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      
      try {
        final errorData = jsonDecode(response.body);
        debugPrint('Create TopUp Order API Error: ${response.statusCode} - $errorData');
        return errorData; // Return error data so UI can show message
      } catch (_) {
        debugPrint('Create TopUp Order Error: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      debugPrint('Create TopUp Order error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> verifyTopUpPayment(
    String token,
    String orderId,
    String paymentId,
    String signature,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rider/wallet/verify/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'razorpay_order_id': orderId,
          'razorpay_payment_id': paymentId,
          'razorpay_signature': signature,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Verify TopUp Payment error: $e');
      return null;
    }
  }
}
