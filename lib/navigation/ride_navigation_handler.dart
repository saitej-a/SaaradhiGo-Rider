import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../state/ride_notifier.dart';
import '../state/ride_state.dart';

class RideNavigationHandler extends ConsumerWidget {
  final Widget child;

  const RideNavigationHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to changes in the ride state globally
    ref.listen<RideState>(rideNotifierProvider, (previous, next) {
      if (previous?.status == next.status) return;

      // Navigate based on the new state
      switch (next.status) {
        case RideStatus.searchingDriver:
          context.push('/searching-driver');
          break;
        case RideStatus.driverAccepted:
        case RideStatus.driverArrived:
          // Using pushReplacement/go based on desired backstack behavior
          // go() clears stack to the path. push() adds to backstack.
          // Since it's an ongoing ride, we typically use go() or pushReplacement
          context.go('/driver-found');
          break;
        case RideStatus.rideStarted:
          context.go('/tracking');
          break;
        case RideStatus.rideCompleted:
        case RideStatus.paymentPending:
          context.go('/ride-summary');
          break;
        case RideStatus.rated:
        case RideStatus.cancelled:
        case RideStatus.none:
          // Fallback to home when ride is completely cleared
          context.go('/home');
          break;
      }
    });

    return child;
  }
}
