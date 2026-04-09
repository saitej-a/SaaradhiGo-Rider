import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../core/app_config.dart';
import 'package:google_fonts/google_fonts.dart';

// Conditional import for Web support
import 'web_payment_stub.dart' if (dart.library.html) 'web_payment_helper.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;

  late Razorpay _razorpay;
  Completer<PaymentSuccessResponse?>? _paymentCompleter;

  PaymentService._internal() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('PaymentService: Payment Success - ${response.paymentId}');
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(response);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('PaymentService: Payment Error - ${response.code} : ${response.message}');
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(null);
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('PaymentService: External Wallet - ${response.walletName}');
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(null);
    }
  }

  Future<PaymentSuccessResponse?> startPayment({
    required double amount,
    required String name,
    required String description,
    required String orderId,
    Map<String, String>? prefill,
    Duration timeout = const Duration(minutes: 2),
    BuildContext? context,
  }) async {
    _paymentCompleter = Completer<PaymentSuccessResponse?>();

    final options = {
      'key': AppConfig.razorpayKey,
      'amount': (amount * 100).toInt(), // amount in paise
      'name': name,
      'description': description,
      'order_id': orderId,
      'prefill': prefill ?? {},
      'retry': {'enabled': true, 'max_count': 1},
      'send_sms_hash': true,
    };

    if (orderId.isEmpty) {
      debugPrint('PaymentService Error: orderId is empty. Razorpay will not open.');
      if (!_paymentCompleter!.isCompleted) {
        _paymentCompleter!.complete(null);
      }
      return null;
    }

    // Show overlay if requested
    OverlayEntry? overlayEntry;
    if (context != null && mounted(context)) {
      overlayEntry = _createOverlayEntry(context);
      Overlay.of(context).insert(overlayEntry);
    }

    try {
      debugPrint('PaymentService: Opening Razorpay with options: $options');
      
      if (kIsWeb) {
        // Use JS Interop fallback for Web
        final response = await WebPaymentHelper.launchRazorpay(options);
        overlayEntry?.remove();
        return response;
      }

      // Native platform logic
      _razorpay.open(options);
      
      final result = await _paymentCompleter!.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint('PaymentService: Payment timed out after ${timeout.inMinutes} minutes');
          if (!_paymentCompleter!.isCompleted) {
            _paymentCompleter!.complete(null);
          }
          return null;
        },
      );
      
      overlayEntry?.remove();
      return result;
    } catch (e) {
      debugPrint('PaymentService Exception: $e');
      if (!_paymentCompleter!.isCompleted) {
        _paymentCompleter!.complete(null);
      }
      overlayEntry?.remove();
      return null;
    }
  }

  bool mounted(BuildContext context) {
    try {
      return (context as dynamic).mounted;
    } catch (_) {
      return true; // Fallback for older Flutter versions if necessary
    }
  }

  OverlayEntry _createOverlayEntry(BuildContext context) {
    return OverlayEntry(
      builder: (context) => Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFEEBD2B)),
              const SizedBox(height: 20),
              Material(
                color: Colors.transparent,
                child: Text(
                  'Initiating secure payment...',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void dispose() {
    _razorpay.clear();
  }
}
