// ============================================================================
// ble_repository.dart
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/debug_log.dart';
import 'ble_scan_policy.dart';
import 'demo_pico.dart';
import '../link/machine_link.dart';

// ============================================================================
// BLE REPOSITORY
// ============================================================================

class BLERepository implements MachineLink {
  /// Process-wide singleton — survives route changes; not disposed on background.
  static final BLERepository instance = BLERepository._();
  BLERepository._();

  static const String targetDeviceName = 'EspressoPico';
  static const _keepAliveChannel = MethodChannel('espressopico/ble_keepalive');

  // Match Pico bluetooth_handler.py (standard 16-bit UUIDs in 128-bit form)
  final Guid serviceUUID = Guid('0000180A-0000-1000-8000-00805F9B34FB');
  final Guid dataCharUUID = Guid('00002A29-0000-1000-8000-00805F9B34FB');
  final Guid commandCharUUID = Guid('00002A2A-0000-1000-8000-00805F9B34FB');

  BluetoothDevice? _device;
  BluetoothCharacteristic? _dataCharacteristic;
  BluetoothCharacteristic? _commandCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;

  /// BLE notifies may arrive in MTU-sized chunks; reassemble until a full JSON object.
  final StringBuffer _rxJsonBuf = StringBuffer();

  final _connectionController = StreamController<bool>.broadcast();
  final _dataController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<bool> get isConnectedStream => _connectionController.stream;
  @override
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  Timer? _reconnectTimer;
  Timer? _rescanTimer;
  Timer? _watchdogTimer;
  Timer? _scanTimeoutTimer;
  StreamSubscription? _scanSubscription;
  final BleScanPolicy _scanPolicy = BleScanPolicy();
  bool get _scanning => _scanPolicy.scanning;
  bool get _connecting => _scanPolicy.connecting;
  set _connecting(bool v) => _scanPolicy.onConnecting(v);
  bool _keepAliveRunning = false;
  /// Last value published on [isConnectedStream] (broadcast has no replay).
  bool _publishedConnected = false;
  /// Failed GATT bind attempts (exponential backoff).
  int _failStreak = 0;
  DateTime? _nextConnectAllowed;

  /// When true (default): always scan/reconnect in background if Pico is on air.
  bool backgroundMode = true;

  /// iOS simulator has no CoreBluetooth: --dart-define=EXPRESSO_DEMO=true swaps
  /// the GATT link for a simulated Pico (demo_pico.dart). Off in every other build.
  static const bool demoMode = bool.fromEnvironment('EXPRESSO_DEMO');
  DemoPico? _demo;

  void _startDemo() {
    _demo ??= DemoPico((json) {
      _publishConnected(true);
      if (!_dataController.isClosed) _dataController.add(json);
    });
    _demo!.start();
  }

  /// True when link is up and at least data notify is bound (live telemetry works).
  @override
  bool get isConnected {
    if (demoMode) return _demo?.running ?? false;
    final link = _device?.isConnected ?? false;
    if (!link) return false;
    // Prefer command+data; data-only still means we are talking to Pico.
    return _dataCharacteristic != null || _commandCharacteristic != null;
  }

  bool get _linkUp => _device?.isConnected ?? false;

  /// Publish connection state only when it changes (UI icon + notifier).
  void _publishConnected(bool connected) {
    if (_publishedConnected == connected) return;
    _publishedConnected = connected;
    if (!_connectionController.isClosed) {
      _connectionController.add(connected);
    }
    DLog.ble('publish isConnected=$connected');
  }

  /// Start background watch (FGS + periodic reconnect) — safe to call repeatedly.
  Future<void> enableBackgroundWatch() async {
    if (demoMode) {
      _startDemo();
      return;
    }
    backgroundMode = true;
    DLog.ble('background watch ON');
    await _startKeepAlive(text: isConnected
        ? 'Connected to EspressoPico'
        : 'Waiting for EspressoPico…');
    _startWatchdog();
    // Only kick one scan; concurrent startScan was racing connect.
    if (!isConnected && !_connecting && !_scanning) {
      unawaited(startScan(force: true));
    }
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    // Every 12 s: if not GATT-ready, clean zombie links and reconnect.
    _watchdogTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      if (!backgroundMode) return;
      if (_connecting) return;
      if (isConnected) {
        _failStreak = 0;
        _scanPolicy.onConnected();
        return;
      }
      DLog.ble('watchdog: not GATT-ready — clean reconnect');
      await _updateKeepAliveText('Looking for EspressoPico…');
      final d = _device;
      if (d != null) {
        // OS may claim "connected" while ATT is dead — force clean link.
        try {
          if (d.isConnected) {
            DLog.ble('watchdog: zombie isConnected — disconnect');
            await d.disconnect();
            await Future<void>.delayed(const Duration(milliseconds: 400));
          }
        } catch (e) {
          DLog.ble('watchdog disconnect: $e');
        }
        await _connectToDevice(d);
        if (isConnected) return;
      }
      if (_scanPolicy.shouldWatchdogRescan() &&
          _scanPolicy.canStartScan(DateTime.now(), force: true)) {
        startScan(force: true);
      }
    });
  }

  Future<bool> _ensurePermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    if (Platform.isAndroid) {
      // Request BT + location. Many OEMs still require location *service* ON
      // for BLE scan even with BLUETOOTH_SCAN + neverForLocation.
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? false;
      final connectOk = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      final locOk = statuses[Permission.locationWhenInUse]?.isGranted ?? false;
      DLog.ble('permissions scan=$scanOk connect=$connectOk location=$locOk');

      // Service location enabled? (separate from permission)
      try {
        final service = await Permission.locationWhenInUse.serviceStatus;
        DLog.ble('location serviceStatus=$service');
        if (service.isDisabled) {
          DLog.ble(
            'WARNING: Location service is OFF — BLE scan often fails on Android. '
            'Turn on Location in system settings.',
          );
        }
      } catch (e) {
        DLog.ble('location serviceStatus check failed: $e');
      }

      if (scanOk && connectOk) return true;
      if (locOk && (scanOk || connectOk)) return true;
      if (locOk) return true;

      DLog.ble('permissions denied: $statuses');
      return false;
    }

    final bt = await Permission.bluetooth.request();
    return bt.isGranted || bt.isLimited;
  }

  @override
  Future<void> startScan({bool force = false}) async {
    if (demoMode) {
      _startDemo();
      return;
    }
    final now = DateTime.now();
    // Keep policy in sync with GATT-ready (not mere ACL).
    if (isConnected) {
      _scanPolicy.onConnected();
    } else {
      _scanPolicy.onDisconnected();
    }
    // Claim slot immediately so concurrent enableBackgroundWatch / watchdog
    // cannot pile up permission requests during the async gap.
    if (!_scanPolicy.tryBeginKickoff(now, force: force)) {
      final bo = _scanPolicy.remainingBackoff(now);
      DLog.ble(
        'startScan skipped policy '
        '(force=$force scanning=$_scanning kickoff=${_scanPolicy.kickoff} '
        'connecting=$_connecting ready=$isConnected '
        'backoff=${bo?.inSeconds ?? 0}s)',
      );
      return;
    }

    try {
      final ok = await _ensurePermissions();
      if (!ok) {
        DLog.ble('permissions not granted — will retry');
        _scanPolicy.onScanFailed(DateTime.now());
        _scheduleRescan(const Duration(seconds: 5));
        return;
      }
    } catch (e) {
      DLog.ble('permissions error: $e');
      _scanPolicy.onScanFailed(DateTime.now());
      _scheduleRescan(const Duration(seconds: 5));
      return;
    }
    DLog.ble('startScan() target=$targetDeviceName force=$force');

    try {
      if (await FlutterBluePlus.isSupported == false) {
        DLog.ble('not supported on this device');
        _scanPolicy.onScanFailed(DateTime.now());
        return;
      }
      final state = await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 3),
        onTimeout: () => BluetoothAdapterState.unknown,
      );
      DLog.ble('adapter state=$state');
      if (state == BluetoothAdapterState.off) {
        DLog.ble('turning adapter ON…');
        if (Platform.isAndroid) {
          await FlutterBluePlus.turnOn();
        }
        await FlutterBluePlus.adapterState
            .where((s) => s == BluetoothAdapterState.on)
            .first
            .timeout(const Duration(seconds: 10));
        DLog.ble('adapter ON');
      }
    } catch (e) {
      DLog.ble('adapter error: $e');
      _scanPolicy.onScanFailed(DateTime.now());
      _scheduleRescan(const Duration(seconds: 5));
      return;
    }

    // Try system-known / bonded / last-connected before a full scan
    if (await _tryKnownDevices()) {
      _scanPolicy.cancelScan(); // kickoff done; connected path owns state
      return;
    }

    _scanSubscription?.cancel();
    _scanTimeoutTimer?.cancel();

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    try {
      // No withNames — Android often has empty platformName during scan.
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      DLog.ble('startScan error: $e');
      if (msg.contains('frequently') || msg.contains('status=6')) {
        _scanPolicy.onScanFailedRateLimit(DateTime.now());
        _scheduleRescan(_scanPolicy.rateLimitBackoff);
      } else {
        _scanPolicy.onScanFailed(DateTime.now());
        _scheduleRescan(const Duration(seconds: 5));
      }
      return;
    }

    _scanPolicy.onScanStarted(DateTime.now());

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final name = _deviceName(result);
        // Log a sample of unnamed devices occasionally for debug
        if (name.isEmpty) {
          DLog.throttle(
            'BLE',
            'unnamed',
            'scan unnamed id=${result.device.remoteId} rssi=${result.rssi} '
            'adv=${result.advertisementData.serviceUuids}',
            interval: const Duration(seconds: 5),
          );
          // Match by service UUID in advertisement if name missing
          final uuids = result.advertisementData.serviceUuids;
          final hasOurService = uuids.any(
            (u) => u.str128.toLowerCase() == serviceUUID.str128.toLowerCase(),
          );
          if (hasOurService) {
            DLog.ble('TARGET by service UUID ${result.device.remoteId}');
            FlutterBluePlus.stopScan();
            _cancelScan();
            _connectToDevice(result.device);
            return;
          }
          continue;
        }
        DLog.ble('scan saw "$name" rssi=${result.rssi}');
        final advName = result.advertisementData.advName.trim();
        if (_isTarget(name) || _isTarget(advName)) {
          DLog.ble(
              'TARGET FOUND "${_isTarget(name) ? name : advName}" — connecting');
          FlutterBluePlus.stopScan();
          _cancelScan();
          _connectToDevice(result.device);
          return;
        }
      }
    }, onError: (e) {
      DLog.ble('scan stream error: $e');
    }, onDone: () {
      _scanPolicy.onScanEnded();
      DLog.ble('scan stream done');
    });

    // Single cancellable timeout — never stack Future.delayed per startScan.
    _scanTimeoutTimer = Timer(const Duration(seconds: 16), () {
      if (isConnected || _connecting) return;
      if (!_scanPolicy.onScanTimeout()) return;
      _scanSubscription?.cancel();
      _scanSubscription = null;
      DLog.ble('scan timed out (15s) — scheduling rescan');
      _scheduleRescan(const Duration(seconds: 3));
    });
  }

  void _scheduleRescan(Duration delay) {
    _rescanTimer?.cancel();
    if (isConnected || _connecting) return;
    _rescanTimer = Timer(delay, () {
      if (!isConnected &&
          !_connecting &&
          !_scanning &&
          _scanPolicy.canStartScan(DateTime.now(), force: true)) {
        DLog.ble('auto rescan fire');
        startScan(force: true);
      }
    });
  }

  /// Connect via system cache / bonded list / previous remote id when scan
  /// does not see advertisements (common after Pico reboot or name empty).
  ///
  /// Note: "system connected" is often a zombie — `_connectToDevice` always
  /// force-disconnects before a clean connect when GATT is not ready.
  Future<bool> _tryKnownDevices() async {
    try {
      final connected = FlutterBluePlus.connectedDevices;
      for (final d in connected) {
        final n = d.platformName.trim();
        DLog.ble('system connected "$n" ${d.remoteId}');
        if (_isTarget(n) ||
            (_device != null && d.remoteId == _device!.remoteId)) {
          await _connectToDevice(d);
          // Only success if GATT bound — not mere ACL isConnected
          return isConnected;
        }
      }
    } catch (e) {
      DLog.ble('connectedDevices: $e');
    }

    try {
      // systemDevices may include recently seen LE peripherals
      final withServices = await FlutterBluePlus.systemDevices([serviceUUID]);
      for (final d in withServices) {
        DLog.ble('systemDevices(svc) "${d.platformName}" ${d.remoteId}');
        if (!_isTarget(d.platformName.trim())) {
          DLog.ble('systemDevices skip "${d.platformName}" ${d.remoteId}');
          continue;
        }
        await _connectToDevice(d);
        if (isConnected) return true;
      }
    } catch (e) {
      DLog.ble('systemDevices: $e');
    }

    try {
      final bonded = await FlutterBluePlus.bondedDevices;
      for (final d in bonded) {
        final n = d.platformName.trim();
        if (_isTarget(n)) {
          DLog.ble('bonded target "$n" ${d.remoteId} — connect');
          await _connectToDevice(d);
          if (isConnected || _linkUp) return true;
        }
      }
    } catch (e) {
      DLog.ble('bondedDevices: $e');
    }

    // Last successful remote id (this session)
    final prev = _device;
    if (prev != null) {
      try {
        DLog.ble('retry previous remoteId ${prev.remoteId}');
        await _connectToDevice(prev);
        if (isConnected || _linkUp) return true;
      } catch (e) {
        DLog.ble('previous id connect failed: $e');
      }
    }
    return false;
  }

  String _deviceName(ScanResult result) {
    final platform = result.device.platformName.trim();
    if (platform.isNotEmpty) return platform;
    final adv = result.advertisementData.advName.trim();
    if (adv.isNotEmpty) return adv;
    try {
      // ignore: deprecated_member_use
      final local = result.advertisementData.localName.trim();
      if (local.isNotEmpty) return local;
    } catch (_) {}
    return '';
  }

  bool _isTarget(String name) {
    final n = name.toLowerCase();
    return n == targetDeviceName.toLowerCase() ||
        n.contains('espressopico') ||
        n.contains('espresso');
  }

  void _cancelScan() {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _scanPolicy.cancelScan();
  }

  void _clearGatt() {
    _notifySub?.cancel();
    _notifySub = null;
    _dataCharacteristic = null;
    _commandCharacteristic = null;
    _rxJsonBuf.clear();
  }

  Future<void> _requestMtu(BluetoothDevice device) async {
    try {
      final mtu = await device.requestMtu(512);
      DLog.ble('MTU=$mtu');
    } catch (e) {
      DLog.ble('MTU request failed: $e');
      try {
        final mtu = await device.requestMtu(185);
        DLog.ble('MTU retry=$mtu');
      } catch (e2) {
        DLog.ble('MTU retry failed: $e2');
      }
    }
  }

  /// Feed one BLE notify chunk; emit complete JSON object(s) when braces balance.
  void _onNotifyBytes(List<int> value) {
    if (value.isEmpty) return;
    String chunk;
    try {
      chunk = utf8.decode(value, allowMalformed: true);
    } catch (e) {
      DLog.data('UTF8 decode error: $e raw=${value.length}B');
      return;
    }
    _rxJsonBuf.write(chunk);

    // Cap runaway buffer (lost framing). Must fit a full brew_log multipack
    // samples part (and room for a bit of glue) — 8 KB was too tight and
    // wiped partial brew_log frames → no post-shot banner.
    if (_rxJsonBuf.length > 65536) {
      DLog.data('RX buffer overflow — reset (${_rxJsonBuf.length}B)');
      _rxJsonBuf.clear();
      return;
    }

    var buf = _rxJsonBuf.toString();
    while (true) {
      final start = buf.indexOf('{');
      if (start < 0) {
        _rxJsonBuf.clear();
        return;
      }
      if (start > 0) {
        buf = buf.substring(start);
      }

      var depth = 0;
      var inString = false;
      var escape = false;
      var end = -1;
      for (var i = 0; i < buf.length; i++) {
        final c = buf[i];
        if (inString) {
          if (escape) {
            escape = false;
          } else if (c == r'\') {
            escape = true;
          } else if (c == '"') {
            inString = false;
          }
          continue;
        }
        if (c == '"') {
          inString = true;
          continue;
        }
        if (c == '{') {
          depth++;
        } else if (c == '}') {
          depth--;
          if (depth == 0) {
            end = i;
            break;
          }
        }
      }

      if (end < 0) {
        // Incomplete object — keep from first '{'
        _rxJsonBuf
          ..clear()
          ..write(buf);
        return;
      }

      final piece = buf.substring(0, end + 1);
      buf = buf.substring(end + 1);
      _emitParsedJson(piece);
    }
  }

  void _emitParsedJson(String text) {
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      if (json['type'] == 'brew_log') {
        DLog.data(
          'RX brew_log part=${json['part']} id=${json['id']} '
          'len=${text.length}B',
        );
      } else if (json.containsKey('brew_temperature') ||
          json.containsKey('pre_infusion_time') ||
          json.containsKey('pressure_soft_release_time') ||
          json['type'] == 'settings') {
        DLog.data('RX settings $json');
      } else {
        DLog.throttle(
          'DATA',
          'live',
          'RX live T=${json['boiler_temperature']} '
          'P=${json['pressure']} W=${json['weight_g']} '
          'abs=${json['weight_abs_g']} mode=${json['mode']}',
          interval: const Duration(seconds: 2),
        );
      }
      // Live packets prove the link is up — keep UI green even if a race
      // dropped an earlier connection event (broadcast stream has no replay).
      if (json.containsKey('boiler_temperature') ||
          json.containsKey('pressure') ||
          json.containsKey('weight_g')) {
        _publishConnected(true);
      }
      _dataController.add(json);
    } catch (e) {
      // wifi_key packets carry the Wi-Fi link key: never print their text
      final shown = text.contains('wifi_key')
          ? '<wifi_key redacted>'
          : (text.length > 80 ? text.substring(0, 80) : text);
      DLog.data('JSON parse error: $e raw=${text.length}B text=$shown');
    }
  }

  /// Single-flight connect. Always establishes a *fresh* ACL link before GATT.
  ///
  /// Android often leaves a zombie "connected" device (connectedDevices lists it,
  /// isConnected==true) but ATT is dead → MTU/discover fail. We force disconnect
  /// first whenever we do not already have GATT characteristics bound.
  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_connecting) {
      DLog.ble('connect skipped (already connecting)');
      return;
    }
    if (isConnected &&
        _device != null &&
        _device!.remoteId == device.remoteId) {
      DLog.ble('connect skipped (already GATT-ready ${device.remoteId})');
      return;
    }

    final now = DateTime.now();
    if (_nextConnectAllowed != null && now.isBefore(_nextConnectAllowed!)) {
      final wait = _nextConnectAllowed!.difference(now).inMilliseconds;
      DLog.ble('connect backoff ${wait}ms (failStreak=$_failStreak)');
      return;
    }

    _connecting = true;
    _rescanTimer?.cancel();
    _reconnectTimer?.cancel();
    _cancelScan();
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    await _connSub?.cancel();
    _connSub = null;
    _clearGatt();

    _device = device;
    DLog.ble('connect_attempt ${device.remoteId} failStreak=$_failStreak');

    try {
      // Always tear down zombie OS link so we get a real ATT session.
      if (device.isConnected) {
        DLog.ble('force disconnect before clean connect (zombie guard)');
        try {
          await device.disconnect();
        } catch (e) {
          DLog.ble('pre-disconnect: $e');
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      // Explicit connect only (autoConnect races with zombie state on OnePlus)
      await device.connect(
        autoConnect: false,
        mtu: null,
        timeout: const Duration(seconds: 20),
      );

      await device.connectionState
          .where((s) => s == BluetoothConnectionState.connected)
          .first
          .timeout(const Duration(seconds: 12));
      DLog.ble('CONNECTED ${device.remoteId}');

      _connSub = device.connectionState.listen((state) {
        final connected = state == BluetoothConnectionState.connected;
        DLog.ble('connectionState=$state');
        if (!connected) {
          DLog.ble('link_drop reason=connectionState_$state');
          _clearGatt();
          _scanPolicy.onDisconnected();
          _publishConnected(false);
          unawaited(_updateKeepAliveText('Looking for EspressoPico…'));
          if (backgroundMode && !_connecting) {
            _startReconnectTimer();
            _scheduleRescan(const Duration(seconds: 3));
          }
        } else if (!isConnected && !_connecting) {
          unawaited(_onReconnected());
        }
      });

      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!device.isConnected) {
        throw Exception('link dropped during settle before GATT');
      }

      // MTU optional — fail-soft while still connected
      await _requestMtu(device);
      if (!device.isConnected) {
        throw Exception('link dropped during MTU');
      }

      await _discoverServices();
      if (!device.isConnected) {
        throw Exception('link dropped during service discovery');
      }

      _publishConnected(isConnected);
      if (isConnected) {
        _failStreak = 0;
        _nextConnectAllowed = null;
        _reconnectTimer?.cancel();
        _scanPolicy.onConnected();
        DLog.ble('gatt_ready ${device.remoteId}');
        DLog.ble('link READY (notify+command) ${device.remoteId}');
        await _startKeepAlive(text: 'Connected to EspressoPico');
        await _requestSettingsSync();
      } else {
        throw Exception('GATT incomplete (no characteristics)');
      }
    } catch (e) {
      _failStreak++;
      final backoffSec = (_failStreak * 2).clamp(2, 20);
      _nextConnectAllowed =
          DateTime.now().add(Duration(seconds: backoffSec));
      DLog.ble(
        'connection error: $e (failStreak=$_failStreak backoff=${backoffSec}s)',
      );
      _clearGatt();
      _publishConnected(false);
      try {
        if (device.isConnected) await device.disconnect();
      } catch (_) {}
      unawaited(_updateKeepAliveText('Looking for EspressoPico…'));
      _scheduleRescan(Duration(seconds: backoffSec));
    } finally {
      _connecting = false;
    }
  }

  Future<void> _onReconnected() async {
    if (_connecting) return;
    final d = _device;
    if (d == null) return;
    try {
      if (!d.isConnected) return;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _requestMtu(d);
      await _discoverServices();
      _publishConnected(isConnected);
      if (isConnected) {
        _reconnectTimer?.cancel();
        await _startKeepAlive(text: 'Connected to EspressoPico');
        DLog.ble('reconnected + GATT re-bound');
        await _requestSettingsSync();
      }
    } catch (e) {
      DLog.ble('reconnected bind failed: $e');
    }
  }

  /// Called when app returns to foreground — re-open notify if needed.
  @override
  Future<void> onAppResumed() async {
    if (demoMode) return;
    DLog.ble('onAppResumed linkUp=$_linkUp ready=$isConnected');
    if (backgroundMode) {
      await _startKeepAlive(
        text: isConnected
            ? 'Connected to EspressoPico'
            : 'Looking for EspressoPico…',
      );
      _startWatchdog();
    }
    final d = _device;
    if (d == null) {
      startScan(force: true);
      return;
    }
    try {
      if (d.isConnected) {
        if (!isConnected) {
          await _discoverServices();
        }
        _publishConnected(isConnected);
        if (isConnected) {
          await _startKeepAlive(text: 'Connected to EspressoPico');
          // Catch pending shot log if multipack was mid-flight during pause.
          requestPendingBrewLog();
        }
      } else {
        _publishConnected(false);
        _startReconnectTimer();
        startScan(force: true);
      }
    } catch (e) {
      DLog.ble('onAppResumed error: $e');
      startScan(force: true);
    }
  }

  /// App backgrounded — keep scanning + FGS so we connect when Pico appears.
  @override
  void onAppPaused() {
    DLog.ble('onAppPaused — background watch (scan+reconnect stay on)');
    if (demoMode) return;
    if (backgroundMode) {
      unawaited(_startKeepAlive(
        text: isConnected
            ? 'Connected to EspressoPico'
            : 'Looking for EspressoPico…',
      ));
      _startWatchdog();
      // Keep hunting while backgrounded (do not cancel scan permanently)
      if (!isConnected && !_scanning && !_connecting) {
        startScan(force: true);
      }
    }
  }

  Future<void> _startKeepAlive({String text = 'Waiting for EspressoPico…'}) async {
    if (!Platform.isAndroid) return;
    try {
      await Permission.notification.request();
      if (!_keepAliveRunning) {
        await _keepAliveChannel.invokeMethod<void>('start', {'text': text});
        _keepAliveRunning = true;
        DLog.ble('foreground keep-alive START: $text');
      } else {
        await _updateKeepAliveText(text);
      }
    } catch (e) {
      DLog.ble('keep-alive start failed: $e');
    }
  }

  Future<void> _updateKeepAliveText(String text) async {
    if (!Platform.isAndroid || !_keepAliveRunning) return;
    try {
      await _keepAliveChannel.invokeMethod<void>('update', {'text': text});
    } catch (e) {
      DLog.ble('keep-alive update failed: $e');
    }
  }

  Future<void> _stopKeepAlive() async {
    if (!Platform.isAndroid || !_keepAliveRunning) return;
    try {
      await _keepAliveChannel.invokeMethod<void>('stop');
      _keepAliveRunning = false;
      DLog.ble('foreground keep-alive STOP');
    } catch (e) {
      DLog.ble('keep-alive stop failed: $e');
    }
  }

  bool _uuidEquals(Guid a, Guid b) {
    return a.str128.toLowerCase() == b.str128.toLowerCase();
  }

  Future<void> _discoverServices() async {
    if (_device == null) return;
    _clearGatt();
    try {
      final services = await _device!.discoverServices();
      DLog.ble('services: ${services.map((s) => s.uuid).toList()}');
      for (final service in services) {
        if (!_uuidEquals(service.uuid, serviceUUID)) continue;
        DLog.ble('matched service ${service.uuid}');
        for (final char in service.characteristics) {
          DLog.ble('char ${char.uuid} props=${char.properties}');
          if (_uuidEquals(char.uuid, dataCharUUID)) {
            _dataCharacteristic = char;
            _rxJsonBuf.clear();
            await char.setNotifyValue(true);
            DLog.ble('data notify ON');
            _notifySub = char.onValueReceived.listen(_onNotifyBytes);
          } else if (_uuidEquals(char.uuid, commandCharUUID)) {
            _commandCharacteristic = char;
            DLog.ble('command char ready ${char.uuid}');
          }
        }
      }
      if (_dataCharacteristic == null) {
        DLog.ble('ERROR data characteristic not found');
      }
      if (_commandCharacteristic == null) {
        DLog.ble('ERROR command characteristic not found — sliders will not work');
      }
    } catch (e) {
      DLog.ble('service discovery error: $e');
    }
  }

  @override
  Future<void> sendCommand(String command) async {
    if (demoMode) {
      _demo?.command(command);
      return;
    }
    if (_commandCharacteristic == null) {
      DLog.ble('TX SKIP (no command char): $command — forcing rescan');
      _scheduleRescan(const Duration(seconds: 1));
      return;
    }
    try {
      final data = utf8.encode(command);
      try {
        await _commandCharacteristic!.write(data, withoutResponse: false);
        DLog.ble('TX OK (with response): $command');
      } catch (e1) {
        DLog.ble('TX retry withoutResponse after: $e1');
        await _commandCharacteristic!.write(data, withoutResponse: true);
        DLog.ble('TX OK (no response): $command');
      }
    } catch (e) {
      DLog.ble('TX FAIL: $command err=$e');
      _clearGatt();
      _publishConnected(false);
      _scheduleRescan(const Duration(seconds: 2));
    }
  }

  /// Request brew_temperature / times from Pico after notify is on.
  Future<void> _requestSettingsSync() async {
    DLog.ble('request settings sync');
    await sendCommand('sync');
    // Second request after a short delay (belt and suspenders)
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (isConnected) {
        sendCommand('sync');
      }
    });
    // Pending brew_log after reconnect / flutterRestart (Pico keeps pending
    // until ack). Ask explicitly so multipack meta is not missed.
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (isConnected) {
        requestPendingBrewLog();
      }
    });
  }

  /// Ask Pico to (re)send pending brew_log multipack from meta.
  @override
  void requestPendingBrewLog() {
    DLog.ble('TX brew_log? (request pending multipack)');
    sendCommand('brew_log?');
  }

  void _startReconnectTimer() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 6), (timer) async {
      if (isConnected || _connecting) return;
      final d = _device;
      if (d != null) {
        DLog.ble('reconnect timer → full connect ${d.remoteId}');
        // Use the same robust path as first connect (wait + GATT bind)
        await _connectToDevice(d);
        if (isConnected) {
          DLog.ble('reconnect OK');
          return;
        }
      }
      if (!isConnected && !_scanning && !_connecting) {
        startScan(force: true);
      }
    });
  }

  @override
  String deviceSummary() {
    if (demoMode) return 'demo ready=$isConnected';
    final d = _device;
    if (d == null) return 'no-device';
    return '${d.remoteId} ready=$isConnected';
  }

  @override
  Future<void> disconnect() async {
    DLog.ble('disconnect()');
    if (demoMode) {
      _demo?.stop();
      _publishConnected(false);
      return;
    }
    backgroundMode = false;
    _reconnectTimer?.cancel();
    _rescanTimer?.cancel();
    _watchdogTimer?.cancel();
    _cancelScan();
    _connSub?.cancel();
    _clearGatt();
    await _stopKeepAlive();
    try {
      await _device?.disconnect();
    } catch (e) {
      DLog.ble('disconnect error: $e');
    }
    _publishConnected(false);
  }

  /// Intentionally does NOT disconnect BLE or close streams.
  /// Process exit is the only full teardown.
  void dispose() {
    DLog.ble('dispose() ignored for keep-alive singleton');
  }
}
