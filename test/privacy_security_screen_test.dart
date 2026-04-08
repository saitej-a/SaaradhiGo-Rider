import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vahango/providers/auth_provider.dart';
import 'package:vahango/screens/profile/privacy_security_screen.dart';
import 'package:vahango/services/api_service.dart';

class _FakeAuthApiClient implements AuthApiClient {
  @override
  Future<void> clearSession() async {}

  @override
  Future<Map<String, dynamic>?> requestOtp(String phoneNumber, String role) async => {'status': 'success'};

  @override
  Future<Map<String, dynamic>?> getProfile() async => null;

  @override
  Future<Map<String, dynamic>?> updateProfile({
    required String fullName,
    required String email,
    required String gender,
    required String dob,
    required String emergencyContact,
    required String houseNo,
    String? profilePicPath,
    required String street,
    required String city,
    required String zipCode,
  }) async {
    return null;
  }

  @override
  Future<Map<String, dynamic>?> verifyOtpAndLogin(
    String phoneNumber,
    String otp,
    String deviceToken,
  ) async {
    return null;
  }
}

GoRouter _buildRouter({String initialLocation = '/privacy-security'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/privacy-security',
        builder: (context, state) => const PrivacySecurityScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'] ?? 'none';
          return Scaffold(body: Center(child: Text('Home Tab $tab')));
        },
      ),
    ],
  );
}

Future<AuthProvider> _buildProvider(Map<String, Object> prefsData) async {
  SharedPreferences.setMockInitialValues(prefsData);
  final provider = AuthProvider(apiService: _FakeAuthApiClient());
  await provider.initializationFuture;
  return provider;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  AuthProvider provider, {
  String initialLocation = '/privacy-security',
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: provider,
      child: MaterialApp.router(
        routerConfig: _buildRouter(initialLocation: initialLocation),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrivacySecurityScreen redesign', () {
    testWidgets('renders sections, rows, toggles, and bottom nav', (
      tester,
    ) async {
      final provider = await _buildProvider({});
      await _pumpScreen(tester, provider);

      expect(find.text('Privacy & Security'), findsOneWidget);
      expect(find.text('ACCOUNT SECURITY'), findsOneWidget);
      expect(find.text('DATA PRIVACY'), findsOneWidget);
      expect(find.text('Two-Factor Authentication'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Location Permissions'), findsOneWidget);
      expect(find.text('Marketing Preferences'), findsOneWidget);
      expect(find.text('Manage My Data'), findsOneWidget);

      expect(find.byKey(const Key('privacy-back')), findsOneWidget);
      expect(find.byKey(const Key('privacy-nav-home')), findsOneWidget);
      expect(find.byKey(const Key('privacy-nav-history')), findsOneWidget);
      expect(find.byKey(const Key('privacy-nav-wallet')), findsOneWidget);
      expect(find.byKey(const Key('privacy-nav-profile')), findsOneWidget);

      final twoFactorSwitch = tester.widget<Switch>(
        find.byKey(const Key('privacy-toggle-two-factor')),
      );
      final marketingSwitch = tester.widget<Switch>(
        find.byKey(const Key('privacy-toggle-marketing')),
      );
      expect(twoFactorSwitch.value, isTrue);
      expect(marketingSwitch.value, isFalse);
    });

    testWidgets('back button routes to /home?tab=3 when no back stack', (
      tester,
    ) async {
      final provider = await _buildProvider({});
      await _pumpScreen(tester, provider);

      await tester.tap(find.byKey(const Key('privacy-back')));
      await tester.pumpAndSettle();

      expect(find.text('Home Tab 3'), findsOneWidget);
    });

    testWidgets('row taps show temporary snackbar feedback', (tester) async {
      final provider = await _buildProvider({});
      await _pumpScreen(tester, provider);

      await tester.tap(find.byKey(const Key('privacy-row-change-password')));
      await tester.pump();
      expect(
        find.text('Change Password will be available soon.'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('privacy-row-location-permissions')),
      );
      await tester.pump();
      expect(
        find.text('Location Permissions will be available soon.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('privacy-row-manage-data')));
      await tester.pump();
      expect(
        find.text('Manage My Data will be available soon.'),
        findsOneWidget,
      );
    });

    testWidgets('bottom nav routes to /home?tab=0..3', (tester) async {
      final targets = <String, int>{
        'privacy-nav-home': 0,
        'privacy-nav-history': 1,
        'privacy-nav-wallet': 2,
        'privacy-nav-profile': 3,
      };

      for (final entry in targets.entries) {
        final provider = await _buildProvider({});
        await _pumpScreen(tester, provider);

        await tester.tap(find.byKey(Key(entry.key)));
        await tester.pumpAndSettle();

        expect(find.text('Home Tab ${entry.value}'), findsOneWidget);
      }
    });

    testWidgets('toggle updates persist across provider rebuild', (
      tester,
    ) async {
      final provider = await _buildProvider({});
      await _pumpScreen(tester, provider);

      await tester.tap(find.byKey(const Key('privacy-toggle-two-factor')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('privacy-toggle-marketing')));
      await tester.pumpAndSettle();

      expect(provider.twoFactorEnabled, isFalse);
      expect(provider.marketingOptIn, isTrue);

      final rehydratedProvider = AuthProvider(apiService: _FakeAuthApiClient());
      await rehydratedProvider.initializationFuture;
      await _pumpScreen(tester, rehydratedProvider);

      final twoFactorSwitch = tester.widget<Switch>(
        find.byKey(const Key('privacy-toggle-two-factor')),
      );
      final marketingSwitch = tester.widget<Switch>(
        find.byKey(const Key('privacy-toggle-marketing')),
      );
      expect(twoFactorSwitch.value, isFalse);
      expect(marketingSwitch.value, isTrue);
    });
  });
}
