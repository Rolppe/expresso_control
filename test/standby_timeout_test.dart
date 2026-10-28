import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silvia_pico_ui/core/providers.dart';
import 'package:silvia_pico_ui/core/standby_timeout.dart';
import 'package:silvia_pico_ui/features/link/link_selector.dart';
import 'package:silvia_pico_ui/features/link/machine_link.dart';
import 'package:silvia_pico_ui/features/link/wifi_key_store.dart';
import 'package:silvia_pico_ui/features/ui/views/home_view.dart';
import 'package:silvia_pico_ui/features/ui/widgets/standby_overlay.dart';
import 'package:silvia_pico_ui/models/machine_status.dart';

class TestLink implements WifiLink {
  final List<String> sent = [];
  final connController = StreamController<bool>.broadcast();
  final dataController = StreamController<Map<String, dynamic>>.broadcast();
  bool connected = false;

  @override
  bool get isConnected => connected;

  @override
  Stream<bool> get isConnectedStream => connController.stream;

  @override
  Stream<Map<String, dynamic>> get dataStream => dataController.stream;

  @override
  Future<void> sendCommand(String command) async {
    sent.add(command);
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> onAppResumed() async {}

  @override
  void onAppPaused() {}

  @override
  void requestPendingBrewLog() {}

  @override
  Future<void> start() async {}

  @override
  Future<void> startScan({bool force = false}) async {}

  @override
  String deviceSummary() => 'test';

  @override
  bool hasKey = true;

  @override
  String? bootId = 'b1';

  @override
  DateTime? lastPacketAt;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('standby labels and ranges', () {
    test('labels format correctly', () {
      expect(standbyTimeoutLabel(0), 'Pois');
      expect(standbyTimeoutLabel(15), '15 min');
      expect(standbyTimeoutLabel(45), '45 min');
      expect(standbyTimeoutLabel(60), '1 h');
      expect(standbyTimeoutLabel(90), '1 h 30 min');
      expect(standbyTimeoutLabel(120), '2 h');
      expect(standbyTimeoutLabel(150), '2 h 30 min');
      expect(standbyTimeoutLabel(240), '4 h');
    });

    test('startup choices are within 1h - 4h', () {
      for (final m in standbyStartupTimeoutChoices) {
        expect(m >= 60 && m <= 240, isTrue);
      }
      expect(standbyStartupTimeoutChoices.first, 60);
      expect(standbyStartupTimeoutChoices.last, 240);
    });

    test('brew choices are within 15min - 2h', () {
      for (final m in standbyBrewTimeoutChoices) {
        expect(m >= 15 && m <= 120, isTrue);
      }
      expect(standbyBrewTimeoutChoices.first, 15);
      expect(standbyBrewTimeoutChoices.last, 120);
    });
  });

  group('standby notifiers', () {
    late TestLink link;
    late TestLink dummyWifi;
    late MemoryWifiKeyStore keyStore;
    late LinkSelector selector;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      link = TestLink();
      dummyWifi = TestLink();
      link.connected = true;
      keyStore = MemoryWifiKeyStore();
      selector = LinkSelector(
        ble: link,
        wifi: dummyWifi,
        keyStore: keyStore,
        mode: LinkMode.ble,
        wifiEnabled: false,
        autoKeyRequest: false,
      );
      container = ProviderContainer(
        overrides: [
          machineLinkProvider.overrideWithValue(selector),
        ],
      );
    });

    tearDown(() {
      selector.dispose();
      container.dispose();
    });

    test('startup notifier defaults to 120 and sends stby:start on change', () async {
      final notifier = container.read(standbyStartupTimeoutProvider.notifier);
      expect(container.read(standbyStartupTimeoutProvider), 120);

      await notifier.set(180);
      expect(container.read(standbyStartupTimeoutProvider), 180);
      expect(link.sent, contains('stby:start:180'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('standbyStartupTimeoutMin'), 180);
    });

    test('brew notifier defaults to 30 and sends stby:brew on change', () async {
      final notifier = container.read(standbyBrewTimeoutProvider.notifier);
      expect(container.read(standbyBrewTimeoutProvider), 30);

      await notifier.set(45);
      expect(container.read(standbyBrewTimeoutProvider), 45);
      expect(link.sent, contains('stby:brew:45'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('standbyTimeoutMin'), 45);
    });

    test('wakeFromStandby sends stby:wake and clears standby state', () async {
      container.read(machineDataProvider);
      link.dataController.add({'boiler_temperature': 90.0, 'standby': true});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(machineDataProvider).standby, isTrue);

      final dataNotifier = container.read(machineDataProvider.notifier);
      await dataNotifier.wakeFromStandby();
      expect(container.read(machineDataProvider).standby, isFalse);
      expect(link.sent, contains('stby:wake'));
    });

    test('enterStandby sends stby:on and sets standby state', () async {
      container.read(machineDataProvider);
      link.dataController.add({'boiler_temperature': 95.0, 'standby': false});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(machineDataProvider).standby, isFalse);

      final dataNotifier = container.read(machineDataProvider.notifier);
      await dataNotifier.enterStandby();
      expect(container.read(machineDataProvider).standby, isTrue);
      expect(link.sent, contains('stby:on'));
    });
  });

  group('StandbyOverlay widget', () {
    testWidgets('renders standby message and wake button', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final link = TestLink();
      final dummyWifi = TestLink();
      link.connected = true;
      final keyStore = MemoryWifiKeyStore();
      final selector = LinkSelector(
        ble: link,
        wifi: dummyWifi,
        keyStore: keyStore,
        mode: LinkMode.ble,
        wifiEnabled: false,
        autoKeyRequest: false,
      );

      final container = ProviderContainer(
        overrides: [
          machineLinkProvider.overrideWithValue(selector),
        ],
      );

      const status = MachineStatus(
        boilerTemperature: 90.5,
        standby: true,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: StandbyOverlay(data: status),
            ),
          ),
        ),
      );

      expect(find.text('Keitin on lepotilassa'), findsOneWidget);
      expect(find.textContaining('90.5 °C'), findsOneWidget);
      expect(find.text('Herätä lepotilasta'), findsOneWidget);

      await tester.tap(find.text('Herätä lepotilasta'));
      await tester.pump();

      expect(link.sent, contains('stby:wake'));

      selector.dispose();
      container.dispose();
    });

    testWidgets('renders close button when onClose provided and invokes callback', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final link = TestLink();
      final dummyWifi = TestLink();
      link.connected = true;
      final keyStore = MemoryWifiKeyStore();
      final selector = LinkSelector(
        ble: link,
        wifi: dummyWifi,
        keyStore: keyStore,
        mode: LinkMode.ble,
        wifiEnabled: false,
        autoKeyRequest: false,
      );

      final container = ProviderContainer(
        overrides: [
          machineLinkProvider.overrideWithValue(selector),
        ],
      );

      const status = MachineStatus(
        boilerTemperature: 85.0,
        standby: true,
      );

      bool closed = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: StandbyOverlay(
                data: status,
                onClose: () => closed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('standby_overlay_close_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('standby_overlay_close_button')));
      await tester.pump();

      expect(closed, isTrue);

      selector.dispose();
      container.dispose();
    });

    testWidgets('HomeView dismisses StandbyOverlay when X is tapped', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final link = TestLink();
      final dummyWifi = TestLink();
      link.connected = true;
      final keyStore = MemoryWifiKeyStore();
      final selector = LinkSelector(
        ble: link,
        wifi: dummyWifi,
        keyStore: keyStore,
        mode: LinkMode.ble,
        wifiEnabled: false,
        autoKeyRequest: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            machineLinkProvider.overrideWithValue(selector),
          ],
          child: const MaterialApp(
            home: HomeView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(HomeView));
      final ref = ProviderScope.containerOf(element);

      // Trigger standby
      await ref.read(machineDataProvider.notifier).enterStandby();
      await tester.pumpAndSettle();

      // StandbyOverlay is visible
      expect(find.byType(StandbyOverlay), findsOneWidget);
      expect(find.byKey(const Key('standby_overlay_close_button')), findsOneWidget);

      // Tap close button (X)
      await tester.tap(find.byKey(const Key('standby_overlay_close_button')));
      await tester.pumpAndSettle();

      // StandbyOverlay is gone, revealing main view
      expect(find.byType(StandbyOverlay), findsNothing);
      expect(find.text('Fast heatup'), findsOneWidget);
      expect(find.byKey(const Key('wake_from_standby_controls_button')), findsOneWidget);

      // Tapping wake button wakes machine up
      await tester.tap(find.byKey(const Key('wake_from_standby_controls_button')));
      await tester.pumpAndSettle();
      expect(ref.read(machineDataProvider).standby, isFalse);
      expect(find.byKey(const Key('wake_from_standby_controls_button')), findsNothing);

      // If user enters standby, dismisses, and later re-opens app:
      await ref.read(machineDataProvider.notifier).enterStandby();
      await tester.pumpAndSettle();
      expect(find.byType(StandbyOverlay), findsOneWidget);

      await tester.tap(find.byKey(const Key('standby_overlay_close_button')));
      await tester.pumpAndSettle();
      expect(find.byType(StandbyOverlay), findsNothing);

      // Re-opening / resuming app presents the standby overlay again
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(StandbyOverlay), findsOneWidget);
    });
  });
}
