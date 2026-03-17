import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../core/app_config.dart';
import 'models/location_model.dart';

class LocationService {
  final String _googleApiKey = AppConfig.googleMapsApiKey;

  Future<List<PlaceSuggestion>> getPlaceAutocomplete(String query, String sessionToken) async {
    if (query.length < 3) return [];

    Uri url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(query)}'
      '&key=$_googleApiKey'
      '&sessiontoken=$sessionToken'
      '&components=country:in'
    );

    if (kIsWeb) {
      url = Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(url.toString())}');
    }

    try {
      final response = await http.get(url, headers: {'User-Agent': 'SaaradhiGo/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final List predictions = data['predictions'];
          return predictions.map((p) => PlaceSuggestion.fromJson(p)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching autocomplete: $e');
    }
    return [];
  }

  Future<PlaceDetails?> getPlaceDetails(String placeId, String sessionToken) async {
    if (placeId == 'current') return null;

    Uri url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId'
      '&key=$_googleApiKey'
      '&sessiontoken=$sessionToken'
      '&fields=name,geometry,formatted_address,place_id'
    );

    if (kIsWeb) {
      url = Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(url.toString())}');
    }

    try {
      final response = await http.get(url, headers: {'User-Agent': 'SaaradhiGo/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('Error fetching place details: $e');
    }
    
    if (placeId.contains(',')) {
      final parts = placeId.split(',');
      if (parts.length == 2) {
        return PlaceDetails(
          placeId: placeId,
          name: 'Selected Location',
          formattedAddress: '',
          latitude: double.tryParse(parts[0]) ?? 0.0,
          longitude: double.tryParse(parts[1]) ?? 0.0,
        );
      }
    }
    return null;
  }

  Future<String?> getAddressFromCoordinates(double lat, double lon) async {
    Uri url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lon&key=$_googleApiKey'
    );

    if (kIsWeb) {
      url = Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(url.toString())}');
    }

    try {
      final response = await http.get(url, headers: {'User-Agent': 'SaaradhiGo/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
           final firstResult = data['results'][0];
           String address = firstResult['formatted_address'];
           final addressComponents = firstResult['address_components'] as List;
           
           String? route;
           String? sublocality;
           String? locality;

           for (var component in addressComponents) {
             final types = component['types'] as List;
             if (types.contains('route')) route = component['long_name'];
             if (types.contains('sublocality')) sublocality = component['long_name'];
             if (types.contains('locality')) locality = component['long_name'];
           }

           List<String> parts = [];
           if (route != null) parts.add(route);
           else if (sublocality != null) parts.add(sublocality);
           if (locality != null) parts.add(locality);

           if (parts.isNotEmpty) return parts.join(', ');
           return address;
        }
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    Uri url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=polyline'
    );

    if (kIsWeb) {
      url = Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(url.toString())}');
    }

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final List<PointLatLng> result = PolylinePoints.decodePolyline(route['geometry']);
          final List<LatLng> polylineCoordinates = result.map((point) => LatLng(point.latitude, point.longitude)).toList();

          final num durationSeconds = route['duration'] ?? 0;
          final num distanceMeters = route['distance'] ?? 0;
          
          final int minutes = (durationSeconds / 60).round();
          final double km = distanceMeters / 1000;

          double minLat = origin.latitude;
          double maxLat = origin.latitude;
          double minLng = origin.longitude;
          double maxLng = origin.longitude;

          if (polylineCoordinates.isNotEmpty) {
             minLat = polylineCoordinates.first.latitude;
             maxLat = polylineCoordinates.first.latitude;
             minLng = polylineCoordinates.first.longitude;
             maxLng = polylineCoordinates.first.longitude;
            for (var p in polylineCoordinates) {
              if (p.latitude < minLat) minLat = p.latitude;
              if (p.latitude > maxLat) maxLat = p.latitude;
              if (p.longitude < minLng) minLng = p.longitude;
              if (p.longitude > maxLng) maxLng = p.longitude;
            }
          }

          return {
            'distance': '${km.toStringAsFixed(1)} km',
            'duration': '$minutes mins',
            'bounds': {
              'southwest': {'lat': minLat, 'lng': minLng},
              'northeast': {'lat': maxLat, 'lng': maxLng},
            },
            'polylineCoordinates': polylineCoordinates,
          };
        }
      }
    } catch (e) {
      debugPrint('Error fetching directions: $e');
    }
    return null;
  }
}
