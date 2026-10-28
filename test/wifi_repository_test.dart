// WifiRepository against a fake Pico on 127.0.0.1 (RawDatagramSocket).
// The fake follows pico/wifilink.py: hello, HMAC check, stale boot, seq
// de-duplication with the same ack again, `sub`.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silvia_pico_ui/features/link/wifi_key_store.dart';
import 'package:silvia_pico_ui/features/link/wifi_repository.dart';

final List<int> testKey = List<int>.generate(32, (i) => i);
final String testKeyHex =
    testKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

class FakePico {
  final RawDatagramSocket sock;
  List<int> key;
  String boot;

  /// Commands that passed auth and were run (not re-runs of a repeated seq).
  final List<String> executed = [];

  /// Every authenticated command packet, retries included: "seq cmd".
  final List<String> packets = [];
  final Map<String, int> lastSeq = {};
  final Map<String, String> lastAck = {};
  final Set<String> subs = {};
  final Set<String> forbid = {};
  final Set<String> ignoreCmds = {};
  int helloCount = 0;
  int rxCount = 0;
  int authFail = 0;
  int dropAcks = 0;
  bool muteHello = false;
  bool muted = false;
  (InternetAddress, int)? lastSender;

  FakePico._(this.sock, this.key, this.boot);

  static Future<FakePico> start({List<int>? key, String boot = 'abcd1234'}) async {
    final s = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final p = FakePico._(s, key ?? testKey, boot);
    s.listen((e) {
      if (e != RawSocketEvent.read) return;
      Datagram? d;
      while ((d = s.receive()) != null) {
        p._packet(d!);
      }
    });
    return p;
  }

  int get port => sock.port;

  void close() => sock.close();

  void _sendTo(InternetAddress a, int port, Map<String, dynamic> obj) {
    sock.send(utf8.encode(jsonEncode(obj)), a, port);
  }

  void _packet(Datagram d) {
    rxCount++;
    if (muted) return;
    lastSender = (d.address, d.port);
    final addr = '${d.address.address}:${d.port}';
    final parts = utf8.decode(d.data).trim().split(' ');
    if (parts.length == 2 && parts[0] == 'EXA1' && parts[1] == 'hello') {
      helloCount++;
      if (!muteHello) {
        _sendTo(d.address, d.port, {'type': 'hello', 'boot': boot, 'name': 'EspressoPico', 'v': 1});
      }
      return;
    }
    if (parts.length < 5 || parts[0] != 'EXA1') return;
    final b = parts[1], seqS = parts[2], mac = parts[3];
    final cmd = parts.sublist(4).join(' ');
    final seq = int.parse(seqS);
    if (mac != wifiMac16(key, '$b $seqS $cmd')) {
      authFail++;
      return;
    }
    packets.add('$seq $cmd');
    if (ignoreCmds.contains(cmd)) return;
    if (b != boot) {
      _sendTo(d.address, d.port, {'type': 'ack', 'seq': seq, 'r': 'stale'});
      return;
    }
    final last = lastSeq[addr];
    if (last != null && seq <= last) {
      if (seq == last) {
        if (dropAcks > 0) {
          dropAcks--;
          return;
        }
        sock.send(utf8.encode(lastAck[addr]!), d.address, d.port);
      }
      return;
    }
    String r;
    if (forbid.contains(cmd)) {
      r = 'denied';
    } else {
      executed.add(cmd);
      if (cmd == 'sub') subs.add(addr);
      r = 'ok';
    }
    final ack = jsonEncode({'type': 'ack', 'seq': seq, 'r': r});
    lastSeq[addr] = seq;
    lastAck[addr] = ack;
    if (dropAcks > 0) {
      dropAcks--;
      return;
    }
    sock.send(utf8.encode(ack), d.address, d.port);
  }

  /// The Pico restarted: new boot id, all per-sender state gone.
  void reboot(String newBoot) {
    boot = newBoot;
    lastSeq.clear();
    lastAck.clear();
    subs.clear();
    executed.clear();
  }

  void emit(Object obj) {
    final s = lastSender;
    if (s == null) return;
    sock.send(utf8.encode(obj is String ? obj : jsonEncode(obj)), s.$1, s.$2);
  }
}

Future<void> waitFor(bool Function() cond,
    {Duration timeout = const Duration(seconds: 4), String what = 'condition'}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('timed out waiting for $what');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

const fast = WifiTimings(
  helloInterval: Duration(milliseconds: 100),
  subInterval: Duration(milliseconds: 300),
  ackTimeout: Duration(milliseconds: 60),
  connectedWindow: Duration(milliseconds: 400),
  tick: Duration(milliseconds: 50),
  syncGap: Duration(milliseconds: 40),
  brewLogGap: Duration(milliseconds: 70),
);

void main() {
  late FakePico pico;
  late MemoryWifiKeyStore store;
  late WifiRepository repo;

  WifiLinkConfig cfg() =>
      WifiLinkConfig(keyHex: testKeyHex, host: '127.0.0.1', port: pico.port);

  setUp(() async {
    pico = await FakePico.start();
    store = MemoryWifiKeyStore(cfg());
    repo = WifiRepository(store: store, timings: fast);
  });

  tearDown(() async {
    await repo.disconnect();
    pico.close();
  });

  test('HMAC test vector: key 0..31, "abcd1234 7 stbt:90" -> 131fc9407df6b680', () {
    expect(wifiMac16(testKey, 'abcd1234 7 stbt:90'), '131fc9407df6b680');
    // and the same through the package's own HMAC, so the helper is not
    // just agreeing with itself
    final full = Hmac(sha256, testKey).convert(utf8.encode('abcd1234 7 stbt:90'));
    expect(full.toString().substring(0, 16), '131fc9407df6b680');
  });

  test('hello every helloInterval until the Pico answers, then it stops', () async {
    pico.muteHello = true;
    await repo.start();
    await waitFor(() => pico.helloCount >= 3, what: '3 hellos');
    expect(repo.isConnected, isFalse);
    pico.muteHello = false;
    await waitFor(() => repo.isConnected, what: 'connected');
    expect(repo.bootId, 'abcd1234');
    final n = pico.helloCount;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(pico.helloCount, n); // connected: no more hellos
  });

  test('start series: sub, sync, sync (400 ms), brew_log? (700 ms)', () async {
    await repo.start();
    await waitFor(() => pico.executed.length >= 4, what: 'start series');
    expect(pico.executed.take(4).toList(), ['sub', 'sync', 'sync', 'brew_log?']);
  });

  test('commands are signed so the Pico accepts them (wrong key: no ack, 4 tries)', () async {
    await repo.start();
    await waitFor(() => repo.isConnected);
    await repo.sendCommand('stbt:90');
    expect(pico.executed, contains('stbt:90'));
    expect(pico.authFail, 0);

    pico.key = List<int>.generate(32, (i) => 255 - i);
    final before = pico.authFail;
    await repo.sendCommand('stbt:80');
    expect(pico.executed, isNot(contains('stbt:80')));
    expect(pico.authFail - before, 4); // first try + 3 retries
  });

  test('lost ack: same seq is retried and the command runs once', () async {
    await repo.start();
    await waitFor(() => pico.executed.length >= 4);
    pico.dropAcks = 2;
    await repo.sendCommand('pit:3.0');
    final mine = pico.packets.where((p) => p.endsWith(' pit:3.0')).toList();
    expect(mine.length, 3);
    expect(mine.toSet().length, 1); // identical seq every time
    expect(pico.executed.where((c) => c == 'pit:3.0').length, 1);
  });

  test('no answer at all: 1 try + 3 retries, then the next command still goes', () async {
    await repo.start();
    await waitFor(() => pico.executed.length >= 4);
    pico.ignoreCmds.add('bp:9.0');
    final t0 = DateTime.now();
    await repo.sendCommand('bp:9.0');
    expect(DateTime.now().difference(t0), greaterThanOrEqualTo(const Duration(milliseconds: 200)));
    expect(pico.packets.where((p) => p.endsWith(' bp:9.0')).length, 4);
    await repo.sendCommand('bp:8.0');
    expect(pico.executed, contains('bp:8.0'));
  });

  test('a repeated or late ack is ignored (and never reaches dataStream)', () async {
    final seen = <Map<String, dynamic>>[];
    repo.dataStream.listen(seen.add);
    await repo.start();
    await waitFor(() => pico.executed.length >= 4);
    await repo.sendCommand('srt:2.0');
    pico.emit({'type': 'ack', 'seq': 1, 'r': 'ok'});
    pico.emit({'type': 'ack', 'seq': 1, 'r': 'ok'});
    await repo.sendCommand('srt:2.5');
    expect(pico.executed.where((c) => c.startsWith('srt:')).toList(), ['srt:2.0', 'srt:2.5']);
    expect(seen, isEmpty);
  });

  test('stale boot: hello, new boot id, command retried and run; start series again', () async {
    await repo.start();
    await waitFor(() => pico.executed.length >= 4);
    pico.reboot('beef0002'); // the repo has not been told
    await repo.sendCommand('bt:93');
    expect(repo.bootId, 'beef0002');
    expect(pico.executed, contains('bt:93'));
    await waitFor(() => pico.executed.length >= 5, what: 'series after new boot');
    await waitFor(() => pico.executed.contains('brew_log?'), what: 'brew_log? after new boot');
    expect(pico.executed.where((c) => c == 'sync').length, 2);
    expect(pico.executed, contains('sub'));
  });

  test('new boot id seen in a hello restarts the start series', () async {
    await repo.start();
    await waitFor(() => pico.executed.length >= 4);
    pico.reboot('c0ffee03');
    pico.emit({'type': 'hello', 'boot': 'c0ffee03', 'name': 'EspressoPico', 'v': 1});
    await waitFor(() => pico.executed.contains('brew_log?'), what: 'series after hello');
    expect(repo.bootId, 'c0ffee03');
    expect(pico.executed.take(4).toList(), ['sub', 'sync', 'sync', 'brew_log?']);
  });

  test('denied is only logged: the link and the queue carry on', () async {
    await repo.start();
    await waitFor(() => pico.executed.length >= 4);
    pico.forbid.add('tare');
    await repo.sendCommand('tare');
    expect(pico.executed, isNot(contains('tare')));
    expect(repo.isConnected, isTrue);
    await repo.sendCommand('pip:2.0');
    expect(pico.executed, contains('pip:2.0'));
  });

  test('queued commands go out in order, one at a time', () async {
    await repo.start();
    await waitFor(() => pico.executed.length >= 4);
    final a = repo.sendCommand('pit:1');
    final b = repo.sendCommand('srt:2');
    final c = repo.sendCommand('bt:3');
    await Future.wait([a, b, c]);
    final mine = pico.executed.where((x) => x.contains(':')).toList();
    expect(mine, ['pit:1', 'srt:2', 'bt:3']);
  });

  test('dataStream: Pico JSON objects only; ack/hello/wifi_key, garbage and strangers are filtered', () async {
    final seen = <Map<String, dynamic>>[];
    repo.dataStream.listen(seen.add);
    await repo.start();
    await waitFor(() => pico.executed.length >= 4);
    pico.emit({'boiler_temperature': 91.5, 'pressure': 9.1, 'mode': 'IDLE'});
    pico.emit({'type': 'ack', 'seq': 5, 'r': 'ok'});
    pico.emit({'type': 'hello', 'boot': 'abcd1234'});
    pico.emit({'type': 'wifi_key', 'key': '00' * 32, 'host': '1.2.3.4', 'port': 1});
    pico.emit('not json at all');
    pico.emit('[1,2,3]');
    pico.emit({'type': 'brew_log', 'part': 'meta', 'id': 7});
    // a stranger (other source port) with a perfectly good live packet
    final rogue = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final me = pico.lastSender!;
    rogue.send(utf8.encode(jsonEncode({'boiler_temperature': 1.0})), me.$1, me.$2);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    rogue.close();
    expect(seen, [
      {'boiler_temperature': 91.5, 'pressure': 9.1, 'mode': 'IDLE'},
      {'type': 'brew_log', 'part': 'meta', 'id': 7},
    ]);
  });

  test('isConnected: packet within the window; silence drops it; hello brings it back', () async {
    final events = <bool>[];
    repo.isConnectedStream.listen(events.add);
    await repo.start();
    await waitFor(() => repo.isConnected);
    pico.muted = true;
    await waitFor(() => !repo.isConnected, what: 'drop after silence');
    expect(events, [true, false]);
    pico.muted = false;
    pico.executed.clear();
    await waitFor(() => repo.isConnected, what: 'back up');
    await waitFor(() => pico.executed.contains('brew_log?'), what: 'series after recovery');
    expect(events, [true, false, true]);
  });

  test('sub is renewed every subInterval', () async {
    await repo.start();
    await waitFor(() => pico.executed.where((c) => c == 'sub').length >= 3,
        what: 'three subs');
  });

  test('without a key nothing is sent; saving one connects', () async {
    await repo.disconnect();
    final empty = MemoryWifiKeyStore();
    final r = WifiRepository(store: empty, timings: fast);
    await r.start();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(pico.rxCount, 0);
    expect(r.isConnected, isFalse);
    expect(r.hasKey, isFalse);
    await empty.save(cfg());
    await waitFor(() => r.isConnected, what: 'connected after key saved');
    await r.disconnect();
  });

  test('a malformed stored key is no key', () async {
    await repo.disconnect();
    final bad = MemoryWifiKeyStore(
        WifiLinkConfig(keyHex: 'zz' * 32, host: '127.0.0.1', port: pico.port));
    final r = WifiRepository(store: bad, timings: fast);
    await r.start();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(pico.rxCount, 0);
    await r.disconnect();
  });

  test('paused closes the socket; resumed opens a new one and says hello', () async {
    await repo.start();
    await waitFor(() => pico.executed.length >= 4, what: 'start series');
    final firstPort = pico.lastSender!.$2;
    repo.onAppPaused();
    expect(repo.isConnected, isFalse);
    final n = pico.rxCount;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(pico.rxCount, n); // silent in the background
    await repo.onAppResumed();
    await waitFor(() => repo.isConnected, what: 'connected after resume');
    expect(pico.lastSender!.$2, isNot(firstPort));
  });

  test('the config is not printed: toString hides the key', () {
    expect(cfg().toString(), isNot(contains(testKeyHex)));
    expect(cfg().toString(), contains('***'));
  });
}
