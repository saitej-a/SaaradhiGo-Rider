import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vahango/providers/auth_provider.dart';
import 'package:vahango/screens/profile/edit_personal_information_screen.dart';
import 'package:vahango/services/api_service.dart';

class _FakeAuthApiClient implements AuthApiClient {
  _FakeAuthApiClient({
    this.updateProfileResponse,
    this.updateProfileDelay = Duration.zero,
  });

  Map<String, dynamic>? updateProfileResponse;
  Duration updateProfileDelay;
  Map<String, dynamic>? lastUpdateProfileRequest;

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
    lastUpdateProfileRequest = {
      'full_name': fullName,
      'email': email,
      'gender': gender,
      'dob': dob,
      'emergency_contact': emergencyContact,
      'house_no': houseNo,
      'street': street,
      'city': city,
      'zip_code': zipCode,
    };
    if (updateProfileDelay > Duration.zero) {
      await Future<void>.delayed(updateProfileDelay);
    }
    return updateProfileResponse;
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

GoRouter _buildRouter({String initialLocation = '/personal-info'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/personal-info',
        builder: (context, state) => const EditPersonalInformationScreen(),
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

Future<AuthProvider> _buildProvider(
  _FakeAuthApiClient apiClient,
  Map<String, Object> prefsData,
) async {
  SharedPreferences.setMockInitialValues(prefsData);
  final provider = AuthProvider(apiService: apiClient);
  await provider.initializationFuture;
  return provider;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  AuthProvider provider, {
  String initialLocation = '/personal-info',
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

  group('EditPersonalInformationScreen redesign', () {
    testWidgets('renders fallback values and keeps phone read-only', (
      tester,
    ) async {
      final provider = await _buildProvider(_FakeAuthApiClient(), {});
      await _pumpScreen(tester, provider);

      expect(find.text('FULL NAME'), findsOneWidget);
      expect(find.text('EMAIL ADDRESS'), findsOneWidget);
      expect(find.text('PHONE NUMBER'), findsOneWidget);
      expect(find.text('GENDER'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('johndoe@example.com'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      expect(find.byKey(const Key('personal-phone-display')), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.byType(EditableText), findsNWidgets(2));
    });

    testWidgets('save triggers loading, calls API, and routes to profile tab', (
      tester,
    ) async {
      final apiClient = _FakeAuthApiClient(
        updateProfileDelay: const Duration(milliseconds: 200),
        updateProfileResponse: {
          'status': 'success',
          'data': {'full_name': 'John Doe'},
        },
      );
      final provider = await _buildProvider(apiClient, {});
      await _pumpScreen(tester, provider);

      await tester.tap(find.byKey(const Key('personal-save')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(apiClient.lastUpdateProfileRequest, isNotNull);
      expect(apiClient.lastUpdateProfileRequest!['full_name'], 'John Doe');
      expect(apiClient.lastUpdateProfileRequest!['email'], 'johndoe@example.com');
      expect(apiClient.lastUpdateProfileRequest!['gender'], 'male');
      expect(find.text('Home Tab 3'), findsOneWidget);
      expect(provider.phoneNumber, '9876543210');
      expect(provider.countryCode, '+91');
    });

    testWidgets('save failure shows error and stays on the same screen', (
      tester,
    ) async {
      final provider = await _buildProvider(_FakeAuthApiClient(), {});
      await _pumpScreen(tester, provider);

      await tester.tap(find.byKey(const Key('personal-save')));
      await tester.pumpAndSettle();

      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Failed to update profile.'), findsOneWidget);
      expect(find.text('Home Tab 3'), findsNothing);
    });

    testWidgets('bottom nav routes to /home?tab=0..3', (tester) async {
      final targets = <String, int>{
        'personal-nav-home': 0,
        'personal-nav-history': 1,
        'personal-nav-wallet': 2,
        'personal-nav-profile': 3,
      };

      for (final entry in targets.entries) {
        final provider = await _buildProvider(_FakeAuthApiClient(), {});
        await _pumpScreen(tester, provider);

        await tester.tap(find.byKey(Key(entry.key)));
        await tester.pumpAndSettle();

        expect(find.text('Home Tab ${entry.value}'), findsOneWidget);
      }
    });
  });
}
