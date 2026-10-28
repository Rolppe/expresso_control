// ============================================================================
// wifi_repository.dart — the Pico over UDP (protocol: pico/wifilink.py)
// ============================================================================
// App -> Pico, one ASCII datagram to port 47211:
//   EXA1 hello                           -> {"type":"hello","boot":<id>,...}
//   EXA1 <boot> <seq> <mac16> <command>  -> {"type":"ack","seq":n,"r":"..."}
// mac16 = first 16 hex of HMAC-SHA256(key, "<boot> <seq> <command>").
// Pico -> app: the BLE notify objects, one JSON object per datagram, to every
// sender whose `sub` is under 15 s old.
//
// Commands go one at a time: the Pico drops any seq below the last one it saw,
// so a lost older command cannot be retried after a newer one has run.
// The key is never logged, printed or put in an error message.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../core/debug_log.dart';
import 'machine_link.dart';
import 'wifi_key_store.dart';

/// First 16 hex chars of HMAC-SHA256([key], [message]).
String wifiMac16(List<int> key, String message) {
  final d = Hmac(sha256, key).convert(utf8.encode(message)).bytes;
  final sb = StringBuffer();
  for (final b in d.take(8)) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

class WifiTimings {
  final Duration helloInterval;
  final Duration subInterval;
  final Duration ackTimeout;
  final Duration connectedWindow;
  final Duration tick;
  final Duration syncGap;
  final Duration brewLogGap;
  final int retries;
  final int maxStaleRestarts;

  const WifiTimings({
    this.helloInterval = const Duration(seconds: 2),
    this.subInterval = const Duration(seconds: 5),
    this.ackTimeout = const Duration(milliseconds: 300),
    this.connectedWindow = const Duration(seconds: 3),
    this.tick = const Duration(milliseconds: 250),
    this.syncGap = const Duration(milliseconds: 400),
    this.brewLogGap = const Duration(milliseconds: 700),
    this.retries = 3,
    this.maxStaleRestarts = 2,
  });
}

class _Pending {
  final String cmd;
  final bool isSub;
  final Completer<void> done = Completer<void>();
  int? seq;
  int attempts = 0;
  int staleRestarts = 0;
  bool waitingForBoot = false;
  Timer? timer;

  _Pending(this.cmd, {this.isSub = false});
}

class WifiRepository implements WifiLink {
  final WifiKeyStore store;
  final WifiTimings timings;
  final DateTime Function() _now;

  WifiRepository({
    required this.store,
    this.timings = const WifiTimings(),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now {
    _seq = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  // ---- state --------------------------------------------------------------
  WifiLinkConfig? _config;
  List<int>? _keyBytes;
  InternetAddress? _target;
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _socketSub;
  StreamSubscription<void>? _storeSub;

  bool _started = false;
  bool _paused = false;
  String? _boot;
  int _seq = 0;
  DateTime? _lastRx;
  bool _connected = false;

  Timer? _helloTimer;
  Timer? _subTimer;
  Timer? _tickTimer;
  final List<Timer> _sessionTimers = [];

  final List<_Pending> _queue = [];
  _Pending? _inflight;

  final _connectionController = StreamController<bool>.broadcast();
  final _dataController = StreamController<Map<String, dynamic>>.broadcast();

  // ---- MachineLink --------------------------------------------------------
  @override
  Stream<bool> get isConnectedStream => _connectionController.stream;

  @override
  bool get isConnected => _connected;

  @override
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  @override
  String? get bootId => _boot;

  @override
  DateTime? get lastPacketAt => _lastRx;

  @override
  bool get hasKey => _config != null;

  /// Begin (idempotent): load the key, open the socket, say hello.
  @override
  Future<void> start() async {
    if (_started && !_paused) {
      return;
    }
    _started = true;
    _paused = false;
    _storeSub ??= store.changes.listen((_) => unawaited(_applyConfig(force: true)));
    await _applyConfig();
  }

  @override
  Future<void> startScan({bool force = false}) async {
    if (!_started) {
      await start();
      return;
    }
    _paused = false;
    if (force || _socket == null) {
      await _applyConfig(force: true);
    }
  }

  @override
  Future<void> onAppResumed() async {
    if (!_started) return;
    DLog.ble('wifi onAppResumed');
    _paused = false;
    await _applyConfig(force: true);
  }

  /// iOS suspends the socket in the background anyway; close it cleanly.
  @override
  void onAppPaused() {
    if (!_started) return;
    DLog.ble('wifi onAppPaused — socket closed');
    _paused = true;
    _closeSocket();
  }

  @override
  Future<void> disconnect() async {
    DLog.ble('wifi disconnect()');
    _started = false;
    _paused = false;
    await _storeSub?.cancel();
    _storeSub = null;
    _closeSocket();
  }

  @override
  String deviceSummary() {
    final c = _config;
    if (c == null) return 'wifi no-key';
    return 'wifi ${c.host}:${c.port} boot=${_boot ?? '-'} ready=$_connected';
  }

  @override
  void requestPendingBrewLog() {
    DLog.ble('TX brew_log? (wifi)');
    unawaited(sendCommand('brew_log?'));
  }

  @override
  Future<void> sendCommand(String command) {
    if (_socket == null || _config == null) {
      DLog.ble('WIFI TX SKIP (no socket/key): $command');
      return Future<void>.value();
    }
    if (_boot == null || !_connected) {
      DLog.ble('WIFI TX SKIP (no hello yet): $command');
      return Future<void>.value();
    }
    final p = _Pending(command);
    _queue.add(p);
    _pump();
    return p.done.future;
  }

  // ---- config / socket ----------------------------------------------------
  Future<void> _lock = Future<void>.value();

  /// Config changes and (re)opens never overlap.
  Future<void> _applyConfig({bool force = false}) {
    final next = _lock.then((_) => _applyConfigNow(force: force));
    _lock = next.catchError((Object _) {});
    return next;
  }

  Future<void> _applyConfigNow({bool force = false}) async {
    if (!_started) return;
    final cfg = await store.load();
    if (!_started) return;
    final bytes = cfg?.keyBytes;
    if (cfg == null || bytes == null) {
      DLog.ble('wifi: no key stored — not connecting');
      _config = null;
      _keyBytes = null;
      _closeSocket();
      return;
    }
    final changed = _config == null ||
        _config!.keyHex != cfg.keyHex ||
        _config!.host != cfg.host ||
        _config!.port != cfg.port;
    _config = cfg;
    _keyBytes = bytes;
    if (_paused) return;
    if (!changed && !force && _socket != null) return;
    await _open();
  }

  Future<void> _open() async {
    _closeSocket();
    final cfg = _config;
    if (cfg == null) return;
    try {
      _target = InternetAddress.tryParse(cfg.host) ??
          (await InternetAddress.lookup(cfg.host, type: InternetAddressType.IPv4))
              .first;
      final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      if (!_started || _paused || _config != cfg) {
        s.close();
        return;
      }
      _socket = s;
      _socketSub = s.listen(_onSocketEvent, onError: (Object e) {
        DLog.ble('wifi socket error: ${e.runtimeType}');
      });
    } catch (e) {
      DLog.ble('wifi open failed: ${e.runtimeType}');
      _socket = null;
      return;
    }
    _boot = null; // a fresh socket is a fresh sender: say hello first
    _lastRx = null;
    _helloTimer = Timer.periodic(timings.helloInterval, (_) {
      if (_boot == null || !_connected) _sendHello();
    });
    _subTimer = Timer.periodic(timings.subInterval, (_) {
      if (_boot != null && _connected) _enqueueSub();
    });
    _tickTimer = Timer.periodic(timings.tick, (_) => _evalConnected());
    DLog.ble('wifi open → ${cfg.host}:${cfg.port}');
    _sendHello();
  }

  void _closeSocket() {
    _helloTimer?.cancel();
    _subTimer?.cancel();
    _tickTimer?.cancel();
    _helloTimer = _subTimer = _tickTimer = null;
    for (final t in _sessionTimers) {
      t.cancel();
    }
    _sessionTimers.clear();
    _socketSub?.cancel();
    _socketSub = null;
    _socket?.close();
    _socket = null;
    _failAll('socket closed');
    _boot = null;
    _lastRx = null;
    _evalConnected();
  }

  // ---- send ---------------------------------------------------------------
  void _sendRaw(String text) {
    final s = _socket;
    final t = _target;
    final c = _config;
    if (s == null || t == null || c == null) return;
    try {
      s.send(utf8.encode(text), t, c.port);
    } catch (e) {
      DLog.ble('wifi send failed: ${e.runtimeType}');
    }
  }

  void _sendHello() => _sendRaw('EXA1 hello');

  String? _packetFor(_Pending p) {
    final boot = _boot;
    final key = _keyBytes;
    if (boot == null || key == null) return null;
    p.seq ??= ++_seq;
    final mac = wifiMac16(key, '$boot ${p.seq} ${p.cmd}');
    return 'EXA1 $boot ${p.seq} $mac ${p.cmd}';
  }

  void _enqueueSub() {
    final queued = _queue.any((p) => p.isSub) || (_inflight?.isSub ?? false);
    if (queued) return;
    _queue.add(_Pending('sub', isSub: true));
    _pump();
  }

  // ---- command queue ------------------------------------------------------
  void _pump() {
    if (_inflight != null || _queue.isEmpty) return;
    _inflight = _queue.removeAt(0);
    _transmit(_inflight!);
  }

  void _transmit(_Pending p) {
    p.timer?.cancel();
    final packet = _packetFor(p);
    if (packet == null) {
      // no boot (stale restart or reboot): the next hello resumes this one
      p.waitingForBoot = true;
      p.timer = Timer(
        timings.ackTimeout * (timings.retries + 2),
        () => _finish(p, 'no hello'),
      );
      return;
    }
    p.waitingForBoot = false;
    p.attempts++;
    _sendRaw(packet);
    p.timer = Timer(timings.ackTimeout, () {
      if (!identical(_inflight, p)) return;
      if (p.attempts > timings.retries) {
        _finish(p, 'no ack');
      } else {
        _transmit(p);
      }
    });
  }

  void _finish(_Pending p, [String? failure]) {
    p.timer?.cancel();
    if (failure != null) {
      DLog.ble('WIFI cmd failed ($failure): ${p.cmd}');
    }
    if (!p.done.isCompleted) p.done.complete();
    if (identical(_inflight, p)) _inflight = null;
    _pump();
  }

  void _failAll(String why) {
    final all = <_Pending>[
      if (_inflight != null) _inflight!,
      ..._queue,
    ];
    _inflight = null;
    _queue.clear();
    for (final p in all) {
      p.timer?.cancel();
      if (!p.done.isCompleted) p.done.complete();
    }
    if (all.isNotEmpty) DLog.ble('WIFI dropped ${all.length} command(s): $why');
  }

  /// The inflight command was signed with a boot id that is gone.
  void _restartInflight() {
    final p = _inflight;
    if (p == null) return;
    p.seq = null;
    p.attempts = 0;
    p.staleRestarts++;
    if (p.staleRestarts > timings.maxStaleRestarts) {
      _finish(p, 'stale');
      return;
    }
    _transmit(p);
  }

  // ---- receive ------------------------------------------------------------
  void _onSocketEvent(RawSocketEvent e) {
    if (e != RawSocketEvent.read) return;
    final s = _socket;
    if (s == null) return;
    for (var i = 0; i < 64; i++) {
      final d = s.receive();
      if (d == null) break;
      _onDatagram(d);
    }
  }

  void _onDatagram(Datagram d) {
    final c = _config;
    final t = _target;
    if (c == null || t == null) return;
    if (d.address.address != t.address || d.port != c.port) return; // not the Pico
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(utf8.decode(d.data));
      if (decoded is! Map<String, dynamic>) return;
      json = decoded;
    } catch (_) {
      return;
    }
    final becameConnected = _touch();
    final type = json['type'];
    if (type == 'hello') {
      final boot = json['boot']?.toString();
      if (boot == null) return;
      final changed = boot != _boot;
      _boot = boot;
      if (changed) DLog.ble('wifi hello boot=$boot');
      final p = _inflight;
      if (p != null) {
        if (p.waitingForBoot) {
          _transmit(p);
        } else if (changed) {
          _restartInflight(); // signed under a boot id that is gone
        }
      }
      if (changed || becameConnected) _startSession();
      return;
    }
    if (becameConnected && _boot != null) _startSession();
    if (type == 'ack') {
      _onAck(json);
      return;
    }
    if (type == 'wifi_key') return; // the key travels over BLE only; never forward
    if (!_dataController.isClosed) _dataController.add(json);
  }

  void _onAck(Map<String, dynamic> json) {
    final p = _inflight;
    final seq = (json['seq'] as num?)?.toInt();
    if (p == null || seq == null || seq != p.seq) return; // late or repeated ack
    final r = json['r']?.toString() ?? '';
    switch (r) {
      case 'ok':
      case 'updated':
        _finish(p);
      case 'stale':
        _boot = null;
        _restartInflight(); // waits for the hello answer below
        _sendHello();
      case 'denied':
      case 'unknown':
        DLog.ble('WIFI cmd $r: ${p.cmd}');
        _finish(p);
      default:
        DLog.ble('WIFI cmd answered "$r": ${p.cmd}');
        _finish(p);
    }
  }

  // ---- connection state ---------------------------------------------------
  /// Record a packet; true when this packet brought the link up.
  bool _touch() {
    _lastRx = _now();
    final was = _connected;
    _evalConnected();
    return !was && _connected;
  }

  void _evalConnected() {
    final rx = _lastRx;
    final up = _socket != null &&
        rx != null &&
        _now().difference(rx) <= timings.connectedWindow;
    if (up == _connected) return;
    _connected = up;
    if (!up) {
      // silence: commands in flight are not going to be answered
      _failAll('link silent');
    }
    DLog.ble('wifi isConnected=$up');
    if (!_connectionController.isClosed) _connectionController.add(up);
  }

  // ---- session start (mirrors BLERepository._requestSettingsSync) ----------
  void _startSession() {
    for (final t in _sessionTimers) {
      t.cancel();
    }
    _sessionTimers.clear();
    final boot = _boot;
    bool alive() => _connected && _boot == boot;
    _enqueueSub();
    unawaited(sendCommand('sync'));
    _sessionTimers.add(Timer(timings.syncGap, () {
      if (alive()) unawaited(sendCommand('sync'));
    }));
    _sessionTimers.add(Timer(timings.brewLogGap, () {
      if (alive()) requestPendingBrewLog();
    }));
  }
}
