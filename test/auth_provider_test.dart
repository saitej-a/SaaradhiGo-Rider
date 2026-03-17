import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vahango/providers/auth_provider.dart';
import 'package:vahango/services/api_service.dart';

class _FakeAuthApiClient implements AuthApiClient {
  Map<String, dynamic>? verifyOtpResponse;
  Map<String, dynamic>? updateProfileResponse;
  bool clearSessionCalled = false;

  @override
  Future<void> clearSession() async {
    clearSessionCalled = true;
  }

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
    return updateProfileResponse;
  }

  @override
  Future<Map<String, dynamic>?> verifyOtpAndLogin(
    String phoneNumber,
    String otp,
    String deviceToken,
  ) async {
    return verifyOtpResponse;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthProvider profile state', () {
    test('verifyOtp payload hydrates profile and persists values', () async {
      SharedPreferences.setMockInitialValues({});
      final fakeApi = _FakeAuthApiClient()
        ..verifyOtpResponse = {
          'status': 'success',
          'data': {
            'token': 'token-1',
            'refresh_token': 'refresh-1',
            'user': {
              'full_name': 'Alice Rider',
              'email': 'alice@example.com',
              'gender': 'female',
              'profile_picture': 'https://example.com/alice.png',
              'rating': 4.72,
            },
          },
        };

      final provider = AuthProvider(apiService: fakeApi);
      await provider.initializationFuture;

      final success = await provider.verifyOtp('+911234567890', '123456', 'dummy-token');

      expect(success, isTrue);
      expect(provider.fullName, 'Alice Rider');
      expect(provider.email, 'alice@example.com');
      expect(provider.gender, 'female');
      expect(provider.avatarUrl, 'https://example.com/alice.png');
      expect(provider.rating, '4.72');
      expect(provider.countryCode, '+91');
      expect(provider.phoneNumber, '1234567890');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('profile_full_name'), 'Alice Rider');
      expect(prefs.getString('profile_email'), 'alice@example.com');
      expect(prefs.getString('profile_gender'), 'female');
      expect(
        prefs.getString('profile_avatar_url'),
        'https://example.com/alice.png',
      );
      expect(prefs.getString('profile_rating'), '4.72');
      expect(prefs.getString('profile_country_code'), '+91');
      expect(prefs.getString('profile_phone_number'), '1234567890');
    });

    test(
      'updateProfile payload hydrates profile and normalizes rating',
      () async {
        SharedPreferences.setMockInitialValues({});
        final fakeApi = _FakeAuthApiClient()
          ..updateProfileResponse = {
            'status': 'success',
            'data': {
              'full_name': 'Bob Rider',
              'avatar_url': 'https://example.com/bob.png',
              'avg_rating': '4.5',
            },
          };

        final provider = AuthProvider(apiService: fakeApi);
        await provider.initializationFuture;

        final success = await provider.updateProfile({
          'full_name': 'Bob Rider',
          'email': 'bob@example.com',
          'gender': 'male',
          'dob': '',
          'emergency_contact': '',
          'house_no': '',
          'street': '',
          'city': '',
          'zip_code': '',
        });

        expect(success, isTrue);
        expect(provider.fullName, 'Bob Rider');
        expect(provider.email, 'bob@example.com');
        expect(provider.gender, 'male');
        expect(provider.avatarUrl, 'https://example.com/bob.png');
        expect(provider.rating, '4.50');
      },
    );

    test(
      'savePersonalInformation persists personal fields and local avatar path',
      () async {
        SharedPreferences.setMockInitialValues({});
        final provider = AuthProvider(apiService: _FakeAuthApiClient());
        await provider.initializationFuture;

        await provider.savePersonalInformation(
          fullName: 'Saved Name',
          email: 'saved@example.com',
          gender: 'Male',
          phoneNumber: '9876543210',
          countryCode: '+91',
          localAvatarPath: 'C:/temp/avatar.png',
        );

        expect(provider.fullName, 'Saved Name');
        expect(provider.email, 'saved@example.com');
        expect(provider.gender, 'Male');
        expect(provider.phoneNumber, '9876543210');
        expect(provider.countryCode, '+91');
        expect(provider.localAvatarPath, 'C:/temp/avatar.png');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('profile_full_name'), 'Saved Name');
        expect(prefs.getString('profile_email'), 'saved@example.com');
        expect(prefs.getString('profile_gender'), 'Male');
        expect(prefs.getString('profile_phone_number'), '9876543210');
        expect(prefs.getString('profile_country_code'), '+91');
        expect(
          prefs.getString('profile_local_avatar_path'),
          'C:/temp/avatar.png',
        );
        expect(prefs.getBool('privacy_two_factor_enabled'), isTrue);
        expect(prefs.getBool('privacy_marketing_opt_in'), isFalse);
      },
    );

    test('savePrivacySettings persists privacy toggles', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AuthProvider(apiService: _FakeAuthApiClient());
      await provider.initializationFuture;

      await provider.savePrivacySettings(
        twoFactorEnabled: false,
        marketingOptIn: true,
      );

      expect(provider.twoFactorEnabled, isFalse);
      expect(provider.marketingOptIn, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('privacy_two_factor_enabled'), isFalse);
      expect(prefs.getBool('privacy_marketing_opt_in'), isTrue);
    });

    test('cached profile values are hydrated from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'profile_full_name': 'Cached User',
        'profile_email': 'cached@example.com',
        'profile_gender': 'Other',
        'profile_phone_number': '9876501234',
        'profile_country_code': '+91',
        'profile_avatar_url': 'https://example.com/cached.png',
        'profile_local_avatar_path': 'C:/cached/avatar.jpg',
        'profile_rating': '4.20',
        'privacy_two_factor_enabled': false,
        'privacy_marketing_opt_in': true,
      });

      final provider = AuthProvider(apiService: _FakeAuthApiClient());
      await provider.initializationFuture;

      expect(provider.fullName, 'Cached User');
      expect(provider.email, 'cached@example.com');
      expect(provider.gender, 'Other');
      expect(provider.phoneNumber, '9876501234');
      expect(provider.countryCode, '+91');
      expect(provider.avatarUrl, 'https://example.com/cached.png');
      expect(provider.localAvatarPath, 'C:/cached/avatar.jpg');
      expect(provider.rating, '4.20');
      expect(provider.twoFactorEnabled, isFalse);
      expect(provider.marketingOptIn, isTrue);
    });

    test('privacy settings use expected defaults when not cached', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = AuthProvider(apiService: _FakeAuthApiClient());
      await provider.initializationFuture;

      expect(provider.twoFactorEnabled, isTrue);
      expect(provider.marketingOptIn, isFalse);
    });

    test('logout clears cached profile values and auth session', () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'abc',
        'refresh_token': 'xyz',
        'profile_full_name': 'To Be Cleared',
        'profile_email': 'clear@example.com',
        'profile_gender': 'Female',
        'profile_phone_number': '9999999999',
        'profile_country_code': '+91',
        'profile_avatar_url': 'https://example.com/clear.png',
        'profile_local_avatar_path': 'C:/clear/avatar.jpg',
        'profile_rating': '4.33',
        'privacy_two_factor_enabled': false,
        'privacy_marketing_opt_in': true,
      });
      final fakeApi = _FakeAuthApiClient();

      final provider = AuthProvider(apiService: fakeApi);
      await provider.initializationFuture;
      await provider.logout();

      expect(fakeApi.clearSessionCalled, isTrue);
      expect(provider.fullName, isNull);
      expect(provider.email, isNull);
      expect(provider.gender, isNull);
      expect(provider.phoneNumber, isNull);
      expect(provider.countryCode, isNull);
      expect(provider.avatarUrl, isNull);
      expect(provider.localAvatarPath, isNull);
      expect(provider.rating, isNull);
      expect(provider.twoFactorEnabled, isTrue);
      expect(provider.marketingOptIn, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('profile_full_name'), isNull);
      expect(prefs.getString('profile_email'), isNull);
      expect(prefs.getString('profile_gender'), isNull);
      expect(prefs.getString('profile_phone_number'), isNull);
      expect(prefs.getString('profile_country_code'), isNull);
      expect(prefs.getString('profile_avatar_url'), isNull);
      expect(prefs.getString('profile_local_avatar_path'), isNull);
      expect(prefs.getString('profile_rating'), isNull);
      expect(prefs.getBool('privacy_two_factor_enabled'), isNull);
      expect(prefs.getBool('privacy_marketing_opt_in'), isNull);
    });
  });
}
