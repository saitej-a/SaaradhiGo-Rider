import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ride_state.dart';

final ridePersistenceProvider = Provider<RidePersistence>((ref) => RidePersistence());

class RidePersistence {
  static const _rideStateKey = 'riverpod_ride_state';

  Future<void> saveRideState(RideState state) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (state.status == RideStatus.none || 
        state.status == RideStatus.cancelled || 
        state.status == RideStatus.rideCompleted ||
        state.status == RideStatus.rated) {
      await prefs.remove(_rideStateKey);
      return;
    }
    
    final jsonStr = jsonEncode(state.toJson());
    await prefs.setString(_rideStateKey, jsonStr);
  }

  Future<RideState?> loadRideState() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_rideStateKey);
    if (jsonStr != null) {
      try {
        final Map<String, dynamic> json = jsonDecode(jsonStr);
        return RideState.fromJson(json);
      } catch (e) {
        // Corrupted JSON
      }
    }
    return null;
  }
}
