import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  void _openHomeTab(int tabIndex) {
    FocusScope.of(context).unfocus();
    context.go('/home?tab=$tabIndex');
  }

  void _handleBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      context.pop();
      return;
    }
    _openHomeTab(3);
  }

  void _showComingSoon(String label) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label will be available soon.'),
          backgroundColor: const Color(0xFF2B2722),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1814),
      bottomNavigationBar: SafeArea(
        top: false,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 84,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: const BoxDecoration(
                color: Color(0xE61A1814),
                border: Border(top: BorderSide(color: Color(0x0DFFFFFF))),
              ),
              child: Row(
                children: [
                  _PrivacyNavItem(
                    key: const Key('privacy-nav-home'),
                    icon: Icons.home,
                    label: 'Home',
                    selected: false,
                    onTap: () => _openHomeTab(0),
                  ),
                  _PrivacyNavItem(
                    key: const Key('privacy-nav-history'),
                    icon: Icons.history,
                    label: 'History',
                    selected: false,
                    onTap: () => _openHomeTab(1),
                  ),
                  _PrivacyNavItem(
                    key: const Key('privacy-nav-wallet'),
                    icon: Icons.account_balance_wallet,
                    label: 'Wallet',
                    selected: false,
                    onTap: () => _openHomeTab(2),
                  ),
                  _PrivacyNavItem(
                    key: const Key('privacy-nav-profile'),
                    icon: Icons.person,
                    label: 'Profile',
                    selected: true,
                    onTap: () => _openHomeTab(3),
                  ),
                ],
              ),
            ),
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
                    key: const Key('privacy-back'),
                    onTap: _handleBack,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0x1AFFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFFE2E8F0),
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Privacy & Security',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFF8FAFC),
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40, height: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                children: [
                  const _PrivacySectionLabel('Account Security'),
                  const SizedBox(height: 14),
                  _PrivacyCard(
                    child: Column(
                      children: [
                        _PrivacyToggleRow(
                          key: const Key('privacy-toggle-two-factor'),
                          title: 'Two-Factor Authentication',
                          subtitle:
                              'Add an extra layer of security to your account.',
                          value: auth.twoFactorEnabled,
                          onChanged: (value) {
                            unawaited(
                              context.read<AuthProvider>().setTwoFactorEnabled(
                                value,
                              ),
                            );
                          },
                        ),
                        const _PrivacyDivider(),
                        _PrivacyActionRow(
                          key: const Key('privacy-row-change-password'),
                          title: 'Change Password',
                          subtitle:
                              'Update your password regularly to keep your account safe.',
                          onTap: () => _showComingSoon('Change Password'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const _PrivacySectionLabel('Data Privacy'),
                  const SizedBox(height: 14),
                  _PrivacyCard(
                    child: Column(
                      children: [
                        _PrivacyActionRow(
                          key: const Key('privacy-row-location-permissions'),
                          title: 'Location Permissions',
                          subtitle:
                              'Control when SaaradhiGo can access your location.',
                          onTap: () => _showComingSoon('Location Permissions'),
                        ),
                        const _PrivacyDivider(),
                        _PrivacyToggleRow(
                          key: const Key('privacy-toggle-marketing'),
                          title: 'Marketing Preferences',
                          subtitle:
                              'Choose how you want to receive offers and updates.',
                          value: auth.marketingOptIn,
                          onChanged: (value) {
                            unawaited(
                              context.read<AuthProvider>().setMarketingOptIn(
                                value,
                              ),
                            );
                          },
                        ),
                        const _PrivacyDivider(),
                        _PrivacyActionRow(
                          key: const Key('privacy-row-manage-data'),
                          title: 'Manage My Data',
                          subtitle:
                              'Download or delete your account data securely.',
                          onTap: () => _showComingSoon('Manage My Data'),
                        ),
                      ],
                    ),
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

class _PrivacySectionLabel extends StatelessWidget {
  const _PrivacySectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          color: const Color(0xFF94A3B8),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF24211C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: child,
    );
  }
}

class _PrivacyDivider extends StatelessWidget {
  const _PrivacyDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      height: 1,
      color: const Color(0x0DFFFFFF),
    );
  }
}

class _PrivacyActionRow extends StatelessWidget {
  const _PrivacyActionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFF8FAFC),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF64748B),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyToggleRow extends StatelessWidget {
  const _PrivacyToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF8FAFC),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: key,
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFEEBD2B),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFF475569),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _PrivacyNavItem extends StatelessWidget {
  const _PrivacyNavItem({
    super.key,
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
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24, shadows: shadows),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                shadows: shadows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
