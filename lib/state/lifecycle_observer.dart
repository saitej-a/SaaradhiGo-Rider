import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/ride_notifier.dart';

class LifecycleObserver extends ConsumerStatefulWidget {
  final Widget child;

  const LifecycleObserver({super.key, required this.child});

  @override
  ConsumerState<LifecycleObserver> createState() => _LifecycleObserverState();
}

class _LifecycleObserverState extends ConsumerState<LifecycleObserver> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load persisted state as early as possible
    WidgetsBinding.instance.addPostFrameCallback((_) {
       ref.read(rideNotifierProvider.notifier).loadInitialState();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Background -> Foreground transition
      // We could trigger a network sync here (e.g., fetch active trip status via REST API)
      // For now, load locally so any missed socket states from background notifications update
      ref.read(rideNotifierProvider.notifier).loadInitialState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
