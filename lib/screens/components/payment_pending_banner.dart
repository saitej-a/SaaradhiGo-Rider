import 'package:flutter/material.dart';

class PaymentPendingBanner extends StatelessWidget {
  const PaymentPendingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: const Color(0xFFEEBD2B),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 12,
          left: 16,
          right: 16,
        ),
        child: const Row(
          children: [
            Icon(Icons.payment, color: Color(0xFF12110E)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Payment Pending for your last ride',
                style: TextStyle(
                  color: Color(0xFF12110E),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
