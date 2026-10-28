// ============================================================================
// main.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/keep_screen_on.dart';
import 'core/standby_timeout.dart';
import 'core/providers.dart';
import 'core/safe_bouncing_scroll_physics.dart';
import 'features/brew_log/brew_log_notifier.dart';
import 'features/ui/views/home_view.dart';

// ============================================================================
// APP ENTRY POINT
// ============================================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Kick BLE + brew-log. enableBackgroundWatch is safe to call twice;
    // connect/scan are single-flight.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(machineLinkProvider).enableBackgroundWatch();
      ref.read(brewLogProvider);
      ref.read(linkModeProvider); // saved Yhteys setting (auto | wifi | ble)
      ref.read(linkStatusProvider); // active link for the icon
      ref.read(bleNotifierProvider); // seed BT icon + watch
      ref.read(machineDataProvider); // live + stale-mode watchdog before first paint
      ref.read(keepScreenOnProvider); // load saved setting + apply wakelock
      ref.read(standbyStartupTimeoutProvider); // load saved startup standby time + send stby:start on connect
      ref.read(standbyBrewTimeoutProvider); // load saved brew standby time + send stby:brew on connect
      ref.read(standbyTemperatureProvider); // load saved standby temperature + send stbt on connect
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final repo = ref.read(machineLinkProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        repo.onAppResumed();
        // Re-bind brew log listener state after unlock
        ref.read(brewLogProvider);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Leave BLE connected — Android FGS keeps process alive for brew_log RX
        repo.onAppPaused();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always subscribe so multiparts are assembled even when Home is not rebuilt
    ref.watch(brewLogProvider);

    return MaterialApp(
      title: 'EspressoPico',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const AlwaysScrollableScrollPhysics(
          parent: SafeBouncingScrollPhysics(),
        ),
      ),
      home: const HomeView(),
    );
  }
}
