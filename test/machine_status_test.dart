import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silvia_pico_ui/core/providers.dart';
import 'package:silvia_pico_ui/features/link/link_selector.dart';
import 'package:silvia_pico_ui/features/link/machine_link.dart';
import 'package:silvia_pico_ui/features/link/wifi_key_store.dart';
import 'package:silvia_pico_ui/features/ui/widgets/controls_widget.dart';
import 'package:silvia_pico_ui/models/machine_status.dart';

class FakeLink implements WifiLink {
  final data = StreamController<Map<String, dynamic>>.broadcast();
  final conn = StreamController<bool>.broadcast();
  final List<String> sent = [];
  bool up = false;

  @override
  Stream<bool> get isConnectedStream => conn.stream;
  @override
  bool get isConnected => up;
  @override
  Stream<Map<String, dynamic>> get dataStream => data.stream;
  @override
  Future<void> sendCommand(String command) async {
    sent.add(command);
  }
  @override
  void requestPendingBrewLog() {}
  @override
  Future<void> onAppResumed() async {}
  @override
  void onAppPaused() {}
  @override
  Future<void> startScan({bool force = false}) async {}
  @override
  Future<void> disconnect() async {}
  @override
  String deviceSummary() => 'fake up=$up';
  bool get enableBackgroundWatch => false;
  @override
  Future<void> start() async {}
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

void main() {
  group('MachineStatus model', () {
    test('default steamTemperature is 135.0, steamTemperatureMax is 140.0, steamValveTrigger is 1.8, steamValveRelease is 2.1, steamPressureHigh is 2.5', () {
      const status = MachineStatus();
      expect(status.steamTemperature, 135.0);
      expect(status.steamTemperatureMax, 140.0);
      expect(status.steamValveTrigger, 1.8);
      expect(status.steamValveRelease, 2.1);
      expect(status.steamPressureLow, 1.8);
      expect(status.steamPressureHigh, 2.5);
    });

    test('fromJson deserializes steam_temperature, steam_temperature_max and steam valve trigger/release', () {
      final fromSnake = MachineStatus.fromJson({
        'steam_temperature': 130.0,
        'steam_temperature_max': 138.0,
        'steam_valve_trigger': 1.6,
        'steam_valve_release': 2.2,
        'steam_pressure_high': 2.7,
      });
      expect(fromSnake.steamTemperature, 130.0);
      expect(fromSnake.steamTemperatureMax, 138.0);
      expect(fromSnake.steamValveTrigger, 1.6);
      expect(fromSnake.steamValveRelease, 2.2);
      expect(fromSnake.steamPressureLow, 1.6);
      expect(fromSnake.steamPressureHigh, 2.7);

      final fromCamel = MachineStatus.fromJson({
        'steamTemperature': 138.5,
        'steamTemperatureMax': 142.0,
        'steamValveTrigger': 1.5,
        'steamValveRelease': 2.3,
        'steamPressureHigh': 2.9,
      });
      expect(fromCamel.steamTemperature, 138.5);
      expect(fromCamel.steamTemperatureMax, 142.0);
      expect(fromCamel.steamValveTrigger, 1.5);
      expect(fromCamel.steamValveRelease, 2.3);
      expect(fromCamel.steamPressureLow, 1.5);
      expect(fromCamel.steamPressureHigh, 2.9);

      final defaultVal = MachineStatus.fromJson({});
      expect(defaultVal.steamTemperature, 135.0);
      expect(defaultVal.steamTemperatureMax, 140.0);
      expect(defaultVal.steamValveTrigger, 1.8);
      expect(defaultVal.steamValveRelease, 2.1);
      expect(defaultVal.steamPressureHigh, 2.5);
      expect(defaultVal.firstDrop, false);
      expect(defaultVal.firstDropTime, null);
      expect(defaultVal.preInfusionTriggerOn, false);
      expect(defaultVal.preInfusionTriggerThreshold, 0.25);
    });

    test('fromJson deserializes pre_infusion_trigger_mode and pre_infusion_trigger_threshold', () {
      final s1 = MachineStatus.fromJson({
        'pre_infusion_trigger_mode': true,
        'pre_infusion_trigger_threshold': 0.15,
      });
      expect(s1.preInfusionTriggerOn, true);
      expect(s1.preInfusionTriggerThreshold, 0.15);

      final s2 = MachineStatus.fromJson({
        'preInfusionTriggerOn': true,
        'preInfusionTriggerThreshold': 0.35,
      });
      expect(s2.preInfusionTriggerOn, true);
      expect(s2.preInfusionTriggerThreshold, 0.35);
    });

    test('fromJson deserializes peq_mode, idle_pressure_equalize_mode, and peq into pressureEqualizationOn', () {
      final s1 = MachineStatus.fromJson({'peq_mode': true});
      expect(s1.pressureEqualizationOn, true);

      final s2 = MachineStatus.fromJson({'idle_pressure_equalize_mode': true});
      expect(s2.pressureEqualizationOn, true);

      final s3 = MachineStatus.fromJson({'peq': true});
      expect(s3.pressureEqualizationOn, true);

      final s4 = MachineStatus.fromJson({'peq_mode': false});
      expect(s4.pressureEqualizationOn, false);
    });

    test('fromJson deserializes first_drop and first_drop_time', () {
      final s1 = MachineStatus.fromJson({
        'first_drop': true,
        'first_drop_time': 7,
      });
      expect(s1.firstDrop, true);
      expect(s1.firstDropTime, 7);

      final s2 = MachineStatus.fromJson({
        'firstDrop': true,
        'firstDropTime': 5,
      });
      expect(s2.firstDrop, true);
      expect(s2.firstDropTime, 5);
    });

    test('toJson serializes steamTemperature, steamTemperatureMax and steam valve trigger/release', () {
      const status = MachineStatus(
        steamTemperature: 132.0,
        steamTemperatureMax: 139.0,
        steamValveTrigger: 1.4,
        steamValveRelease: 2.2,
        steamPressureHigh: 2.8,
      );
      final json = status.toJson();
      expect(json['steamTemperature'], 132.0);
      expect(json['steamTemperatureMax'], 139.0);
      expect(json['steamValveTrigger'], 1.4);
      expect(json['steamValveRelease'], 2.2);
      expect(json['steamPressureHigh'], 2.8);
    });

    test('copyWith updates steamTemperature, steamTemperatureMax and steam valve trigger/release', () {
      const status = MachineStatus();
      final updated = status.copyWith(
        steamTemperature: 125.0,
        steamTemperatureMax: 137.0,
        steamValveTrigger: 1.2,
        steamValveRelease: 2.0,
        steamPressureHigh: 2.2,
      );
      expect(updated.steamTemperature, 125.0);
      expect(updated.steamTemperatureMax, 137.0);
      expect(updated.steamValveTrigger, 1.2);
      expect(updated.steamValveRelease, 2.0);
      expect(updated.steamPressureHigh, 2.2);
    });
  });

  group('MachineDataNotifier & steam settings', () {
    late FakeLink fakeBle;
    late FakeLink fakeWifi;
    late MemoryWifiKeyStore keyStore;
    late LinkSelector selector;
    late ProviderContainer container;

    setUp(() {
      fakeBle = FakeLink();
      fakeWifi = FakeLink();
      fakeBle.setUp(true);
      keyStore = MemoryWifiKeyStore();
      selector = LinkSelector(
        ble: fakeBle,
        wifi: fakeWifi,
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
      container.dispose();
      selector.dispose();
    });

    test('setSteamTemperatureLocal clamps to [120.0, 140.0]', () {
      final notifier = container.read(machineDataProvider.notifier);
      expect(container.read(machineDataProvider).steamTemperature, 135.0);

      notifier.setSteamTemperatureLocal(115.0);
      expect(container.read(machineDataProvider).steamTemperature, 120.0);

      notifier.setSteamTemperatureLocal(137.5);
      expect(container.read(machineDataProvider).steamTemperature, 137.5);

      notifier.setSteamTemperatureLocal(145.0);
      expect(container.read(machineDataProvider).steamTemperature, 140.0);
    });

    test('setSteamTemperatureMaxLocal clamps to [125.0, 145.0]', () {
      final notifier = container.read(machineDataProvider.notifier);
      expect(container.read(machineDataProvider).steamTemperatureMax, 140.0);

      notifier.setSteamTemperatureMaxLocal(120.0);
      expect(container.read(machineDataProvider).steamTemperatureMax, 125.0);

      notifier.setSteamTemperatureMaxLocal(138.5);
      expect(container.read(machineDataProvider).steamTemperatureMax, 138.5);

      notifier.setSteamTemperatureMaxLocal(150.0);
      expect(container.read(machineDataProvider).steamTemperatureMax, 145.0);
    });

    test('setSteamValveTriggerLocal, setSteamValveReleaseLocal and HighLocal clamp to ranges', () {
      final notifier = container.read(machineDataProvider.notifier);
      expect(container.read(machineDataProvider).steamValveTrigger, 1.8);
      expect(container.read(machineDataProvider).steamValveRelease, 2.1);
      expect(container.read(machineDataProvider).steamPressureHigh, 2.5);

      notifier.setSteamValveTriggerLocal(0.2);
      expect(container.read(machineDataProvider).steamValveTrigger, 0.5);
      expect(container.read(machineDataProvider).steamPressureLow, 0.5);
      notifier.setSteamValveTriggerLocal(3.5);
      expect(container.read(machineDataProvider).steamValveTrigger, 3.0);
      expect(container.read(machineDataProvider).steamPressureLow, 3.0);

      notifier.setSteamValveReleaseLocal(0.4);
      expect(container.read(machineDataProvider).steamValveRelease, 0.6);
      notifier.setSteamValveReleaseLocal(3.8);
      expect(container.read(machineDataProvider).steamValveRelease, 3.2);

      notifier.setSteamPressureHighLocal(0.5);
      expect(container.read(machineDataProvider).steamPressureHigh, 1.0);
      notifier.setSteamPressureHighLocal(4.0);
      expect(container.read(machineDataProvider).steamPressureHigh, 3.5);
    });

    test('settings packet with steam_temperature, steam_temperature_max and steam valve trigger/release updates state', () async {
      // Subscribe to provider
      container.read(machineDataProvider);

      // Send settings payload over active fake link
      fakeBle.data.add({
        'type': 'settings',
        'brew_temperature': 96.0,
        'steam_temperature': 133.0,
        'steam_temperature_max': 139.0,
        'steam_valve_trigger': 1.6,
        'steam_valve_release': 2.2,
        'steam_pressure_high': 2.7,
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final current = container.read(machineDataProvider);
      expect(current.brewTemperature, 96.0);
      expect(current.steamTemperature, 133.0);
      expect(current.steamTemperatureMax, 139.0);
      expect(current.steamValveTrigger, 1.6);
      expect(current.steamValveRelease, 2.2);
      expect(current.steamPressureHigh, 2.7);
    });

    test('first_drop payload updates MachineStatus', () async {
      container.read(machineDataProvider);

      fakeBle.data.add({
        'boiler_temperature': 93.5,
        'pressure': 8.5,
        'mode': 'BREW',
        'first_drop': true,
        'first_drop_time': 6,
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final current = container.read(machineDataProvider);
      expect(current.firstDrop, true);
      expect(current.firstDropTime, 6);
    });

    test('pre_infusion_trigger settings payload updates MachineStatus', () async {
      container.read(machineDataProvider);

      fakeBle.data.add({
        'type': 'settings',
        'brew_temperature': 96.0,
        'pre_infusion_trigger_mode': true,
        'pre_infusion_trigger_threshold': 0.15,
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final current = container.read(machineDataProvider);
      expect(current.preInfusionTriggerOn, true);
      expect(current.preInfusionTriggerThreshold, 0.15);
    });

    test('peq_mode settings payload updates MachineStatus pressureEqualizationOn', () async {
      container.read(machineDataProvider);

      fakeBle.data.add({
        'type': 'settings',
        'brew_pressure': 8.0,
        'peq_mode': true,
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final current = container.read(machineDataProvider);
      expect(current.pressureEqualizationOn, true);
    });

    testWidgets('ControlsWidget renders collapsed sections by default and opens on click', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            machineLinkProvider.overrideWithValue(selector),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ControlsWidget(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sections are collapsed by default
      expect(find.text('Fast heatup'), findsOneWidget);
      expect(find.text('Preinfusion'), findsOneWidget);
      expect(find.text('Brew'), findsOneWidget);
      expect(find.text('Steam'), findsOneWidget);
      expect(find.text('Sleep'), findsOneWidget);

      // Sliders/buttons are collapsed (not yet visible)
      expect(find.text('Steam temperature'), findsNothing);
      expect(find.text('Pressure equalization'), findsNothing);
      expect(find.text('Preinfusion trigger'), findsNothing);
      expect(find.text('Siirry lepotilaan'), findsNothing);

      // Open Fast heatup
      await tester.tap(find.byKey(const Key('section_fastheatup')));
      await tester.pumpAndSettle();
      expect(find.text('Pressure equalization'), findsOneWidget);

      // Open Preinfusion
      await tester.tap(find.byKey(const Key('section_preinfusion')));
      await tester.pumpAndSettle();
      expect(find.text('Preinfusion trigger'), findsOneWidget);
      expect(find.text('Trigger threshold'), findsOneWidget);

      // Open Steam (ensure visible in scroll view)
      await tester.ensureVisible(find.byKey(const Key('section_steam')));
      await tester.tap(find.byKey(const Key('section_steam')));
      await tester.pumpAndSettle();
      expect(find.text('Steam temperature'), findsOneWidget);
      expect(find.text('Steam max temp'), findsOneWidget);
      expect(find.text('135.0 °C'), findsOneWidget);
      expect(find.text('140.0 °C'), findsOneWidget);
      expect(find.text('Steam valve trigger'), findsOneWidget);
      expect(find.text('1.8 bar'), findsOneWidget);
      expect(find.text('Steam valve release'), findsOneWidget);
      expect(find.text('2.1 bar'), findsOneWidget);
      expect(find.text('Steam pressure max'), findsOneWidget);
      expect(find.text('2.5 bar'), findsOneWidget);

      // Open Sleep (ensure visible in scroll view)
      await tester.ensureVisible(find.byKey(const Key('section_sleep')));
      await tester.tap(find.byKey(const Key('section_sleep')));
      await tester.pumpAndSettle();
      expect(find.text('Siirry lepotilaan'), findsOneWidget);
    });

    testWidgets('ControlsWidget renders wake button above groups when in standby and sends stby:wake', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            machineLinkProvider.overrideWithValue(selector),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ControlsWidget(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(ControlsWidget));
      final ref = ProviderScope.containerOf(element);

      // Enter standby
      await ref.read(machineDataProvider.notifier).enterStandby();
      await tester.pumpAndSettle();

      // Wake button must be visible above settings groups
      expect(find.byKey(const Key('wake_from_standby_controls_button')), findsOneWidget);
      expect(find.text('Herätä lepotilasta'), findsOneWidget);

      // Tap wake button
      await tester.tap(find.byKey(const Key('wake_from_standby_controls_button')));
      await tester.pumpAndSettle();

      expect(fakeBle.sent, contains('stby:wake'));
      expect(ref.read(machineDataProvider).standby, isFalse);

      // Button disappears once standby is false
      expect(find.byKey(const Key('wake_from_standby_controls_button')), findsNothing);
    });
  });
}
