import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../link/link_selector.dart';
import '../../core/providers.dart';
import '../../core/debug_log.dart';

// ============================================================================
// BLE NOTIFIER — connection state of the active link (BLE or Wi-Fi)
// ============================================================================

class BLENotifier extends Notifier<bool> {
  late final LinkSelector _repository;
  StreamSubscription<bool>? _connectionSubscription;

  @override
  bool build() {
    // Keep notifier alive with the repository
    ref.keepAlive();
    _repository = ref.watch(machineLinkProvider);

    _connectionSubscription?.cancel();
    _connectionSubscription = _repository.isConnectedStream.listen((connected) {
      // Schedule after build completes — never touch state synchronously in build
      Future.microtask(() {
        DLog.ble('notifier isConnected=$connected');
        state = connected;
      });
    });

    ref.onDispose(() {
      // Do NOT disconnect BLE — only cancel UI subscription
      _connectionSubscription?.cancel();
      _connectionSubscription = null;
    });

    // Background watch (BLE scan + Wi-Fi) + sync icon to actual link (broadcast stream has no replay,
    // so we must seed state after watch starts / if already connected).
    Future.microtask(() async {
      DLog.sys('BLENotifier build — enable background watch');
      await _repository.enableBackgroundWatch();
      final now = _repository.isConnected;
      DLog.ble('notifier seed isConnected=$now');
      state = now;
    });

    return _repository.isConnected;
  }

  void startScan() {
    DLog.ble('notifier.startScan()');
    _repository.startScan();
  }

  void sendCommand(String command) {
    DLog.ble('notifier.sendCommand($command)');
    _repository.sendCommand(command);
  }

  void disconnect() {
    DLog.ble('notifier.disconnect()');
    _repository.disconnect();
  }
}
