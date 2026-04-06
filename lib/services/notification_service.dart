import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/notification_model.dart';
import '../core/app_config.dart';

class NotificationService {
  static String _baseUrl = AppConfig.baseUrl;

  Future<Map<String, dynamic>> fetchNotifications(String token, {int page = 1}) async {
    final String url = '$_baseUrl${AppConfig.riderNotifications}?page=$page';
    
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
        
        List<dynamic> results = [];
        bool hasNext = false;

        if (data is Map<String, dynamic>) {
          // Handle standard DRF pagination
          if (data['results'] != null) {
            results = data['results'];
            hasNext = data['next'] != null;
          } 
          // Handle custom wrapped response if it exists
          else if (data['status'] == 'success' && data['data'] != null) {
            final innerData = data['data'];
            if (innerData is Map<String, dynamic> && innerData['results'] != null) {
              results = innerData['results'];
              hasNext = innerData['next'] != null;
            }
          }
        } else if (data is List) {
          results = data;
          hasNext = false;
        }
        
        return {
          'notifications': results.map((json) => NotificationModel.fromJson(json)).toList(),
          'hasNext': hasNext,
        };
      }
      return {'notifications': <NotificationModel>[], 'hasNext': false};
    } catch (e) {
      debugPrint('Fetch Notifications error: $e');
      return {'notifications': <NotificationModel>[], 'hasNext': false};
    }
  }

  Future<bool> markAsRead(String token, int notificationId) async {
    final String url = '$_baseUrl/rider/notifications/$notificationId/read/';
    
    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Mark Notification as Read error: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead(String token) async {
    final String url = '$_baseUrl/rider/notifications/read-all/';
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Mark All Notifications as Read error: $e');
      return false;
    }
  }
}
