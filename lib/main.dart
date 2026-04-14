import 'dart:ui';
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
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'navigation/ride_navigation_handler.dart';
import 'state/lifecycle_observer.dart';
import 'state/ride_notifier.dart';
import 'state/ride_state.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/profile/profile_setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/rider_flow_screens.dart';
import 'screens/home/wallet_screen.dart';
import 'screens/home/payment_status_screen.dart';
import 'screens/home/notification_screen.dart';
import 'screens/home/route_map_screen.dart';
import 'screens/home/precise_pickup_screen.dart';
import 'screens/profile/privacy_security_screen.dart';
import 'screens/profile/edit_personal_information_screen.dart';
import 'screens/profile/help_support_screen.dart';
import 'screens/profile/manage_payment_methods_screen.dart';
import 'screens/home/add_money_screen.dart';
import 'screens/home/payment_success_screen.dart';

import 'screens/components/sync_overlay.dart';
import 'screens/components/cancelled_overlay.dart';
import 'screens/components/payment_pending_banner.dart';

import 'services/push_notification_service.dart';
import 'services/ongoing_ride_notification_service.dart';

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
  final container = riverpod.ProviderContainer();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await PushNotificationService.initialize(container);
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
    riverpod.UncontrolledProviderScope(
      container: container,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(
            create: (_) => MapProvider(container: container),
          ),
          ChangeNotifierProvider(create: (_) => HistoryProvider()),
          ChangeNotifierProvider(create: (_) => WalletProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ],
        child: VahanGoApp(isFirstLaunch: isFirstLaunch, isLoggedIn: isLoggedIn),
      ),
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
            final initialTabIndex =
                (parsedTabIndex != null &&
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
        GoRoute(
          path: '/add-money',
          builder: (BuildContext context, GoRouterState state) =>
              const AddMoneyScreen(),
        ),
        GoRoute(
          path: '/wallet',
          builder: (BuildContext context, GoRouterState state) =>
              const WalletScreen(),
        ),
        GoRoute(
          path: '/payment-status',
          builder: (BuildContext context, GoRouterState state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            final amountVal = extra['amount'];
            final newBalanceVal = extra['new_balance'];
            return PaymentStatusScreen(
              status: extra['status'] ?? 'success',
              amount: amountVal is double
                  ? amountVal
                  : (amountVal is num
                        ? amountVal.toDouble()
                        : double.tryParse(amountVal?.toString() ?? '')),
              transactionId: extra['transaction_id']?.toString(),
              newBalance: newBalanceVal is double
                  ? newBalanceVal
                  : (newBalanceVal is num
                        ? newBalanceVal.toDouble()
                        : double.tryParse(newBalanceVal?.toString() ?? '')),
              errorMessage: extra['error_message']?.toString(),
            );
          },
        ),
        GoRoute(
          path: '/payment-success',
          builder: (BuildContext context, GoRouterState state) =>
              const PaymentSuccessScreen(),
        ),
      ],
    );

    return RideNavigationHandler(
      child: LifecycleObserver(
        child: MaterialApp.router(
          title: 'VahanGo',
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return riverpod.Consumer(
              builder: (context, ref, _) {
                final rideState = ref.watch(rideNotifierProvider);
                return Stack(
                  children: [
                    if (child != null) child,
                    if (rideState.isSyncing) const SyncOverlay(),
                    if (rideState.showCancelledOverlay)
                      const CancelledOverlay(),
                    if (rideState.status == RideStatus.paymentPending)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: PaymentPendingBanner(),
                      ),
                  ],
                );
              },
            );
          },
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
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.mouse,
              PointerDeviceKind.touch,
              PointerDeviceKind.stylus,
              PointerDeviceKind.unknown,
            },
          ),
        ),
      ),
    );
  }
}
