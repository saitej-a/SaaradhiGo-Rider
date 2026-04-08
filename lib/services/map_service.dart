import 'package:latlong2/latlong.dart';
import 'location_service.dart';
import 'fare_service.dart';
import 'driver_service.dart';
import 'favorite_location_service.dart';
import 'models/location_model.dart';

// Re-export models so existing imports don't break
export 'location_service.dart';
export 'fare_service.dart';
export 'driver_service.dart';
export 'favorite_location_service.dart';
export 'models/location_model.dart';

class MapService {
  final LocationService _locationService = LocationService();
  final FareService _fareService = FareService();
  final DriverService _driverService = DriverService();
  final FavoriteLocationService _favoriteLocationService = FavoriteLocationService();

  Future<List<PlaceSuggestion>> getPlaceAutocomplete(String query, String sessionToken) =>
      _locationService.getPlaceAutocomplete(query, sessionToken);

  Future<PlaceDetails?> getPlaceDetails(String placeId, String sessionToken) =>
      _locationService.getPlaceDetails(placeId, sessionToken);

  Future<String?> getAddressFromCoordinates(double lat, double lon) =>
      _locationService.getAddressFromCoordinates(lat, lon);

  Future<Map<String, dynamic>?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) =>
      _locationService.getDirections(origin: origin, destination: destination);

  Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required double lat,
    required double lng,
    double radius = 1000,
  }) =>
      _driverService.getNearbyDrivers(lat: lat, lng: lng, radius: radius);

  Future<Map<String, dynamic>?> estimateFare({
    required double pickup_lat,
    required double pickup_lng,
    required double destination_lat,
    required double destination_long,
    required double distance_km,
    required int duration_min,
    required String vehicle_type,
  }) =>
      _fareService.estimateFare(
        pickupLat: pickup_lat,
        pickupLng: pickup_lng,
        destinationLat: destination_lat,
        destinationLng: destination_long,
        distanceKm: distance_km,
        durationMin: duration_min,
        vehicleType: vehicle_type,
      );

  Future<List<FavoriteLocation>> fetchFavoriteLocations() =>
      _favoriteLocationService.fetchFavoriteLocations();

  Future<bool> saveFavoriteLocation(String address, double lat, double lng) =>
      _favoriteLocationService.saveFavoriteLocation(address, lat, lng);

  Future<bool> deleteFavoriteLocation(int id) =>
      _favoriteLocationService.deleteFavoriteLocation(id);
}
