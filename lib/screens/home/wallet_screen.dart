import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/models/wallet_model.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().refreshWallet();
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, provider, child) {
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: RefreshIndicator(
            onRefresh: provider.refreshWallet,
            color: const Color(0xFFEEBD2B),
            backgroundColor: const Color(0xFF24211C),
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const _WalletHeader(),
                const SizedBox(height: 24),
                const Text(
                  'Wallet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 24),
                _WalletBalanceCard(balance: provider.balance, isLoading: provider.isLoading),
                const SizedBox(height: 28),
                if (provider.isLoading && provider.transactions.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(color: Color(0xFFEEBD2B)),
                    ),
                  )
                else if (provider.errorMessage != null && provider.transactions.isEmpty)
                  _ErrorState(message: provider.errorMessage!)
                else if (provider.transactions.isEmpty)
                  const _EmptyTransactionsState()
                else
                  ..._buildTransactionHistory(provider.transactions),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildTransactionHistory(List<Transaction> transactions) {
    // Group transactions by month
    final Map<String, List<Transaction>> grouped = {};
    final DateFormat monthFormat = DateFormat('MMMM yyyy');

    for (var tx in transactions) {
      final month = monthFormat.format(tx.dateTime);
      grouped.putIfAbsent(month, () => []).add(tx);
    }

    final List<Widget> widgets = [];
    grouped.forEach((month, txs) {
      widgets.add(_WalletMonthLabel(label: month));
      widgets.add(const SizedBox(height: 14));
      for (int i = 0; i < txs.length; i++) {
        widgets.add(
          _WalletTxnCard(
            transaction: txs[i],
            showTimelineTail: i < txs.length - 1,
          ),
        );
        widgets.add(const SizedBox(height: 12));
      }
      widgets.add(const SizedBox(height: 12));
    });

    return widgets;
  }
}

class _WalletHeader extends StatelessWidget {
  const _WalletHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'SaaradhiGo',
            style: TextStyle(
              color: Color(0xFFEEBD2B),
              fontSize: 23,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.6,
            ),
          ),
        ),
        Consumer<NotificationProvider>(
          builder: (context, provider, child) => GestureDetector(
            onTap: () => context.push('/notifications'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 3),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0x14FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications,
                      color: Color(0xFFE2E8F0),
                      size: 21,
                    ),
                  ),
                ),
                if (provider.unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${provider.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard({required this.balance, required this.isLoading});
  final double balance;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEBD2B), Color(0xFFC59A1D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEEBD2B).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Balance',
                style: GoogleFonts.inter(
                  color: Colors.black.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Icon(Icons.account_balance_wallet, color: Colors.black54, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          isLoading && balance == 0
          ? const SizedBox(
              height: 40,
              child: Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)),
            )
          : Text(
            formatter.format(balance),
            style: GoogleFonts.inter(
              color: Colors.black,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _WalletActionButton(
                  icon: Icons.add_rounded,
                  label: 'Add Money',
                  onTap: () {
                    // TODO: Implement Add Money logic
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WalletActionButton(
                  icon: Icons.send_rounded,
                  label: 'Send',
                  onTap: () {
                    // TODO: Implement Send Money logic
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletActionButton extends StatelessWidget {
  const _WalletActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.black, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletMonthLabel extends StatelessWidget {
  const _WalletMonthLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.inter(
        color: const Color(0xFF94A3B8),
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.4,
      ),
    );
  }
}

class _WalletTxnCard extends StatelessWidget {
  const _WalletTxnCard({
    required this.transaction,
    required this.showTimelineTail,
  });

  final Transaction transaction;
  final bool showTimelineTail;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM dd, yyyy \u2022 hh:mm a').format(transaction.dateTime);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: transaction.isCredit ? const Color(0xFF10B981) : const Color(0xFFEEBD2B),
                boxShadow: [
                  BoxShadow(
                    color: (transaction.isCredit ? const Color(0xFF10B981) : const Color(0xFFEEBD2B)).withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            if (showTimelineTail)
              Container(
                width: 2,
                height: 48,
                color: const Color(0x1AFFFFFF),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF24211C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x0DFFFFFF)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFF8FAFC),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${transaction.isCredit ? '+' : '-'}\u20B9${transaction.amount}',
                  style: GoogleFonts.inter(
                    color: transaction.isCredit ? const Color(0xFF10B981) : const Color(0xFFF8FAFC),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyTransactionsState extends StatelessWidget {
  const _EmptyTransactionsState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.history_rounded, size: 64, color: Colors.white.withValues(alpha: 0.1)),
        const SizedBox(height: 16),
        Text(
          'No transactions yet',
          style: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.error_outline_rounded, size: 64, color: Color(0xFFF87171)),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFFF87171),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.read<WalletProvider>().refreshWallet(),
          child: const Text('Retry', style: TextStyle(color: Color(0xFFEEBD2B))),
        ),
      ],
    );
  }
}
