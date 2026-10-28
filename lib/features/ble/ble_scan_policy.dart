// ============================================================================
// ble_scan_policy.dart — pure scan/reconnect timing (host-testable)
// ============================================================================

/// Policy for when BLE scans may start. No FlutterBlue dependency.
///
/// Prevents Android "scanning too frequently" by enforcing:
/// - single logical scan session
/// - min gap between start attempts
/// - longer backoff after rate-limit failures
/// - at most one scan-timeout → rescan schedule
class BleScanPolicy {
  BleScanPolicy({
    this.minStartGap = const Duration(seconds: 5),
    this.rateLimitBackoff = const Duration(seconds: 20),
    this.scanDuration = const Duration(seconds: 15),
  });

  final Duration minStartGap;
  final Duration rateLimitBackoff;
  final Duration scanDuration;

  bool scanning = false;
  /// True from claim until end/fail — covers async permission gap before OS scan.
  bool kickoff = false;
  bool connecting = false;
  bool connected = false;

  DateTime? _lastStartAttempt;
  DateTime? _backoffUntil;
  bool _timeoutPending = false;

  /// Whether a new startScan is allowed at [now].
  bool canStartScan(DateTime now, {bool force = false}) {
    if (connecting) return false;
    if (!force && connected) return false;
    if (scanning || kickoff) return false;
    if (_backoffUntil != null && now.isBefore(_backoffUntil!)) return false;
    if (_lastStartAttempt != null) {
      final gap = now.difference(_lastStartAttempt!);
      if (gap < minStartGap) return false;
    }
    return true;
  }

  /// Claim the scan slot immediately (before await permissions).
  /// Returns false if another kickoff already owns the slot.
  bool tryBeginKickoff(DateTime now, {bool force = false}) {
    if (!canStartScan(now, force: force)) return false;
    kickoff = true;
    _lastStartAttempt = now;
    return true;
  }

  /// Call when OS startScan succeeds (scanner registered).
  void onScanStarted(DateTime now) {
    kickoff = false;
    scanning = true;
    _lastStartAttempt = now;
    _timeoutPending = true;
  }

  /// Call when scan ends cleanly (found target, stopped, or stream done).
  void onScanEnded() {
    kickoff = false;
    scanning = false;
    _timeoutPending = false;
  }

  /// Scan timed out without connect. Returns true if this was the active
  /// session's single timeout (caller should schedule one rescan).
  bool onScanTimeout() {
    if (!_timeoutPending) return false;
    _timeoutPending = false;
    kickoff = false;
    scanning = false;
    return true;
  }

  /// Android scanner registration failed (status 6 / rate limit).
  void onScanFailedRateLimit(DateTime now) {
    kickoff = false;
    scanning = false;
    _timeoutPending = false;
    _lastStartAttempt = now;
    _backoffUntil = now.add(rateLimitBackoff);
  }

  /// Generic startScan exception.
  void onScanFailed(DateTime now) {
    kickoff = false;
    scanning = false;
    _timeoutPending = false;
    _lastStartAttempt = now;
  }

  /// Watchdog may start scan only when idle and not connected.
  bool shouldWatchdogRescan() {
    if (connected || connecting || scanning || kickoff) return false;
    return true;
  }

  void onConnected() {
    connected = true;
    connecting = false;
    kickoff = false;
    scanning = false;
    _timeoutPending = false;
  }

  void onDisconnected() {
    connected = false;
  }

  void onConnecting(bool value) {
    connecting = value;
  }

  /// Cancel outstanding scan session without rate-limit backoff.
  void cancelScan() {
    kickoff = false;
    scanning = false;
    _timeoutPending = false;
  }

  Duration? remainingBackoff(DateTime now) {
    if (_backoffUntil == null) return null;
    final d = _backoffUntil!.difference(now);
    return d.isNegative ? null : d;
  }
}
