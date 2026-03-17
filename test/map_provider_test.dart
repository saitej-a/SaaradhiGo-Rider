import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vahango/providers/map_provider.dart';
import 'package:vahango/services/map_service.dart';
import 'package:vahango/services/ride_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeLocationService extends Fake implements LocationService {
  @override
  Future<Map<String, dynamic>?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    return {
      'distance': '5.0 km',
      'duration': '10 mins',
      'bounds': {
        'southwest': {'lat': 0.0, 'lng': 0.0},
        'northeast': {'lat': 1.0, 'lng': 1.0},
      },
      'polylineCoordinates': [origin, destination],
    };
  }

  @override
  Future<PlaceDetails?> getPlaceDetails(String placeId, String sessionToken) async {
    return PlaceDetails(
      placeId: placeId,
      name: 'Destination',
      formattedAddress: '123 Test St',
      latitude: 17.4400,
      longitude: 78.3489,
    );
  }
}

class FakeFareService extends Fake implements FareService {
  @override
  Future<Map<String, dynamic>?> estimateFare({
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
    required double distanceKm,
    required int durationMin,
    required String vehicleType,
  }) async {
    return {
      'estimated_fare': '100.00',
      'vehicle_type': vehicleType,
    };
  }
}

class FakeDriverService extends Fake implements DriverService {
  @override
  Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required double lat,
    required double lng,
    double radius = 1000,
  }) async {
    return [
      {'driver_id': '1', 'latitude': lat + 0.001, 'longitude': lng + 0.001},
      {'driver_id': '2', 'latitude': lat - 0.001, 'longitude': lng - 0.001},
    ];
  }
}

class FakeRideService extends Fake implements RideService {
  @override
  void closeConnection() {}
  
  @override
  Stream<dynamic>? get rideUpdates => const Stream.empty();

  @override
  Stream<dynamic>? get tripUpdates => const Stream.empty();

  @override
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
  }) async {}
}

void main() {
  group('MapProvider Tests', () {
    late MapProvider mapProvider;
    late FakeLocationService fakeLocationService;
    late FakeFareService fakeFareService;
    late FakeDriverService fakeDriverService;
    late FakeRideService fakeRideService;

    setUp(() {
      fakeLocationService = FakeLocationService();
      fakeFareService = FakeFareService();
      fakeDriverService = FakeDriverService();
      fakeRideService = FakeRideService();
      
      mapProvider = MapProvider(
        locationService: fakeLocationService, 
        fareService: fakeFareService,
        driverService: fakeDriverService,
        rideService: fakeRideService,
      ); 
      SharedPreferences.setMockInitialValues({'access_token': 'test_token'});
    });

    test('Initial state is correct', () {
      expect(mapProvider.nearbyDrivers, isEmpty);
      expect(mapProvider.fareEstimates, isEmpty);
      expect(mapProvider.isLoadingFares, isFalse);
    });

    test('fetchNearbyDrivers updates state', () async {
      await mapProvider.fetchNearbyDrivers(const LatLng(17.3850, 78.4867));
      expect(mapProvider.nearbyDrivers, isNotEmpty);
      expect(mapProvider.nearbyDrivers.length, 2);
    });

    test('prepareAndCalculateRoute updates fare estimates', () async {
      await mapProvider.prepareAndCalculateRoute(
        presetPickup: const LatLng(17.3850, 78.4867),
        pickupName: 'Home',
        dropPlaceId: 'destination_id',
      );
      
      expect(mapProvider.fareEstimates, isNotEmpty);
      expect(mapProvider.fareEstimates.containsKey('bike'), isTrue);
      expect(mapProvider.fareEstimates['bike']?['estimated_fare'], '100.00');
      expect(mapProvider.fareEstimates['bike']?['time_to_drop'], '8 mins');
      
      expect(mapProvider.fareEstimates.containsKey('auto'), isTrue);
      expect(mapProvider.fareEstimates['auto']?['time_to_drop'], '10 mins');
      
      expect(mapProvider.fareEstimates.containsKey('car'), isTrue);
      expect(mapProvider.fareEstimates['car']?['time_to_drop'], '9 mins');
    });

    test('selectVehicleType updates state', () {
      expect(mapProvider.selectedVehicleType, isNull);
      mapProvider.selectVehicleType('bike');
      expect(mapProvider.selectedVehicleType, 'bike');
      mapProvider.selectVehicleType('car');
      expect(mapProvider.selectedVehicleType, 'car');
    });

    test('cancelRideRequest resets state', () {
      mapProvider.cancelRideRequest();
      expect(mapProvider.isRequestingRide, isFalse);
      expect(mapProvider.rideRequestResponse, isNull);
    });
  });
}
