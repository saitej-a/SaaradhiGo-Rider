import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../services/models/trip_model.dart';
import '../services/models/location_model.dart';

enum RideStatus {
  none,
  searchingDriver,
  driverAccepted,
  driverArrived,
  rideStarted,
  rideCompleted,
  paymentPending,
  rated,
  cancelled,
}

@immutable
class RideState {
  final RideStatus status;
  final String? tripId;
  final LatLng? driverLocation;
  final PlaceDetails? pickupLocation;
  final PlaceDetails? dropLocation;
  final String? pickupAddress;
  final String? destinationAddress;
  final String? vehicleType;
  final String? distance;
  final String? duration;
  final Map<String, dynamic>? fareEstimates;
  final Map<String, dynamic>? rawResponse;

  const RideState({
    this.status = RideStatus.none,
    this.tripId,
    this.driverLocation,
    this.pickupLocation,
    this.dropLocation,
    this.pickupAddress,
    this.destinationAddress,
    this.vehicleType,
    this.distance,
    this.duration,
    this.fareEstimates,
    this.rawResponse,
  });

  RideState copyWith({
    RideStatus? status,
    String? tripId,
    LatLng? driverLocation,
    PlaceDetails? pickupLocation,
    PlaceDetails? dropLocation,
    String? pickupAddress,
    String? destinationAddress,
    String? vehicleType,
    String? distance,
    String? duration,
    Map<String, dynamic>? fareEstimates,
    Map<String, dynamic>? rawResponse,
  }) {
    return RideState(
      status: status ?? this.status,
      tripId: tripId ?? this.tripId,
      driverLocation: driverLocation ?? this.driverLocation,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropLocation: dropLocation ?? this.dropLocation,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      vehicleType: vehicleType ?? this.vehicleType,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      fareEstimates: fareEstimates ?? this.fareEstimates,
      rawResponse: rawResponse ?? this.rawResponse,
    );
  }

  // Helper getters
  bool get isRequesting => status == RideStatus.searchingDriver;
  bool get isActiveRide => status != RideStatus.none && status != RideStatus.cancelled && status != RideStatus.rideCompleted && status != RideStatus.paymentPending && status != RideStatus.rated;

  // Converts from json map (for persistence or fast resume)
  factory RideState.fromJson(Map<String, dynamic> json) {
    PlaceDetails? pickup;
    if (json['pickup_lat'] != null && json['pickup_lng'] != null) {
      pickup = PlaceDetails(
        placeId: 'persisted_pickup',
        name: json['pickup_address'] ?? 'Pickup',
        formattedAddress: json['pickup_address'] ?? '',
        latitude: (json['pickup_lat'] as num).toDouble(),
        longitude: (json['pickup_lng'] as num).toDouble(),
      );
    }

    PlaceDetails? drop;
    if (json['drop_lat'] != null && json['drop_lng'] != null) {
      drop = PlaceDetails(
        placeId: 'persisted_drop',
        name: json['destination_address'] ?? 'Destination',
        formattedAddress: json['destination_address'] ?? '',
        latitude: (json['drop_lat'] as num).toDouble(),
        longitude: (json['drop_lng'] as num).toDouble(),
      );
    }

    return RideState(
      status: _parseStatus(json['status']),
      tripId: json['trip_id']?.toString(),
      driverLocation: json['driver_lat'] != null && json['driver_lng'] != null
          ? LatLng((json['driver_lat'] as num).toDouble(), (json['driver_lng'] as num).toDouble())
          : null,
      pickupLocation: pickup,
      dropLocation: drop,
      pickupAddress: json['pickup_address'],
      destinationAddress: json['destination_address'],
      vehicleType: json['vehicle_type'],
      distance: json['distance']?.toString(),
      duration: json['duration']?.toString(),
      rawResponse: json['raw_response'] != null
          ? Map<String, dynamic>.from(json['raw_response'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'trip_id': tripId,
      'driver_lat': driverLocation?.latitude,
      'driver_lng': driverLocation?.longitude,
      'pickup_address': pickupAddress ?? pickupLocation?.name,
      'destination_address': destinationAddress ?? dropLocation?.name,
      'pickup_lat': pickupLocation?.latitude,
      'pickup_lng': pickupLocation?.longitude,
      'drop_lat': dropLocation?.latitude,
      'drop_lng': dropLocation?.longitude,
      'vehicle_type': vehicleType,
      'distance': distance,
      'duration': duration,
      'raw_response': rawResponse,
    };
  }

  static RideStatus _parseStatus(String? statusStr) {
    switch (statusStr) {
      case 'searchingDriver':
      case 'searching': return RideStatus.searchingDriver;
      case 'driverAccepted': return RideStatus.driverAccepted;
      case 'driverArrived': return RideStatus.driverArrived;
      case 'rideStarted': return RideStatus.rideStarted;
      case 'rideCompleted': return RideStatus.rideCompleted;
      case 'paymentPending': return RideStatus.paymentPending;
      case 'rated': return RideStatus.rated;
      case 'cancelled': return RideStatus.cancelled;
      default: return RideStatus.none;
    }
  }
}
