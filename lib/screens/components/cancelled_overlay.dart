import 'package:flutter/material.dart';

class CancelledOverlay extends StatelessWidget {
  const CancelledOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF12110E).withOpacity(0.9),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cancel_outlined,
                color: Colors.redAccent,
                size: 64,
              ),
              SizedBox(height: 24),
              Text(
                'Ride Cancelled',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Manrope',
                  fontSize: 24,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Returning to home...',
                style: TextStyle(
                  color: Color(0xFFBDBDBD),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
