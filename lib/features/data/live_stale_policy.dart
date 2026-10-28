// ============================================================================
// live_stale_policy.dart — when live telemetry stalls, clear frozen brew mode
// ============================================================================

/// Pure policy: UI must not stay on BREW / SOFT_RELEASE forever when BLE
/// still claims connected but live packets stop (zombie link / dual-app fight).
///
/// Thresholds differ by mode: SOFT_RELEASE ends quickly after the switch;
/// active brew tolerates longer multipack/live gaps.
class LiveStalePolicy {
  LiveStalePolicy({
    this.softReleaseTimeout = const Duration(seconds: 4),
    this.brewingTimeout = const Duration(seconds: 12),
  });

  final Duration softReleaseTimeout;
  final Duration brewingTimeout;

  /// Modes that should fall back to IDLE if live stalls.
  static const Set<String> activeModes = {
    'pre-infusion main',
    'brew loop',
    'PRE_INFUSION',
    'BREW',
    'SOFT_RELEASE',
  };

  static const Set<String> softReleaseModes = {
    'SOFT_RELEASE',
  };

  /// Returns true if [brewMode] should be forced to IDLE because no live
  /// telemetry arrived since [lastLiveAt] for longer than the mode timeout.
  bool shouldForceIdle({
    required String brewMode,
    required DateTime? lastLiveAt,
    required DateTime now,
  }) {
    if (!activeModes.contains(brewMode)) return false;
    if (lastLiveAt == null) return false;
    final timeout = softReleaseModes.contains(brewMode)
        ? softReleaseTimeout
        : brewingTimeout;
    return now.difference(lastLiveAt) >= timeout;
  }
}
