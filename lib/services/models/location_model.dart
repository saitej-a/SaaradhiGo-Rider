import 'package:latlong2/latlong.dart';

class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('display_name')) {
      // OSM Fallback (if still used somehow)
      final displayName = json['display_name'] as String? ?? '';
      final parts = displayName.split(',');
      final mainText = parts.isNotEmpty ? parts[0].trim() : '';
      final secondaryText = parts.length > 1 ? parts.skip(1).join(',').trim() : '';
      
      final lat = json['lat'];
      final lon = json['lon'];
      final pId = (lat != null && lon != null) ? '$lat,$lon' : json['place_id'].toString();

      return PlaceSuggestion(
        placeId: pId,
        description: displayName,
        mainText: mainText,
        secondaryText: secondaryText,
      );
    } else {
      // Google Places Autocomplete format
      final structuredFormatting = json['structured_formatting'] ?? {};
      return PlaceSuggestion(
        placeId: json['place_id'],
        description: json['description'] ?? '',
        mainText: structuredFormatting['main_text'] ?? '',
        secondaryText: structuredFormatting['secondary_text'] ?? '',
      );
    }
  }
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final result = json['result'] ?? json;
    final geometry = result['geometry'];
    final location = geometry != null ? geometry['location'] : (json['geometry'] != null ? json['geometry']['location'] : null);
    
    return PlaceDetails(
      placeId: result['place_id'] ?? '',
      name: result['name'] ?? '',
      formattedAddress: result['formatted_address'] ?? '',
      latitude: location != null ? location['lat'] : 0.0,
      longitude: location != null ? location['lng'] : 0.0,
    );
  }
}

class FavoriteLocation {
  final int id;
  final String addressText;
  final double latitude;
  final double longitude;

  FavoriteLocation({
    required this.id,
    required this.addressText,
    required this.latitude,
    required this.longitude,
  });

  factory FavoriteLocation.fromJson(Map<String, dynamic> json) {
    return FavoriteLocation(
      id: json['id'] as int,
      addressText: json['address_text'] as String? ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? '0.0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}
