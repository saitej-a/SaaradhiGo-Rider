import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/wallet_provider.dart';

class ManagePaymentMethodsScreen extends StatelessWidget {
  const ManagePaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1814).withValues(alpha: 0.8),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        title: Text(
          'Payment Methods',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<WalletProvider>(
        builder: (context, provider, child) {
          final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
          
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'SAVED METHODS',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              _PaymentTile(
                title: 'SaaradhiGo Wallet',
                subtitle: 'Balance: ${formatter.format(provider.balance)}',
                icon: Icons.account_balance_wallet,
                isWallet: true,
                onTap: () {
                  context.go('/home?tab=2');
                },
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add New Payment Method'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  foregroundColor: const Color(0xFFEEBD2B),
                  side: BorderSide(color: const Color(0xFF8B6508).withValues(alpha: 0.4)),
                  backgroundColor: const Color(0xFF8B6508).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isWallet = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isWallet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isWallet
              ? LinearGradient(
                  colors: [
                    const Color(0xFF8B6508).withValues(alpha: 0.2),
                    const Color(0xFF8B6508).withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isWallet ? null : const Color(0xFF22201C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isWallet 
                ? const Color(0xFF8B6508).withValues(alpha: 0.3)
                : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isWallet 
                    ? const Color(0xFF8B6508).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isWallet ? const Color(0xFFEEBD2B) : const Color(0xFF94A3B8),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      children: [
                        if (isWallet) const TextSpan(text: 'Balance: '),
                        if (isWallet)
                          TextSpan(
                            text: subtitle.split(': ').last,
                            style: const TextStyle(
                              color: Color(0xFFEEBD2B),
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else
                          TextSpan(text: subtitle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFEEBD2B),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
