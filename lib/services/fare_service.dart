import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_config.dart';

class FareService {
  Future<Map<String, dynamic>?> estimateFare({
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
    required double distanceKm,
    required int durationMin,
    required String vehicleType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final url = Uri.parse('${AppConfig.baseUrl}/ride/estimate-fare/');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'SaaradhiGo/1.0',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'pickup_lat': pickupLat,
          'pickup_long': pickupLng,
          'destination_lat': destinationLat,
          'destination_long': destinationLng,
          'distance_km': distanceKm,
          'duration_min': durationMin,
          'vehicle_type': vehicleType,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data['data'];
        }
      }
    } catch (e) {
      debugPrint('Error estimating fare: $e');
    }
    return null;
  }
}
