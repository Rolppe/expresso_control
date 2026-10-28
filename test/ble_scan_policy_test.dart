import 'package:flutter_test/flutter_test.dart';
import 'package:silvia_pico_ui/features/ble/ble_scan_policy.dart';

void main() {
  late BleScanPolicy p;
  late DateTime t0;

  setUp(() {
    p = BleScanPolicy(
      minStartGap: const Duration(seconds: 5),
      rateLimitBackoff: const Duration(seconds: 20),
    );
    t0 = DateTime.utc(2026, 1, 1, 12, 0, 0);
  });

  test('CI-BLE1: second start before gap rejected', () {
    expect(p.canStartScan(t0), isTrue);
    p.onScanStarted(t0);
    expect(p.canStartScan(t0.add(const Duration(seconds: 1))), isFalse);
    p.onScanEnded();
    // still within min gap from last attempt
    expect(p.canStartScan(t0.add(const Duration(seconds: 2))), isFalse);
    expect(p.canStartScan(t0.add(const Duration(seconds: 6))), isTrue);
  });

  test('CI-BLE2: timeout fires once; cancel clears pending', () {
    p.onScanStarted(t0);
    expect(p.onScanTimeout(), isTrue);
    expect(p.onScanTimeout(), isFalse); // no multi timed-out
    p.onScanStarted(t0.add(const Duration(seconds: 10)));
    p.cancelScan();
    expect(p.onScanTimeout(), isFalse);
  });

  test('CI-BLE3: rate-limit backoff ≥20s', () {
    p.onScanStarted(t0);
    p.onScanFailedRateLimit(t0);
    expect(p.canStartScan(t0.add(const Duration(seconds: 5))), isFalse);
    expect(p.canStartScan(t0.add(const Duration(seconds: 19))), isFalse);
    expect(p.canStartScan(t0.add(const Duration(seconds: 21))), isTrue);
  });

  test('CI-BLE4: watchdog while scanning → no rescan', () {
    p.onScanStarted(t0);
    expect(p.shouldWatchdogRescan(), isFalse);
    p.onScanEnded();
    expect(p.shouldWatchdogRescan(), isTrue);
  });

  test('CI-BLE5: connected → force=false skip; force=true allowed', () {
    p.onConnected();
    expect(p.canStartScan(t0, force: false), isFalse);
    expect(p.canStartScan(t0, force: true), isTrue);
  });

  test('CI-BLE5b: force allows start while not connected after gap', () {
    p.onDisconnected();
    expect(p.canStartScan(t0, force: true), isTrue);
  });

  test('connecting blocks start', () {
    p.onConnecting(true);
    expect(p.canStartScan(t0), isFalse);
  });

  test('kickoff blocks concurrent start before OS scan', () {
    expect(p.tryBeginKickoff(t0), isTrue);
    expect(p.tryBeginKickoff(t0), isFalse);
    expect(p.canStartScan(t0), isFalse);
    p.onScanFailed(t0);
    // still within min gap
    expect(p.canStartScan(t0.add(const Duration(seconds: 1))), isFalse);
    expect(p.canStartScan(t0.add(const Duration(seconds: 6))), isTrue);
  });
}
