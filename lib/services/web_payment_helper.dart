import 'dart:js' as js;
import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/foundation.dart';

class WebPaymentHelper {
  static Future<PaymentSuccessResponse?> launchRazorpay(
      Map<String, dynamic> options) {
    final completer = Completer<PaymentSuccessResponse?>();

    // Define success callback
    void successCallback(String paymentId, String orderId, String signature) {
      debugPrint('WebPaymentHelper: Success - $paymentId');
      completer.complete(PaymentSuccessResponse(paymentId, orderId, signature, null));
    }

    // Define error callback
    void errorCallback(dynamic code, String message) {
      debugPrint('WebPaymentHelper: Error - $code : $message');
      completer.complete(null);
    }

    try {
      if (js.context.hasProperty('launchRazorpay')) {
        js.context.callMethod('launchRazorpay', [
          js.JsObject.jsify(options),
          js.allowInterop(successCallback),
          js.allowInterop(errorCallback),
        ]);
      } else {
        debugPrint('WebPaymentHelper Error: launchRazorpay not found in JS context');
        completer.complete(null);
      }
    } catch (e) {
      debugPrint('WebPaymentHelper Exception: $e');
      completer.complete(null);
    }

    return completer.future;
  }
}
