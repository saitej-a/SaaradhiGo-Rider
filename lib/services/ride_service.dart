import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import 'models/trip_model.dart';
import 'api_service.dart';
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
}
