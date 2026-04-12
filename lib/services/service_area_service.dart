import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class ServiceAreaService {
  static const LatLng hyderabadCenter = LatLng(17.3850, 78.4867);

  static const double maxDistanceFromCenterKm = 30.0;
  static const double bufferThresholdKm = 1.5;

  static final List<LatLng> hyderabadPolygon = [
    const LatLng(17.5400, 78.2800),
    const LatLng(17.5200, 78.2300),
    const LatLng(17.4500, 78.2300),
    const LatLng(17.4000, 78.2500),
    const LatLng(17.3600, 78.2800),
    const LatLng(17.3000, 78.2800),
    const LatLng(17.2500, 78.3000),
    const LatLng(17.2000, 78.3500),
    const LatLng(17.2200, 78.4200),
    const LatLng(17.2500, 78.4800),
    const LatLng(17.3000, 78.5200),
    const LatLng(17.3800, 78.5500),
    const LatLng(17.4500, 78.5200),
    const LatLng(17.5000, 78.4800),
    const LatLng(17.5200, 78.4200),
    const LatLng(17.5400, 78.3500),
    const LatLng(17.5400, 78.2800),
  ];

  static double _calculateDistanceKm(LatLng from, LatLng to) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _toRadians(to.latitude - from.latitude);
    final double dLng = _toRadians(to.longitude - from.longitude);
    final double lat1 = _toRadians(from.latitude);
    final double lat2 = _toRadians(to.latitude);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  static bool _isPointInsidePolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final LatLng vi = polygon[i];
      final LatLng vj = polygon[j];

      final double viLat = vi.latitude;
      final double viLng = vi.longitude;
      final double vjLat = vj.latitude;
      final double vjLng = vj.longitude;

      if (((viLng > point.longitude) != (vjLng > point.longitude)) &&
          (point.latitude <
              (vjLat - viLat) * (point.longitude - viLng) / (vjLng - viLng) +
                  viLat)) {
        inside = !inside;
      }
    }
    return inside;
  }

  static bool _isPointNearPolygonEdge(
    LatLng point,
    List<LatLng> polygon,
    double thresholdKm,
  ) {
    for (final vi in polygon) {
      final distance = _calculateDistanceKm(point, vi);
      if (distance <= thresholdKm) {
        return true;
      }
    }
    return false;
  }

  static bool isWithinHyderabad(LatLng location) {
    if (_isPointInsidePolygon(location, hyderabadPolygon)) {
      return true;
    }

    final distanceFromCenter = _calculateDistanceKm(hyderabadCenter, location);
    if (distanceFromCenter <= maxDistanceFromCenterKm) {
      return true;
    }

    if (_isPointNearPolygonEdge(
      location,
      hyderabadPolygon,
      bufferThresholdKm,
    )) {
      return true;
    }

    return false;
  }

  static Future<bool> checkCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final requestedPermission = await Geolocator.requestPermission();
        if (requestedPermission == LocationPermission.denied ||
            requestedPermission == LocationPermission.deniedForever) {
          debugPrint('Location permission denied');
          return false;
        }
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services disabled');
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final location = LatLng(position.latitude, position.longitude);
      debugPrint(
        'Current location: lat=${location.latitude}, lng=${location.longitude}',
      );

      return isWithinHyderabad(location);
    } catch (e) {
      debugPrint('Error checking location: $e');
      return false;
    }
  }

  static bool isPickupWithinHyderabad(LatLng? pickupLatLng) {
    if (pickupLatLng == null) return false;
    return isWithinHyderabad(pickupLatLng);
  }
}
