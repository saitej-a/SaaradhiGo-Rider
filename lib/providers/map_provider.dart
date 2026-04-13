import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../services/location_service.dart';
import '../services/fare_service.dart';
import '../services/driver_service.dart';
import '../services/favorite_location_service.dart';
import '../services/ride_service.dart';
import '../services/service_area_service.dart';
import '../services/models/location_model.dart';
import '../services/models/trip_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/ride_notifier.dart';
import '../state/ride_state.dart';
import '../services/websocket_service.dart';
import '../screens/components/coming_soon_overlay.dart';

enum LocationStatus { unknown, loading, confirmed, failed }

class MapProvider extends ChangeNotifier {
  final ProviderContainer? container;
  LocationStatus _locationStatus = LocationStatus.unknown;
  final LocationService _locationService;
  final FareService _fareService;
  final DriverService _driverService;
  final FavoriteLocationService _favoriteLocationService;
  final RideService _rideService;

  String _sessionToken = '';

  MapProvider({
    this.container,
    LocationService? locationService,
    FareService? fareService,
    DriverService? driverService,
    FavoriteLocationService? favoriteLocationService,
    RideService? rideService,
  }) : _locationService = locationService ?? LocationService(),
       _fareService = fareService ?? FareService(),
       _driverService = driverService ?? DriverService(),
       _favoriteLocationService =
           favoriteLocationService ?? FavoriteLocationService(),
       _rideService = rideService ?? RideService() {
    container?.listen<RideState>(rideNotifierProvider, (prev, next) {
      if (prev?.driverLocation != next.driverLocation &&
          next.driverLocation != null) {
        if (next.status == RideStatus.driverAccepted ||
            next.status == RideStatus.driverArrived) {
          updateArrivingPolyline();
        } else if (next.status == RideStatus.rideStarted) {
          updateRidingPolyline();
        }
      }
      notifyListeners();
    });
  }

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

  List<FavoriteLocation> _favoriteLocations = [];
  List<Trip> _recentLocations = [];
  bool _isLoadingHomeData = false;
  LatLng? _precisePickupLocation;
  bool _showComingSoonOverlay = false;

  List<FavoriteLocation> get favoriteLocations => _favoriteLocations;
  List<Trip> get recentLocations => _recentLocations;
  bool get isLoadingHomeData => _isLoadingHomeData;
  bool get showComingSoonOverlay => _showComingSoonOverlay;

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
  LatLng? get precisePickupLocation => _precisePickupLocation;

  LocationStatus get locationStatus => _locationStatus;
  bool get isLocationConfirmed => _locationStatus == LocationStatus.confirmed;
  bool get isRequestEnabled => isLocationConfirmed;

  Future<void> confirmLocation() async {
    _locationStatus = LocationStatus.loading;
    notifyListeners();

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _locationStatus = LocationStatus.failed;
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _locationStatus = LocationStatus.failed;
        notifyListeners();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      ).timeout(const Duration(seconds: 10));

      _pickupLocation = PlaceDetails(
        placeId: 'current',
        name: 'Current Location',
        formattedAddress: '',
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _locationStatus = LocationStatus.confirmed;
      notifyListeners();
      await _calculateRoute();
    } catch (e) {
      debugPrint('Error confirming location: $e');
      _locationStatus = LocationStatus.failed;
      notifyListeners();
    }
  }

  // Delegated Getters (Riverpod Sink)
  bool get isRequestingRide =>
      container?.read(rideNotifierProvider).status ==
      RideStatus.searchingDriver;
  dynamic get rideRequestResponse =>
      container?.read(rideNotifierProvider).rawResponse;
  LatLng? get driverLocation =>
      container?.read(rideNotifierProvider).driverLocation;
  String? get tripId => container?.read(rideNotifierProvider).tripId;
  bool get isDriverArriving =>
      container?.read(rideNotifierProvider).status ==
          RideStatus.driverArrived ||
      container?.read(rideNotifierProvider).status == RideStatus.driverAccepted;
  String _selectedPaymentMethod = 'cash';
  String get selectedPaymentMethod => _selectedPaymentMethod;

  bool get isTripInProgress {
    final status = container?.read(rideNotifierProvider).status;
    return status == RideStatus.driverAccepted ||
        status == RideStatus.rideStarted ||
        status == RideStatus.searchingDriver ||
        status == RideStatus.driverArrived;
  }

  void setPaymentMethod(String method) {
    if (_selectedPaymentMethod != method) {
      _selectedPaymentMethod = method;
      notifyListeners();
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('preferred_payment_method', method);
      });
    }
  }

  void setPrecisePickupLocation(LatLng location) {
    if (_precisePickupLocation == location) return;
    _precisePickupLocation = location;
    notifyListeners();
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
      final results = await _locationService.getPlaceAutocomplete(
        query,
        _sessionToken,
      );
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

      final savedPaymentMethod = prefs.getString('preferred_payment_method');
      if (savedPaymentMethod != null) {
        _selectedPaymentMethod = savedPaymentMethod;
      }

      if (token != null) {
        final results = await Future.wait([
          _favoriteLocationService.fetchFavoriteLocations(),
          _rideService.fetchRideHistory(token),
        ]);

        _favoriteLocations = results[0] as List<FavoriteLocation>;
        final allHistory = results[1] as List<Trip>;
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
    await container?.read(rideNotifierProvider.notifier).loadInitialState();
    final rideState = container?.read(rideNotifierProvider);
    final status = rideState?.status;

    // Sync MapProvider fields from the persisted RideState
    if (rideState != null && status != null && status != RideStatus.none) {
      _distance = rideState.distance ?? _distance;
      _duration = rideState.duration ?? _duration;

      if (rideState.pickupLocation != null) {
        _pickupLocation = rideState.pickupLocation;
      }
      if (rideState.dropLocation != null) {
        _dropLocation = rideState.dropLocation;
      }

      notifyListeners();

      // Recalculate polyline based on current ride phase
      if (status == RideStatus.rideStarted) {
        updateRidingPolyline();
      } else if (status == RideStatus.driverAccepted ||
          status == RideStatus.driverArrived) {
        updateArrivingPolyline();
      }
    }

    if (status == RideStatus.searchingDriver) return 'searching';
    if (status == RideStatus.driverAccepted) return 'accept';
    if (status == RideStatus.driverArrived) return 'arrive';
    if (status == RideStatus.rideStarted) return 'active';
    return null;
  }

  Future<void> saveLocation(String address, double lat, double lng) async {
    final success = await _favoriteLocationService.saveFavoriteLocation(
      address,
      lat,
      lng,
    );
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

  Future<void> setPickupLocation(
    String placeId, {
    String? defaultName,
    LatLng? presetLocation,
  }) async {
    if (presetLocation != null) {
      _pickupLocation = PlaceDetails(
        placeId: placeId,
        name: defaultName ?? 'Current Location',
        formattedAddress: '',
        latitude: presetLocation.latitude,
        longitude: presetLocation.longitude,
      );
      notifyListeners();
      await _calculateRoute();
      return;
    }

    if (_sessionToken.isEmpty) resetSessionToken();

    final details = await _locationService.getPlaceDetails(
      placeId,
      _sessionToken,
    );
    if (details != null) {
      _pickupLocation = details;
      resetSessionToken();
      clearSuggestions();
      await _calculateRoute();
    }
  }

  Future<void> setDropLocation(String placeId) async {
    if (_sessionToken.isEmpty) resetSessionToken();

    final details = await _locationService.getPlaceDetails(
      placeId,
      _sessionToken,
    );
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
        _isLoadingRoute = false;
        notifyListeners();
        return;
      }

      // Validate pickup location is within Hyderabad service area
      final pickupLatLng = _pickupLocation!.latLng;
      if (!ServiceAreaService.isPickupWithinHyderabad(pickupLatLng)) {
        debugPrint('Pickup location outside Hyderabad: $pickupLatLng');
        // Show the coming soon overlay
        triggerComingSoonOverlay();
        return;
      }

      final dropDetails = await _locationService.getPlaceDetails(
        dropPlaceId,
        _sessionToken,
      );
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
          _polylineCoordinates = List<LatLng>.from(
            directions['polylineCoordinates'],
          );

          final kmMatch = RegExp(r'(\d+\.?\d*)').firstMatch(_distance ?? '');
          final minMatch = RegExp(r'(\d+)').firstMatch(_duration ?? '');

          if (kmMatch != null && minMatch != null) {
            final km = double.parse(kmMatch.group(1)!);
            final mins = int.parse(minMatch.group(1)!);
            await _estimateAllFares(km, mins);
          }
        }
      }
    } catch (e) {
      debugPrint('Route preparation error: \$e');
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

    // Validate pickup location is within Hyderabad service area
    final pickupLatLng = _pickupLocation!.latLng;
    if (!ServiceAreaService.isPickupWithinHyderabad(pickupLatLng)) {
      debugPrint(
        '_calculateRoute: Pickup location outside Hyderabad, skipping route calculation',
      );
      triggerComingSoonOverlay();
      return;
    }

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
      _polylineCoordinates = List<LatLng>.from(
        directions['polylineCoordinates'],
      );

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
      'bike': 40,
      'auto': 30,
      'car': 35,
      'car_xl': 35,
      'car_premium': 40,
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
        estimate['time_to_drop'] = timeToDrop;
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

  Future<void> requestRide({BuildContext? context}) async {
    debugPrint(
      "MapProvider: requestRide called. Vehicle: $_selectedVehicleType, Pickup: ${_pickupLocation?.name}, Drop: ${_dropLocation?.name}",
    );
    if (_selectedVehicleType == null ||
        _pickupLocation == null ||
        _dropLocation == null) {
      debugPrint(
        "MapProvider: requestRide aborted due to missing REQUIRED fields.",
      );
      return;
    }

    final kmMatch = RegExp(r'(\d+\.?\d*)').firstMatch(_distance ?? '');

    final minMatch = RegExp(r'(\d+)').firstMatch(_duration ?? '');
    final km = kmMatch != null ? double.parse(kmMatch.group(1)!) : 0.0;
    final mins = minMatch != null ? int.parse(minMatch.group(1)!) : 0;
    final effectivePickup = _precisePickupLocation ?? _pickupLocation!.latLng;

    container
        ?.read(rideNotifierProvider.notifier)
        .setSearching(
          pickup: _pickupLocation,
          drop: _dropLocation,
          vehicleType: _selectedVehicleType,
          distance: _distance,
          duration: _duration,
        );

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    debugPrint(
      "MapProvider: Retrieved token: ${token.isNotEmpty ? 'YES' : 'NO'}. Calling WebSocketService.requestRide...",
    );

    container
        ?.read(webSocketServiceProvider)
        .requestRide(
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
          paymentMethod: selectedPaymentMethod,
        );
  }

  void cancelRideRequest() {
    container?.read(rideNotifierProvider.notifier).clearState();
    container?.read(webSocketServiceProvider).disconnectAll();
    notifyListeners();
  }

  Future<void> updateRidingPolyline() async {
    final driverLoc = driverLocation;
    final dropLoc = _dropLocation?.latLng;

    if (driverLoc == null || dropLoc == null) return;

    final directions = await _locationService.getDirections(
      origin: driverLoc,
      destination: dropLoc,
    );

    if (directions != null) {
      _polylineCoordinates = List<LatLng>.from(
        directions['polylineCoordinates'],
      );
      _distance = directions['distance'];
      _duration = directions['duration'];
      _bounds = directions['bounds'];
      notifyListeners();
    }
  }

  Future<void> updateArrivingPolyline() async {
    final driverLoc = driverLocation;
    final pickupLoc = _precisePickupLocation ?? _pickupLocation?.latLng;

    if (driverLoc == null || pickupLoc == null) return;

    final directions = await _locationService.getDirections(
      origin: driverLoc,
      destination: pickupLoc,
    );

    if (directions != null) {
      _polylineCoordinates = List<LatLng>.from(
        directions['polylineCoordinates'],
      );
      _distance = directions['distance'];
      _duration = directions['duration'];
      _bounds = directions['bounds'];
      notifyListeners();
    }
  }

  void triggerComingSoonOverlay() {
    _showComingSoonOverlay = true;
    notifyListeners();
  }

  void dismissComingSoonOverlay() {
    _showComingSoonOverlay = false;
    notifyListeners();
  }

  /// Public method to fetch fare estimates manually
  /// This can be called when fare estimates need to be refreshed
  Future<void> fetchFareEstimates() async {
    if (_pickupLocation == null || _dropLocation == null) {
      debugPrint(
        'Cannot fetch fare estimates: pickup or drop location is null',
      );
      return;
    }

    // Check if we have distance and duration from route calculation
    final kmMatch = RegExp(r'(\d+\.?\d*)').firstMatch(_distance ?? '');
    final minMatch = RegExp(r'(\d+)').firstMatch(_duration ?? '');

    if (kmMatch == null || minMatch == null) {
      debugPrint(
        'Cannot fetch fare estimates: distance or duration not available',
      );
      // Try to recalculate the route first
      await _calculateRoute();
      return;
    }

    final km = double.parse(kmMatch.group(1)!);
    final mins = int.parse(minMatch.group(1)!);

    await _estimateAllFares(km, mins);
  }
}
