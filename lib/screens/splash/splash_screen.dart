import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _autoAdvanceSplash();
  }

  void _autoAdvanceSplash() async {
    await _requestPermissions();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted && _currentPage == 0) {
      _pageController.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    }
  }

  Future<void> _requestPermissions() async {
    try {
      // 1. Notification Permission
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 2. Location Permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      debugPrint('Initial Permissions - Notification requested, Location: $permission');
    } catch (e) {
      debugPrint('Error requesting initial permissions: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _completeFirstLaunch(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    if (context.mounted) {
      context.go('/login');
    }
  }

  Widget _buildDotIndicator(int index) {
    bool isSelected = _currentPage == index;
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 6,
      width: isSelected ? 24 : 6,
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildInitializingPage() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Container(
          height: 96,
          width: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.4)],
            ),
            boxShadow: [
              BoxShadow(color: colorScheme.primary.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          padding: const EdgeInsets.all(2),
          child: Container(
            decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.navigation, size: 60, color: colorScheme.primary),
          ),
        ),
        const SizedBox(height: 24),
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            children: [
              const TextSpan(text: 'Saaradhi'),
              TextSpan(text: 'Go', style: TextStyle(color: colorScheme.primary)),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('INITIALIZING', style: TextStyle(fontSize: 10, letterSpacing: 2, color: colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.bold)),
                  Text('64%', style: TextStyle(fontSize: 10, color: colorScheme.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: 0.64,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                color: colorScheme.primary,
                minHeight: 2,
              ),
              const SizedBox(height: 24),
              Text('PRIORITIZING DRIVERS & RIDERS', style: TextStyle(fontSize: 11, letterSpacing: 3, color: colorScheme.onSurface.withValues(alpha: 0.4))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInspirationPage() {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        // Placeholder for background image
        Container(
          width: double.infinity,
          height: double.infinity,
          color: colorScheme.surfaceContainerHighest,
          child: Opacity(
            opacity: 0.5,
            child: Image.network(
              'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?q=80&w=1000&auto=format&fit=crop',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.image, size: 64)),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, colorScheme.surface.withValues(alpha: 0.8), colorScheme.surface],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Text('Our Inspiration', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                    const SizedBox(height: 16),
                    Text(
                      "We believe a happy driver provides the best service. That's why we prioritize driver welfare.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(4, (index) {
                        return index == 0 ? const SizedBox() : _buildDotIndicator(index);
                      }),
                    ),
                    ElevatedButton(
                      onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Row(
                        children: const [
                          Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumPage() {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: () => _completeFirstLaunch(context),
              child: Text('Skip', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5))),
            ),
          ),
          const Spacer(),
          Container(
            height: 96,
            width: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.1),
            ),
            child: Icon(Icons.directions_car, size: 48, color: colorScheme.primary),
          ),
          const SizedBox(height: 32),
          Text('Built for You', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "From seamless bookings to premium rides, every detail is crafted for your comfort and safety.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return index == 0 ? const SizedBox() : _buildDotIndicator(index);
            }),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Next', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityPage() {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.55,
          color: colorScheme.surfaceContainerHighest,
          child: Image.network(
            'https://images.unsplash.com/photo-1517400508447-f8dd518b86db?q=80&w=1000&auto=format&fit=crop',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.group, size: 64)),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, colorScheme.surface.withValues(alpha: 0.5), colorScheme.surface],
                stops: const [0.3, 0.5, 0.6],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Spacer(flex: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return index == 0 ? const SizedBox() : _buildDotIndicator(index);
                }),
              ),
              const SizedBox(height: 32),
              Text('Better Together', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  "SaaradhiGo is more than an app; it's a commitment to a transparent and fair mobility ecosystem.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _completeFirstLaunch(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Get Started', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        physics: _currentPage == 0 ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
        children: [
          _buildInitializingPage(), // Screen 1
          _buildInspirationPage(),  // Screen 2
          _buildPremiumPage(),      // Screen 3
          _buildCommunityPage(),    // Screen 4
        ],
      ),
    );
  }
}
