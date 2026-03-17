import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ride_service.dart';
import '../services/models/trip_model.dart';

class HistoryProvider extends ChangeNotifier {
  final RideService _rideService = RideService();
  
  List<Trip> _trips = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Trip> get trips => _trips;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchHistory() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token == null) {
        _errorMessage = 'Authentication token not found. Please log in again.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final fetchedTrips = await _rideService.fetchRideHistory(token);
      _trips = fetchedTrips;
    } catch (e) {
      _errorMessage = 'Failed to load ride history. Please try again later.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearHistory() {
    _trips = [];
    notifyListeners();
  }
}
