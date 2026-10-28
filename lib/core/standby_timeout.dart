// ============================================================================
// standby_timeout.dart — "Standby after" app settings (SharedPreferences + stby:*)
// ============================================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'debug_log.dart';
import 'providers.dart';
import '../features/ble/ble_repository.dart';

const String _startupPrefKey = 'standbyStartupTimeoutMin';
const String _brewPrefKey = 'standbyTimeoutMin';

/// Firmware defaults (RAM only on Pico):
const int standbyStartupFirmwareDefaultMin = 120; // 2 h
const int standbyBrewFirmwareDefaultMin = 30;     // 30 min

/// Choices for startup standby: 1 h to 4 h (every 15 min).
const List<int> standbyStartupTimeoutChoices = [
  60, 75, 90, 105, 120, 135, 150, 165, 180, 195, 210, 225, 240,
];

/// Choices for post-brew / steam standby: 15 min to 2 h (every 15 min).
const List<int> standbyBrewTimeoutChoices = [
  15, 30, 45, 60, 75, 90, 105, 120,
];

/// Legacy alias for backwards compatibility:
const List<int> standbyTimeoutChoices = standbyBrewTimeoutChoices;

String standbyTimeoutLabel(int minutes) {
  if (minutes == 0) return 'Pois';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}

// ---------------------------------------------------------------------------
// 1. Standby after startup (Käynnistyksen jälkeen, 1h - 4h, oletus 2h)
// ---------------------------------------------------------------------------

class StandbyStartupTimeoutNotifier extends Notifier<int> {
  StreamSubscription<bool>? _connSub;
  bool _loaded = false;

  @override
  int build() {
    final repo = ref.read(machineLinkProvider);
    _connSub = repo.isConnectedStream.listen((connected) {
      if (connected) {
        // After settings sync (1200 ms)
        Future<void>.delayed(const Duration(milliseconds: 1200), _send);
      }
    });
    ref.onDispose(() => _connSub?.cancel());
    _load();
    return standbyStartupFirmwareDefaultMin;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_loaded) return;
      _loaded = true;
      final value = prefs.getInt(_startupPrefKey) ?? standbyStartupFirmwareDefaultMin;
      state = value;
      if (value != standbyStartupFirmwareDefaultMin) await _send();
    } catch (e) {
      DLog.sys('standbyStartupTimeout load failed: $e');
    }
  }

  Future<void> set(int minutes) async {
    _loaded = true;
    state = minutes;
    await _send();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_startupPrefKey, minutes);
    } catch (e) {
      DLog.sys('standbyStartupTimeout save failed: $e');
    }
  }

  Future<void> _send() async {
    final repo = ref.read(machineLinkProvider);
    if (!repo.isConnected && !BLERepository.demoMode) return;
    await repo.sendCommand('stby:start:$state');
  }
}

final standbyStartupTimeoutProvider =
    NotifierProvider<StandbyStartupTimeoutNotifier, int>(() => StandbyStartupTimeoutNotifier());

// ---------------------------------------------------------------------------
// 2. Standby after brew / steam (Uuton tai höyrytyksen jälkeen, 15min - 2h)
// ---------------------------------------------------------------------------

class StandbyBrewTimeoutNotifier extends Notifier<int> {
  StreamSubscription<bool>? _connSub;
  bool _loaded = false;

  @override
  int build() {
    final repo = ref.read(machineLinkProvider);
    _connSub = repo.isConnectedStream.listen((connected) {
      if (connected) {
        // After startup timeout send (1400 ms)
        Future<void>.delayed(const Duration(milliseconds: 1400), _send);
      }
    });
    ref.onDispose(() => _connSub?.cancel());
    _load();
    return standbyBrewFirmwareDefaultMin;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_loaded) return;
      _loaded = true;
      final value = prefs.getInt(_brewPrefKey) ?? standbyBrewFirmwareDefaultMin;
      state = value;
      if (value != standbyBrewFirmwareDefaultMin) await _send();
    } catch (e) {
      DLog.sys('standbyBrewTimeout load failed: $e');
    }
  }

  Future<void> set(int minutes) async {
    _loaded = true;
    state = minutes;
    await _send();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_brewPrefKey, minutes);
    } catch (e) {
      DLog.sys('standbyBrewTimeout save failed: $e');
    }
  }

  Future<void> _send() async {
    final repo = ref.read(machineLinkProvider);
    if (!repo.isConnected && !BLERepository.demoMode) return;
    await repo.sendCommand('stby:brew:$state');
  }
}

final standbyBrewTimeoutProvider =
    NotifierProvider<StandbyBrewTimeoutNotifier, int>(() => StandbyBrewTimeoutNotifier());

/// Backwards compatibility alias:
typedef StandbyTimeoutNotifier = StandbyBrewTimeoutNotifier;
final standbyTimeoutProvider = standbyBrewTimeoutProvider;

// ---------------------------------------------------------------------------
// 3. "Standby temperature" app setting (SharedPreferences + stbt:<C>, 6.10.2026)
// ---------------------------------------------------------------------------

const String _tempPrefKey = 'standbyTemperatureC';

/// Pico default: stbt is RAM only, so every restart and flash returns to 90 °C.
const int standbyTemperatureFirmwareDefaultC = 90;

/// Choices in °C, every 5 °C; the Pico clamps to the same 60–95.
const List<int> standbyTemperatureChoices = [60, 65, 70, 75, 80, 85, 90, 95];

/// Boiler target in standby. The Pico uses min(brew, this). Saved in the app
/// and sent as `stbt:<C>` on change and after every connect, because the Pico
/// forgets it on restart. stbt is not activity on the Pico, so resending it
/// never wakes the boiler from standby.
class StandbyTemperatureNotifier extends Notifier<int> {
  StreamSubscription<bool>? _connSub;
  bool _loaded = false;

  @override
  int build() {
    final repo = ref.read(machineLinkProvider);
    _connSub = repo.isConnectedStream.listen((connected) {
      if (connected && state != standbyTemperatureFirmwareDefaultC) {
        // After the settings sync and the stby resends (1600 ms).
        Future<void>.delayed(const Duration(milliseconds: 1600), _send);
      }
    });
    ref.onDispose(() => _connSub?.cancel());
    _load();
    return standbyTemperatureFirmwareDefaultC;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_loaded) return;
      _loaded = true;
      final value =
          prefs.getInt(_tempPrefKey) ?? standbyTemperatureFirmwareDefaultC;
      state = value;
      if (value != standbyTemperatureFirmwareDefaultC) await _send();
    } catch (e) {
      DLog.sys('standbyTemperature load failed: $e');
    }
  }

  Future<void> set(int celsius) async {
    _loaded = true;
    state = celsius;
    await _send();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_tempPrefKey, celsius);
    } catch (e) {
      DLog.sys('standbyTemperature save failed: $e');
    }
  }

  Future<void> _send() async {
    final repo = ref.read(machineLinkProvider);
    if (!repo.isConnected && !BLERepository.demoMode) return;
    await repo.sendCommand('stbt:$state');
  }
}

final standbyTemperatureProvider =
    NotifierProvider<StandbyTemperatureNotifier, int>(
        () => StandbyTemperatureNotifier());
