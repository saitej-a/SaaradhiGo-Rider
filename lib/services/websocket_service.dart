import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_config.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

class WebSocketService {
  WebSocketChannel? _rideChannel;
  WebSocketChannel? _tripChannel;
  StreamSubscription? _tripSubscription;
  
  final _rideEventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get eventStream => _rideEventController.stream;

  String? _lastToken;
  int? _lastTripId;
  Map<String, dynamic>? _lastRideRequestPayload;

  Timer? _rideReconnectTimer;
  Timer? _tripReconnectTimer;
  bool _isIntentionalDisconnect = false;
  bool _tripActive = false;

  // Connection tracking
  String? _activeTripWsUrl;
  bool _isConnectingTrip = false;
  int _tripReconnectAttempts = 0;

  void requestRide({
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
  }) {
    debugPrint("WebSocketService: requestRide invoked.");
    _lastToken = token;
    _isIntentionalDisconnect = false;
    final wsUrl = '${AppConfig.rideRequestWs}?token=$token';
    
    _lastRideRequestPayload = {
      'action': 'request',
      'type': 'ride_request',
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
      'pickup_address': pickupAddress,
      'destination_address': destinationAddress,
      'distance_km': distanceKm,
      'duration_min': durationMin,
      'vehicle_type': vehicleType,
      'payment_method': paymentMethod,
    };

    debugPrint("WebSocketService: Payload prepared. Connecting to WS URL: $wsUrl");
    _connectRideChannel(wsUrl);
  }

  void connectToTrip(String token, int tripId) {
    _isIntentionalDisconnect = false;
    _tripActive = true;
    final wsUrl = '${AppConfig.tripWs(tripId)}?token=$token';
    
    // Prevent redundant connection attempts to the SAME URL
    // Also check if we are ALREADY scheduled to reconnect to this URL
    if (_activeTripWsUrl == wsUrl) {
      if (_tripChannel != null || _isConnectingTrip) {
        debugPrint("WebSocketService: Already connected or connecting to trip WS: $tripId");
        return;
      }
      if (_tripReconnectTimer != null && _tripReconnectTimer!.isActive) {
        debugPrint("WebSocketService: Reconnection already scheduled for trip WS: $tripId. Respecting backoff.");
        return;
      }
    }

    debugPrint("WebSocketService: connectToTrip invoked for trip: $tripId. URL: $wsUrl");
    _lastToken = token;
    _lastTripId = tripId;

    // Close the ride request channel since we have a trip now
    _rideReconnectTimer?.cancel();
    _tripReconnectTimer?.cancel(); // Cancel any pending trip logic/reconnects
    _rideChannel?.sink.close();
    _rideChannel = null;
    _lastRideRequestPayload = null;

    _connectTripChannel(wsUrl);
  }

  void _connectRideChannel(String wsUrl) {
    debugPrint("WebSocketService: _connectRideChannel executing...");
    try {
      _rideChannel?.sink.close();
      _rideChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      debugPrint("WebSocketService: WebSocketChannel initialized.");

      _rideChannel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> decoded = jsonDecode(data);
            _rideEventController.add(decoded);
          } catch (e) {
             debugPrint("Error parsing ride WS data: $e");
          }
        },
        onDone: () {
          debugPrint("Ride request WS closed");
          _scheduleRideReconnect(wsUrl);
        },
        onError: (err) {
          debugPrint("Ride request WS error: $err");
          _scheduleRideReconnect(wsUrl);
        },
      );

      _rideChannel!.ready.then((_) {
        debugPrint("Ride WS Ready, sending payload");
        if (_lastRideRequestPayload != null) {
          _rideChannel!.sink.add(jsonEncode(_lastRideRequestPayload));
        }
      }).catchError((error) {
         debugPrint("Ride WS failed to be ready: $error");
      });
    } catch (e) {
      debugPrint("Ride request WS connect error: $e");
      _scheduleRideReconnect(wsUrl);
    }
  }

  void _scheduleRideReconnect(String wsUrl) {
    if (_isIntentionalDisconnect || _tripActive) return;
    _rideReconnectTimer?.cancel();
    _rideReconnectTimer = Timer(const Duration(seconds: 5), () {
      debugPrint("Reconnecting Ride request WS...");
      _connectRideChannel(wsUrl);
    });
  }

  void _connectTripChannel(String wsUrl) {
    debugPrint("WebSocketService: _connectTripChannel starting for $wsUrl");
    _isConnectingTrip = true;
    _activeTripWsUrl = wsUrl;

    try {
      // Cancel old subscription first to prevent ghost onDone callbacks
      _tripSubscription?.cancel();
      _tripSubscription = null;
      _tripChannel?.sink.close();
      _tripChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _tripSubscription = _tripChannel!.stream.listen(
        (data) {
          // On first successful message, we consider it "connected"
          _isConnectingTrip = false;
          _tripReconnectAttempts = 0; // Reset backoff on success
          
          try {
            final Map<String, dynamic> decoded = jsonDecode(data);
            _rideEventController.add(decoded);
          } catch (e) {
             debugPrint("Error parsing trip WS data: $e");
          }
        },
        onDone: () {
          debugPrint("Trip WS closed. URL: $wsUrl, Code: ${_tripChannel?.closeCode}, Reason: ${_tripChannel?.closeReason}");
          _isConnectingTrip = false;
          // Note: we KEEP _activeTripWsUrl to track what we are reconnecting to
          _scheduleTripReconnect(wsUrl);
        },
        onError: (err) {
          debugPrint("Trip WS error: $err, Code: ${_tripChannel?.closeCode}, Reason: ${_tripChannel?.closeReason}");
          _isConnectingTrip = false;
          _scheduleTripReconnect(wsUrl);
        },
      );

      _tripChannel!.ready.then((_) {
        debugPrint("Trip WS Ready for $wsUrl");
        _isConnectingTrip = false;
        _tripReconnectAttempts = 0;
      }).catchError((error) {
         debugPrint("Trip WS failed to be ready: $error");
         // onDone/onError will handle reconnection
      });

    } catch (e) {
       debugPrint("Trip WS connect error: $e");
       _isConnectingTrip = false;
       _scheduleTripReconnect(wsUrl);
    }
  }

  void _scheduleTripReconnect(String wsUrl) {
    if (_isIntentionalDisconnect) return;
    
    _tripReconnectTimer?.cancel();
    
    // Exponential backoff: 2, 4, 8, 16, max 30 seconds
    _tripReconnectAttempts++;
    final delaySeconds = (2 * _tripReconnectAttempts).clamp(2, 30);
    
    debugPrint("Scheduling Trip WS reconnect in ${delaySeconds}s (Attempt: $_tripReconnectAttempts)");
    
    _tripReconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      debugPrint("Reconnecting Trip WS...");
      _connectTripChannel(wsUrl);
    });
  }

  void disconnectAll() {
    debugPrint("WebSocketService: Disconnecting all channels intentionally.");
    _isIntentionalDisconnect = true;
    _tripActive = false;
    _rideReconnectTimer?.cancel();
    _tripReconnectTimer?.cancel();
    _tripSubscription?.cancel();
    _tripSubscription = null;
    _rideChannel?.sink.close();
    _tripChannel?.sink.close();
    _rideChannel = null;
    _tripChannel = null;
    _lastTripId = null;
    _lastRideRequestPayload = null;
    _activeTripWsUrl = null;
    _isConnectingTrip = false;
    _tripReconnectAttempts = 0;
  }
}
