import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'https://dev.api.saaradhigo.in/api/v1';
  static String get wsBaseUrl => dotenv.env['WS_BASE_URL'] ?? 'wss://dev.api.saaradhigo.in/ws';

  // API Endpoints
  static const String authOtp = '/auth/otp/';
  static const String authLogin = '/auth/login/';
  static const String authUpdate = '/auth/update/';
  static const String authProfile = '/auth/profile/';
  
  static const String riderNotifications = '/rider/notifications/';
  static const String rideHistory = '/ride/ride-history/';

  // WebSocket Endpoints
  static String rideRequestWs = '$wsBaseUrl/ride/request/';
  static String tripWs(int tripId) => '$wsBaseUrl/ride/trip/$tripId/';

  // Google Maps (if needed centrally)
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
}
