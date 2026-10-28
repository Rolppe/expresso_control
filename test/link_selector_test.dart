// LinkSelector with two fake links: auto switch and hysteresis, no switch in
// the middle of a brew log, only the active link's data, BLE never stopped.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:silvia_pico_ui/features/link/link_selector.dart';
import 'package:silvia_pico_ui/features/link/machine_link.dart';
import 'package:silvia_pico_ui/features/link/wifi_key_store.dart';

class FakeLink implements WifiLink {
  final data = StreamController<Map<String, dynamic>>.broadcast();
  final conn = StreamController<bool>.broadcast();
  bool up = false;
  final List<String> sent = [];
  int startScans = 0, disconnects = 0, resumes = 0, pauses = 0, starts = 0, brewLogReqs = 0;

  @override
  Stream<bool> get isConnectedStream => conn.stream;
  @override
  bool get isConnected => up;
  @override
  Stream<Map<String, dynamic>> get dataStream => data.stream;
  @override
  Future<void> sendCommand(String command) async => sent.add(command);
  @override
  void requestPendingBrewLog() {
    brewLogReqs++;
    sent.add('brew_log?');
  }
  @override
  Future<void> onAppResumed() async => resumes++;
  @override
  void onAppPaused() => pauses++;
  @override
  Future<void> startScan({bool force = false}) async => startScans++;
  @override
  Future<void> disconnect() async => disconnects++;
  @override
  String deviceSummary() => 'fake up=$up';
  @override
  Future<void> start() async => starts++;
  @override
  bool hasKey = true;
  @override
  String? bootId = 'b1';
  @override
  DateTime? lastPacketAt;

  void setUp(bool v) {
    up = v;
    conn.add(v);
  }
}

const hyst = Duration(milliseconds: 150);
const quiet = Duration(milliseconds: 400);

Future<void> pause(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late FakeLink ble, wifi;
  late MemoryWifiKeyStore store;
  late LinkSelector sel;
  late List<Map<String, dynamic>> got;

  LinkSelector make({LinkMode mode = LinkMode.auto, bool autoKey = true}) {
    final s = LinkSelector(
      ble: ble,
      wifi: wifi,
      keyStore: store,
      mode: mode,
      hysteresis: hyst,
      brewLogQuiet: quiet,
      keyRequestDelay: const Duration(milliseconds: 50),
      keyRetryInterval: const Duration(milliseconds: 60),
      autoKeyRequest: autoKey,
    );
    got = [];
    s.dataStream.listen(got.add);
    return s;
  }

  setUp(() {
    ble = FakeLink();
    wifi = FakeLink();
    store = MemoryWifiKeyStore();
    sel = make();
  });

  tearDown(() => sel.dispose());

  test('starts on BLE; Wi-Fi up -> switch only after the 3 s (here 150 ms) hysteresis', () async {
    ble.setUp(true);
    expect(sel.active, LinkKind.ble);
    wifi.setUp(true);
    await pause(60);
    expect(sel.active, LinkKind.ble); // not yet
    await pause(150);
    expect(sel.active, LinkKind.wifi);
  });

  test('hysteresis: Wi-Fi up and down inside the window changes nothing', () async {
    ble.setUp(true);
    wifi.setUp(true);
    await pause(80);
    wifi.setUp(false);
    await pause(250);
    expect(sel.active, LinkKind.ble);
    wifi.setUp(true);
    await pause(80);
    wifi.setUp(false);
    await pause(250);
    expect(sel.active, LinkKind.ble);
  });

  test('Wi-Fi lost: back to BLE after the hysteresis', () async {
    ble.setUp(true);
    wifi.setUp(true);
    await pause(250);
    expect(sel.active, LinkKind.wifi);
    wifi.setUp(false);
    await pause(60);
    expect(sel.active, LinkKind.wifi);
    await pause(150);
    expect(sel.active, LinkKind.ble);
  });

  test('no switch in the middle of a brew log (frame < quiet ago), then it switches', () async {
    ble.setUp(true);
    wifi.setUp(true);
    // frames keep coming from BLE (the active link) past the hysteresis
    for (var i = 0; i < 6; i++) {
      ble.data.add({'type': 'brew_log', 'part': 'samples', 'id': 1});
      await pause(100);
    }
    expect(sel.active, LinkKind.ble);
    await pause(750); // quiet again
    expect(sel.active, LinkKind.wifi);
  });

  test('only the active link\'s data is forwarded', () async {
    ble.setUp(true);
    ble.data.add({'src': 'ble1'});
    wifi.data.add({'src': 'wifi-early'});
    await pause(20);
    expect(got.map((j) => j['src']), ['ble1']);
    wifi.setUp(true);
    await pause(250);
    expect(sel.active, LinkKind.wifi);
    ble.data.add({'src': 'ble-late'});
    wifi.data.add({'src': 'wifi1'});
    await pause(20);
    expect(got.map((j) => j['src']), ['ble1', 'wifi1']);
  });

  test('commands go to the active link', () async {
    ble.setUp(true);
    await sel.sendCommand('pit:3.0');
    expect(ble.sent, contains('pit:3.0'));
    wifi.setUp(true);
    await pause(250);
    await sel.sendCommand('srt:2.0');
    expect(wifi.sent, contains('srt:2.0'));
    expect(ble.sent, isNot(contains('srt:2.0')));
  });

  test('switching starts the new link like a connect: sync and brew_log?', () async {
    ble.setUp(true);
    wifi.setUp(true);
    wifi.sent.clear();
    await pause(250);
    expect(wifi.sent, ['sync', 'brew_log?']);
  });

  test('isConnected follows the active link and the stream reports changes', () async {
    final events = <bool>[];
    sel.isConnectedStream.listen(events.add);
    ble.setUp(true);
    await pause(10);
    expect(sel.isConnected, isTrue);
    wifi.setUp(true);
    await pause(250);
    expect(sel.isConnected, isTrue);
    expect(events, [true]); // BLE -> Wi-Fi, both up: no flap
    wifi.up = false;
    wifi.conn.add(false);
    await pause(20);
    expect(events, [true, false]); // active Wi-Fi went down during hysteresis
  });

  test('mode wifi / ble pins the link at once; auto resumes the rule', () async {
    ble.setUp(true);
    wifi.setUp(false);
    sel.setMode(LinkMode.wifi);
    expect(sel.active, LinkKind.wifi);
    sel.setMode(LinkMode.ble);
    wifi.setUp(true);
    await pause(300);
    expect(sel.active, LinkKind.ble); // pinned
    sel.setMode(LinkMode.auto);
    await pause(250);
    expect(sel.active, LinkKind.wifi);
  });

  test('BLE is never stopped: no disconnect, no pause of its scan, whatever the mode', () async {
    ble.setUp(true);
    wifi.setUp(true);
    await pause(250);
    sel.setMode(LinkMode.wifi);
    sel.setMode(LinkMode.ble);
    sel.setMode(LinkMode.auto);
    await sel.disconnect();
    expect(ble.disconnects, 0);
    expect(wifi.disconnects, 1); // the selector's disconnect() ends Wi-Fi only
    await sel.startScan(force: true);
    expect(ble.startScans, 1);
    expect(wifi.startScans, 1);
  });

  test('background: BLE at once (no hysteresis), resume goes back to the rule', () async {
    ble.setUp(true);
    wifi.setUp(true);
    await pause(250);
    expect(sel.active, LinkKind.wifi);
    sel.onAppPaused();
    expect(sel.active, LinkKind.ble);
    expect(ble.pauses, 1);
    expect(wifi.pauses, 1);
    await sel.onAppResumed();
    expect(ble.resumes, 1);
    expect(wifi.resumes, 1);
    await pause(250);
    expect(sel.active, LinkKind.wifi);
  });

  test('BLE brew_log frames in the background still reach the app', () async {
    ble.setUp(true);
    wifi.setUp(true);
    await pause(250);
    sel.onAppPaused();
    ble.data.add({'type': 'brew_log', 'part': 'meta', 'id': 3});
    await pause(20);
    expect(got.where((j) => j['type'] == 'brew_log').length, 1);
  });

  test('BLE up without a key: wifi:key? goes over BLE even when Wi-Fi is active', () async {
    ble.setUp(true);
    await pause(200);
    expect(ble.sent, contains('wifi:key?'));
    await sel.sendCommand('wifi:key?'); // explicit use stays on BLE as well
    wifi.setUp(true);
    await pause(250);
    wifi.sent.clear();
    await sel.sendCommand('wifi:key?');
    expect(wifi.sent, isEmpty);
  });

  test('a stored key stops the requests', () async {
    await store.save(WifiLinkConfig(keyHex: '11' * 32));
    ble.setUp(true);
    await pause(250);
    expect(ble.sent, isNot(contains('wifi:key?')));
  });

  test('wifi_key from BLE is stored (host/port kept), not forwarded', () async {
    ble.setUp(true);
    ble.data.add({
      'type': 'wifi_key',
      'key': 'ab' * 32,
      'host': '192.0.2.10',
      'port': 47211,
    });
    await pause(50);
    final cfg = await store.load();
    expect(cfg, isNotNull);
    expect(cfg!.keyHex, 'ab' * 32);
    expect(cfg.host, '192.0.2.10');
    expect(cfg.port, 47211);
    expect(got, isEmpty);
  });

  test('wifi_key with a bad key or unknown address: bad key ignored, "?" -> default host', () async {
    ble.setUp(true);
    ble.data.add({'type': 'wifi_key', 'key': 'xyz', 'host': '1.2.3.4', 'port': 1});
    await pause(30);
    expect(await store.load(), isNull);
    ble.data.add({'type': 'wifi_key', 'key': 'cd' * 32, 'host': '?', 'port': 47211});
    await pause(30);
    final cfg = await store.load();
    expect(cfg!.host, wifiDefaultHost);
  });

  test('enableBackgroundWatch starts Wi-Fi after BLE', () async {
    var bleStarted = 0;
    final s = LinkSelector(
      ble: ble,
      wifi: wifi,
      keyStore: store,
      bleWatch: () async => bleStarted++,
    );
    await s.enableBackgroundWatch();
    expect(bleStarted, 1);
    expect(wifi.starts, 1);
    s.dispose();
  });

  test('linkModeFromName', () {
    expect(linkModeFromName('wifi'), LinkMode.wifi);
    expect(linkModeFromName('ble'), LinkMode.ble);
    expect(linkModeFromName('auto'), LinkMode.auto);
    expect(linkModeFromName(null), LinkMode.auto);
    expect(linkModeFromName('x'), LinkMode.auto);
  });
}
