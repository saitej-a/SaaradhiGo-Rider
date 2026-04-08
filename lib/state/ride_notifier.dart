import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'ride_state.dart';
import 'ride_persistence.dart';
import '../services/models/location_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/websocket_service.dart';
import '../services/ride_service.dart';

final rideNotifierProvider = NotifierProvider<RideNotifier, RideState>(RideNotifier.new);

class RideNotifier extends Notifier<RideState> {
  @override
  RideState build() {
    final wsService = ref.watch(webSocketServiceProvider);
    final subscription = wsService.eventStream.listen((data) {
      updateFromWebSocket(data);
    });
    
    ref.onDispose(() {
      subscription.cancel();
    });

    return const RideState();
  }

  Future<void> loadInitialState() async {
    final savedState = await ref.read(ridePersistenceProvider).loadRideState();
    if (savedState != null) {
      state = savedState;

      if (state.isActiveRide && state.tripId != null) {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) {
          ref.read(webSocketServiceProvider).connectToTrip(token, int.parse(state.tripId!));
        }
        await syncStateFromBackend(state.tripId!);
      }
    }
  }

  Future<void> syncStateFromBackend(String tripId) async {
    state = state.copyWith(isSyncing: true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      clearState();
      state = state.copyWith(isSyncing: false);
      return;
    }

    final rideService = RideService();
    
    // Fetch in parallel
    final results = await Future.wait([
      rideService.getTripStatus(token, tripId),
      rideService.getTripDetails(token, tripId),
    ]);

    final statusData = results[0];
    final detailsData = results[1];

    if (statusData == null || statusData['status'] == 'error' || statusData['data'] == null) {
      clearState();
      state = state.copyWith(isSyncing: false);
      return;
    }

    final String tripStatus = statusData['data']['status'] ?? '';
    
    if (tripStatus == 'cancelled') {
        clearState();
        state = state.copyWith(showCancelledOverlay: true);
        Future.delayed(const Duration(seconds: 3), () {
            state = state.copyWith(showCancelledOverlay: false);
        });
        return;
    }

    RideStatus newStatus = state.status;
    if (tripStatus == 'accepted') newStatus = RideStatus.driverAccepted;
    else if (tripStatus == 'arrived') newStatus = RideStatus.driverArrived;
    else if (tripStatus == 'started' || tripStatus == 'in_progress') newStatus = RideStatus.rideStarted;
    else if (tripStatus == 'completed') newStatus = RideStatus.paymentPending;

    Map<String, dynamic> mergedResponse = Map<String, dynamic>.from(state.rawResponse ?? {});
    if (detailsData != null && detailsData['data'] != null) {
       final dData = detailsData['data'];
       if (dData['driver_name'] != null) mergedResponse['driver_name'] = dData['driver_name'];
       if (dData['vehicle_info'] != null) mergedResponse['vehicle_info'] = dData['vehicle_info'];
       if (dData['otp'] != null) mergedResponse['otp'] = dData['otp'];
       if (dData['driver_rating'] != null) mergedResponse['driver_rating'] = dData['driver_rating'];
    }

    state = state.copyWith(
       status: newStatus,
       rawResponse: mergedResponse,
       isSyncing: false,
    );
    _saveState();
  }

  void _saveState() {
    ref.read(ridePersistenceProvider).saveRideState(state);
  }

  void setSearching({
    PlaceDetails? pickup,
    PlaceDetails? drop,
    String? vehicleType,
    String? distance,
    String? duration,
  }) {
    state = state.copyWith(
      status: RideStatus.searchingDriver,
      pickupLocation: pickup,
      dropLocation: drop,
      pickupAddress: pickup?.name,
      destinationAddress: drop?.name,
      vehicleType: vehicleType,
      distance: distance,
      duration: duration,
      rawResponse: {},
    );
    _saveState();
  }

  void updateFromWebSocket(Map<String, dynamic> data) {
    final type = data['type'];
    final status = data['status'];

    if (type == 'driver_location_update' || type == 'location_update') {
      final lat = data['lat'] ?? data['latitude'];
      final lng = data['lng'] ?? data['longitude'];
      if (lat != null && lng != null) {
        state = state.copyWith(
          driverLocation: LatLng(
            double.parse(lat.toString()), 
            double.parse(lng.toString())
          )
        );
        _saveState();
      }
      return; 
    }

    RideStatus newStatus = state.status;
    
    // Strict event -> state mapping
    if (type == 'trip_created' || type == 'drivers_notified') {
      // Prevent reverting to searching if a driver has already accepted
      if (state.status == RideStatus.none || state.status == RideStatus.searchingDriver) {
        newStatus = RideStatus.searchingDriver;
      }
    } else if (type == 'trip_update' || type == 'trip_status_update') {
      if (status == 'accept') {
        newStatus = RideStatus.driverAccepted;
      } else if (status == 'reached') {
        newStatus = RideStatus.driverArrived;
      } else if (status == 'start') {
        newStatus = RideStatus.rideStarted;
      } else if (status == 'complete') {
        newStatus = RideStatus.rideCompleted;
      } else if (status == 'cancel') {
        newStatus = RideStatus.cancelled;
      }
    }

    LatLng? driverLoc = state.driverLocation;
    final initLat = data['driver_lat'] ?? data['latitude'];
    final initLng = data['driver_lng'] ?? data['longitude'];
    if (initLat != null && initLng != null) {
      driverLoc = LatLng(
        double.parse(initLat.toString()), 
        double.parse(initLng.toString())
      );
    }
    
    String? tripId = state.tripId;
    bool shouldConnectTrip = false;
    
    // Check if we should connect to the trip websocket now
    if (newStatus == RideStatus.driverAccepted && state.status == RideStatus.searchingDriver) {
      shouldConnectTrip = true;
    }

    if (data['trip_id'] != null) {
      final newTripId = data['trip_id'].toString();
      if (tripId != newTripId) {
        tripId = newTripId;
        if (newStatus != RideStatus.searchingDriver && newStatus != RideStatus.none) {
          shouldConnectTrip = true;
        }
      }
    }

    Map<String, dynamic> mergedResponse = Map<String, dynamic>.from(state.rawResponse ?? {});
    if (type != 'connection_established' && type != 'driver_location_update' && type != 'location_update') {
      // Keys that should not be overwritten once set (only come with accept events)
      const protectedKeys = {'driver_info', 'vehicle_info', 'otp', 'driver_name', 'vehicle_number'};
      data.forEach((key, value) {
        // Don't let non-accept events erase protected driver/vehicle details
        if (protectedKeys.contains(key) && mergedResponse.containsKey(key) && (value == null || (value is String && value.isEmpty))) {
          return;
        }
        mergedResponse[key] = value;
      });
    }

    state = state.copyWith(
      status: newStatus,
      rawResponse: mergedResponse,
      driverLocation: driverLoc,
      tripId: tripId,
    );
    _saveState();

    if (shouldConnectTrip && tripId != null && newStatus != RideStatus.searchingDriver) {
      SharedPreferences.getInstance().then((prefs) {
        final token = prefs.getString('access_token');
        if (token != null) {
          ref.read(webSocketServiceProvider).connectToTrip(token, int.parse(tripId!));
        }
      });
    }
  }

  // Explicit methods for payment and rating transition
  void setPaymentPending() {
    state = state.copyWith(status: RideStatus.paymentPending);
    _saveState();
  }

  void setRated() {
    state = state.copyWith(status: RideStatus.rated);
    _saveState();
  }

  Future<void> updateFromNotification(Map<String, dynamic> payload) async {
    final action = payload['action'] ?? payload['type'];
    if (action != null) {
       updateFromWebSocket(payload);
       
       final tripIdStr = payload['trip_id']?.toString() ?? state.tripId;
       if (tripIdStr != null && state.isActiveRide) {
         final prefs = await SharedPreferences.getInstance();
         final token = prefs.getString('access_token');
         if (token != null) {
           ref.read(webSocketServiceProvider).connectToTrip(token, int.parse(tripIdStr));
         }
       }
    }
  }

  void clearState() {
    state = const RideState();
    _saveState();
  }
}
