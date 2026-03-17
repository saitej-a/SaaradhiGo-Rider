class Trip {
  final int id;
  final String pickupAddress;
  final String destinationAddress;
  final String status;
  final String? estimatedFare;
  final String? finalFare;
  final DateTime? createdAt;
  final String? vehicleType;
  final String? driverName;
  final Map<String, dynamic>? driver;

  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;

  Trip({
    required this.id,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.status,
    this.estimatedFare,
    this.finalFare,
    this.createdAt,
    this.vehicleType,
    this.driverName,
    this.driver,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    // Map date: created_at or requested_at
    final dateStr = json['created_at'] ?? json['requested_at'];
    
    return Trip(
      id: json['id'] as int,
      pickupAddress: json['pickup_address'] as String? ?? 'Unknown Pickup',
      destinationAddress: json['destination_address'] as String? ?? 'Unknown Destination',
      status: json['status'] as String? ?? 'unknown',
      estimatedFare: json['estimated_fare']?.toString(),
      finalFare: json['final_fare']?.toString(),
      createdAt: dateStr != null ? DateTime.tryParse(dateStr) : null,
      vehicleType: json['vehicle_type'] as String? ?? json['vehicle_info'] as String?,
      pickupLat: double.tryParse(json['pickup_lat']?.toString() ?? ''),
      pickupLng: double.tryParse(json['pickup_long']?.toString() ?? ''),
      destinationLat: double.tryParse(json['destination_lat']?.toString() ?? ''),
      destinationLng: double.tryParse(json['destination_long']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pickup_address': pickupAddress,
      'destination_address': destinationAddress,
      'status': status,
      'estimated_fare': estimatedFare,
      'final_fare': finalFare,
      'created_at': createdAt?.toIso8601String(),
      'vehicle_type': vehicleType,
      'driver_name': driverName,
      'driver': driver,
    };
  }
}
