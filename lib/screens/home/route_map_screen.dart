import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/map_provider.dart';
import '../components/coming_soon_overlay.dart';

class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({super.key});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final MapController _mapController = MapController();
  late DraggableScrollableController _sheetController;
  MapProvider? _mapProvider;
  bool _isNavigated = false;
  bool _showTiles = false; // New flag to delay tile loading


  String _getVehicleTypeDisplay(String? type) {
    switch (type) {
      case 'bike':
        return 'Bike';
      case 'auto':
        return 'Auto';
      case 'car':
        return 'Car';
      case 'car_xl':
        return 'Car XL';
      case 'car_premium':
        return 'Premium';
      default:
        return 'Car';
    }
  }

  /// Validates if a LatLng coordinate is within reasonable bounds
  bool _isValidCoordinate(LatLng? coordinate) {
    if (coordinate == null) return false;
    // Explicitly check for NaN or infinite values which cause FlutterMap crashes
    if (coordinate.latitude.isNaN || coordinate.latitude.isInfinite) return false;
    if (coordinate.longitude.isNaN || coordinate.longitude.isInfinite) return false;
    
    // Check for valid latitude (-90 to 90) and longitude (-180 to 180)
    if (coordinate.latitude < -90 || coordinate.latitude > 90) return false;
    if (coordinate.longitude < -180 || coordinate.longitude > 180) return false;
    
    // Check for obviously invalid coordinates (0,0 might be valid but often indicates no location)
    if (coordinate.latitude == 0 && coordinate.longitude == 0) return false;
    return true;
  }

  /// Creates a safe SVG widget with proper error handling and fallback
  Widget _buildSafeSvgMarker({
    required String assetPath,
    required Color fallbackColor,
    double size = 40,
  }) {
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      placeholderBuilder: (BuildContext context) =>
          _buildFallbackIcon(fallbackColor, size),
      // Add errorBuilder for additional error handling
      // Note: SvgPicture.asset doesn't have errorBuilder, but we can catch errors in the widget tree
    );
  }

  /// Builds a fallback icon when SVG fails to load
  Widget _buildFallbackIcon(Color color, double size) {
    return Icon(Icons.location_on, color: color, size: size);
  }

  /// Creates a marker with safe coordinate validation and error handling
  Marker? _buildSafeMarker({
    required LatLng? point,
    required Widget child,
    double width = 40,
    double height = 40,
  }) {
    if (point == null || !_isValidCoordinate(point)) {
      return null;
    }

    return Marker(point: point, width: width, height: height, child: child);
  }

  /// Validates polyline coordinates and returns a safe polyline or null
  Polyline? _buildSafePolyline({
    required List<LatLng> points,
    required Color color,
    double strokeWidth = 4,
  }) {
    if (points.isEmpty) return null;

    // Filter out invalid coordinates
    final validPoints = points
        .where((point) => _isValidCoordinate(point))
        .toList();
    if (validPoints.length < 2) return null;

    return Polyline(
      points: validPoints,
      color: color,
      strokeWidth: strokeWidth,
    );
  }

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
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
    _sheetController.dispose();
    _mapProvider?.removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
    if (!mounted || _isNavigated || _mapProvider == null) return;

    if (_mapProvider!.showComingSoonOverlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => const ComingSoonOverlay(),
          ).then((_) {
            _mapProvider?.dismissComingSoonOverlay();
            context.pop();
          });
        }
      });
      return;
    }

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

  void _fitBoundsIfNeeded(MapProvider mapProvider) {
    if (!mounted) return;

    try {
      LatLng? pickup;
      LatLng? dropoff;

      if (mapProvider.pickupLocation != null) {
        pickup =
            mapProvider.precisePickupLocation ??
            mapProvider.pickupLocation!.latLng;
        if (pickup.latitude.isNaN || pickup.longitude.isNaN) {
          pickup = null;
        }
      }
      if (mapProvider.dropLocation != null) {
        dropoff = mapProvider.dropLocation!.latLng;
        if (dropoff.latitude.isNaN || dropoff.longitude.isNaN) {
          dropoff = null;
        }
      }

      if (pickup == null || !_isValidCoordinate(pickup)) return;
      
      // Don't try to fit camera if we are showing the coming soon overlay (outside service area)
      if (mapProvider.showComingSoonOverlay) return;

      final validPolyline = mapProvider.polylineCoordinates
          .where((point) => _isValidCoordinate(point))
          .toList();

      LatLngBounds bounds;
      if (dropoff != null && _isValidCoordinate(dropoff) && validPolyline.isNotEmpty) {
        bounds = LatLngBounds.fromPoints(validPolyline);
      } else if (dropoff != null && _isValidCoordinate(dropoff)) {
        bounds = LatLngBounds.fromPoints([pickup, dropoff]);
      } else {
        // If only one point, create a tiny bound around it
        bounds = LatLngBounds(pickup, pickup);
      }

      // Check if the bounds are degenerate (exactly the same point)
      // fitCamera with padding on zero-size bounds can sometimes cause "viewport too small" errors
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          // Reduce vertical padding to prevent zoom overflows on smaller viewports
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 80),
          // Ensure we don't zoom in too far if bounds are small/single point
          maxZoom: 16,
        ),
      );
      
      // Delay tile rendering until the camera has fitted its target bounds
      if (!_showTiles && mounted) {
        setState(() {
          _showTiles = true;
        });
      }
    } catch (e) {
      debugPrint('Fit bounds error: $e');
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12110E),
      body: Consumer<MapProvider>(
        builder: (context, mapProvider, child) {
          final List<Marker> markers = [];

          // Pickup Marker with safe coordinate validation
          if (mapProvider.pickupLocation != null) {
            final pickupPoint =
                mapProvider.precisePickupLocation ??
                mapProvider.pickupLocation!.latLng;

            final pickupMarker = _buildSafeMarker(
              point: pickupPoint,
              child: _buildSafeSvgMarker(
                assetPath: 'assets/markers/pickup.svg',
                fallbackColor: const Color(0xFFEEBD2B),
                size: 40,
              ),
              width: 40,
              height: 40,
            );

            if (pickupMarker != null) {
              markers.add(pickupMarker);
            } else {
              debugPrint('Invalid pickup coordinate: $pickupPoint');
            }
          }

          // Dropoff Marker with safe coordinate validation
          if (mapProvider.dropLocation != null) {
            final dropoffMarker = _buildSafeMarker(
              point: mapProvider.dropLocation!.latLng,
              child: _buildSafeSvgMarker(
                assetPath: 'assets/markers/dropoff.svg',
                fallbackColor: Colors.blue,
                size: 40,
              ),
              width: 40,
              height: 40,
            );

            if (dropoffMarker != null) {
              markers.add(dropoffMarker);
            } else {
              debugPrint(
                'Invalid dropoff coordinate: ${mapProvider.dropLocation!.latLng}',
              );
            }
          }

          // Nearby Driver Markers with safe coordinate validation
          for (var driver in mapProvider.nearbyDrivers) {
            final lat = driver['latitude'] ?? driver['lat'];
            final lng = driver['longitude'] ?? driver['lng'];
            if (lat != null && lng != null) {
              try {
                final point = LatLng(lat.toDouble(), lng.toDouble());
                final driverMarker = _buildSafeMarker(
                  point: point,
                  child: const Icon(
                    Icons.directions_car,
                    color: Color(0xFFEEBD2B),
                    size: 24,
                  ),
                  width: 30,
                  height: 30,
                );

                if (driverMarker != null) {
                  markers.add(driverMarker);
                } else {
                  debugPrint('Invalid driver coordinate: lat=$lat, lng=$lng');
                }
              } catch (e) {
                debugPrint('Error creating driver marker: $e');
              }
            }
          }

          final List<Polyline> polylines = [];
          // Use safe polyline creation with coordinate validation
          final safePolyline = _buildSafePolyline(
            points: mapProvider.polylineCoordinates,
            color: const Color(0xFFEEBD2B),
            strokeWidth: 4,
          );
          if (safePolyline != null) {
            polylines.add(safePolyline);
          } else if (mapProvider.polylineCoordinates.isNotEmpty) {
            debugPrint('Polyline coordinates invalid or insufficient');
          }

          final LatLng? tempCenter =
              _isValidCoordinate(mapProvider.dropLocation?.latLng)
                  ? mapProvider.dropLocation?.latLng
                  : _isValidCoordinate(mapProvider.pickupLocation?.latLng)
                      ? mapProvider.pickupLocation?.latLng
                      : null;
                      
          final initialCenter = tempCenter ?? const LatLng(17.385044, 78.4867);
          final initialZoom =
              (tempCenter != null)
              ? 14.0
              : 2.0;

          final bool hasTripDetails =
              mapProvider.distance != null && mapProvider.duration != null;

          if (mapProvider.isLoadingRoute) {
            return Scaffold(
              backgroundColor: const Color(0xFF12110E),
              body: const Center(
                child: CircularProgressIndicator(color: Color(0xFFEEBD2B)),
              ),
            );
          }

          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              if (hasTripDetails) {
                final shouldPop = await _showCancelConfirmation(context);
                if (!shouldPop && context.mounted) {
                  // User cancelled, prevent navigation
                  return;
                }
              }
              // Allow navigation to proceed
              if (context.mounted) {
                context.pop();
              }
            },
            child: Stack(
              children: [
                // Ensure FlutterMap has explicit constraints to prevent "render box with no size" errors
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Provide fallback if constraints are zero (shouldn't happen but defensive)
                      if (constraints.maxWidth <= 0 ||
                          constraints.maxHeight <= 0) {
                        return Container(
                          color: const Color(0xFF12110E),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFEEBD2B),
                            ),
                          ),
                        );
                      }

                      try {
                        return FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: initialCenter,
                            initialZoom: initialZoom,
                            onMapReady: () {
                              _fitBoundsIfNeeded(mapProvider);
                            },
                          ),
                          children: [
                            // Wrap TileLayer to only load after polyline/markers are fitted
                            if (_showTiles)
                              TileLayer(
                                urlTemplate:
                                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                                subdomains: const ['a', 'b', 'c', 'd'],
                                userAgentPackageName: 'com.saaradhigo.app',
                                retinaMode: RetinaMode.isHighDensity(context),
                                tileProvider: CancellableNetworkTileProvider(),
                                // Enable preloading to prevent gray areas on load or scroll
                                panBuffer: 1,
                                keepBuffer: 2,
                              ),
                            if (polylines.isNotEmpty)
                              PolylineLayer(polylines: polylines),
                            if (markers.isNotEmpty)
                              MarkerLayer(markers: markers),

                            // Remove empty marker layer that was causing hit testing errors
                            // Instead, we'll ensure the map has a proper interactive area
                          ],
                        );
                      } catch (e, stackTrace) {
                        debugPrint('FlutterMap rendering error: $e');
                        debugPrint('Stack trace: $stackTrace');
                        // Fallback UI when map fails to render
                        return Container(
                          color: const Color(0xFF12110E),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Color(0xFFEEBD2B),
                                  size: 64,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Map unavailable',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please check your connection',
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () {
                                    // Try to reload the map
                                    if (mounted) {
                                      setState(() {});
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEEBD2B),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                Positioned(
                  top: 48,
                  left: 24,
                  child: GestureDetector(
                    onTap: () async {
                      if (hasTripDetails) {
                        final shouldPop = await _showCancelConfirmation(
                          context,
                        );
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
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                ),
                if (mapProvider.isLoadingRoute)
                  const Center(
                    child: CircularProgressIndicator(color: Color(0xFFEEBD2B)),
                  ),
                if (hasTripDetails)
                  Positioned.fill(
                    child: DraggableScrollableSheet(
                      controller: _sheetController,
                      initialChildSize: 0.15,
                      minChildSize: 0.15,
                      maxChildSize: 0.70,
                      snap: true,
                      snapSizes: const [0.15, 0.70],
                      builder: (context, scrollController) {
                        return _buildSnapAwareSheet(
                          context,
                          mapProvider,
                          scrollController,
                        );
                      },
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
    String? subtitle,
    required String time,
    required String price,
    required IconData icon,
    required bool isRecommended,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Ensure all text values have fallbacks to prevent layout issues
    final safeTitle = title.isNotEmpty ? title : 'Ride Option';
    final safeTime = time.isNotEmpty
        ? time
        : (subtitle?.isNotEmpty == true ? subtitle! : '');
    final safePrice = price.isNotEmpty ? price : '₹...';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 88, // Ensure minimum height to prevent "no size" errors
        ),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon container with explicit dimensions
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
                  // Content section
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          safeTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (safeTime.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              safeTime,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (subtitle != null &&
                            subtitle.isNotEmpty &&
                            safeTime.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                color: const Color(0xFFEEBD2C).withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Price with proper constraints
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 60, // Ensure price has minimum width
                    ),
                    child: Text(
                      safePrice,
                      style: const TextStyle(
                        color: Color(0xFFEEBD2B),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              if (isRecommended)
                Positioned(
                  top: -12,
                  right: -12,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 80,
                      minHeight: 24,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFareEstimatesSection(
    MapProvider provider,
    ScrollController scrollController,
  ) {
    // Check for loading state
    if (provider.isLoadingFares) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFEEBD2B)),
      );
    }

    // Check for error state (empty fare estimates after loading)
    final fareEstimates = provider.fareEstimates;

    // More lenient check: allow partial fare data
    final hasFareData =
        fareEstimates.isNotEmpty &&
        fareEstimates.values.any(
          (estimate) => estimate != null && estimate.isNotEmpty,
        );

    // Also check if we have at least one valid fare estimate with estimated_fare
    final hasValidFare = fareEstimates.values.any(
      (estimate) =>
          estimate != null &&
          estimate.isNotEmpty &&
          estimate['estimated_fare'] != null,
    );

    if (!hasFareData || !hasValidFare) {
      // Show error/empty state with retry option
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEEBD2B), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Unable to load fare estimates',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (provider.pickupLocation != null &&
                    provider.dropLocation != null) {
                  provider.fetchFareEstimates();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEEBD2B),
                foregroundColor: const Color(0xFF1A1814),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRideOption(
          title: 'Bike',
          isSelected: provider.selectedVehicleType == 'bike',
          onTap: () => provider.selectVehicleType('bike'),
          time: _getTimeToDrop(fareEstimates['bike']),
          price: _getEstimatedFare(fareEstimates['bike']),
          icon: Icons.two_wheeler,
          isRecommended: false,
        ),
        _buildRideOption(
          title: 'Auto',
          isSelected: provider.selectedVehicleType == 'auto',
          onTap: () => provider.selectVehicleType('auto'),
          time: _getTimeToDrop(fareEstimates['auto']),
          price: _getEstimatedFare(fareEstimates['auto']),
          icon: Icons.electric_rickshaw,
          isRecommended: true,
        ),
        _buildRideOption(
          title: 'Car',
          isSelected: provider.selectedVehicleType == 'car',
          onTap: () => provider.selectVehicleType('car'),
          time: _getTimeToDrop(fareEstimates['car']),
          price: _getEstimatedFare(fareEstimates['car']),
          icon: Icons.directions_car,
          isRecommended: false,
        ),
        _buildRideOption(
          title: 'Car XL',
          subtitle: 'More Space',
          isSelected: provider.selectedVehicleType == 'car_xl',
          onTap: () => provider.selectVehicleType('car_xl'),
          time: _getTimeToDrop(fareEstimates['car_xl']),
          price: _getEstimatedFare(fareEstimates['car_xl']),
          icon: Icons.airline_seat_recline_extra,
          isRecommended: false,
        ),
        _buildRideOption(
          title: 'Premium',
          subtitle: 'Luxury Ride',
          isSelected: provider.selectedVehicleType == 'car_premium',
          onTap: () => provider.selectVehicleType('car_premium'),
          time: _getTimeToDrop(fareEstimates['car_premium']),
          price: _getEstimatedFare(fareEstimates['car_premium']),
          icon: Icons.diamond_outlined,
          isRecommended: false,
        ),
      ],
    );
  }

  String _getTimeToDrop(Map<String, dynamic>? estimate) {
    if (estimate == null || estimate['time_to_drop'] == null) {
      return '';
    }
    final timeToDrop = estimate['time_to_drop'];
    if (timeToDrop is num) {
      return 'Drop in ${timeToDrop.ceil()} min';
    }
    return '';
  }

  String _getEstimatedFare(Map<String, dynamic>? estimate) {
    if (estimate == null || estimate['estimated_fare'] == null) {
      return '₹...';
    }
    final fare = estimate['estimated_fare'];
    if (fare is num) {
      return '₹${fare.toStringAsFixed(0)}';
    } else if (fare is String) {
      return '₹$fare';
    }
    return '₹...';
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
          const Icon(
            Icons.account_balance_wallet,
            color: Color(0xFF94A3B8),
            size: 20,
          ),
          const SizedBox(width: 12),
          const Text(
            'Payment',
            style: TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
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
          color: isSelected
              ? const Color(0xFFEEBD2B)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFEEBD2B)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? const Color(0xFF1A1814)
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF1A1814)
                    : const Color(0xFFE2E8F0),
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
            title: Text(
              'Cancel Trip?',
              style: GoogleFonts.inter(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Are you sure you want to cancel and go back?',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Keep Going',
                  style: GoogleFonts.inter(color: const Color(0xFFEEBD2B)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  double _lastSnapExtent = 0.15;

  Widget _buildSnapAwareSheet(
    BuildContext context,
    MapProvider mapProvider,
    ScrollController scrollController,
  ) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        final newExtent = notification.extent;
        if ((newExtent <= 0.15 && _lastSnapExtent > 0.15) ||
            (newExtent >= 0.35 && _lastSnapExtent < 0.35)) {
          HapticFeedback.lightImpact();
          _lastSnapExtent = newExtent;
        }
        return false;
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1C18),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 48,
                height: 6,
                // Reduce top margin to save vertical space in minimized view
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            _buildCollapsedHeader(mapProvider),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildExpandedContent(mapProvider, scrollController),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedHeader(MapProvider mapProvider) {
    return GestureDetector(
      onTap: () {
        // Toggle between 15% and 70% height on click
        final currentExtent = _sheetController.size;
        final targetExtent = currentExtent > 0.35 ? 0.15 : 0.70;
        _sheetController.animateTo(
          targetExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        // Reduce vertical padding from 16 to 8 to fit within 15% height constraint
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        // Add a transparent background to ensure the entire area is hittable
        color: Colors.transparent,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.route, color: Color(0xFFEEBD2B), size: 18),
                const SizedBox(width: 8),
                Text(
                  mapProvider.distance ?? '--',
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
                  mapProvider.duration ?? '--',
                  style: const TextStyle(
                    color: Color(0xFFEEBD2B),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.bookmark_add_outlined,
                    color: Color(0xFFEEBD2B),
                  ),
                  tooltip: 'Save location',
                  onPressed: () {
                    if (mapProvider.dropLocation != null) {
                      context.read<MapProvider>().saveLocation(
                            mapProvider.dropLocation!.name,
                            mapProvider.dropLocation!.latitude,
                            mapProvider.dropLocation!.longitude,
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Destination saved to favorites'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildPullUpHint(),
          ],
        ),
      ),
    );
  }

  Widget _buildPullUpHint() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Opacity(
          opacity: 0.5 + (0.5 * (1 - value)),
          child: Transform.translate(
            offset: Offset(0, 4 * (1 - value)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.white.withOpacity(0.4),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Pull up for more options',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpandedContent(
    MapProvider mapProvider,
    ScrollController scrollController,
  ) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
          _buildFareEstimatesSection(mapProvider, scrollController),
          const SizedBox(height: 16),
          _buildPaymentMethodSelector(mapProvider),
          Padding(
            padding: EdgeInsets.only(
              top: 16,
              left: 24,
              right: 24,
              // Use safe area bottom or a fixed reasonable padding, but avoid fractional overflow
              bottom: (MediaQuery.of(context).padding.bottom + 16).clamp(16.0, 100.0),
            ),
            child: ElevatedButton(
              onPressed: mapProvider.selectedVehicleType == null
                  ? null
                  : () {
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
                    ? 'Confirm ${_getVehicleTypeDisplay(mapProvider.selectedVehicleType)}'
                    : 'Select a Ride',
              ),
            ),
        ),
      ],
    );
  }
}
