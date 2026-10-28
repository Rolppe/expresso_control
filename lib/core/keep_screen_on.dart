// ============================================================================
// keep_screen_on.dart — "Keep screen on" app setting (SharedPreferences + wakelock)
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'debug_log.dart';

const String _prefKey = 'keepScreenOn';

/// Persistent "keep screen on" flag (default false). Loads the stored value at
/// startup and applies it to the wakelock; setting it saves and applies.
class KeepScreenOnNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool(_prefKey) ?? false;
      state = value;
      await _apply(value);
    } catch (e) {
      DLog.sys('keepScreenOn load failed: $e');
    }
  }

  Future<void> set(bool value) async {
    state = value;
    await _apply(value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (e) {
      DLog.sys('keepScreenOn save failed: $e');
    }
  }

  Future<void> _apply(bool value) async {
    try {
      if (value) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (e) {
      DLog.sys('keepScreenOn wakelock failed: $e');
    }
  }
}

final keepScreenOnProvider =
    NotifierProvider<KeepScreenOnNotifier, bool>(() => KeepScreenOnNotifier());
