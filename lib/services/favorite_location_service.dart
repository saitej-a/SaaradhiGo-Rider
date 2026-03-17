import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_config.dart';
import 'models/location_model.dart';

class FavoriteLocationService {
  Future<List<FavoriteLocation>> fetchFavoriteLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    final url = Uri.parse('${AppConfig.baseUrl}/rider/locations/all/');
    
    try {
      final response = await http.get(
        url, 
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'SaaradhiGo/1.0',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final List locations = data['data'];
          return locations.map((json) => FavoriteLocation.fromJson(json)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching favorite locations: $e');
    }
    return [];
  }

  Future<bool> saveFavoriteLocation(String address, double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    final url = Uri.parse('${AppConfig.baseUrl}/rider/locations/');
    
    try {
      final response = await http.post(
        url, 
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'SaaradhiGo/1.0',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'address_text': address,
          'latitude': lat.toString(),
          'longitude': lng.toString(),
        }),
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('Error saving favorite location: $e');
    }
    return false;
  }

  Future<bool> deleteFavoriteLocation(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    final url = Uri.parse('${AppConfig.baseUrl}/rider/locations/$id/delete/');
    
    try {
      final response = await http.delete(
        url, 
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'SaaradhiGo/1.0',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 204 || response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting favorite location: $e');
    }
    return false;
  }
}
