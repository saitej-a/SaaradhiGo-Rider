import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthApiClient? apiService,
    Future<SharedPreferences> Function()? prefsFactory,
  }) : _apiService = apiService ?? ApiService(),
       _prefsFactory = prefsFactory ?? SharedPreferences.getInstance {
    _initializationFuture = _hydrateProfileFromPrefs();
  }

  static const String _fullNameKey = 'profile_full_name';
  static const String _avatarUrlKey = 'profile_avatar_url';
  static const String _ratingKey = 'profile_rating';
  static const String _emailKey = 'profile_email';
  static const String _genderKey = 'profile_gender';
  static const String _phoneNumberKey = 'profile_phone_number';
  static const String _countryCodeKey = 'profile_country_code';
  static const String _localAvatarPathKey = 'profile_local_avatar_path';
  static const String _twoFactorEnabledKey = 'privacy_two_factor_enabled';
  static const String _marketingOptInKey = 'privacy_marketing_opt_in';
  static const String _isUpdatedKey = 'profile_is_updated';
  static const String _dobKey = 'profile_dob';
  static const String _emergencyContactKey = 'profile_emergency_contact';
  static const String _houseNoKey = 'profile_house_no';
  static const String _streetKey = 'profile_street';
  static const String _cityKey = 'profile_city';
  static const String _zipCodeKey = 'profile_zip_code';

  final AuthApiClient _apiService;
  final Future<SharedPreferences> Function() _prefsFactory;

  late final Future<void> _initializationFuture;
  Future<void> get initializationFuture => _initializationFuture;

  bool _isLoading = false;
  String? _error;
  String? _fullName;
  String? _avatarUrl;
  String? _rating;
  String? _email;
  String? _gender;
  String? _phoneNumber;
  String? _countryCode;
  String? _localAvatarPath;
  bool _twoFactorEnabled = true;
  bool _marketingOptIn = false;
  bool _isUpdated = false;
  String? _dob;
  String? _emergencyContact;
  String? _houseNo;
  String? _street;
  String? _city;
  String? _zipCode;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get fullName => _fullName;
  String? get avatarUrl => _avatarUrl;
  String? get rating => _rating;
  String? get email => _email;
  String? get gender => _gender;
  String? get phoneNumber => _phoneNumber;
  String? get countryCode => _countryCode;
  String? get localAvatarPath => _localAvatarPath;
  bool get twoFactorEnabled => _twoFactorEnabled;
  bool get marketingOptIn => _marketingOptIn;
  bool get isUpdated => _isUpdated;

  String? get dob => _dob;
  String? get emergencyContact => _emergencyContact;
  String? get houseNo => _houseNo;
  String? get street => _street;
  String? get city => _city;
  String? get zipCode => _zipCode;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  String? _normalizedString(dynamic rawValue) {
    if (rawValue == null) return null;
    final value = rawValue.toString().trim();
    return value.isEmpty ? null : value;
  }

  String? _normalizedRating(dynamic rawValue) {
    final text = _normalizedString(rawValue);
    if (text == null) return null;
    final parsed = double.tryParse(text);
    if (parsed == null) return text;
    return parsed.toStringAsFixed(2);
  }

  String? _normalizedCountryCode(dynamic rawValue) {
    final text = _normalizedString(rawValue);
    if (text == null) return null;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty || digits.length > 3) return null;
    return '+$digits';
  }

  String? _normalizedPhoneNumber(dynamic rawValue) {
    final text = _normalizedString(rawValue);
    if (text == null) return null;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : digits;
  }

  bool _setPhoneFields({String? countryCode, String? phoneNumber}) {
    String? normalizedCountryCode = _normalizedCountryCode(countryCode);
    String? normalizedPhoneNumber = _normalizedPhoneNumber(phoneNumber);

    final rawCountryDigits = _normalizedString(
      countryCode,
    )?.replaceAll(RegExp(r'[^0-9]'), '');
    if (rawCountryDigits != null &&
        rawCountryDigits.length > 3 &&
        normalizedPhoneNumber != null) {
      final assumedCountryDigits = rawCountryDigits.startsWith('91')
          ? '91'
          : rawCountryDigits.substring(0, 3);
      final spillDigits = rawCountryDigits.substring(
        assumedCountryDigits.length,
      );
      normalizedCountryCode = _normalizedCountryCode(assumedCountryDigits);
      normalizedPhoneNumber = _normalizedPhoneNumber(
        '$spillDigits$normalizedPhoneNumber',
      );
    }

    if (_countryCode == normalizedCountryCode &&
        _phoneNumber == normalizedPhoneNumber) {
      return false;
    }

    _countryCode = normalizedCountryCode;
    _phoneNumber = normalizedPhoneNumber;
    return true;
  }

  bool _capturePhoneFromRawValue(
    String? rawPhone, {
    String? explicitCountryCode,
    String? fallbackCountryCode,
  }) {
    final phoneText = _normalizedString(rawPhone);
    final payloadCountryCode = _normalizedCountryCode(explicitCountryCode);
    final fallbackCode = _normalizedCountryCode(fallbackCountryCode);

    if (phoneText == null && payloadCountryCode == null) {
      return false;
    }

    if (phoneText != null) {
      final compactPhone = phoneText.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final preferredCountryCodes = <String>[];
      if (payloadCountryCode != null) {
        preferredCountryCodes.add(payloadCountryCode);
      }
      if (fallbackCode != null &&
          !preferredCountryCodes.contains(fallbackCode)) {
        preferredCountryCodes.add(fallbackCode);
      }
      if (_countryCode != null &&
          !preferredCountryCodes.contains(_countryCode)) {
        preferredCountryCodes.add(_countryCode!);
      }

      for (final code in preferredCountryCodes) {
        if (!compactPhone.startsWith(code)) continue;
        final numberWithoutCode = _normalizedPhoneNumber(
          compactPhone.substring(code.length),
        );
        if (numberWithoutCode == null) continue;
        return _setPhoneFields(
          countryCode: code,
          phoneNumber: numberWithoutCode,
        );
      }

      if (compactPhone.startsWith('+')) {
        final digitsAfterPlus = _normalizedPhoneNumber(compactPhone);
        if (digitsAfterPlus != null && digitsAfterPlus.length > 10) {
          final splitIndex = digitsAfterPlus.length - 10;
          final codeDigits = digitsAfterPlus.substring(0, splitIndex);
          final localDigits = digitsAfterPlus.substring(splitIndex);
          if (codeDigits.isNotEmpty && codeDigits.length <= 3) {
            return _setPhoneFields(
              countryCode: '+$codeDigits',
              phoneNumber: localDigits,
            );
          }
        }
      }

      final digitsOnly = _normalizedPhoneNumber(compactPhone);
      if (digitsOnly != null) {
        final localNumber = digitsOnly.length > 10
            ? digitsOnly.substring(digitsOnly.length - 10)
            : digitsOnly;
        return _setPhoneFields(
          countryCode: payloadCountryCode ?? fallbackCode ?? _countryCode,
          phoneNumber: localNumber,
        );
      }
    }

    if (payloadCountryCode != null) {
      return _setPhoneFields(
        countryCode: payloadCountryCode,
        phoneNumber: _phoneNumber,
      );
    }

    return false;
  }

  String? _pickFirstString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = _normalizedString(source[key]);
      if (value != null) return value;
    }
    return null;
  }

  String? _pickFirstRating(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = _normalizedRating(source[key]);
      if (value != null) return value;
    }
    return null;
  }

  Future<void> _hydrateProfileFromPrefs() async {
    final prefs = await _prefsFactory();
    _fullName = _normalizedString(prefs.getString(_fullNameKey));
    _avatarUrl = _normalizedString(prefs.getString(_avatarUrlKey));
    _rating = _normalizedRating(prefs.getString(_ratingKey));
    _email = _normalizedString(prefs.getString(_emailKey));
    _gender = _normalizedString(prefs.getString(_genderKey));
    final persistedPhoneRaw = prefs.getString(_phoneNumberKey);
    final persistedCountryRaw = prefs.getString(_countryCodeKey);
    final persistedPhone = _normalizedPhoneNumber(persistedPhoneRaw);
    final persistedCountry = _normalizedCountryCode(persistedCountryRaw);
    _setPhoneFields(
      countryCode: persistedCountryRaw,
      phoneNumber: persistedPhoneRaw,
    );
    _localAvatarPath = _normalizedString(prefs.getString(_localAvatarPathKey));
    _twoFactorEnabled = prefs.getBool(_twoFactorEnabledKey) ?? true;
    _marketingOptIn = prefs.getBool(_marketingOptInKey) ?? false;
    _isUpdated = prefs.getBool(_isUpdatedKey) ?? false;
    _dob = _normalizedString(prefs.getString(_dobKey));
    _emergencyContact = _normalizedString(prefs.getString(_emergencyContactKey));
    _houseNo = _normalizedString(prefs.getString(_houseNoKey));
    _street = _normalizedString(prefs.getString(_streetKey));
    _city = _normalizedString(prefs.getString(_cityKey));
    _zipCode = _normalizedString(prefs.getString(_zipCodeKey));
    if (_phoneNumber != persistedPhone || _countryCode != persistedCountry) {
      await _persistProfileToPrefs();
    }
    notifyListeners();
  }

  Future<void> _persistProfileToPrefs() async {
    final prefs = await _prefsFactory();

    if (_fullName == null) {
      await prefs.remove(_fullNameKey);
    } else {
      await prefs.setString(_fullNameKey, _fullName!);
    }

    if (_avatarUrl == null) {
      await prefs.remove(_avatarUrlKey);
    } else {
      await prefs.setString(_avatarUrlKey, _avatarUrl!);
    }

    if (_rating == null) {
      await prefs.remove(_ratingKey);
    } else {
      await prefs.setString(_ratingKey, _rating!);
    }

    if (_email == null) {
      await prefs.remove(_emailKey);
    } else {
      await prefs.setString(_emailKey, _email!);
    }

    if (_gender == null) {
      await prefs.remove(_genderKey);
    } else {
      await prefs.setString(_genderKey, _gender!);
    }

    if (_phoneNumber == null) {
      await prefs.remove(_phoneNumberKey);
    } else {
      await prefs.setString(_phoneNumberKey, _phoneNumber!);
    }

    if (_countryCode == null) {
      await prefs.remove(_countryCodeKey);
    } else {
      await prefs.setString(_countryCodeKey, _countryCode!);
    }

    if (_localAvatarPath == null) {
      await prefs.remove(_localAvatarPathKey);
    } else {
      await prefs.setString(_localAvatarPathKey, _localAvatarPath!);
    }

    await prefs.setBool(_twoFactorEnabledKey, _twoFactorEnabled);
    await prefs.setBool(_marketingOptInKey, _marketingOptIn);
    await prefs.setBool(_isUpdatedKey, _isUpdated);

    if (_dob == null) await prefs.remove(_dobKey); else await prefs.setString(_dobKey, _dob!);
    if (_emergencyContact == null) await prefs.remove(_emergencyContactKey); else await prefs.setString(_emergencyContactKey, _emergencyContact!);
    if (_houseNo == null) await prefs.remove(_houseNoKey); else await prefs.setString(_houseNoKey, _houseNo!);
    if (_street == null) await prefs.remove(_streetKey); else await prefs.setString(_streetKey, _street!);
    if (_city == null) await prefs.remove(_cityKey); else await prefs.setString(_cityKey, _city!);
    if (_zipCode == null) await prefs.remove(_zipCodeKey); else await prefs.setString(_zipCodeKey, _zipCode!);
  }

  Future<void> _clearProfilePrefs() async {
    final prefs = await _prefsFactory();
    await prefs.remove(_fullNameKey);
    await prefs.remove(_avatarUrlKey);
    await prefs.remove(_ratingKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_genderKey);
    await prefs.remove(_phoneNumberKey);
    await prefs.remove(_countryCodeKey);
    await prefs.remove(_localAvatarPathKey);
    await prefs.remove(_twoFactorEnabledKey);
    await prefs.remove(_marketingOptInKey);
    await prefs.remove(_isUpdatedKey);
    await prefs.remove(_dobKey);
    await prefs.remove(_emergencyContactKey);
    await prefs.remove(_houseNoKey);
    await prefs.remove(_streetKey);
    await prefs.remove(_cityKey);
    await prefs.remove(_zipCodeKey);
  }

  Map<String, dynamic>? _extractUserPayload(Map<String, dynamic>? payload) {
    if (payload == null) return null;

    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      final user = data['user'];
      if (user is Map<String, dynamic>) {
        return user;
      }
      return data;
    }

    final user = payload['user'];
    if (user is Map<String, dynamic>) {
      return user;
    }

    return null;
  }

  bool _applyProfileFromUserPayload(Map<String, dynamic>? userPayload) {
    if (userPayload == null) return false;

    final previousFullName = _fullName;
    final previousAvatarUrl = _avatarUrl;
    final previousRating = _rating;
    final previousEmail = _email;
    final previousGender = _gender;
    final previousPhoneNumber = _phoneNumber;
    final previousCountryCode = _countryCode;
    final previousIsUpdated = _isUpdated;
    final previousDob = _dob;
    final previousEmergencyContact = _emergencyContact;
    final previousHouseNo = _houseNo;
    final previousStreet = _street;
    final previousCity = _city;
    final previousZipCode = _zipCode;

    _fullName =
        _pickFirstString(userPayload, ['full_name', 'fullName', 'name']) ??
        _fullName;

    _avatarUrl =
        _pickFirstString(userPayload, [
          'avatar_url',
          'avatar',
          'profile_picture',
          'profile_image',
          'image',
          'photo_url',
        ]) ??
        _avatarUrl;

    _rating =
        _pickFirstRating(userPayload, [
          'rating',
          'avg_rating',
          'average_rating',
          'rider_rating',
        ]) ??
        _rating;

    _email =
        _pickFirstString(userPayload, ['email', 'email_address']) ?? _email;

    _gender = _pickFirstString(userPayload, ['gender', 'sex']) ?? _gender;

    final payloadCountryCode = _pickFirstString(userPayload, [
      'country_code',
      'countryCode',
      'dial_code',
    ]);
    final payloadPhone = _pickFirstString(userPayload, [
      'phone_number',
      'phone',
      'mobile',
      'mobile_number',
      'contact_number',
    ]);
    if (payloadCountryCode != null || payloadPhone != null) {
      _capturePhoneFromRawValue(
        payloadPhone,
        explicitCountryCode: payloadCountryCode,
        fallbackCountryCode: _countryCode ?? '+91',
      );
    }
    
    _isUpdated = userPayload['is_updated'] ?? userPayload['isUpdated'] ?? _isUpdated;

    _dob = _pickFirstString(userPayload, ['dob', 'date_of_birth', 'birth_date']) ?? _dob;
    _emergencyContact = _pickFirstString(userPayload, ['emergency_contact', 'emergency_phone']) ?? _emergencyContact;
    _houseNo = _pickFirstString(userPayload, ['house_no', 'house_number', 'apartment']) ?? _houseNo;
    _street = _pickFirstString(userPayload, ['street', 'street_name', 'address_line1']) ?? _street;
    _city = _pickFirstString(userPayload, ['city', 'town']) ?? _city;
    _zipCode = _pickFirstString(userPayload, ['zip_code', 'zipcode', 'postcode', 'postal_code']) ?? _zipCode;

    return previousFullName != _fullName ||
        previousAvatarUrl != _avatarUrl ||
        previousRating != _rating ||
        previousEmail != _email ||
        previousGender != _gender ||
        previousPhoneNumber != _phoneNumber ||
        previousCountryCode != _countryCode ||
        previousIsUpdated != _isUpdated ||
        previousDob != _dob ||
        previousEmergencyContact != _emergencyContact ||
        previousHouseNo != _houseNo ||
        previousStreet != _street ||
        previousCity != _city ||
        previousZipCode != _zipCode;
  }

  Future<void> savePersonalInformation({
    String? fullName,
    String? email,
    String? gender,
    String? phoneNumber,
    String? countryCode,
    String? localAvatarPath,
    String? dob,
    String? emergencyContact,
    String? houseNo,
    String? street,
    String? city,
    String? zipCode,
  }) async {
    final previousFullName = _fullName;
    final previousEmail = _email;
    final previousGender = _gender;
    final previousPhoneNumber = _phoneNumber;
    final previousCountryCode = _countryCode;
    final previousLocalAvatarPath = _localAvatarPath;
    final previousDob = _dob;
    final previousEmergencyContact = _emergencyContact;
    final previousHouseNo = _houseNo;
    final previousStreet = _street;
    final previousCity = _city;
    final previousZipCode = _zipCode;

    _fullName = _normalizedString(fullName);
    _email = _normalizedString(email);
    _gender = _normalizedString(gender);
    if (countryCode != null && phoneNumber != null) {
      _setPhoneFields(countryCode: countryCode, phoneNumber: phoneNumber);
    }
    _localAvatarPath = _normalizedString(localAvatarPath);
    _dob = _normalizedString(dob);
    _emergencyContact = _normalizedString(emergencyContact);
    _houseNo = _normalizedString(houseNo);
    _street = _normalizedString(street);
    _city = _normalizedString(city);
    _zipCode = _normalizedString(zipCode);

    final hasChanged =
        previousFullName != _fullName ||
        previousEmail != _email ||
        previousGender != _gender ||
        previousPhoneNumber != _phoneNumber ||
        previousCountryCode != _countryCode ||
        previousLocalAvatarPath != _localAvatarPath ||
        previousDob != _dob ||
        previousEmergencyContact != _emergencyContact ||
        previousHouseNo != _houseNo ||
        previousStreet != _street ||
        previousCity != _city ||
        previousZipCode != _zipCode;

    if (!hasChanged) return;
    await _persistProfileToPrefs();
    notifyListeners();
  }

  Future<void> setLocalAvatarPath(String? localPath) async {
    final normalizedLocalPath = _normalizedString(localPath);
    if (_localAvatarPath == normalizedLocalPath) return;
    _localAvatarPath = normalizedLocalPath;
    await _persistProfileToPrefs();
    notifyListeners();
  }

  Future<void> savePrivacySettings({
    required bool twoFactorEnabled,
    required bool marketingOptIn,
  }) async {
    final hasChanged =
        _twoFactorEnabled != twoFactorEnabled ||
        _marketingOptIn != marketingOptIn;
    if (!hasChanged) return;

    _twoFactorEnabled = twoFactorEnabled;
    _marketingOptIn = marketingOptIn;
    await _persistProfileToPrefs();
    notifyListeners();
  }

  Future<void> setTwoFactorEnabled(bool value) async {
    await savePrivacySettings(
      twoFactorEnabled: value,
      marketingOptIn: _marketingOptIn,
    );
  }

  Future<void> setMarketingOptIn(bool value) async {
    await savePrivacySettings(
      twoFactorEnabled: _twoFactorEnabled,
      marketingOptIn: value,
    );
  }

  bool _applyRequestProfileFallback(Map<String, dynamic> profileData) {
    final previousFullName = _fullName;
    final previousEmail = _email;
    final previousGender = _gender;

    final requestFullName = _normalizedString(profileData['full_name']);
    final requestEmail = _normalizedString(profileData['email']);
    final requestGender = _normalizedString(profileData['gender']);

    if (requestFullName != null) _fullName = requestFullName;
    if (requestEmail != null) _email = requestEmail;
    if (requestGender != null) _gender = requestGender;

    return previousFullName != _fullName ||
        previousEmail != _email ||
        previousGender != _gender;
  }

  bool _capturePhoneFromProfileRequest(Map<String, dynamic> profileData) {
    final hasPhoneData =
        profileData.containsKey('phone_number') ||
        profileData.containsKey('country_code');
    if (!hasPhoneData) return false;

    return _capturePhoneFromRawValue(
      profileData['phone_number']?.toString(),
      explicitCountryCode: profileData['country_code']?.toString(),
      fallbackCountryCode: _countryCode ?? '+91',
    );
  }

  Future<void> _persistIfNeeded(List<bool> changedFlags) async {
    if (changedFlags.any((flag) => flag)) {
      await _persistProfileToPrefs();
    }
  }

  Future<void> _handleSuccessfulProfileSync({
    required Map<String, dynamic>? response,
    required Map<String, dynamic> requestData,
  }) async {
    final profileUpdated = _applyProfileFromUserPayload(
      _extractUserPayload(response),
    );
    final requestFallbackUpdated = _applyRequestProfileFallback(requestData);
    final requestPhoneUpdated = _capturePhoneFromProfileRequest(requestData);
    await _persistIfNeeded([
      profileUpdated,
      requestFallbackUpdated,
      requestPhoneUpdated,
    ]);
  }

  Future<void> _handleSuccessfulOtpSync({
    required Map<String, dynamic>? response,
    required String phone,
  }) async {
    final profileUpdated = _applyProfileFromUserPayload(
      _extractUserPayload(response),
    );
    final phoneUpdated = _capturePhoneFromRawValue(
      phone,
      fallbackCountryCode: '+91',
    );
    await _persistIfNeeded([profileUpdated, phoneUpdated]);
  }

  Future<Map<String, dynamic>?> requestOtp(String phone) async {
    _setLoading(true);
    _setError(null);
    final response = await _apiService.requestOtp(phone, 'rider');
    if (response == null) {
      _setError('Failed to request OTP. Please check your number.');
    }
    _setLoading(false);
    return response;
  }

  Future<bool> verifyOtp(String phone, String otp, String deviceToken) async {
    _setLoading(true);
    _setError(null);
    final response = await _apiService.verifyOtpAndLogin(
      phone,
      otp,
      deviceToken,
    );

    if (response == null) {
      _setError('Invalid OTP. Please try again.');
      _setLoading(false);
      return false;
    }

    await _handleSuccessfulOtpSync(response: response, phone: phone);

    _setLoading(false);
    return true;
  }

  Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    _setLoading(true);
    _setError(null);
    final response = await _apiService.updateProfile(
      fullName: profileData['full_name'] ?? '',
      email: profileData['email'] ?? '',
      gender: profileData['gender'] ?? '',
      dob: profileData['dob'] ?? '',
      emergencyContact: profileData['emergency_contact'] ?? '',
      houseNo: profileData['house_no'] ?? '',
      street: profileData['street'] ?? '',
      city: profileData['city'] ?? '',
      zipCode: profileData['zip_code'] ?? '',
    );

    if (response == null) {
      _setError('Failed to update profile.');
      _setLoading(false);
      return false;
    }

    await _handleSuccessfulProfileSync(
      response: response,
      requestData: profileData,
    );

    _setLoading(false);
    return true;
  }

  Future<bool> fetchProfile() async {
    _setLoading(true);
    _setError(null);
    final response = await _apiService.getProfile();

    if (response == null) {
      _setError('Failed to fetch profile.');
      _setLoading(false);
      return false;
    }

    final profileUpdated = _applyProfileFromUserPayload(
      _extractUserPayload(response),
    );
    if (profileUpdated) {
      await _persistProfileToPrefs();
    }

    _setLoading(false);
    return true;
  }

  Future<void> logout() async {
    _setLoading(true);
    _setError(null);

    try {
      await _apiService.clearSession();
      _fullName = null;
      _avatarUrl = null;
      _rating = null;
      _email = null;
      _gender = null;
      _phoneNumber = null;
      _countryCode = null;
      _localAvatarPath = null;
      _dob = null;
      _emergencyContact = null;
      _houseNo = null;
      _street = null;
      _city = null;
      _zipCode = null;
      _twoFactorEnabled = true;
      _marketingOptIn = false;
      await _clearProfilePrefs();
    } catch (_) {
      _setError('Failed to clear session.');
    }

    _setLoading(false);
  }
}
