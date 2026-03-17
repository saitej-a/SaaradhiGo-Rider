import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'providers/auth_provider.dart';
import 'providers/map_provider.dart';
import 'providers/history_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/notification_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Import Screens (to be created)
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/profile/profile_setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/rider_flow_screens.dart' hide RouteMapScreen, PrivacySecurityScreen, EditPersonalInformationScreen, HelpSupportScreen, ManagePaymentMethodsScreen;
import 'screens/home/notification_screen.dart';
import 'screens/home/route_map_screen.dart';
import 'screens/home/precise_pickup_screen.dart';
import 'screens/profile/privacy_security_screen.dart';
import 'screens/profile/edit_personal_information_screen.dart';
import 'screens/profile/help_support_screen.dart';
import 'screens/profile/manage_payment_methods_screen.dart';

import 'services/push_notification_service.dart';
import 'services/ongoing_ride_notification_service.dart';

import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase background init error: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // For Web, this requires firebase_options.dart which is missing.
    // On Android/iOS with native config, it works without options.
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await PushNotificationService.initialize();
    await OngoingRideNotificationService.initialize();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  await dotenv.load(fileName: "assets/.env");
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
  final token = prefs.getString('access_token');
  final isLoggedIn = token != null && token.isNotEmpty;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: VahanGoApp(isFirstLaunch: isFirstLaunch, isLoggedIn: isLoggedIn),
    ),
  );
}

class VahanGoApp extends StatelessWidget {
  final bool isFirstLaunch;
  final bool isLoggedIn;

  const VahanGoApp({
    super.key,
    required this.isFirstLaunch,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: isFirstLaunch
          ? '/splash'
          : (isLoggedIn ? '/home' : '/login'),
      routes: <RouteBase>[
        GoRoute(
          path: '/splash',
          builder: (BuildContext context, GoRouterState state) =>
              const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (BuildContext context, GoRouterState state) =>
              const LoginScreen(),
        ),
        GoRoute(
          path: '/otp',
          builder: (BuildContext context, GoRouterState state) {
            final phone = state.extra as String? ?? '';
            return OtpVerificationScreen(phoneNumber: phone);
          },
        ),
        GoRoute(
          path: '/profile-setup',
          builder: (BuildContext context, GoRouterState state) =>
              const ProfileSetupScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (BuildContext context, GoRouterState state) {
            final parsedTabIndex = int.tryParse(
              state.uri.queryParameters['tab'] ?? '',
            );
            final initialTabIndex = (parsedTabIndex != null &&
                    parsedTabIndex >= 0 &&
                    parsedTabIndex <= 3)
                ? parsedTabIndex
                : 0;
            return HomeScreen(initialTabIndex: initialTabIndex);
          },
        ),
        GoRoute(
          path: '/notifications',
          builder: (BuildContext context, GoRouterState state) =>
              const NotificationScreen(),
        ),
        GoRoute(
          path: '/privacy-security',
          builder: (BuildContext context, GoRouterState state) =>
              const PrivacySecurityScreen(),
        ),
        GoRoute(
          path: '/personal-info',
          builder: (BuildContext context, GoRouterState state) =>
              const EditPersonalInformationScreen(),
        ),
        GoRoute(
          path: '/help-support',
          builder: (BuildContext context, GoRouterState state) =>
              const HelpSupportScreen(),
        ),
        GoRoute(
          path: '/payment-methods',
          builder: (BuildContext context, GoRouterState state) =>
              const ManagePaymentMethodsScreen(),
        ),
        GoRoute(
          path: '/set-destination',
          builder: (BuildContext context, GoRouterState state) =>
              const SetDestinationScreen(),
        ),
        GoRoute(
          path: '/route-map',
          builder: (BuildContext context, GoRouterState state) =>
              const RouteMapScreen(),
        ),
        GoRoute(
          path: '/precise-pickup',
          builder: (BuildContext context, GoRouterState state) =>
              const PrecisePickupScreen(),
        ),
        GoRoute(
          path: '/searching-driver',
          builder: (BuildContext context, GoRouterState state) =>
              const SearchingDriverScreen(),
        ),
        GoRoute(
          path: '/driver-found',
          builder: (BuildContext context, GoRouterState state) =>
              const DriverFoundScreen(),
        ),
        GoRoute(
          path: '/tracking',
          builder: (BuildContext context, GoRouterState state) =>
              const FullMapTrackingScreen(),
        ),
        GoRoute(
          path: '/ride-summary',
          builder: (BuildContext context, GoRouterState state) =>
              const RidePaymentSummaryScreen(),
        ),
        GoRoute(
          path: '/rate-driver',
          builder: (BuildContext context, GoRouterState state) =>
              const RateReviewDriverScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'VahanGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEEBD2B),
          primary: const Color(0xFFEEBD2B),
          surface: const Color(0xFFF8F7F6),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEEBD2B),
          primary: const Color(0xFFEEBD2B),
          surface: const Color(0xFF221D10),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
      ),
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
