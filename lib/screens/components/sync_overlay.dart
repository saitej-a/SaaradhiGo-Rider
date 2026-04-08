import 'package:flutter/material.dart';

class SyncOverlay extends StatelessWidget {
  const SyncOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF12110E).withOpacity(0.8),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEBD2B)),
              ),
              SizedBox(height: 24),
              Text(
                'Syncing your ride...',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
