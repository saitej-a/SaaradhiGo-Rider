import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../services/location_service.dart';
import '../services/fare_service.dart';
import '../services/driver_service.dart';
import '../services/favorite_location_service.dart';
import '../services/ride_service.dart';
import '../services/models/location_model.dart';
import '../services/models/trip_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ongoing_ride_notification_service.dart';

class MapProvider extends ChangeNotifier {
  final LocationService _locationService;
  final FareService _fareService;
  final DriverService _driverService;
  final FavoriteLocationService _favoriteLocationService;
  final RideService _rideService;
  
  String _sessionToken = '';

  MapProvider({
    LocationService? locationService,
    FareService? fareService,
    DriverService? driverService,
    FavoriteLocationService? favoriteLocationService,
    RideService? rideService,
  })  : _locationService = locationService ?? LocationService(),
        _fareService = fareService ?? FareService(),
        _driverService = driverService ?? DriverService(),
        _favoriteLocationService = favoriteLocationService ?? FavoriteLocationService(),
        _rideService = rideService ?? RideService();

  List<PlaceSuggestion> _suggestions = [];
  bool _isLoadingSuggestions = false;
  Timer? _debounceTimer;

  PlaceDetails? _pickupLocation;
  PlaceDetails? _dropLocation;
  String? _pickupAddress;
  String? _dropAddress;
  List<LatLng> _polylineCoordinates = [];
  String? _distance;
  String? _duration;
  Map<String, dynamic>? _bounds;
  bool _isLoadingRoute = false;
  
  List<Map<String, dynamic>> _nearbyDrivers = [];
  Map<String, Map<String, dynamic>> _fareEstimates = {};
  bool _isLoadingFares = false;
  String? _selectedVehicleType;
  bool _isRequestingRide = false;
  dynamic _rideRequestResponse;
  LatLng? _driverLocation;
  bool _isDriverArriving = false;
  String _selectedPaymentMethod = 'cash';

  // Stream Subscriptions to prevent leaks
  StreamSubscription? _rideUpdatesSubscription;
  StreamSubscription? _tripUpdatesSubscription;

  List<FavoriteLocation> _favoriteLocations = [];
  List<Trip> _recentLocations = [];
  bool _isLoadingHomeData = false;
  LatLng? _precisePickupLocation;

  List<FavoriteLocation> get favoriteLocations => _favoriteLocations;
  List<Trip> get recentLocations => _recentLocations;
  bool get isLoadingHomeData => _isLoadingHomeData;

  List<PlaceSuggestion> get suggestions => _suggestions;
  bool get isLoadingSuggestions => _isLoadingSuggestions;
  
  PlaceDetails? get pickupLocation => _pickupLocation;
  PlaceDetails? get dropLocation => _dropLocation;
  String? get pickupAddress => _pickupAddress;
  String? get destinationAddress => _dropAddress ?? _dropLocation?.name;
  List<LatLng> get polylineCoordinates => _polylineCoordinates;
  String? get distance => _distance;
  String? get duration => _duration;
  Map<String, dynamic>? get bounds => _bounds;
  bool get isLoadingRoute => _isLoadingRoute;
  
  List<Map<String, dynamic>> get nearbyDrivers => _nearbyDrivers;
  Map<String, Map<String, dynamic>> get fareEstimates => _fareEstimates;
  bool get isLoadingFares => _isLoadingFares;
  String? get selectedVehicleType => _selectedVehicleType;
  bool get isRequestingRide => _isRequestingRide;
  dynamic get rideRequestResponse => _rideRequestResponse;
  LatLng? get driverLocation => _driverLocation;
  bool get isDriverArriving => _isDriverArriving;
  String get selectedPaymentMethod => _selectedPaymentMethod;
  LatLng? get precisePickupLocation => _precisePickupLocation;

  bool get isTripInProgress {
    if (_isRequestingRide) return true;
    if (_rideRequestResponse != null) {
      final status = _rideRequestResponse['status'];
      return status == 'accept' || status == 'start' || status == 'active';
    }
    return false;
  }

  Future<void> _persistRideState({
    required String status,
    String? tripId,
    Map<String, dynamic>? rideDetails,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_ride_status', status);
    if (tripId != null) {
      await prefs.setString('active_trip_id', tripId);
    } else {
      await prefs.remove('active_trip_id');
    }
    
    if (_driverLocation != null) {
      await prefs.setDouble('active_driver_lat', _driverLocation!.latitude);
      await prefs.setDouble('active_driver_lng', _driverLocation!.longitude);
    }

    if (rideDetails != null) {
      // Merge with existing details if possible
      final existingStr = prefs.getString('active_ride_details');
      Map<String, dynamic>? merged = rideDetails;
      if (existingStr != null) {
        try {
          final existing = jsonDecode(existingStr) as Map<String, dynamic>;
          merged = {...existing, ...rideDetails};
        } catch (_) {}
      }
      await prefs.setString('active_ride_details', jsonEncode(merged));
    } else if (status == 'none') {
      await prefs.remove('active_ride_details');
      await prefs.remove('active_driver_lat');
      await prefs.remove('active_driver_lng');
    }
  }

  Future<Map<String, dynamic>?> _getPersistedRideState() async {
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getString('active_ride_status');
    if (status == null || status == 'none') return null;
    
    final tripId = prefs.getString('active_trip_id');
    final detailsStr = prefs.getString('active_ride_details');
    final driverLat = prefs.getDouble('active_driver_lat');
    final driverLng = prefs.getDouble('active_driver_lng');

    Map<String, dynamic>? details;
    if (detailsStr != null) {
      try {
        details = jsonDecode(detailsStr);
      } catch (e) {
        debugPrint('Error decoding persisted ride details: $e');
      }
    }
    
    return {
      'status': status,
      'trip_id': tripId,
      'details': details,
      'driver_lat': driverLat,
      'driver_lng': driverLng,
    };
  }

  void setPaymentMethod(String method) {
    _selectedPaymentMethod = method;
    notifyListeners();
  }

  void setPrecisePickupLocation(LatLng location) {
    if (_precisePickupLocation == location) return;
    _precisePickupLocation = location;
    notifyListeners();
    // Recalculate route and fares based on the new precise location
    _calculateRoute();
  }

  void resetSessionToken() {
    _sessionToken = const Uuid().v4();
  }

  void clearSuggestions() {
    _suggestions = [];
    notifyListeners();
  }

  Future<void> fetchSuggestions(String query) async {
    if (query.length < 4) {
      clearSuggestions();
      return;
    }

    if (_sessionToken.isEmpty) resetSessionToken();

    _isLoadingSuggestions = true;
    notifyListeners();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final results = await _locationService.getPlaceAutocomplete(query, _sessionToken);
      _suggestions = results;
      _isLoadingSuggestions = false;
      notifyListeners();
    });
  }

  Future<void> fetchNearbyDrivers(LatLng location) async {
    final drivers = await _driverService.getNearbyDrivers(
      lat: location.latitude,
      lng: location.longitude,
    );
    _nearbyDrivers = drivers;
    notifyListeners();
  }

  Future<void> fetchDynamicHomeData() async {
    _isLoadingHomeData = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token != null) {
        final results = await Future.wait([
          _favoriteLocationService.fetchFavoriteLocations(),
          _rideService.fetchRideHistory(token),
        ]);

        _favoriteLocations = results[0] as List<FavoriteLocation>;
        final allHistory = results[1] as List<Trip>;
        // Filter to last 2 completed trips for "Recent"
        _recentLocations = allHistory
            .where((t) => t.status.toLowerCase() == 'completed')
            .take(2)
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching dynamic home data: $e');
    } finally {
      _isLoadingHomeData = false;
      notifyListeners();
    }
  }

  Future<String?> checkActiveRide() async {
    final state = await _getPersistedRideState();
    if (state == null) return null;

    final status = state['status'] as String;
    final tripId = state['trip_id'] as String?;
    final details = state['details'] as Map<String, dynamic>?;
    final driverLat = state['driver_lat'] as double?;
    final driverLng = state['driver_lng'] as double?;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) return null;

      if (status == 'searching' || status == 'accept' || status == 'start' || status == 'active') {
        // Recover driver location if available
        if (driverLat != null && driverLng != null) {
          _driverLocation = LatLng(driverLat, driverLng);
        }

        // Recover state from persisted details
        if (details != null && _pickupLocation == null) {
          _pickupLocation = PlaceDetails(
            placeId: 'recovered',
            name: details['pickup_address'] ?? 'Recovered',
            formattedAddress: '',
            latitude: details['pickup_lat'] ?? (details['pickup_latitude'] ?? 0.0),
            longitude: details['pickup_lng'] ?? (details['pickup_longitude'] ?? 0.0),
          );
          _dropLocation = PlaceDetails(
            placeId: 'recovered',
            name: details['destination_address'] ?? 'Recovered',
            formattedAddress: '',
            latitude: details['destination_lat'] ?? (details['destination_latitude'] ?? 0.0),
            longitude: details['destination_lng'] ?? (details['destination_longitude'] ?? 0.0),
          );
          _selectedVehicleType = details['vehicle_type'];
          _distance = details['distance_km'] != null ? '${details['distance_km']} km' : null;
          _duration = details['duration_min'] != null ? '${details['duration_min']} mins' : null;
          
          // Populate rideRequestResponse from recovery details to ensure UI handles 'in-progress' state correctly
          _rideRequestResponse = {
            'status': status,
            'pickup_address': details['pickup_address'],
            'destination_address': details['destination_address'],
            'trip_id': tripId,
          };
          _isDriverArriving = status == 'accept';

          // Re-calculate route coordinates if needed
          if (status == 'start' || status == 'active') {
            await _updateRidingPolyline();
          } else if (status == 'accept') {
            await _updateArrivingPolyline();
          } else {
            await _calculateRoute();
          }
        }

        if (status == 'searching') {
          _isRequestingRide = true;
          notifyListeners();
          
          // Restore notification
          await OngoingRideNotificationService.startService();
          OngoingRideNotificationService.updateNotification(
            title: 'Searching for Driver',
            content: 'Finding the best ride for you...',
          );
          
          return 'searching';
        }
      }

      // For all other active states, ensure isRequestingRide is false
      _isRequestingRide = false;
      notifyListeners();

      if (tripId == null) return null;
      final id = int.tryParse(tripId);
      if (id == null) return null;
      
      await _rideService.connectToTrip(token, id);
      
      // Setup listener to get the first update and determine status
      final completer = Completer<String?>();
      
      _tripUpdatesSubscription?.cancel();
      _tripUpdatesSubscription?.cancel();
      _tripUpdatesSubscription = _rideService.tripUpdates?.listen((event) {
        _handleTripUpdateEvent(event);
        final data = jsonDecode(event);
        final currentStatus = data['status'];
        if (currentStatus != null && !completer.isCompleted) {
            completer.complete(currentStatus);
        } else if (data['type'] == 'trip_update' && !completer.isCompleted) {
            completer.complete(null);
        }
      });

      // Timeout if no update received
      Future.delayed(const Duration(seconds: 4), () {
        if (!completer.isCompleted) {
          debugPrint('Recovery timeout: falling back to persisted status $status');
          // Fallback to persisted status if it was active
          if (status == 'accept' || status == 'start' || status == 'active') {
             completer.complete(status);
          } else {
            completer.complete(null);
          }
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint('Error recoverying active ride: $e');
      // If error occurs but we have a persisted active state, try to return it
      if (status == 'accept' || status == 'start' || status == 'active') {
        return status;
      }
      return null;
    }
  }

  Future<void> saveLocation(String address, double lat, double lng) async {
    final success = await _favoriteLocationService.saveFavoriteLocation(address, lat, lng);
    if (success) {
      await fetchDynamicHomeData();
    }
  }

  Future<void> deleteLocation(int id) async {
    final success = await _favoriteLocationService.deleteFavoriteLocation(id);
    if (success) {
      await fetchDynamicHomeData();
    }
  }

  Future<void> toggleFavorite({
    required String address,
    required double lat,
    required double lng,
    int? existingId,
  }) async {
    if (existingId != null) {
      await deleteLocation(existingId);
    } else {
      await saveLocation(address, lat, lng);
    }
  }

  Future<void> setPickupLocation(String placeId, {String? defaultName, LatLng? presetLocation}) async {
    if (presetLocation != null) {
      _pickupLocation = PlaceDetails(
        placeId: placeId, 
        name: defaultName ?? 'Current Location', 
        formattedAddress: '', 
        latitude: presetLocation.latitude, 
        longitude: presetLocation.longitude
      );
      notifyListeners();
      await _calculateRoute();
      return;
    }

    if (_sessionToken.isEmpty) resetSessionToken();
    
    final details = await _locationService.getPlaceDetails(placeId, _sessionToken);
    if (details != null) {
      _pickupLocation = details;
      resetSessionToken(); 
      clearSuggestions();
      await _calculateRoute();
    }
  }

  Future<void> setDropLocation(String placeId) async {
    if (_sessionToken.isEmpty) resetSessionToken();
    
    final details = await _locationService.getPlaceDetails(placeId, _sessionToken);
    if (details != null) {
      _dropLocation = details;
      resetSessionToken(); 
      clearSuggestions();
      await _calculateRoute();
    }
  }

  Future<void> prepareAndCalculateRoute({
    LatLng? presetPickup,
    required String pickupName,
    required String dropPlaceId,
  }) async {
    _isLoadingRoute = true;
    notifyListeners();

    try {
      if (_sessionToken.isEmpty) resetSessionToken();
      
      if (presetPickup != null) {
        _pickupLocation = PlaceDetails(
          placeId: 'current',
          name: pickupName,
          formattedAddress: '',
          latitude: presetPickup.latitude,
          longitude: presetPickup.longitude,
        );
      } else if (_pickupLocation == null) {
        // Fallback or error handling if no pickup is available
        debugPrint('No pickup location available for route calculation');
        _isLoadingRoute = false;
        notifyListeners();
        return;
      }

      final dropDetails = await _locationService.getPlaceDetails(dropPlaceId, _sessionToken);
      if (dropDetails != null) {
        _dropLocation = dropDetails;
        resetSessionToken(); 
        clearSuggestions();
        
        final directions = await _locationService.getDirections(
          origin: _precisePickupLocation ?? _pickupLocation!.latLng,
          destination: _dropLocation!.latLng,
        );

        if (directions != null) {
          _distance = directions['distance'];
          _duration = directions['duration'];
          _bounds = directions['bounds'];
          _polylineCoordinates = List<LatLng>.from(directions['polylineCoordinates']);
          
          final kmMatch = RegExp(r'(\d+\.?\d*)').firstMatch(_distance ?? '');
          final minMatch = RegExp(r'(\d+)').firstMatch(_duration ?? '');
          
          if (kmMatch != null && minMatch != null) {
            final km = double.parse(kmMatch.group(1)!);
            final mins = int.parse(minMatch.group(1)!);
            await _estimateAllFares(km, mins);
          }
        }
      }
    } catch(e) {
      debugPrint('Route preparation error: $e');
    } finally {
      _isLoadingRoute = false;
      notifyListeners();
    }
  }

  void resetRoute() {
    _pickupLocation = null;
    _dropLocation = null;
    _precisePickupLocation = null;
    _polylineCoordinates = [];
    _distance = null;
    _duration = null;
    _bounds = null;
    notifyListeners();
  }

  Future<void> _calculateRoute() async {
    if (_pickupLocation == null || _dropLocation == null) return;

    _isLoadingRoute = true;
    notifyListeners();

    final directions = await _locationService.getDirections(
      origin: _precisePickupLocation ?? _pickupLocation!.latLng,
      destination: _dropLocation!.latLng,
    );

    if (directions != null) {
      _distance = directions['distance'];
      _duration = directions['duration'];
      _bounds = directions['bounds'];
      _polylineCoordinates = List<LatLng>.from(directions['polylineCoordinates']);

      final kmMatch = RegExp(r'(\d+\.?\d*)').firstMatch(_distance ?? '');
      final minMatch = RegExp(r'(\d+)').firstMatch(_duration ?? '');
      
      if (kmMatch != null && minMatch != null) {
        final km = double.parse(kmMatch.group(1)!);
        final mins = int.parse(minMatch.group(1)!);
        await _estimateAllFares(km, mins);
      }
    }

    _isLoadingRoute = false;
    notifyListeners();
  }

  Future<void> _estimateAllFares(double km, int mins) async {
    if (_pickupLocation == null || _dropLocation == null) return;

    _isLoadingFares = true;
    _fareEstimates = {};
    notifyListeners();

    final vehicleSpeeds = {
      'bike': 40, // km/h
      'auto': 30, // km/h
      'car': 35,  // km/h
    };
    
    final effectivePickup = _precisePickupLocation ?? _pickupLocation!.latLng;
    
    for (var type in vehicleSpeeds.keys) {
      final estimate = await _fareService.estimateFare(
        pickupLat: effectivePickup.latitude,
        pickupLng: effectivePickup.longitude,
        destinationLat: _dropLocation!.latitude,
        destinationLng: _dropLocation!.longitude,
        distanceKm: km,
        durationMin: mins,
        vehicleType: type,
      );
      
      if (estimate != null) {
        final speed = vehicleSpeeds[type] ?? 30;
        final timeToDrop = (km / speed * 60).round();
        estimate['time_to_drop'] = '$timeToDrop mins';
        _fareEstimates[type] = estimate;
      }
    }
    _isLoadingFares = false;
    notifyListeners();
  }

  void selectVehicleType(String? type) {
    if (_selectedVehicleType == type) return;
    _selectedVehicleType = type;
    notifyListeners();
  }

  Future<void> requestRide() async {
    if (_selectedVehicleType == null || _pickupLocation == null || _dropLocation == null) {
      debugPrint('Missing details for ride request');
      return;
    }

    // If we are already requesting, don't start another one
    if (_isRequestingRide) {
      debugPrint('Already requesting a ride. ignoring duplicate request.');
      return;
    }

    // Set requesting state BEFORE potentially early return to handle recovery
    _isRequestingRide = true;
    _rideRequestResponse = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      
      final kmMatch = RegExp(r'(\d+\.?\d*)').firstMatch(_distance ?? '');
      final minMatch = RegExp(r'(\d+)').firstMatch(_duration ?? '');
      
      final km = kmMatch != null ? double.parse(kmMatch.group(1)!) : 0.0;
      final mins = minMatch != null ? int.parse(minMatch.group(1)!) : 0;

      final effectivePickup = _precisePickupLocation ?? _pickupLocation!.latLng;

      final rideDetails = {
        'pickup_lat': effectivePickup.latitude,
        'pickup_lng': effectivePickup.longitude,
        'destination_lat': _dropLocation!.latitude,
        'destination_lng': _dropLocation!.longitude,
        'pickup_address': _pickupLocation!.name,
        'destination_address': _dropLocation!.name,
        'distance_km': km,
        'duration_min': mins,
        'vehicle_type': _selectedVehicleType!,
      };

      await _persistRideState(status: 'searching', rideDetails: rideDetails);
      
      // Start ongoing notification
      await OngoingRideNotificationService.startService();
      OngoingRideNotificationService.updateNotification(
        title: 'Searching for Driver',
        content: 'Finding the best ride for you...',
      );

      await _rideService.requestRide(
        token: token,
        pickupLat: effectivePickup.latitude,
        pickupLng: effectivePickup.longitude,
        destinationLat: _dropLocation!.latitude,
        destinationLng: _dropLocation!.longitude,
        distanceKm: km,
        durationMin: mins,
        pickupAddress: _pickupLocation!.name,
        destinationAddress: _dropLocation!.name,
        vehicleType: _selectedVehicleType!,
        paymentMethod: _selectedPaymentMethod,
      );

      _rideUpdatesSubscription?.cancel();
      _rideUpdatesSubscription = _rideService.rideUpdates?.listen((event) async {
        final data = jsonDecode(event);
        debugPrint('Ride Update Event: $data');
        
        final type = data['type'];
        final status = data['status'];
        
        // Handle various acceptance message formats
        final isAccepted = (type == 'trip_update' && status == 'accept') || 
                           (type == 'ride_accepted') || 
                           (type == 'ride.accepted');

        if (isAccepted) {
          _isRequestingRide = false; // Transitioning from searching to active
          final tripId = data['trip_id'];
          if (tripId != null) {
            debugPrint('Transitioning to Trip WS for ID: $tripId');
            
            // Connect to trip-specific socket
            await _rideService.connectToTrip(token, int.parse(tripId.toString()));
            
            // Update ride request response to signal acceptance
            _rideRequestResponse = data;
            final status = data['status'];
            _isDriverArriving = (status == 'accept' || status == null);
            
            // Capture initial driver location if provided in acceptance message
            final initLat = data['driver_lat'] ?? data['lat'] ?? data['driver_latitude'];
            final initLng = data['driver_lng'] ?? data['lng'] ?? data['driver_longitude'];
            if (initLat != null && initLng != null) {
              _driverLocation = LatLng(initLat.toDouble(), initLng.toDouble());
              _updateArrivingPolyline();
            }
            await _persistRideState(status: 'active', tripId: tripId.toString());
            
            // Update notification
            OngoingRideNotificationService.updateNotification(
              title: 'Driver Found!',
              content: 'Your driver is on the way to your pickup location.',
            );
            
            notifyListeners();

            // Setup listener for the trip updates
            _tripUpdatesSubscription?.cancel();
            _tripUpdatesSubscription = _rideService.tripUpdates?.listen((tripEvent) {
               _handleTripUpdateEvent(tripEvent);
            }, onError: (error) {
              debugPrint('Trip WS Stream Error: $error');
            }, onDone: () {
              debugPrint('Trip WS Stream Closed');
            });
          }
        } else {
          _rideRequestResponse = data;
          notifyListeners();
        }
      }, onError: (error) {
        debugPrint('Request WS Stream Error: $error');
        _isRequestingRide = false;
        notifyListeners();
      }, onDone: () {
        debugPrint('Request WS Stream Closed');
      });

    } catch (e) {
      debugPrint('Ride request error: $e');
      _isRequestingRide = false;
      notifyListeners();
    }
  }

  Future<void> _handleTripUpdateEvent(String tripEvent) async {
    try {
      final tripData = jsonDecode(tripEvent);
      
      // Skip internal connection messages to avoid overwriting acceptance data
      if (tripData['type'] == 'connection_established') {
        return;
      }

      if (tripData['type'] == 'driver_location_update' || tripData['type'] == 'location_update') {
        final lat = tripData['lat'];
        final lng = tripData['lng'];
        if (lat != null && lng != null) {
          _driverLocation = LatLng(lat.toDouble(), lng.toDouble());
          notifyListeners();
          
          // Update polyline from driver to pickup if still arriving, else to destination
          if (_isDriverArriving) {
            _updateArrivingPolyline();
          } else if (_rideRequestResponse?['status'] == 'start' || _rideRequestResponse?['status'] == 'active') {
            _updateRidingPolyline();
          }
        }
        return; // Don't overwrite _rideRequestResponse for location updates
      }

      final newStatus = tripData['status'];
      if (newStatus != null) {
        if (newStatus == 'start' || newStatus == 'active') {
          _isDriverArriving = false; // Ensure arriving flag is cleared
          // Update polyline from driver to destination
          _updateRidingPolyline();
          OngoingRideNotificationService.updateNotification(
            title: 'Trip in Progress',
            content: 'You are on your way to ${tripData['destination_address'] ?? 'your destination'}.',
          );
          // Persist status change to start/active
          await _persistRideState(
            status: newStatus, 
            tripId: _rideRequestResponse?['trip_id']?.toString() ?? tripData['trip_id']?.toString(),
            rideDetails: tripData,
          );
        } else if (newStatus == 'complete') {
          _isDriverArriving = false;
          _driverLocation = null;
          await _persistRideState(status: 'none');
          OngoingRideNotificationService.stopService();
        } else if (newStatus == 'cancel') {
          _isDriverArriving = false;
          _driverLocation = null;
          _isRequestingRide = false;
          await _persistRideState(status: 'none');
          OngoingRideNotificationService.stopService();
          _rideService.closeConnection();
        } else if (newStatus == 'accept') {
          _isDriverArriving = true;
          OngoingRideNotificationService.updateNotification(
            title: 'Driver Found!',
            content: 'Your driver is on the way.',
          );
        }
      }

      // Only update the ride request response for status changes
      _rideRequestResponse = tripData;

      // Sync pickup/drop locations from trip update if they are missing
      if (_pickupLocation == null && (tripData['pickup_lat'] != null || tripData['pickup_latitude'] != null)) {
        _pickupLocation = PlaceDetails(
          placeId: 'sync',
          name: tripData['pickup_address'] ?? 'Pickup',
          formattedAddress: '',
          latitude: (tripData['pickup_lat'] ?? tripData['pickup_latitude']).toDouble(),
          longitude: (tripData['pickup_lng'] ?? tripData['pickup_longitude']).toDouble(),
        );
      }
      
      if (_dropLocation == null && (tripData['destination_lat'] != null || tripData['destination_latitude'] != null)) {
        _dropLocation = PlaceDetails(
          placeId: 'sync',
          name: tripData['destination_address'] ?? 'Destination',
          formattedAddress: '',
          latitude: (tripData['destination_lat'] ?? tripData['destination_latitude']).toDouble(),
          longitude: (tripData['destination_lng'] ?? tripData['destination_longitude']).toDouble(),
        );
      }

      notifyListeners();

      debugPrint('Trip Data Update: ${tripData['type']} - ${tripData['status']}');
    } catch (e) {
      debugPrint('Error handling trip update: $e');
    }
  }

  Future<void> _updateArrivingPolyline() async {
    if (_driverLocation == null || _pickupLocation == null) return;
    
    final directions = await _locationService.getDirections(
      origin: _driverLocation!,
      destination: _precisePickupLocation ?? _pickupLocation!.latLng,
    );
    
    if (directions != null) {
      _polylineCoordinates = List<LatLng>.from(directions['polylineCoordinates']);
      _distance = directions['distance'];
      _duration = directions['duration'];
      _bounds = directions['bounds'];
      notifyListeners();
    }
  }

  Future<void> _updateRidingPolyline() async {
    if (_driverLocation == null || _dropLocation == null) return;
    
    final directions = await _locationService.getDirections(
      origin: _driverLocation!,
      destination: _dropLocation!.latLng,
    );
    
    if (directions != null) {
      _polylineCoordinates = List<LatLng>.from(directions['polylineCoordinates']);
      _distance = directions['distance'];
      _duration = directions['duration'];
      _bounds = directions['bounds'];
      notifyListeners();
    }
  }

  void cancelRideRequest() {
    _rideService.closeConnection();
    _isRequestingRide = false;
    _rideRequestResponse = null;
    _isDriverArriving = false;
    _driverLocation = null;
    _rideUpdatesSubscription?.cancel();
    _tripUpdatesSubscription?.cancel();
    _persistRideState(status: 'none');
    
    // Stop ongoing notification
    OngoingRideNotificationService.stopService();
    
    notifyListeners();
  }
}

