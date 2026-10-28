// ============================================================================
// link_selector.dart — picks BLE or Wi-Fi for the app (EXPRESSO-WIFI-APPI v3)
// ============================================================================
// Owns both links. Only the active link's data reaches [dataStream] and
// commands go to the active link. BLE is never stopped: its scan, connection
// and background mode (UIBackgroundModes bluetooth-central, T12) run for the
// life of the process; iOS suspends the UDP socket in the background, BLE
// does not.
//
// auto: Wi-Fi once it is connected, BLE otherwise. A switch needs the wish to
// hold for [hysteresis] and never happens within [brewLogQuiet] of a brew_log
// frame from the active link. In the background the active link is BLE.

import 'dart:async';

import '../../core/debug_log.dart';
import 'machine_link.dart';
import 'wifi_key_store.dart';

enum LinkMode { auto, wifi, ble }

enum LinkKind { ble, wifi }

LinkMode linkModeFromName(String? name) {
  for (final m in LinkMode.values) {
    if (m.name == name) return m;
  }
  return LinkMode.auto;
}

class LinkStatus {
  final LinkKind active;
  final LinkMode mode;
  final bool bleConnected;
  final bool wifiConnected;
  final bool hasKey;
  final String? bootId;
  final DateTime? lastPacketAt;

  const LinkStatus({
    this.active = LinkKind.ble,
    this.mode = LinkMode.auto,
    this.bleConnected = false,
    this.wifiConnected = false,
    this.hasKey = false,
    this.bootId,
    this.lastPacketAt,
  });
}

class LinkSelector implements MachineLink {
  final MachineLink ble;
  final WifiLink wifi;
  final WifiKeyStore keyStore;
  final Duration hysteresis;
  final Duration brewLogQuiet;
  final Duration keyRequestDelay;
  final Duration keyRetryInterval;
  final bool autoKeyRequest;
  final bool wifiEnabled;
  final Future<void> Function()? _bleWatch;
  final DateTime Function() _now;

  LinkSelector({
    required this.ble,
    required this.wifi,
    required this.keyStore,
    LinkMode mode = LinkMode.auto,
    this.hysteresis = const Duration(seconds: 3),
    this.brewLogQuiet = const Duration(seconds: 2),
    this.keyRequestDelay = const Duration(milliseconds: 1500),
    this.keyRetryInterval = const Duration(seconds: 5),
    this.autoKeyRequest = true,
    this.wifiEnabled = true,
    Future<void> Function()? bleWatch,
    DateTime Function()? clock,
  })  : _mode = mode,
        _bleWatch = bleWatch,
        _now = clock ?? DateTime.now {
    _subs.addAll([
      ble.dataStream.listen(_onBleData),
      wifi.dataStream.listen(_onWifiData),
      ble.isConnectedStream.listen(_onBleConnection),
      wifi.isConnectedStream.listen((_) => _evaluate()),
      keyStore.changes.listen((_) => _emitStatus()),
    ]);
    _bleWasConnected = ble.isConnected;
    _lastPublished = isConnected;
    if (_bleWasConnected) _scheduleKeyRequest();
    _evaluate();
  }

  LinkMode _mode;
  LinkKind _active = LinkKind.ble;
  bool _backgrounded = false;
  bool _bleWasConnected = false;
  bool _lastPublished = false;
  DateTime? _lastLogPartAt;
  Timer? _switchTimer;
  Timer? _keyTimer;
  final List<StreamSubscription<dynamic>> _subs = [];

  final _connectionController = StreamController<bool>.broadcast();
  final _dataController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<LinkStatus>.broadcast();

  // ---- state for the UI ----------------------------------------------------
  LinkMode get mode => _mode;

  LinkKind get active => _active;

  MachineLink get _activeLink => _active == LinkKind.wifi ? wifi : ble;

  Stream<LinkStatus> get statusStream => _statusController.stream;

  LinkStatus get status => LinkStatus(
        active: _active,
        mode: _mode,
        bleConnected: ble.isConnected,
        wifiConnected: wifi.isConnected,
        hasKey: wifi.hasKey,
        bootId: wifi.bootId,
        lastPacketAt: wifi.lastPacketAt,
      );

  void setMode(LinkMode mode) {
    if (_mode == mode) return;
    DLog.ble('link mode $_mode -> $mode');
    _mode = mode;
    _switchTimer?.cancel();
    _switchTimer = null;
    _evaluate(immediate: true);
    _emitStatus();
  }

  // ---- MachineLink ---------------------------------------------------------
  @override
  Stream<bool> get isConnectedStream => _connectionController.stream;

  @override
  bool get isConnected => _activeLink.isConnected;

  @override
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  @override
  Future<void> sendCommand(String command) {
    // The key request is a BLE-only conversation, whichever link is active.
    if (command.startsWith('wifi:')) return ble.sendCommand(command);
    return _activeLink.sendCommand(command);
  }

  @override
  void requestPendingBrewLog() => _activeLink.requestPendingBrewLog();

  /// BLE's background watch (scan, reconnect) plus the Wi-Fi link.
  Future<void> enableBackgroundWatch() async {
    await _bleWatch?.call();
    if (wifiEnabled) {
      try {
        await wifi.start();
      } catch (e) {
        DLog.ble('wifi start failed: ${e.runtimeType}');
      }
    }
  }

  @override
  Future<void> startScan({bool force = false}) async {
    if (wifiEnabled) unawaited(wifi.startScan(force: force));
    await ble.startScan(force: force);
  }

  @override
  Future<void> onAppResumed() async {
    _backgrounded = false;
    await Future.wait<void>([
      ble.onAppResumed(),
      if (wifiEnabled) wifi.onAppResumed(),
    ]);
    _evaluate();
  }

  /// Backgrounded: Wi-Fi is suspended by iOS, BLE carries on.
  @override
  void onAppPaused() {
    _backgrounded = true;
    ble.onAppPaused();
    if (wifiEnabled) wifi.onAppPaused();
    _evaluate();
  }

  /// Stops the Wi-Fi link only. BLE is never stopped by the selector.
  @override
  Future<void> disconnect() => wifi.disconnect();

  @override
  String deviceSummary() =>
      'active=${_active.name} mode=${_mode.name} | ${ble.deviceSummary()} | ${wifi.deviceSummary()}';

  // ---- selection -----------------------------------------------------------
  LinkKind _desired() {
    if (_backgrounded) return LinkKind.ble;
    switch (_mode) {
      case LinkMode.wifi:
        return LinkKind.wifi;
      case LinkMode.ble:
        return LinkKind.ble;
      case LinkMode.auto:
        return wifi.isConnected ? LinkKind.wifi : LinkKind.ble;
    }
  }

  void _evaluate({bool immediate = false}) {
    final want = _desired();
    if (want == _active) {
      _switchTimer?.cancel();
      _switchTimer = null;
    } else if (immediate || _backgrounded || _mode != LinkMode.auto) {
      _switchTimer?.cancel();
      _switchTimer = null;
      _switchTo(want);
    } else {
      _switchTimer ??= Timer(hysteresis, _onSwitchTimer);
    }
    _publish();
  }

  void _onSwitchTimer() {
    _switchTimer = null;
    final want = _desired();
    if (want == _active) return;
    final lastPart = _lastLogPartAt;
    if (lastPart != null && _now().difference(lastPart) < brewLogQuiet) {
      // a brew log is arriving: let it finish before changing links
      _switchTimer = Timer(const Duration(milliseconds: 250), _onSwitchTimer);
      return;
    }
    _switchTo(want);
    _publish();
  }

  void _switchTo(LinkKind kind) {
    if (kind == _active) return;
    DLog.ble('link switch ${_active.name} -> ${kind.name}');
    _active = kind;
    final link = _activeLink;
    // the new link has not been forwarded so far: start it as a connect does
    if (link.isConnected) {
      unawaited(link.sendCommand('sync'));
      link.requestPendingBrewLog();
    }
  }

  void _publish() {
    final now = isConnected;
    if (now != _lastPublished) {
      _lastPublished = now;
      if (!_connectionController.isClosed) _connectionController.add(now);
    }
    _emitStatus();
  }

  void _emitStatus() {
    if (!_statusController.isClosed) _statusController.add(status);
  }

  // ---- data ----------------------------------------------------------------
  void _onBleData(Map<String, dynamic> json) {
    if (json['type'] == 'wifi_key') {
      _storeKey(json);
      return;
    }
    if (_active == LinkKind.ble) _forward(json);
  }

  void _onWifiData(Map<String, dynamic> json) {
    if (_active == LinkKind.wifi) _forward(json);
  }

  void _forward(Map<String, dynamic> json) {
    if (json['type'] == 'brew_log') _lastLogPartAt = _now();
    if (!_dataController.isClosed) _dataController.add(json);
  }

  // ---- key hand-over over BLE ---------------------------------------------
  void _storeKey(Map<String, dynamic> json) {
    final key = json['key']?.toString() ?? '';
    if (decodeWifiKey(key) == null) {
      DLog.ble('wifi_key packet ignored (malformed)');
      return;
    }
    var host = json['host']?.toString() ?? '';
    if (host.isEmpty || host == '?' || host == '0.0.0.0') host = wifiDefaultHost;
    final port = (json['port'] as num?)?.toInt() ?? wifiDefaultPort;
    DLog.ble('wifi_key received — stored in Keychain');
    unawaited(keyStore.save(WifiLinkConfig(
      keyHex: key.trim().toLowerCase(),
      host: host,
      port: (port > 0 && port < 65536) ? port : wifiDefaultPort,
    )));
  }

  void _onBleConnection(bool up) {
    if (up && !_bleWasConnected) _scheduleKeyRequest();
    _bleWasConnected = up;
    _evaluate();
  }

  /// BLE just connected and no key is stored: ask the Pico for it, a few tries.
  void _scheduleKeyRequest([int attempt = 0]) {
    _keyTimer?.cancel();
    _keyTimer = null;
    if (!autoKeyRequest || attempt >= 3) return;
    _keyTimer = Timer(attempt == 0 ? keyRequestDelay : keyRetryInterval, () async {
      if (!ble.isConnected) return;
      final cfg = await keyStore.load();
      if (cfg != null) return;
      DLog.ble('TX wifi:key? (no key stored)');
      await ble.sendCommand('wifi:key?');
      _scheduleKeyRequest(attempt + 1);
    });
  }

  /// For tests: cancel timers and subscriptions.
  void dispose() {
    _switchTimer?.cancel();
    _keyTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }
}
