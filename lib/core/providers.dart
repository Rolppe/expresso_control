import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/ble/ble_repository.dart';
import '../features/ble/ble_notifier.dart';
import '../features/data/machine_data_notifier.dart';
import '../features/link/link_selector.dart';
import '../features/link/wifi_key_store.dart';
import '../features/link/wifi_repository.dart';
import '../models/machine_status.dart';
import 'debug_log.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

/// Low-level Bluetooth repository — keepAlive so leaving UI / background
/// does not dispose and kill the GATT link. BLE-specific code only; the rest
/// of the app goes through [machineLinkProvider].
final bleRepositoryProvider = Provider<BLERepository>((ref) {
  ref.keepAlive();
  // Singleton: never dispose the live BLE stack while process lives
  return BLERepository.instance;
});

/// Where the Wi-Fi link key / address live (iOS Keychain).
final wifiKeyStoreProvider = Provider<WifiKeyStore>((ref) {
  ref.keepAlive();
  return SecureWifiKeyStore();
});

/// The Wi-Fi link to the Pico (UDP).
final wifiRepositoryProvider = Provider<WifiRepository>((ref) {
  ref.keepAlive();
  return WifiRepository(store: ref.watch(wifiKeyStoreProvider));
});

/// "Yhteys" setting: auto | wifi | ble (SharedPreferences `linkMode`).
final linkModeProvider =
    NotifierProvider<LinkModeNotifier, LinkMode>(() => LinkModeNotifier());

class LinkModeNotifier extends Notifier<LinkMode> {
  static const _prefKey = 'linkMode';

  @override
  LinkMode build() {
    _load();
    return LinkMode.auto;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = linkModeFromName(prefs.getString(_prefKey));
    } catch (e) {
      DLog.sys('linkMode load failed: $e');
    }
  }

  Future<void> set(LinkMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.name);
    } catch (e) {
      DLog.sys('linkMode save failed: $e');
    }
  }
}

/// What the UI talks to: BLE or Wi-Fi, chosen by [LinkSelector]. BLE keeps
/// running underneath whichever is active.
final machineLinkProvider = Provider<LinkSelector>((ref) {
  ref.keepAlive();
  final ble = ref.watch(bleRepositoryProvider);
  final selector = LinkSelector(
    ble: ble,
    wifi: ref.watch(wifiRepositoryProvider),
    keyStore: ref.watch(wifiKeyStoreProvider),
    mode: ref.read(linkModeProvider),
    bleWatch: ble.enableBackgroundWatch,
    // the demo build has no Pico on the network and no BLE key to ask for
    wifiEnabled: !BLERepository.demoMode,
    autoKeyRequest: !BLERepository.demoMode,
  );
  ref.listen<LinkMode>(linkModeProvider, (_, m) => selector.setMode(m));
  ref.onDispose(selector.dispose);
  return selector;
});

/// Active link, mode and Wi-Fi details for the icon and Settings.
final linkStatusProvider =
    NotifierProvider<LinkStatusNotifier, LinkStatus>(() => LinkStatusNotifier());

class LinkStatusNotifier extends Notifier<LinkStatus> {
  StreamSubscription<LinkStatus>? _sub;

  @override
  LinkStatus build() {
    ref.keepAlive();
    final selector = ref.read(machineLinkProvider);
    _sub?.cancel();
    _sub = selector.statusStream.listen((s) => state = s);
    ref.onDispose(() => _sub?.cancel());
    return selector.status;
  }
}

/// Bluetooth connection status
final bleNotifierProvider = NotifierProvider<BLENotifier, bool>(() => BLENotifier());

/// All machine data and graph state
final machineDataProvider = NotifierProvider<MachineDataNotifier, MachineStatus>(
  () => MachineDataNotifier(),
);
