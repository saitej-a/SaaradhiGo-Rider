import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const Color _screenBackground = Color(0xFF1A1814);

  void _openHomeTab(BuildContext context, int tabIndex) {
    context.go('/home?tab=$tabIndex');
  }

  void _handleBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      context.pop();
      return;
    }
    context.go('/home?tab=3');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 84,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: const BoxDecoration(
            color: Color(0xE61A1814),
            border: Border(top: BorderSide(color: Color(0x0DFFFFFF))),
          ),
          child: Row(
            children: [
              _HelpNavItem(
                icon: Icons.home,
                label: 'Home',
                selected: false,
                onTap: () => _openHomeTab(context, 0),
              ),
              _HelpNavItem(
                icon: Icons.history,
                label: 'History',
                selected: false,
                onTap: () => _openHomeTab(context, 1),
              ),
              _HelpNavItem(
                icon: Icons.account_balance_wallet,
                label: 'Wallet',
                selected: false,
                onTap: () => _openHomeTab(context, 2),
              ),
              _HelpNavItem(
                icon: Icons.person,
                label: 'Profile',
                selected: true,
                onTap: () => _openHomeTab(context, 3),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _handleBack(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0x1AFFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Color(0xFFE2E8F0),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Help & Support',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFF8FAFC),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  const _HelpSearchField(),
                  const SizedBox(height: 32),
                  const _HelpSectionLabel('Common Topics'),
                  const SizedBox(height: 16),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          childAspectRatio: 1.70,
                        ),
                    children: const [
                      _MiniTile(
                        icon: Icons.directions_car,
                        label: 'Ride Issues',
                      ),
                      _MiniTile(
                        icon: Icons.account_balance_wallet,
                        label: 'Payment & Wallet',
                      ),
                      _MiniTile(icon: Icons.person, label: 'Account & App'),
                      _MiniTile(
                        icon: Icons.shield,
                        label: 'Safety',
                        iconBackground: Color(0x338B6508),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const _HelpSectionLabel('Contact Us'),
                  const SizedBox(height: 16),
                  const _ContactTile(
                    icon: Icons.chat_bubble,
                    title: 'Live Chat',
                    subtitle: 'Usually responds in minutes',
                  ),
                  const SizedBox(height: 12),
                  const _ContactTile(
                    icon: Icons.mail,
                    title: 'Email Support',
                    subtitle: 'support@saaradhigo.com',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpNavItem extends StatelessWidget {
  const _HelpNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFEEBD2B) : const Color(0xFF94A3B8);
    final shadows = selected
        ? const [Shadow(color: Color(0x80EEBD2B), blurRadius: 8)]
        : null;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24, shadows: shadows),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                shadows: shadows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpSearchField extends StatelessWidget {
  const _HelpSearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF24211C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: TextField(
        style: GoogleFonts.inter(color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Search for issues...',
          hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _HelpSectionLabel extends StatelessWidget {
  const _HelpSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.icon,
    required this.label,
    this.iconBackground,
  });

  final IconData icon;
  final String label;
  final Color? iconBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF24211C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBackground ?? const Color(0x1AEEBD2B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFEEBD2B), size: 20),
          ),
          const Spacer(),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF24211C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEEBD2B).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFEEBD2B), size: 24),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
            fontSize: 13,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Color(0xFF64748B),
          size: 20,
        ),
      ),
    );
  }
}
