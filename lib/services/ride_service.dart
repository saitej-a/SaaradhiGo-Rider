import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import 'models/trip_model.dart';
import '../core/app_config.dart';

class RideService {
  WebSocketChannel? _rideRequestChannel;
  WebSocketChannel? _tripChannel;
  
  Stream<dynamic>? get rideUpdates => _rideRequestChannel?.stream;
  Stream<dynamic>? get tripUpdates => _tripChannel?.stream;

  Future<List<Trip>> fetchRideHistory(String token) async {
    String url = '${AppConfig.baseUrl}${AppConfig.rideHistory}';
    
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        
        // Handle both wrapped and unwrapped paginated responses
        List<dynamic>? results;
        if (data is Map<String, dynamic>) {
          if (data['results'] != null) {
            results = data['results'];
          } else if (data['status'] == 'success' && data['data'] != null && data['data']['results'] != null) {
            results = data['data']['results'];
          }
        }
        
        if (results != null) {
          return results.map((json) => Trip.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Fetch Ride History error: $e');
      return [];
    }
  }

  Future<void> requestRide({
    required String token,
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
    required double distanceKm,
    required int durationMin,
    required String vehicleType,
    required String pickupAddress,
    required String destinationAddress,
    required String paymentMethod,
  }) async {
    final wsUrl = '${AppConfig.rideRequestWs}?token=$token';
    
    try {
      debugPrint('Connecting to Ride Request WebSocket...');
      // Close existing connection if any
      _rideRequestChannel?.sink.close();
      _rideRequestChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      final requestPayload = {
        'type': 'ride_request',
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'destination_lat': destinationLat,
        'destination_lng': destinationLng,
        'pickup_address': pickupAddress,
        'destination_address': destinationAddress,
        'distance_km': distanceKm,
        'duration_min': durationMin,
        'vehicle_type': vehicleType,
        'payment_method': paymentMethod,
      };

      _rideRequestChannel!.sink.add(jsonEncode(requestPayload));
      debugPrint('Ride request sent');
    } catch (e) {
      debugPrint('Ride Request WebSocket error: $e');
      rethrow;
    }
  }

  Future<void> connectToTrip(String token, int tripId) async {
    final wsUrl = '${AppConfig.tripWs(tripId)}?token=$token';
    
    try {
      debugPrint('Connecting to Trip WebSocket: $tripId');
      // Close existing connection if any
      _tripChannel?.sink.close();
      _tripChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
    } catch (e) {
      debugPrint('Trip WebSocket error: $e');
      rethrow;
    }
  }

  void closeConnection() {
    _rideRequestChannel?.sink.close();
    _tripChannel?.sink.close();
    _rideRequestChannel = null;
    _tripChannel = null;
    debugPrint('All WebSocket connections closed');
  }

  Future<Map<String, dynamic>?> createTripPaymentOrder(String token, int tripId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/payments/create-order/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'trip_id': tripId,
        }),
      );
      print(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      
      try {
        final errorData = jsonDecode(response.body);
        debugPrint('Create Trip Payment Order API Error: ${response.statusCode} - $errorData');
        return errorData; // Return error data so UI can show message
      } catch (_) {
        debugPrint('Create Trip Payment Order Error: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      debugPrint('Create Trip Payment Order error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> verifyTripPayment(
    String token,
    String orderId,
    String paymentId,
    String signature,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/payments/verify/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'razorpay_order_id': orderId,
          'razorpay_payment_id': paymentId,
          'razorpay_signature': signature,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Verify Trip Payment error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getTripStatus(String token, String tripId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/ride/trip/$tripId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Get Trip Status error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getTripDetails(String token, String tripId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/ride/trip/$tripId/details/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Get Trip Details error: $e');
      return null;
    }
  }
}
