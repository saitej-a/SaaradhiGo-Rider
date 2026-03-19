import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/map_provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/flutter_svg.dart';



class SetDestinationScreen extends StatelessWidget {
  const SetDestinationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _DarkMapScaffold(
      title: 'Set Destination',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            leading: Icon(Icons.place, color: Color(0xFFEEBD2B)),
            title: Text(
              '1200 Ocean Drive',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('Miami Beach, FL 33139'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => context.push('/route-map'),
            child: const Text('Confirm Location'),
          ),
        ],
      ),
    );
  }
}

// Redundant RouteMapScreen removed to use screens/home/route_map_screen.dart instead.

class SearchingDriverScreen extends StatefulWidget {
  const SearchingDriverScreen({super.key});

  @override
  State<SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends State<SearchingDriverScreen> {
  bool _isNavigated = false;
  bool _canPop = false;
  MapProvider? _mapProvider;

  @override
  void initState() {
    super.initState();
    // Start ride request when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapProvider = context.read<MapProvider>();
      _mapProvider?.addListener(_handleStateChange);
      _mapProvider?.requestRide();
    });
  }

  @override
  void dispose() {
    _mapProvider?.removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
    if (!mounted || _isNavigated) return;
    
    final mapProvider = _mapProvider;
    if (mapProvider == null) return;

    // Check for ride acceptance
    if (mapProvider.rideRequestResponse != null) {
      final response = mapProvider.rideRequestResponse;
      final status = response['status'];
      final type = response['type'];
      
      // Navigate if ride is accepted
      if (type == 'ride.accepted' || type == 'ride_accepted' || 
          (type == 'trip_update' && status == 'accept')) {
        _isNavigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            String currentRoute = '';
            try {
              currentRoute = GoRouter.of(context).routerDelegate.currentConfiguration.last.matchedLocation;
            } catch (e) {
               debugPrint('Guard route check failed: $e');
            }
            
            if (currentRoute != '/driver-found') {
              context.pushReplacement('/driver-found');
            }
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showCancelConfirmation(context);
        if (shouldPop && mounted && context.mounted) {
          context.read<MapProvider>().cancelRideRequest();
          setState(() => _canPop = true);
          Navigator.of(context).pop();
        }
      },
      child: _DarkMapScaffold(
        title: 'Finding your ride...',
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(seconds: 4),
              tween: Tween(begin: 0.0, end: 0.8),
              builder: (context, value, child) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEEBD2B)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel Search'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showCancelConfirmation(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1C18),
        title: Text('Cancel Search?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to cancel your ride request?', style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Wait', style: GoogleFonts.inter(color: const Color(0xFFEEBD2B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cancel Anyway', style: GoogleFonts.inter(color: Colors.redAccent)),
          ),
        ],
      ),
    ) ?? false;
  }
}

class DriverFoundScreen extends StatefulWidget {
  const DriverFoundScreen({super.key});

  @override
  State<DriverFoundScreen> createState() => _DriverFoundScreenState();
}

class _DriverFoundScreenState extends State<DriverFoundScreen> {
  bool _canPop = false;
  bool _isNavigated = false;
  MapProvider? _mapProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapProvider = context.read<MapProvider>();
      _mapProvider?.addListener(_handleStateChange);
      _handleStateChange(); // Initial check
    });
  }

  @override
  void dispose() {
    _mapProvider?.removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
    if (!mounted || _isNavigated) return;
    
    final mapProvider = _mapProvider;
    if (mapProvider == null) return;
    
    final response = mapProvider.rideRequestResponse;
    
    if (response != null) {
      final status = response['status'];
      
      if (status == 'start' || status == 'active') {
        _isNavigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            context.pushReplacement('/tracking');
          }
        });
      } else if (status == 'cancel') {
        _isNavigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ride was cancelled by driver.')),
            );
            context.go('/home');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, child) {
        final rideData = mapProvider.rideRequestResponse;
        
        // Extracting data with fallbacks
        final driverInfo = rideData?['driver_info'] as Map<String, dynamic>?;
        final driverName = driverInfo?['name'] ?? rideData?['driver_name'] ?? 'Searching...';
        final driverStars = driverInfo?['stars']?.toString() ?? '5.0';
        final driverPhoto = driverInfo?['photo_url'];
        
        final vehicleData = rideData?['vehicle_info'] as Map<String, dynamic>?;
        final vehicleBrand = vehicleData?['brand'] ?? '';
        final vehicleModel = vehicleData?['model'] ?? '';
        final vehicleColor = vehicleData?['color'] ?? '';
        final vehicleNumber = vehicleData?['vehicle_number'] ?? rideData?['vehicle_number'] ?? '...';
        
        final vehicleSummary = (vehicleBrand.isNotEmpty && vehicleModel.isNotEmpty) 
            ? '$vehicleColor $vehicleBrand $vehicleModel' 
            : rideData?['vehicle_info_summary'] ?? 'Vehicle Details';
            
        final otp = rideData?['otp'] ?? '----';

        return PopScope(
          canPop: _canPop,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldPop = await _showCancelConfirmation(context);
            if (shouldPop && mounted && context.mounted) {
              context.read<MapProvider>().cancelRideRequest();
              setState(() => _canPop = true);
              Navigator.of(context).pop();
            }
          },
          child: _DarkMapScaffold(
            title: 'Your Driver is Arriving',
            onBack: () async {
              if (mounted && context.mounted) {
                Navigator.of(context).maybePop();
              }
            },
            bottom: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Driver & Vehicle Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFEEBD2B).withOpacity(0.2),
                      backgroundImage: driverPhoto != null ? NetworkImage(driverPhoto) : null,
                      child: driverPhoto == null 
                          ? const Icon(Icons.person, color: Color(0xFFEEBD2B), size: 32)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driverName,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Color(0xFFEEBD2B), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '$driverStars • Professional Driver',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _ActionButton(icon: Icons.chat_bubble_outline, onTap: () {}),
                        const SizedBox(width: 12),
                        _ActionButton(icon: Icons.phone_outlined, onTap: () {}),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Vehicle Detail Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car_filled_outlined, color: Color(0xFFEEBD2B), size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicleSummary,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            vehicleNumber.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: const Color(0xFFEEBD2B),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // OTP Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFEEBD2B).withOpacity(0.15),
                      const Color(0xFFEEBD2B).withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEEBD2B).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      'PIN TO START THE TRIP',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEEBD2B),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      otp.toString(),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Share this PIN with your driver only',
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Primary Action
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => context.push('/tracking'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEEBD2B),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    'LIVE TRACKING',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(
                    'Cancel Ride',
                    style: GoogleFonts.inter(
                      color: Colors.redAccent.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
    );
  }

  Future<bool> _showCancelConfirmation(BuildContext context) async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1C18),
        title: Text('Ongoing Ride', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('You have an active ride request. Are you sure you want to cancel?', style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Wait', style: GoogleFonts.inter(color: const Color(0xFFEEBD2B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cancel Anyway', style: GoogleFonts.inter(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showCancelDialog(BuildContext context) {
    // This is no longer used individually, but kept if needed for specific flows
    _showCancelConfirmation(context).then((shouldCancel) {
       if (shouldCancel && context.mounted) {
         context.read<MapProvider>().cancelRideRequest();
         context.pop();
       }
    });
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class FullMapTrackingScreen extends StatefulWidget {
  const FullMapTrackingScreen({super.key});

  @override
  State<FullMapTrackingScreen> createState() => _FullMapTrackingScreenState();
}

class _FullMapTrackingScreenState extends State<FullMapTrackingScreen> {
  bool _isNavigated = false;
  MapProvider? _mapProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapProvider = context.read<MapProvider>();
      _mapProvider?.addListener(_handleStateChange);
      _handleStateChange(); // Initial check
    });
  }

  @override
  void dispose() {
    _mapProvider?.removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
    if (!mounted || _isNavigated) return;
    
    final mapProvider = _mapProvider;
    if (mapProvider == null) return;
    
    final response = mapProvider.rideRequestResponse;

    if (response != null) {
      final status = response['status'];
      if (status == 'complete') {
        _isNavigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            context.pushReplacement('/ride-summary');
          }
        });
      } else if (status == 'cancel') {
        _isNavigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ride was cancelled.')),
            );
            context.go('/home');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, child) {
        return _DarkMapScaffold(
          title: 'Ride in Progress',
          forceInProgress: true,
          bottom: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mapProvider.duration ?? '-- min',
                      style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    Text(
                      mapProvider.distance ?? '-- km', 
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1C18),
                      title: const Text('SOS Emergency', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      content: const Text('Are you in danger? This will alert the nearest authorities and our support team.', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('I\'m Safe', style: TextStyle(color: Colors.white54))),
                        ElevatedButton(
                          onPressed: () {
                             Navigator.pop(context);
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text('Emergency Alert Sent! Support is on the way.')));
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('YES, CALL FOR HELP', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 12, spreadRadius: 2),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'SOS',
                    style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          action: mapProvider.rideRequestResponse?['status'] == 'complete' 
            ? ElevatedButton(
                onPressed: () => context.push('/ride-summary'),
                child: const Text('View Summary'),
              )
            : null,
        );
      },
    );
  }
}

class RidePaymentSummaryScreen extends StatelessWidget {
  const RidePaymentSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, child) {
        final rideData = mapProvider.rideRequestResponse;
        final totalFare = rideData?['total_fare'] ?? rideData?['estimated_fare'] ?? '0.00';
        final currency = rideData?['currency'] ?? 'INR';

        return Scaffold(
          backgroundColor: const Color(0xFF12110E),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Icon(Icons.check_circle, color: Color(0xFFEEBD2B), size: 64),
                const SizedBox(height: 8),
                const Text(
                  'Ride Completed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$currency $totalFare',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _DarkCard(child: _FareBreakdown(rideData: rideData)),
                const SizedBox(height: 10),
                _DarkCard(
                  child: ListTile(
                    leading: const Icon(
                      Icons.account_balance_wallet,
                      color: Color(0xFFEEBD2B),
                    ),
                    title: Text(
                      'Paid via ${mapProvider.selectedPaymentMethod.toUpperCase()} Wallet',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(Icons.check, color: Color(0xFFEEBD2B)),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => context.push('/rate-driver'),
                  child: const Text('Done'),
                ),
                TextButton(onPressed: () {}, child: const Text('Download Invoice')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class RateReviewDriverScreen extends StatefulWidget {
  const RateReviewDriverScreen({super.key});

  @override
  State<RateReviewDriverScreen> createState() => _RateReviewDriverScreenState();
}

class _RateReviewDriverScreenState extends State<RateReviewDriverScreen> {
  int score = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12110E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Rate your Driver'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 48)),
          const SizedBox(height: 8),
          const Text(
            'Rajesh Kumar',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text(
            'Toyota Innova Crysta . MH 01 AB 1234',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => IconButton(
                onPressed: () => setState(() => score = i + 1),
                icon: Icon(
                  i < score ? Icons.star : Icons.star_border,
                  color: const Color(0xFFEEBD2B),
                  size: 36,
                ),
              ),
            ),
          ),
          const TextField(
            maxLines: 4,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Write a comment (optional)...',
              hintStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Submit Review'),
          ),
          TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }
}

class _DarkMapScaffold extends StatefulWidget {
  const _DarkMapScaffold({
    required this.title,
    required this.bottom,
    this.action,
    this.onBack,
    this.forceInProgress = false,
  });

  final String title;
  final Widget bottom;
  final Widget? action;
  final VoidCallback? onBack;
  final bool forceInProgress;

  @override
  State<_DarkMapScaffold> createState() => _DarkMapScaffoldState();
}

class _DarkMapScaffoldState extends State<_DarkMapScaffold> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _animatedDriverLocation;
  MapProvider? _mapProvider;
  String? _lastStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapProvider = Provider.of<MapProvider>(context, listen: false);
      _mapProvider?.addListener(_handleMapUpdate);
      _handleMapUpdate(); // Initial sync
    });
  }

  void _handleMapUpdate() {
    if (!mounted) return;
    final mapProvider = _mapProvider;
    if (mapProvider == null) return;

    if (mapProvider.driverLocation != null && _animatedDriverLocation == null) {
      setState(() => _animatedDriverLocation = mapProvider.driverLocation);
      _fitDriverAndTarget();
    } else if (mapProvider.driverLocation != null && _animatedDriverLocation != mapProvider.driverLocation) {
      _animateMarker(mapProvider.driverLocation!);
      _fitDriverAndTarget(); // Re-fit as driver moves
    }

    // Also re-fit if the ride status changes (e.g., from accept to start)
    final currentStatus = mapProvider.rideRequestResponse?['status'];
    if (currentStatus != _lastStatus) {
      _lastStatus = currentStatus;
      _fitDriverAndTarget();
      
      // Initialize arrival polyline if entering arrival phase
      if (currentStatus == 'accept' || currentStatus == 'arrive') {
        mapProvider.updateArrivingPolyline();
      }
    }
  }

  void _fitDriverAndTarget() {
    final mapProvider = _mapProvider;
    if (mapProvider == null || mapProvider.driverLocation == null) return;

    final bool isInProgress = widget.forceInProgress || 
                             mapProvider.rideRequestResponse?['status'] == 'start' || 
                             mapProvider.rideRequestResponse?['status'] == 'active';
    
    final targetLocation = isInProgress 
        ? mapProvider.dropLocation?.latLng 
        : (mapProvider.precisePickupLocation ?? mapProvider.pickupLocation?.latLng);

    if (targetLocation == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final bounds = LatLngBounds.fromPoints([
            mapProvider.driverLocation!,
            targetLocation,
          ]);
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 180),
            )
          );
        } catch (e) {
          debugPrint('MapController not ready for fitCamera: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _mapProvider?.removeListener(_handleMapUpdate);
    super.dispose();
  }

  void _animateMarker(LatLng target) {
    if (_animatedDriverLocation == null) return;
    
    final start = _animatedDriverLocation!;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    final animation = CurvedAnimation(parent: controller, curve: Curves.easeInOut);

    controller.addListener(() {
      if (!mounted) {
        controller.stop();
        return;
      }
      setState(() {
        _animatedDriverLocation = LatLng(
          start.latitude + (target.latitude - start.latitude) * animation.value,
          start.longitude + (target.longitude - start.longitude) * animation.value,
        );
      });
    });

    controller.forward().then((_) => controller.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12110E),
      body: Consumer<MapProvider>(
        builder: (context, mapProvider, child) {
          final List<Marker> markers = [];
          
          // Pickup Marker
          final bool isInProgress = widget.forceInProgress ||
                                   mapProvider.rideRequestResponse?['status'] == 'start' || 
                                   mapProvider.rideRequestResponse?['status'] == 'active';
                                   
          if (mapProvider.pickupLocation != null && !isInProgress) {
            markers.add(
              Marker(
                point: mapProvider.precisePickupLocation ?? mapProvider.pickupLocation!.latLng,
                width: 40,
                height: 40,
                child: SvgPicture.asset(
                  'assets/markers/pickup.svg',
                  width: 40,
                  height: 40,
                  placeholderBuilder: (BuildContext context) => const Icon(Icons.location_on, color: Color(0xFFEEBD2B), size: 40),
                ),
              ),
            );
          }
          
          // Dropoff Marker (Destination)
          if (mapProvider.dropLocation != null && (!mapProvider.isDriverArriving || isInProgress)) {
            markers.add(
              Marker(
                point: mapProvider.dropLocation!.latLng,
                width: 40,
                height: 40,
                child: SvgPicture.asset(
                  'assets/markers/dropoff.svg',
                  width: 40,
                  height: 40,
                  placeholderBuilder: (BuildContext context) => const Icon(Icons.location_on, color: Colors.blue, size: 40),
                ),
              ),
            );
          }

          // Driver Marker (Animated)
          if (_animatedDriverLocation != null && mapProvider.rideRequestResponse != null) {
            markers.add(
              Marker(
                point: _animatedDriverLocation!,
                width: 45,
                height: 45,
                child: const SmoothAnimatedMarker(
                  child: Icon(Icons.directions_car, color: Color(0xFFEEBD2B), size: 34),
                ),
              ),
            );
          }

          // Nearby Driver Markers
          for (var driver in mapProvider.nearbyDrivers) {
            final lat = driver['latitude'] ?? driver['lat'];
            final lng = driver['longitude'] ?? driver['lng'];
            if (lat != null && lng != null) {
              markers.add(
                Marker(
                  point: LatLng(lat.toDouble(), lng.toDouble()),
                  width: 30,
                  height: 30,
                  child: const Icon(Icons.directions_car, color: Color(0xFFEEBD2B), size: 24),
                ),
              );
            }
          }

          final List<Polyline> polylines = [];
          if (mapProvider.polylineCoordinates.isNotEmpty) {
            polylines.add(
              Polyline(
                points: mapProvider.polylineCoordinates,
                color: const Color(0xFFEEBD2B),
                strokeWidth: 4,
              ),
            );
          }

          final initialCenter = mapProvider.dropLocation?.latLng ?? 
                               mapProvider.pickupLocation?.latLng ?? 
                               const LatLng(0, 0); 
          final initialZoom = (mapProvider.dropLocation != null || mapProvider.pickupLocation != null) ? 14.0 : 2.0;

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: initialZoom,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.saaradhigo.app',
                    retinaMode: RetinaMode.isHighDensity(context),
                    tileProvider: CancellableNetworkTileProvider(),
                  ),
                  PolylineLayer(
                    polylines: polylines,
                  ),
                  MarkerLayer(
                    markers: markers,
                  ),
                ],
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: widget.onBack ?? () => context.pop(),
                        icon: const CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(0x77000000),
                          child: Icon(Icons.arrow_back, color: Colors.white),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1C18),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 4,
                        width: 44,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      widget.bottom,
                      if (widget.action != null) ...[const SizedBox(height: 10), widget.action!],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.name,
    required this.eta,
    required this.fare,
    required this.icon,
    this.active = false,
  });

  final String name;
  final String eta;
  final String fare;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? const Color(0x33EEBD2B) : Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? const Color(0x66EEBD2B) : Colors.white24,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFEEBD2B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(eta, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          Text(
            fare,
            style: const TextStyle(
              color: Color(0xFFEEBD2B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: child,
    );
  }
}

class _DarkCard extends StatelessWidget {
  const _DarkCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFEEBD2B)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.icon,
    required this.label,
    this.iconBackground = const Color(0x1AEEBD2B),
  });

  final IconData icon;
  final String label;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF24211C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0DFFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFEEBD2B), size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFFF8FAFC),
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSearchField extends StatelessWidget {
  const _HelpSearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF24211C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: TextField(
        cursorColor: const Color(0xFFEEBD2B),
        textAlignVertical: TextAlignVertical.center,
        style: GoogleFonts.inter(
          color: const Color(0xFFF8FAFC),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 54,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF94A3B8),
            size: 24,
          ),
          hintText: 'Search for help',
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x1A8B6508),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x338B6508)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0x338B6508),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFEEBD2B), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF8FAFC),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 24),
        ],
      ),
    );
  }
}

class _HelpSectionLabel extends StatelessWidget {
  const _HelpSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        color: const Color(0xFF94A3B8),
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 2.4,
      ),
    );
  }
}

class _FareBreakdown extends StatelessWidget {
  final Map<String, dynamic>? rideData;
  const _FareBreakdown({this.rideData});

  @override
  Widget build(BuildContext context) {
    final fareBreakdown = rideData?['fare_breakdown'] as Map<String, dynamic>?;
    final currency = rideData?['currency'] ?? 'INR';
    final totalFare = rideData?['total_fare'] ?? rideData?['estimated_fare'] ?? '0.00';

    if (fareBreakdown == null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: _FareLine('Total Fare', '$currency $totalFare', bold: true),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (fareBreakdown['base_fare'] != null)
            _FareLine('Base Fare', '$currency ${fareBreakdown['base_fare']}'),
          if (fareBreakdown['distance_fare'] != null)
            _FareLine('Distance Fare', '$currency ${fareBreakdown['distance_fare']}'),
          if (fareBreakdown['time_fare'] != null)
            _FareLine('Time Fare', '$currency ${fareBreakdown['time_fare']}'),
          if (fareBreakdown['waiting_fare'] != null)
            _FareLine('Waiting Fare', '$currency ${fareBreakdown['waiting_fare']}'),
          if (fareBreakdown['taxes'] != null)
            _FareLine('Taxes & Fees', '$currency ${fareBreakdown['taxes']}'),
          if (fareBreakdown['discount'] != null && fareBreakdown['discount'] > 0)
            _FareLine('Promo Discount', '-$currency ${fareBreakdown['discount']}', color: const Color(0xFFEEBD2B)),
          const Divider(color: Colors.white24),
          _FareLine('Total', '$currency $totalFare', bold: true),
        ],
      ),
    );
  }
}

class _FareLine extends StatelessWidget {
  const _FareLine(
    this.label,
    this.value, {
    this.color = Colors.white,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color,
      fontSize: bold ? 20 : 15,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class SmoothAnimatedMarker extends StatefulWidget {
  const SmoothAnimatedMarker({super.key, required this.child});
  final Widget child;

  @override
  State<SmoothAnimatedMarker> createState() => _SmoothAnimatedMarkerState();
}

class _SmoothAnimatedMarkerState extends State<SmoothAnimatedMarker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 2.0).animate(_animation),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFFEEBD2B).withOpacity(0.3),
              shape: BoxShape.circle,
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

