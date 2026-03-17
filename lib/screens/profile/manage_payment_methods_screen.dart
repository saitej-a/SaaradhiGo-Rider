import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

class ManagePaymentMethodsScreen extends StatelessWidget {
  const ManagePaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Methods'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _PaymentTile(
            title: 'SaaradhiGo Wallet',
            subtitle: 'Balance: INR 1,250.00',
            icon: Icons.account_balance_wallet,
          ),
          _PaymentTile(
            title: 'UPI',
            subtitle: 'Linked . user@upi',
            icon: Icons.qr_code,
          ),
          _PaymentTile(
            title: 'Credit / Debit Card',
            subtitle: '**** **** **** 1234',
            icon: Icons.credit_card,
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Add New Payment Method'),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
