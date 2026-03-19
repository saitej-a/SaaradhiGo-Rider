import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/map_provider.dart';

class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({super.key});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final MapController _mapController = MapController();
  bool _hasFittedBounds = false;
  MapProvider? _mapProvider;
  bool _isNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapProvider = Provider.of<MapProvider>(context, listen: false);
      _mapProvider?.addListener(_handleStateChange);
      
      if (_mapProvider?.pickupLocation != null) {
        _mapProvider?.fetchNearbyDrivers(_mapProvider!.pickupLocation!.latLng);
      }
      
      _handleStateChange(); // Initial check
    });
  }

  @override
  void dispose() {
    _mapProvider?.removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
    if (!mounted || _isNavigated || _mapProvider == null) return;

    final status = _mapProvider?.rideRequestResponse?['status'];
    
    if (status == 'start' || status == 'accept' || status == 'active') {
      _isNavigated = true;
      String target = (status == 'start') ? '/tracking' : '/driver-found';
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
           context.pushReplacement(target);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12110E),
      body: Consumer<MapProvider>(
        builder: (context, mapProvider, child) {
          final List<Marker> markers = [];
          
          // Pickup Marker
          if (mapProvider.pickupLocation != null) {
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
          
          // Dropoff Marker
          if (mapProvider.dropLocation != null) {
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
          
          if (!_hasFittedBounds && mapProvider.pickupLocation != null && mapProvider.dropLocation != null) {
            if (mapProvider.polylineCoordinates.isNotEmpty || !mapProvider.isLoadingRoute) {
              _hasFittedBounds = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  try {
                    LatLngBounds bounds;
                    if (mapProvider.polylineCoordinates.isNotEmpty) {
                      bounds = LatLngBounds.fromPoints(mapProvider.polylineCoordinates);
                    } else {
                      bounds = LatLngBounds.fromPoints([
                        mapProvider.precisePickupLocation ?? mapProvider.pickupLocation!.latLng,
                        mapProvider.dropLocation!.latLng,
                      ]);
                    }
                    
                    _mapController.fitCamera(
                      CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 120),
                      )
                    );
                  } catch (e) {
                    debugPrint('Fit bounds error: $e');
                  }
                }
              });
            }
          }

          final initialCenter = mapProvider.dropLocation?.latLng ?? 
                               mapProvider.pickupLocation?.latLng ?? 
                               const LatLng(0, 0); 
          final initialZoom = (mapProvider.dropLocation != null || mapProvider.pickupLocation != null) ? 14.0 : 2.0;

          final bool hasTripDetails = mapProvider.distance != null && mapProvider.duration != null;

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              if (hasTripDetails) {
                final shouldPop = await _showCancelConfirmation(context);
                if (shouldPop && context.mounted) {
                  context.pop();
                }
              } else {
                context.pop();
              }
            },
            child: Column(
              children: [
                Expanded(
                  flex: hasTripDetails ? 5 : 10,
                  child: Stack(
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
                      Positioned(
                        top: 48,
                        left: 24,
                        child: GestureDetector(
                          onTap: () async {
                            if (hasTripDetails) {
                              final shouldPop = await _showCancelConfirmation(context);
                              if (shouldPop && context.mounted) {
                                context.pop();
                              }
                            } else {
                              context.pop();
                            }
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (mapProvider.isLoadingRoute)
                         const Center(
                           child: CircularProgressIndicator(color: Color(0xFFEEBD2B)),
                         ),
                    ],
                  ),
                ),
                if (hasTripDetails)
                  Container(
                    height: MediaQuery.of(context).size.height * 0.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1C18),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 40,
                          offset: const Offset(0, -10),
                        )
                      ],
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 48,
                            height: 6,
                            margin: const EdgeInsets.only(top: 16, bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.route, color: Color(0xFFEEBD2B), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                mapProvider.distance!,
                                style: const TextStyle(
                                  color: Color(0xFFEEBD2B),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const Icon(Icons.schedule, color: Color(0xFFEEBD2B), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                mapProvider.duration!,
                                style: const TextStyle(
                                  color: Color(0xFFEEBD2B),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.bookmark_add_outlined, color: Color(0xFFEEBD2B)),
                                tooltip: 'Save location',
                                onPressed: () {
                                  if (mapProvider.dropLocation != null) {
                                    context.read<MapProvider>().saveLocation(
                                      mapProvider.dropLocation!.name,
                                      mapProvider.dropLocation!.latitude,
                                      mapProvider.dropLocation!.longitude,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Destination saved to favorites')),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: mapProvider.isLoadingFares 
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFFEEBD2B)))
                            : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              _buildRideOption(
                                title: 'Bike',
                                isSelected: mapProvider.selectedVehicleType == 'bike',
                                onTap: () => mapProvider.selectVehicleType('bike'),
                                time: mapProvider.fareEstimates['bike']?['time_to_drop'] != null 
                                  ? 'Drop in ${((mapProvider.fareEstimates['bike']?['time_to_drop'] is num ? mapProvider.fareEstimates['bike']!['time_to_drop'] : 0)).ceil()} min' 
                                  : '',
                                price: '₹${mapProvider.fareEstimates['bike']?['estimated_fare'] ?? '...'}',
                                icon: Icons.two_wheeler,
                                isRecommended: false,
                              ),
                              _buildRideOption(
                                title: 'Auto',
                                isSelected: mapProvider.selectedVehicleType == 'auto',
                                onTap: () => mapProvider.selectVehicleType('auto'),
                                time: mapProvider.fareEstimates['auto']?['time_to_drop'] != null 
                                  ? 'Drop in ${((mapProvider.fareEstimates['auto']?['time_to_drop'] is num ? mapProvider.fareEstimates['auto']!['time_to_drop'] : 0)).ceil()} min' 
                                  : '',
                                price: '₹${mapProvider.fareEstimates['auto']?['estimated_fare'] ?? '...'}',
                                icon: Icons.electric_rickshaw,
                                isRecommended: true,
                              ),
                              _buildRideOption(
                                title: 'Car',
                                isSelected: mapProvider.selectedVehicleType == 'car',
                                onTap: () => mapProvider.selectVehicleType('car'),
                                time: mapProvider.fareEstimates['car']?['time_to_drop'] != null 
                                  ? 'Drop in ${((mapProvider.fareEstimates['car']?['time_to_drop'] is num ? mapProvider.fareEstimates['car']!['time_to_drop'] : 0)).ceil()} min' 
                                  : '',
                                price: '₹${mapProvider.fareEstimates['car']?['estimated_fare'] ?? '...'}',
                                icon: Icons.directions_car,
                                isRecommended: false,
                              ),
                            ],
                          ),
                        ),
                        _buildPaymentMethodSelector(mapProvider),
                        Padding(
                          padding: EdgeInsets.only(
                            top: 8,
                            left: 24,
                            right: 24,
                            bottom: MediaQuery.of(context).padding.bottom + 24,
                          ),
                          child: ElevatedButton(
                            onPressed: mapProvider.selectedVehicleType == null ? null : () {
                              context.push('/precise-pickup');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEEBD2B),
                              foregroundColor: const Color(0xFF1A1814),
                              disabledBackgroundColor: Colors.white.withOpacity(0.1),
                              disabledForegroundColor: Colors.white.withOpacity(0.3),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                              shadowColor: const Color(0xFFEEBD2B).withOpacity(0.4),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            child: Text(
                              mapProvider.selectedVehicleType != null 
                                ? 'Confirm ${mapProvider.selectedVehicleType![0].toUpperCase()}${mapProvider.selectedVehicleType!.substring(1)}' 
                                : 'Select a Ride',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRideOption({
    required String title,
    required String time,
    required String price,
    required IconData icon,
    required bool isRecommended,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFEEBD2B).withOpacity(0.2) 
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFFEEBD2B) 
                : Colors.white.withOpacity(0.05),
            width: isSelected ? 2 : 1,
          ),
        ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFFEEBD2B), size: 32),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  color: Color(0xFFEEBD2B),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          if (isRecommended)
            Positioned(
              top: -16,
              right: -16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFEEBD2B),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: const Text(
                  'RECOMMENDED',
                  style: TextStyle(
                    color: Color(0xFF1A1814),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  }

  Widget _buildPaymentMethodSelector(MapProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: Color(0xFF94A3B8), size: 20),
          const SizedBox(width: 12),
          const Text(
            'Payment',
            style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          _buildPaymentChip(
            label: 'Cash',
            icon: Icons.money,
            isSelected: provider.selectedPaymentMethod == 'cash',
            onTap: () => provider.setPaymentMethod('cash'),
          ),
          const SizedBox(width: 8),
          _buildPaymentChip(
            label: 'Online',
            icon: Icons.payment,
            isSelected: provider.selectedPaymentMethod == 'online',
            onTap: () => provider.setPaymentMethod('online'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEBD2B) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFEEBD2B) : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF1A1814) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF1A1814) : const Color(0xFFE2E8F0),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
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
        title: Text('Cancel Trip?', style: GoogleFonts.inter(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to cancel and go back?', style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep Going', style: GoogleFonts.inter(color: const Color(0xFFEEBD2B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.redAccent)),
          ),
        ],
      ),
    ) ?? false;
  }
}
