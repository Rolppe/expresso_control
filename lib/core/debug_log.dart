// ============================================================================
// debug_log.dart — structured app-side logging (logcat / flutter run)
// ============================================================================
// Toggle tags without hunting print calls.
//
// Usage:
//   DLog.ble('command sent pit:3.0');
//   DLog.ui('slider pre end');
//   DLog.change('mode', previous, next);
//
// logcat filter:
//   adb logcat | grep -E '\[BLE\]|\[UI\]|\[SET\]|\[DATA\]|\[SYS\]'

import 'package:flutter/foundation.dart';

class DLog {
  /// Master switch. Release builds still print if true (useful for field debug).
  static bool enabled = true;

  static const Map<String, bool> tags = {
    'BLE': true,
    'UI': true,
    'SET': true,
    'DATA': true,
    'SYS': true,
  };

  static final Map<String, DateTime> _lastThrottle = {};
  static final Map<String, Object?> _lastChange = {};

  static void _log(String tag, String msg) {
    if (!enabled) return;
    // In release, still allow when enabled=true (field debugging)
    if (!kDebugMode && !enabled) return;
    if (tags[tag] != true) return;
    // ignore: avoid_print
    print('[$tag] $msg');
  }

  static void ble(String msg) => _log('BLE', msg);
  static void ui(String msg) => _log('UI', msg);
  static void set(String msg) => _log('SET', msg);
  static void data(String msg) => _log('DATA', msg);
  static void sys(String msg) => _log('SYS', msg);

  /// At most once per [interval] for a given key.
  static void throttle(
    String tag,
    String key,
    String msg, {
    Duration interval = const Duration(seconds: 2),
  }) {
    if (!enabled || tags[tag] != true) return;
    final k = '$tag:$key';
    final now = DateTime.now();
    final prev = _lastThrottle[k];
    if (prev != null && now.difference(prev) < interval) return;
    _lastThrottle[k] = now;
    _log(tag, msg);
  }

  /// Print only when [value] differs from the last call for [key].
  static void change(String tag, String key, Object? value) {
    if (!enabled || tags[tag] != true) return;
    final k = '$tag:$key';
    final hasPrev = _lastChange.containsKey(k);
    final prev = _lastChange[k];
    if (hasPrev && prev == value) return;
    _lastChange[k] = value;
    if (!hasPrev) {
      _log(tag, '$key = $value');
    } else {
      _log(tag, '$key: $prev -> $value');
    }
  }
}
