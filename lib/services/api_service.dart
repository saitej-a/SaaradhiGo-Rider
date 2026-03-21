import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../core/app_config.dart';
import 'package:image_picker/image_picker.dart';

abstract class AuthApiClient {
  Future<Map<String, dynamic>?> requestOtp(String phoneNumber, String role);
  Future<Map<String, dynamic>?> verifyOtpAndLogin(
    String phoneNumber,
    String otp,
    String deviceToken,
  );
  Future<Map<String, dynamic>?> updateProfile({
    String? profilePicPath,
    required String fullName,
    required String email,
    required String gender,
    required String dob,
    required String emergencyContact,
    required String houseNo,
    required String street,
    required String city,
    required String zipCode,
  });
  Future<Map<String, dynamic>?> getProfile();
  Future<void> clearSession();
}

class ApiService implements AuthApiClient {
  static const String baseUrl = AppConfig.baseUrl;

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _accessToken;

  Future<void> _loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
  }

  Future<void> _saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
    _accessToken = access;
  }

  // Request OTP
  @override
  Future<Map<String, dynamic>?> requestOtp(
      String phoneNumber, String role) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl${AppConfig.authOtp}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phoneNumber, 'role': role}),
      );

      debugPrint('OTP Request Status: ${response.statusCode}');
      debugPrint('OTP Request Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == "success") {
          return data;
        }
      }
      return null;
    } catch (e) {
      debugPrint('OTP Request Exception: $e');
      return null;
    }
  }

  // Verify OTP & Login
  @override
  Future<Map<String, dynamic>?> verifyOtpAndLogin(
    String phoneNumber,
    String otp,
    String deviceToken,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl${AppConfig.authLogin}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phoneNumber,
          'otp': otp,
          'device_token': deviceToken,
        }),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['status'] != 'success') {
        return null;
      }

      final sessionData = decoded['data'];
      if (sessionData is Map<String, dynamic>) {
        final accessToken = sessionData['token'];
        final refreshToken = sessionData['refresh_token'];
        if (accessToken is String && refreshToken is String) {
          await _saveTokens(accessToken, refreshToken);
        }
      }

      return decoded;
    } catch (e) {
      debugPrint('OTP Verify Error: $e');
      return null;
    }
  }

  // Update Profile
  @override
  Future<Map<String, dynamic>?> updateProfile({
    String? profilePicPath,
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
    if (_accessToken == null) await _loadTokens();

    try {
      final uri = Uri.parse('$baseUrl${AppConfig.authUpdate}');
      
      http.Response response;

      if (profilePicPath != null && profilePicPath.isNotEmpty) {
        var request = http.MultipartRequest('PATCH', uri);
        request.headers['Authorization'] = 'Bearer $_accessToken';
        
        request.fields['is_updated'] = 'true';
        request.fields['full_name'] = fullName;
        request.fields['email'] = email;
        request.fields['gender'] = gender;
        request.fields['dob'] = dob;
        request.fields['emergency_contact'] = emergencyContact;
        request.fields['house_no'] = houseNo;
        request.fields['street'] = street;
        request.fields['city'] = city;
        request.fields['zip_code'] = zipCode;
        
        final xFile = XFile(profilePicPath);
        final bytes = await xFile.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename: xFile.name.isNotEmpty ? xFile.name : 'avatar.jpg',
        ));

        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        response = await http.patch(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_accessToken',
          },
          body: jsonEncode({
            'is_updated': true,
            'full_name': fullName,
            'email': email,
            'gender': gender,
            'dob': dob,
            'emergency_contact': emergencyContact,
            'house_no': houseNo,
            'street': street,
            'city': city,
            'zip_code': zipCode,
          }),
        );
      }

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('Profile Update Error: $e');
      return null;
    }
  }

  // Get Profile
  @override
  Future<Map<String, dynamic>?> getProfile() async {
    if (_accessToken == null) await _loadTokens();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl${AppConfig.authProfile}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('Get Profile Error: $e');
      return null;
    }
  }

  @override
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    _accessToken = null;
  }
}
