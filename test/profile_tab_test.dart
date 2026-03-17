import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vahango/providers/auth_provider.dart';
import 'package:vahango/screens/home/home_screen.dart';
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

GoRouter _buildRouter({String initialLocation = '/home'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final parsedTab = int.tryParse(state.uri.queryParameters['tab'] ?? '');
          final initialTabIndex =
              (parsedTab != null && parsedTab >= 0 && parsedTab <= 3)
              ? parsedTab
              : 0;
          return HomeScreen(initialTabIndex: initialTabIndex);
        },
      ),
      GoRoute(
        path: '/personal-info',
        builder: (context, state) {
          return const Scaffold(
            body: Center(child: Text('Personal Info Screen')),
          );
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          return const Scaffold(body: Center(child: Text('Login Screen')));
        },
      ),
      GoRoute(
        path: '/payment-methods',
        builder: (context, state) => const Scaffold(body: SizedBox()),
      ),
      GoRoute(
        path: '/privacy-security',
        builder: (context, state) => const Scaffold(body: SizedBox()),
      ),
      GoRoute(
        path: '/help-support',
        builder: (context, state) => const Scaffold(body: SizedBox()),
      ),
    ],
  );
}

Future<void> _openProfileTab(WidgetTester tester) async {
  await tester.tap(find.text('Profile').first);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home profile tab redesign', () {
    testWidgets('supports selecting profile tab via /home?tab=3', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'profile_full_name': 'Rider Jane',
      });

      final provider = AuthProvider(apiService: _FakeAuthApiClient());
      await provider.initializationFuture;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: _buildRouter(initialLocation: '/home?tab=3'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Rider Jane'), findsOneWidget);
    });

    testWidgets('renders provider-driven profile values', (tester) async {
      SharedPreferences.setMockInitialValues({
        'profile_full_name': 'Rider Jane',
        'profile_rating': '4.77',
        'profile_avatar_url': 'https://example.com/jane.png',
      });

      final provider = AuthProvider(apiService: _FakeAuthApiClient());
      await provider.initializationFuture;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: _buildRouter()),
        ),
      );
      await tester.pumpAndSettle();
      await _openProfileTab(tester);

      expect(find.text('Rider Jane'), findsOneWidget);
      expect(find.text('4.77'), findsOneWidget);
      expect(find.text('Personal Information'), findsOneWidget);
    });

    testWidgets('renders fallback values when profile data is unavailable', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});

      final provider = AuthProvider(apiService: _FakeAuthApiClient());
      await provider.initializationFuture;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: _buildRouter()),
        ),
      );
      await tester.pumpAndSettle();
      await _openProfileTab(tester);

      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('4.98'), findsOneWidget);
    });

    testWidgets('keeps Personal Information menu navigation working', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'profile_full_name': 'Navi Test',
      });

      final provider = AuthProvider(apiService: _FakeAuthApiClient());
      await provider.initializationFuture;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: MaterialApp.router(routerConfig: _buildRouter()),
        ),
      );
      await tester.pumpAndSettle();
      await _openProfileTab(tester);

      await tester.tap(find.text('Personal Information'));
      await tester.pumpAndSettle();

      expect(find.text('Personal Info Screen'), findsOneWidget);
    });
  });
}
