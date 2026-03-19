import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/notification_provider.dart';
import 'package:geolocator/geolocator.dart';

import '../../providers/auth_provider.dart';
import '../../providers/map_provider.dart';
import '../../services/map_service.dart';
import 'history_screen.dart';
import 'wallet_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late int _tabIndex;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropController = TextEditingController();
  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _dropFocusNode = FocusNode();
  bool _isGettingLocation = false;
  LatLng? _currentPosition;
  
  // Context safety: store references to providers
  MapProvider? _mapProvider;
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabIndex = widget.initialTabIndex.clamp(0, 3).toInt();
    
    // Listen to MapProvider for real-time redirection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _getCurrentLocation();
      context.read<MapProvider>().fetchDynamicHomeData();
      context.read<NotificationProvider>().fetchNotifications();
      
      _mapProvider = context.read<MapProvider>();
      _mapProvider?.addListener(_onMapProviderChanged);
      
      _checkAndRedirectActiveRide();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Use stored reference instead of context.read in dispose
    _mapProvider?.removeListener(_onMapProviderChanged);
    _pickupController.dispose();
    _dropController.dispose();
    _pickupFocusNode.dispose();
    _dropFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkAndRedirectActiveRide({bool isAutomatic = false}) async {
    if (!mounted || _isRedirecting) return;
    
    final mapProvider = _mapProvider ?? context.read<MapProvider>();
    
    // Safety: If we are already redirecting, or if the provider is in a stable state
    // that matches the current screen, we should avoid redundant checks.
    
    String currentRoute = '';
    try {
      // Use the router's state safely. If this fails, we are likely detached.
      currentRoute = GoRouter.of(context).routerDelegate.currentConfiguration.last.matchedLocation;
    } catch (e) {
      debugPrint('Guard: Failed to get current route, likely detached: $e');
      return;
    }

    if (!mounted) return;

    // Determine target based on provider state
    String? targetRoute;
    
    // Priority 1: Check actual ride status from response
    if (mapProvider.rideRequestResponse != null) {
      final status = mapProvider.rideRequestResponse['status'];
      if (status == 'accept' || status == 'reached') {
        targetRoute = '/driver-found';
      } else if (status == 'start' || status == 'active') {
        targetRoute = '/tracking';
      }
    } 
    
    // Priority 2: Check if currently searching
    if (targetRoute == null && mapProvider.isRequestingRide) {
      targetRoute = '/searching-driver';
    } 
    
    // Priority 3: Persistent check (for app restarts/deep links)
    if (targetRoute == null) {
      // Only do a server check if we are NOT in an automatic listener update
      // and we are currently on the Home tab.
      if (!isAutomatic && _tabIndex == 0) {
        final status = await mapProvider.checkActiveRide();
        if (!mounted) return;
        if (status == 'searching') {
          targetRoute = '/searching-driver';
        } else if (status == 'accept' || status == 'arrive') {
          targetRoute = '/driver-found';
        } else if (status == 'start' || status == 'active') {
          targetRoute = '/tracking';
        }
      }
    }

    // ONLY redirect if we are moving TO a ride screen FROM a non-ride screen (like home)
    // or if we are clearly on the wrong ride screen.
    final rideScreens = ['/searching-driver', '/driver-found', '/tracking'];
    bool onRideScreen = rideScreens.contains(currentRoute);
    
    if (targetRoute != null && targetRoute != currentRoute) {
      // If we are already on some ride screen, don't jump around unless it's a forward progression
      // The individual screens handle their own forward progression listeners.
      if (onRideScreen && isAutomatic) return;

      debugPrint('Redirecting to $targetRoute (current: $currentRoute)');
      _isRedirecting = true;
      
      if (!isAutomatic) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEEBD2B))),
                  SizedBox(width: 16),
                  Text('Resuming your active ride...'),
                ],
              ),
              duration: Duration(seconds: 1),
            ),
          );
        } catch (_) {}
      }
      
      context.push(targetRoute);
      
      // Keep guard active long enough for navigation to settle
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _isRedirecting = false;
      });
    }
  }

  void _onMapProviderChanged() {
    if (!mounted || _isRedirecting) return;
    
    // Passive guard: only trigger if we are on the Home screen
    String currentRoute = '';
    try {
      currentRoute = GoRouter.of(context).routerDelegate.currentConfiguration.last.matchedLocation;
    } catch (_) { return; }

    if (currentRoute != '/home') return;

    final mapProvider = _mapProvider ?? context.read<MapProvider>();
    if (mapProvider.isTripInProgress) {
        _checkAndRedirectActiveRide(isAutomatic: true);
    }
  }

  void _showActiveRideBookingGuard() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1C18),
        title: Text('Active Ride', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('You already have an active ride request or trip. Would you like to view it?', style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Dismiss', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkAndRedirectActiveRide();
            },
            child: Text('View Ride', style: GoogleFonts.inter(color: const Color(0xFFEEBD2B), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled. Please enable them in settings.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      }

      if (mounted) {
        String addressText = "Current Location";
        final mapService = MapService();
        final fetchedAddress = await mapService.getAddressFromCoordinates(position.latitude, position.longitude);
        if (fetchedAddress != null && fetchedAddress.isNotEmpty) {
          addressText = fetchedAddress;
        }

        if (mounted) {
          _pickupController.text = addressText;
          final provider = context.read<MapProvider>();
          await provider.setPickupLocation(
            'current', 
            defaultName: addressText,
            presetLocation: LatLng(position.latitude, position.longitude),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final tabs = [
      _HomeTab(
        pickupController: _pickupController,
        dropController: _dropController,
        pickupFocusNode: _pickupFocusNode,
        dropFocusNode: _dropFocusNode,
        onLocationTap: _getCurrentLocation,
        isGettingLocation: _isGettingLocation,
        currentPosition: _currentPosition,
        onActiveRideTap: _showActiveRideBookingGuard,
      ),
      const HistoryScreen(),
      const WalletScreen(),
      const _ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF1A1814),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 85),
              child: tabs[_tabIndex],
            ),
          ),
          _BottomNav(
            selectedIndex: _tabIndex,
            onItemTap: (index) {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() => _tabIndex = index);
            },
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.pickupController,
    required this.dropController,
    required this.pickupFocusNode,
    required this.dropFocusNode,
    required this.onLocationTap,
    required this.isGettingLocation,
    this.currentPosition,
    required this.onActiveRideTap,
  });

  final TextEditingController pickupController;
  final TextEditingController dropController;
  final FocusNode pickupFocusNode;
  final FocusNode dropFocusNode;
  final VoidCallback onLocationTap;
  final bool isGettingLocation;
  final LatLng? currentPosition;
  final VoidCallback onActiveRideTap;

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();
    final favorites = mapProvider.favoriteLocations;
    final recents = mapProvider.recentLocations;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        children: [
          const _TopHeader(),
          const SizedBox(height: 24),
          const Text(
            'Where are you\ngoing today?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w600,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 24),
          _LocationCard(
            pickupController: pickupController,
            dropController: dropController,
            pickupFocusNode: pickupFocusNode,
            dropFocusNode: dropFocusNode,
            onLocationTap: onLocationTap,
            isGettingLocation: isGettingLocation,
            currentPosition: currentPosition,
            onActiveRideTap: onActiveRideTap,
          ),
          const SizedBox(height: 26),
          const Text(
            'RECENT & SAVED',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 12),
          if (mapProvider.isLoadingHomeData && favorites.isEmpty && recents.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFEEBD2B))),
            )
          else ...[
            // Active Ride Tile
            if (mapProvider.isTripInProgress)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ActiveRideTile(
                  onTap: onActiveRideTap,
                ),
              ),

            // Favorites
            ...favorites.map((fav) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SavedTile(
                icon: Icons.bookmark,
                title: 'Saved',
                subtitle: fav.addressText,
                onTap: () {
                  final provider = context.read<MapProvider>();
                  if (provider.isTripInProgress) {
                    onActiveRideTap();
                    return;
                  }
                  // Navigate immediately, calculate route in background
                  context.push('/route-map');
                  provider.prepareAndCalculateRoute(
                    pickupName: pickupController.text.isNotEmpty ? pickupController.text : 'Current Location',
                    presetPickup: currentPosition,
                    dropPlaceId: fav.latitude != 0 ? '${fav.latitude},${fav.longitude}' : 'current',
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.bookmark_remove, color: Colors.white38, size: 20),
                  onPressed: () {
                    context.read<MapProvider>().deleteLocation(fav.id);
                  },
                ),
              ),
            )),
            // Recents
            ...recents.map((trip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SavedTile(
                icon: Icons.history,
                title: 'Recent Trip',
                subtitle: trip.destinationAddress,
                onTap: () {
                  final provider = context.read<MapProvider>();
                  if (provider.isTripInProgress) {
                    onActiveRideTap();
                    return;
                  }
                  // Navigate immediately, calculate route in background
                  context.push('/route-map');
                  if (trip.destinationLat != null && trip.destinationLng != null) {
                    provider.prepareAndCalculateRoute(
                      pickupName: pickupController.text.isNotEmpty ? pickupController.text : 'Current Location',
                      presetPickup: currentPosition,
                      dropPlaceId: '${trip.destinationLat},${trip.destinationLng}',
                    );
                  } else {
                    provider.fetchSuggestions(trip.destinationAddress);
                  }
                },
                trailing: IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined, color: Color(0xFFEEBD2B), size: 20),
                  onPressed: () {
                    if (trip.destinationLat != null && trip.destinationLng != null) {
                      context.read<MapProvider>().saveLocation(
                        trip.destinationAddress,
                        trip.destinationLat!,
                        trip.destinationLng!,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Location saved to favorites')),
                      );
                    }
                  },
                ),
              ),
            )),
            
            if (favorites.isEmpty && recents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No recent or saved locations',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                ),
              ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// History screen is now a separate component

// Wallet screen is now a separate component


// Profile tab implementation

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  static const String _fallbackName = 'John Doe';
  static const String _fallbackRating = '4.98';
  static const String _fallbackAvatarUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAPKZPGwmJqpCAihXSwtX1NVoImyBkmHzRpQ-VAOuMNCg1NdDM1Y5z1do2yqtE65Qal8OTMrMZednPquFBXo2pxr8NkTMmVDfafUMbVqlrJyooB_iaOuuthn_amKR15p3JWbeC17NBHKxjjTU4nZ3NU_L4DzcY5k1GbTVLX_ylAcrXRisGB6uoEAnuSpO8BJ-JJGe-Ogqdo_EKr7tMfCMRn22AmRjgpGPqbxrGZX-u_F5Y28uaFp0zNckZKrsJfwfzF_QET1MyTl1c';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final displayName = (auth.fullName?.trim().isNotEmpty ?? false)
        ? auth.fullName!.trim()
        : _fallbackName;
    final displayRating = (auth.rating?.trim().isNotEmpty ?? false)
        ? auth.rating!.trim()
        : _fallbackRating;
    final displayAvatar = (auth.avatarUrl?.trim().isNotEmpty ?? false)
        ? auth.avatarUrl!.trim()
        : _fallbackAvatarUrl;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _ProfileHeader(),
          const SizedBox(height: 24),
          const Text(
            'Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w600,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 24),
          Center(child: _ProfileAvatar(imageUrl: displayAvatar)),
          const SizedBox(height: 16),
          Center(
            child: Text(
              displayName,
              style: GoogleFonts.inter(
                color: const Color(0xFFF8FAFC),
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayRating,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEEBD2B),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFEEBD2B),
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _ProfileMenuTile(
            icon: Icons.person,
            title: 'Personal Information',
            onTap: () => context.push('/personal-info'),
          ),
          const SizedBox(height: 8),
          _ProfileMenuTile(
            icon: Icons.credit_card,
            title: 'Payment Methods',
            onTap: () => context.push('/payment-methods'),
          ),
          const SizedBox(height: 8),
          _ProfileMenuTile(
            icon: Icons.lock,
            title: 'Privacy & Security',
            onTap: () => context.push('/privacy-security'),
          ),
          const SizedBox(height: 8),
          _ProfileMenuTile(
            icon: Icons.help,
            title: 'Help & Support',
            onTap: () => context.push('/help-support'),
          ),
          const SizedBox(height: 8),
          const _ProfileMenuTile(icon: Icons.sell, title: 'Refer & Earn'),
          const SizedBox(height: 26),
          OutlinedButton(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              context.go('/login');
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF211D18),
              foregroundColor: const Color(0xFFF87171),
              side: const BorderSide(color: Color(0x33EF4444)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: Text(
              'Log Out',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'SaaradhiGo',
            style: TextStyle(
              color: Color(0xFFEEBD2B),
              fontSize: 23,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.6,
            ),
          ),
        ),
        Consumer<NotificationProvider>(
          builder: (context, provider, child) => GestureDetector(
            onTap: () => context.push('/notifications'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 3),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0x14FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications,
                      color: Color(0xFFE2E8F0),
                      size: 21,
                    ),
                  ),
                ),
                if (provider.unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${provider.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
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
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 116,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFEEBD2B),
        boxShadow: [
          BoxShadow(color: Color(0x99EEBD2B), blurRadius: 22, spreadRadius: 1),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            return Container(
              color: const Color(0xFF24211C),
              child: const Icon(
                Icons.person,
                size: 56,
                color: Color(0xFFCBD5E1),
              ),
            );
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: const Color(0xFF24211C),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFEEBD2B),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'SaaradhiGo',
            style: TextStyle(
              color: Color(0xFFEEBD2B),
              fontSize: 23,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.6,
            ),
          ),
        ),
        Consumer<NotificationProvider>(
          builder: (context, provider, child) => GestureDetector(
            onTap: () => context.push('/notifications'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 3),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0x14FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications,
                      color: Color(0xFFE2E8F0),
                      size: 21,
                    ),
                  ),
                ),
                if (provider.unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${provider.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
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
      ],
    );
  }
}

class _LocationCard extends StatefulWidget {
  const _LocationCard({
    required this.pickupController,
    required this.dropController,
    required this.pickupFocusNode,
    required this.dropFocusNode,
    required this.onLocationTap,
    required this.isGettingLocation,
    this.currentPosition,
    required this.onActiveRideTap,
  });

  final TextEditingController pickupController;
  final TextEditingController dropController;
  final FocusNode pickupFocusNode;
  final FocusNode dropFocusNode;
  final VoidCallback onLocationTap;
  final bool isGettingLocation;
  final LatLng? currentPosition;
  final VoidCallback onActiveRideTap;

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isSearching = false;
  bool _isPickupFocused = false;

  @override
  void initState() {
    super.initState();
    widget.dropFocusNode.addListener(() {
      if (!mounted) return;
      if (widget.dropFocusNode.hasFocus) {
        setState(() => _isPickupFocused = false);
        if (widget.dropController.text.length >= 4) {
          _showOverlay();
        } else {
          _hideOverlay();
        }
      }
    });

    widget.pickupFocusNode.addListener(() {
      if (!mounted) return;
      if (widget.pickupFocusNode.hasFocus) {
        setState(() => _isPickupFocused = true);
        // Only show overlay on focus if empty (to suggest Current Loc) or already has search text
        final text = widget.pickupController.text;
        if (text.isEmpty || (text.length >= 4 && text != 'Current Location')) {
          _showOverlay();
        } else {
          _hideOverlay();
        }
      }
    });

    widget.pickupController.addListener(_onPickupSearchChanged);
    widget.dropController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.pickupController.removeListener(_onPickupSearchChanged);
    widget.dropController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onPickupSearchChanged() {
    final text = widget.pickupController.text;
    
    // Safety check for user-defined threshold and specific strings
    if (text == 'Current Location' || text.isEmpty) {
      if (text.isEmpty && widget.pickupFocusNode.hasFocus) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
      return;
    }

    if (text.length >= 4) {
      context.read<MapProvider>().fetchSuggestions(text);
      if (!_isSearching) {
        setState(() {
          _isSearching = true;
          _isPickupFocused = true;
        });
        _showOverlay();
      }
    } else {
      context.read<MapProvider>().clearSuggestions();
      if (_isSearching && _isPickupFocused) {
        // If we were searching and now deleted below 4 chars, 
        // hide unless it's empty (which is handled above)
        setState(() => _isSearching = false);
        _hideOverlay();
      }
    }
  }

  void _onSearchChanged() {
    final text = widget.dropController.text;
    if (text.length >= 4) {
      context.read<MapProvider>().fetchSuggestions(text);
      if (!_isSearching) {
        setState(() {
          _isSearching = true;
          _isPickupFocused = false;
        });
        _showOverlay();
      }
    } else {
      context.read<MapProvider>().clearSuggestions();
      if (_isSearching && !_isPickupFocused) {
        setState(() => _isSearching = false);
        _hideOverlay();
      }
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: Offset(0.0, size.height + 8),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: size.width,
            child: TapRegion(
              groupId: 'location_search',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: DefaultTextStyle(
                  style: const TextStyle(decoration: TextDecoration.none),
                  child: _buildSuggestionsList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSuggestionsList() {
    return Material(
      color: Colors.transparent,
      child: Consumer<MapProvider>(
        builder: (context, mapProvider, child) {
          if (mapProvider.isLoadingSuggestions) {
            return _buildOverlayContainer(
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFEEBD2B)),
                ),
              ),
            );
          }

          if (mapProvider.suggestions.isEmpty && (!_isPickupFocused || widget.pickupController.text.isNotEmpty)) {
            return const SizedBox.shrink();
          }

          return _buildOverlayContainer(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isPickupFocused)
                    _buildCurrentLocationOption(),
                  if (mapProvider.suggestions.isNotEmpty)
                    ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: mapProvider.suggestions.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1, 
                        color: Color(0x1AFFFFFF),
                      ),
                      itemBuilder: (context, index) {
                        final suggestion = mapProvider.suggestions[index];
                        return _buildSuggestionTile(suggestion);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentLocationOption() {
    return ListTile(
      leading: const Icon(Icons.my_location, color: Color(0xFFEEBD2B)),
      title: const Text('Current Location', style: TextStyle(color: Colors.white)),
      onTap: () {
        if (context.read<MapProvider>().isTripInProgress) {
          _hideOverlay();
          widget.onActiveRideTap();
          return;
        }
        widget.onLocationTap();
        _hideOverlay();
        setState(() => _isSearching = false);
      },
    );
  }

  Widget _buildSuggestionTile(PlaceSuggestion suggestion) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final provider = context.read<MapProvider>();
        
        if (provider.isTripInProgress) {
          _hideOverlay();
          widget.onActiveRideTap();
          return;
        }
        
        if (_isPickupFocused) {
          widget.pickupController.text = suggestion.mainText;
          await provider.setPickupLocation(suggestion.placeId);
        } else {
          widget.dropController.text = suggestion.mainText;
          widget.dropFocusNode.unfocus();
          
          if (mounted) {
            context.push('/route-map');
          }
          
          await provider.prepareAndCalculateRoute(
            pickupName: widget.pickupController.text.isNotEmpty 
                ? widget.pickupController.text 
                : 'Current Location',
            presetPickup: provider.pickupLocation?.latLng ?? widget.currentPosition,
            dropPlaceId: suggestion.placeId,
          );
        }
        
        _hideOverlay();
        setState(() => _isSearching = false);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFF94A3B8)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.mainText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion.secondaryText,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOverlayContainer({required Widget child}) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF24211C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: 'location_search',
      onTapOutside: (_) {
        widget.dropFocusNode.unfocus();
        if (mounted) _hideOverlay();
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF24211C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x33FFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0x1AEEBD2B),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 10,
                        height: 10,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFEEBD2B),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 2,
                    height: 34,
                    color: const Color(0x1AFFFFFF),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InputSection(
                  label: 'CURRENT LOCATION',
                  controller: widget.pickupController,
                  focusNode: widget.pickupFocusNode,
                  hint: 'Enter pickup point',
                  readOnly: false,
                  suffixIcon: widget.isGettingLocation 
                      ? const SizedBox(
                          width: 18, 
                          height: 18, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEEBD2B))
                        )
                      : InkWell(
                          onTap: () {
                            if (context.read<MapProvider>().isTripInProgress) {
                              widget.onActiveRideTap();
                              return;
                            }
                            widget.onLocationTap();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(Icons.my_location, color: Color(0xFFEEBD2B), size: 18),
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: Icon(
                    Icons.location_on,
                    color: Color(0xFFEEBD2B),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InputSection(
                  label: 'DESTINATION',
                  controller: widget.dropController,
                  focusNode: widget.dropFocusNode,
                  hint: 'Search destination',
                  isHintBig: true,
                ),
              ),
            ],
          ),
        ],
      ),
    )));
  }
}
class _InputSection extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final bool isHintBig;
  final bool readOnly;
  final Widget? suffixIcon;

  const _InputSection({
    required this.label,
    required this.controller,
    this.focusNode,
    required this.hint,
    this.isHintBig = false,
    this.readOnly = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                readOnly: readOnly,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isHintBig ? 22 : 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: const Color(0xFF94A3B8),
                    fontSize: isHintBig ? 22 : 18,
                    fontWeight: FontWeight.w600,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (suffixIcon != null) ...[
              const SizedBox(width: 8),
              suffixIcon!,
            ],
          ],
        ),
        if (label == 'CURRENT LOCATION') ...[
          const SizedBox(height: 10),
          Container(height: 1, color: const Color(0x1AFFFFFF)),
        ],
      ],
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1814),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFFEEBD2B)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}



class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF24211C), Color(0xFF221F1A)],
          ),
          border: Border.all(color: const Color(0x1AFFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF94A3B8), size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: const Color(0xFFE2E8F0),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF64748B), size: 24),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onItemTap});

  final int selectedIndex;
  final ValueChanged<int> onItemTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 84,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            decoration: const BoxDecoration(
              color: Color(0xE61A1814),
              border: Border(top: BorderSide(color: Color(0x0DFFFFFF))),
            ),
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home,
                  label: 'Home',
                  selected: selectedIndex == 0,
                  onTap: () => onItemTap(0),
                ),
                _NavItem(
                  icon: Icons.history,
                  label: 'History',
                  selected: selectedIndex == 1,
                  glowWhenSelected: true,
                  onTap: () => onItemTap(1),
                ),
                _NavItem(
                  icon: Icons.account_balance_wallet,
                  label: 'Wallet',
                  selected: selectedIndex == 2,
                  glowWhenSelected: true,
                  onTap: () => onItemTap(2),
                ),
                _NavItem(
                  icon: Icons.person,
                  label: 'Profile',
                  selected: selectedIndex == 3,
                  glowWhenSelected: true,
                  onTap: () => onItemTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.glowWhenSelected = false,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool glowWhenSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color itemColor = selected
        ? const Color(0xFFEEBD2B)
        : const Color(0xFF94A3B8);
    final List<Shadow>? shadows = selected && glowWhenSelected
        ? const [Shadow(color: Color(0x80EEBD2B), blurRadius: 8)]
        : null;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: itemColor, size: 24, shadows: shadows),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: itemColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                shadows: shadows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _ActiveRideTile extends StatelessWidget {
  const _ActiveRideTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();
    final destination = mapProvider.destinationAddress ?? 'Active Ride';
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEBD2B).withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEBD2B).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEBD2B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car, color: Color(0xFF1A1814)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Ongoing Ride',
                          style: TextStyle(
                            color: Color(0xFFEEBD2B),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFEEBD2B)),
            ],
          ),
        ),
      ),
    );
  }
}
