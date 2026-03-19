import 'dart:io';

void main() {
  final file = File('lib/providers/map_provider.dart');
  String content = file.readAsStringSync();

  // Add imports
  if (!content.contains('flutter_riverpod.dart')) {
    content = '''import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/ride_notifier.dart';
import '../state/ride_state.dart';
import '../services/websocket_service.dart';
''' + content;
  }

  // Replace Constructor & State Variables
  content = content.replaceAll(RegExp(r'bool _isRequestingRide = false;[\s\S]*?StreamSubscription\? _tripUpdatesSubscription;'), '''// Riverpod State Variables Delegated''');

  // Replace class declaration and constructor
  content = content.replaceAll(RegExp(r'class MapProvider extends ChangeNotifier \{[\s\S]*?\}  : _locationService = locationService \?\? LocationService\(\),[\s\S]*?_rideService = rideService \?\? RideService\(\);\s*'), '''class MapProvider extends ChangeNotifier {
  final ProviderContainer? container;
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
  })  : _locationService = locationService ?? LocationService(),
        _fareService = fareService ?? FareService(),
        _driverService = driverService ?? DriverService(),
        _favoriteLocationService = favoriteLocationService ?? FavoriteLocationService(),
        _rideService = rideService ?? RideService() {
    container?.listen<RideState>(rideNotifierProvider, (prev, next) {
      notifyListeners();
    });
  }

  // Delegated Getters
  bool get isRequestingRide => container?.read(rideNotifierProvider).status == RideStatus.searchingDriver;
  dynamic get rideRequestResponse => container?.read(rideNotifierProvider).rawResponse;
  LatLng? get driverLocation => container?.read(rideNotifierProvider).driverLocation;
  bool get isDriverArriving => container?.read(rideNotifierProvider).status == RideStatus.driverArrived || container?.read(rideNotifierProvider).status == RideStatus.driverAccepted;
  
  bool get isTripInProgress {
    final status = container?.read(rideNotifierProvider).status;
    return status == RideStatus.driverAccepted || status == RideStatus.rideStarted || status == RideStatus.searchingDriver || status == RideStatus.driverArrived;
  }

''');

  // Remove old getters
  content = content.replaceAll(RegExp(r'bool get isRequestingRide => _isRequestingRide;[\s\S]*?return false;\s+\}'), '');

  // Remove persist logic
  content = content.replaceAll(RegExp(r'Future<void> _persistRideState\(\{[\s\S]*?\}\s*\}\s*\}'), '');
  content = content.replaceAll(RegExp(r'Future<Map<String, dynamic>\?> _getPersistedRideState\(\) async \{[\s\S]*?\}\s*\}\s*return \{\s*.*?\s*\};\s*\}'), '');

  // Rewrite checkActiveRide
  content = content.replaceAll(RegExp(r'Future<String\?> checkActiveRide\(\) async \{[\s\S]*?\}\s*catch \(e\) \{[\s\S]*?\}\s*return null;\s*\}'), '''  Future<String?> checkActiveRide() async {
     await container?.read(rideNotifierProvider.notifier).loadInitialState();
     final status = container?.read(rideNotifierProvider).status;
      if (status == RideStatus.searchingDriver) return 'searching';
     if (status == RideStatus.driverAccepted) return 'accept';
     if (status == RideStatus.driverArrived) return 'arrive';
     if (status == RideStatus.rideStarted) return 'active';
     return null;
  }''');

  // Rewrite requestRide
  content = content.replaceAll(RegExp(r'Future<void> requestRide\(\) async \{[\s\S]*?\}\s*catch \(e\) \{[\s\S]*?notifyListeners\(\);\s*\}\s*\}'), '''  Future<void> requestRide() async {
    if (_selectedVehicleType == null || _pickupLocation == null || _dropLocation == null) return;
    
    final kmMatch = RegExp(r'(\d+\.?\d*)').firstMatch(_distance ?? '');
    final minMatch = RegExp(r'(\d+)').firstMatch(_duration ?? '');
    final km = kmMatch != null ? double.parse(kmMatch.group(1)!) : 0.0;
    final mins = minMatch != null ? int.parse(minMatch.group(1)!) : 0;
    final effectivePickup = _precisePickupLocation ?? _pickupLocation!.latLng;
    
    container?.read(rideNotifierProvider.notifier).setSearching(
      pickup: _pickupLocation, drop: _dropLocation, vehicleType: _selectedVehicleType, distance: _distance, duration: _duration,
    );

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    container?.read(webSocketServiceProvider).requestRide(
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
  }''');

  // Remove _handleTripUpdateEvent
  content = content.replaceAll(RegExp(r'Future<void> _handleTripUpdateEvent\(String tripEvent\) async \{[\s\S]*?\}\s*\}'), '');

  file.writeAsStringSync(content);
  print('Refactor complete!');
}
