import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class GeometryUtils {
  /// Finds the point on the polyline nearest to the given [point].
  static LatLng findNearestPointOnPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return point;
    if (polyline.length == 1) return polyline.first;

    LatLng? nearestPoint;
    double minDistance = double.infinity;

    for (int i = 0; i < polyline.length - 1; i++) {
      final LatLng p1 = polyline[i];
      final LatLng p2 = polyline[i + 1];

      final LatLng candidate = _findNearestPointOnSegment(point, p1, p2);
      final double distance = _calculateDistance(point, candidate);

      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = candidate;
      }
    }

    return nearestPoint ?? polyline.first;
  }

  /// Calculates the nearest point on a line segment [p1]-[p2] to point [p].
  static LatLng _findNearestPointOnSegment(LatLng p, LatLng p1, LatLng p2) {
    final double x = p.longitude;
    final double y = p.latitude;
    final double x1 = p1.longitude;
    final double y1 = p1.latitude;
    final double x2 = p2.longitude;
    final double y2 = p2.latitude;

    final double dx = x2 - x1;
    final double dy = y2 - y1;

    if (dx == 0 && dy == 0) return p1;

    // Project point p onto the line p1-p2
    final double t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);

    if (t < 0) return p1;
    if (t > 1) return p2;

    return LatLng(y1 + t * dy, x1 + t * dx);
  }

  /// Simple Euclidean distance (approximation for small distances)
  static double _calculateDistance(LatLng p1, LatLng p2) {
    final double dx = p1.longitude - p2.longitude;
    final double dy = p1.latitude - p2.latitude;
    return math.sqrt(dx * dx + dy * dy);
  }
}
