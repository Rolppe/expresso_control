import '../../../core/providers.dart';
import '../../../core/debug_log.dart';
// ============================================================================
// controls_widget.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// CONTROLS WIDGET
// ============================================================================

/// Time sliders: **0 s = feature off**. No separate toggles.
class ControlsWidget extends ConsumerStatefulWidget {
  const ControlsWidget({super.key});

  @override
  ConsumerState<ControlsWidget> createState() => _ControlsWidgetState();
}

class _ControlsWidgetState extends ConsumerState<ControlsWidget> {
  static const double _tMin = 0;
  static const double _tMax = 6;

  // Local values so BLE telemetry cannot yank the thumb while dragging
  double? _pre;
  double? _spr;
  double? _temp;
  double? _steamTemp;
  double? _steamTempMax;
  double? _steamValveTrigger;
  double? _steamValveRelease;
  double? _steamPressHigh;
  double? _prePress;
  double? _brewPress;
  double? _preTriggerTh;
  bool _dragPrePress = false;
  bool _dragBrewPress = false;
  bool _dragPre = false;
  bool _dragPreTriggerTh = false;
  bool _dragSpr = false;
  bool _dragTemp = false;
  bool _dragSteamTemp = false;
  bool _dragSteamTempMax = false;
  bool _dragSteamValveTrigger = false;
  bool _dragSteamValveRelease = false;
  bool _dragSteamPressHigh = false;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(machineDataProvider);
    final ble = ref.read(bleNotifierProvider.notifier);
    final connected = ref.watch(bleNotifierProvider);

    // Sync from provider when not actively dragging
    if (!_dragPre) _pre = data.preInfusionTime.clamp(_tMin, _tMax);
    if (!_dragSpr) _spr = data.softPressureReleaseTime.clamp(_tMin, _tMax);
    if (!_dragTemp) _temp = data.brewTemperature.clamp(88.0, 102.0);
    if (!_dragSteamTemp) _steamTemp = data.steamTemperature.clamp(120.0, 140.0);
    if (!_dragSteamTempMax) _steamTempMax = data.steamTemperatureMax.clamp(125.0, 145.0);
    if (!_dragSteamValveTrigger) {
      _steamValveTrigger = (data.steamValveTrigger > 0 ? data.steamValveTrigger : data.steamPressureLow).clamp(0.5, 3.0);
    }
    if (!_dragSteamValveRelease) _steamValveRelease = data.steamValveRelease.clamp(0.6, 3.2);
    if (!_dragSteamPressHigh) _steamPressHigh = data.steamPressureHigh.clamp(1.0, 3.5);
    if (!_dragPrePress) _prePress = data.preInfusionPressure.clamp(1.0, 4.0);
    if (!_dragBrewPress) _brewPress = data.brewPressure.clamp(5.0, 10.0);
    if (!_dragPreTriggerTh) _preTriggerTh = data.preInfusionTriggerThreshold.clamp(0.05, 0.50);

    final pre = _pre ?? 0;
    final preTriggerTh = _preTriggerTh ?? 0.25;
    final spr = _spr ?? 0;
    final temp = _temp ?? 97;
    final steamTemp = _steamTemp ?? 135.0;
    final steamTempMax = _steamTempMax ?? 140.0;
    final steamValveTrigger = _steamValveTrigger ?? 1.8;
    final steamValveRelease = _steamValveRelease ?? 2.1;
    final steamPressHigh = _steamPressHigh ?? 2.5;
    final prePress = _prePress ?? 2.0;
    final brewPress = _brewPress ?? 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.standby)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              key: const Key('wake_from_standby_controls_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.wb_sunny_rounded, size: 22),
              label: const Text(
                'Herätä lepotilasta',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              onPressed: connected
                  ? () => ref.read(machineDataProvider.notifier).wakeFromStandby()
                  : null,
            ),
          ),
        _buildSection(
          key: const Key('section_fastheatup'),
          title: 'Fast heatup',
          icon: Icons.bolt,
          iconColor: Colors.amberAccent,
          children: [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Text('Fast heatup'),
              value: data.fastHeatupOn,
              onChanged: connected
                  ? (val) {
                      final cmd = 'fhu:${val ? "on" : "off"}';
                      DLog.ui('toggle fhu -> $cmd');
                      ble.sendCommand(cmd);
                    }
                  : null,
              activeThumbColor: Colors.green,
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Text('Pressure equalization'),
              value: data.pressureEqualizationOn,
              onChanged: connected
                  ? (val) {
                      final cmd = 'peq:${val ? "on" : "off"}';
                      DLog.ui('toggle peq -> $cmd');
                      ref.read(machineDataProvider.notifier).setPressureEqualizationOnLocal(val);
                      ble.sendCommand(cmd);
                    }
                  : null,
              activeThumbColor: Colors.green,
            ),
          ],
        ),
        _buildSection(
          key: const Key('section_preinfusion'),
          title: 'Preinfusion',
          icon: Icons.water_drop_outlined,
          iconColor: Colors.lightBlueAccent,
          children: [
            _sliderBlock(
              title: 'Pre-infusion',
              display: pre <= 0.01 ? 'OFF' : '${pre.toStringAsFixed(1)} s',
              value: pre,
              min: _tMin,
              max: _tMax,
              divisions: 12,
              enabled: connected,
              onChanged: (v) {
                setState(() {
                  _dragPre = true;
                  _pre = v;
                });
                ref.read(machineDataProvider.notifier).setPreInfusionTimeLocal(v);
              },
              onChangeEnd: (v) {
                setState(() {
                  _dragPre = false;
                  _pre = v;
                });
                ref.read(machineDataProvider.notifier).setPreInfusionTimeLocal(v);
                final cmd = 'pit:${v.toStringAsFixed(1)}';
                DLog.ui('slider pre end -> $cmd connected=$connected');
                ble.sendCommand(cmd);
              },
            ),
            _sliderBlock(
              title: 'Pre-infusion pressure',
              display: '${prePress.toStringAsFixed(1)} bar',
              value: prePress,
              min: 1,
              max: 4,
              divisions: 6,
              enabled: connected,
              onChanged: (v) {
                setState(() {
                  _dragPrePress = true;
                  _prePress = v;
                });
                ref.read(machineDataProvider.notifier).setPreInfusionPressureLocal(v);
              },
              onChangeEnd: (v) {
                setState(() {
                  _dragPrePress = false;
                  _prePress = v;
                });
                ref.read(machineDataProvider.notifier).setPreInfusionPressureLocal(v);
                final cmd = 'pip:${v.toStringAsFixed(1)}';
                DLog.ui('slider pre-infusion pressure end -> $cmd connected=$connected');
                ble.sendCommand(cmd);
              },
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Text('Preinfusion trigger'),
              value: data.preInfusionTriggerOn,
              onChanged: connected
                  ? (val) {
                      final cmd = 'ptrig:${val ? "on" : "off"}';
                      DLog.ui('toggle ptrig -> $cmd');
                      ref.read(machineDataProvider.notifier).setPreInfusionTriggerOnLocal(val);
                      ble.sendCommand(cmd);
                    }
                  : null,
              activeThumbColor: Colors.green,
            ),
            _sliderBlock(
              title: 'Trigger threshold',
              display: data.preInfusionTriggerOn
                  ? '${preTriggerTh.toStringAsFixed(2)} g'
                  : '${preTriggerTh.toStringAsFixed(2)} g (OFF)',
              value: preTriggerTh,
              min: 0.05,
              max: 0.50,
              divisions: 9,
              enabled: connected && data.preInfusionTriggerOn,
              onChanged: (v) {
                setState(() {
                  _dragPreTriggerTh = true;
                  _preTriggerTh = v;
                });
                ref.read(machineDataProvider.notifier).setPreInfusionTriggerThresholdLocal(v);
              },
              onChangeEnd: (v) {
                setState(() {
                  _dragPreTriggerTh = false;
                  _preTriggerTh = v;
                });
                ref.read(machineDataProvider.notifier).setPreInfusionTriggerThresholdLocal(v);
                final cmd = 'ptrig:${v.toStringAsFixed(2)}';
                DLog.ui('slider ptrig end -> $cmd connected=$connected');
                ble.sendCommand(cmd);
              },
            ),
          ],
        ),
        _buildSection(
          key: const Key('section_brew'),
          title: 'Brew',
          icon: Icons.coffee_rounded,
          iconColor: Colors.orangeAccent.shade100,
          children: [
            _sliderBlock(
              title: 'Brew temperature',
              display: '${temp.toStringAsFixed(1)} °C',
              value: temp,
              min: 88,
              max: 102,
              divisions: 14,
              enabled: connected,
              onChanged: (v) {
                setState(() {
                  _dragTemp = true;
                  _temp = v;
                });
                ref.read(machineDataProvider.notifier).setBrewTemperatureLocal(v);
              },
              onChangeEnd: (v) {
                setState(() {
                  _dragTemp = false;
                  _temp = v;
                });
                ref.read(machineDataProvider.notifier).setBrewTemperatureLocal(v);
                final cmd = 'bt:${v.toStringAsFixed(1)}';
                DLog.ui('slider temp end -> $cmd connected=$connected');
                ble.sendCommand(cmd);
              },
            ),
            _sliderBlock(
              title: 'Brew pressure',
              display: '${brewPress.toStringAsFixed(1)} bar',
              value: brewPress,
              min: 5,
              max: 10,
              divisions: 10,
              enabled: connected,
              onChanged: (v) {
                setState(() {
                  _dragBrewPress = true;
                  _brewPress = v;
                });
                ref.read(machineDataProvider.notifier).setBrewPressureLocal(v);
              },
              onChangeEnd: (v) {
                setState(() {
                  _dragBrewPress = false;
                  _brewPress = v;
                });
                ref.read(machineDataProvider.notifier).setBrewPressureLocal(v);
                final cmd = 'bp:${v.toStringAsFixed(1)}';
                DLog.ui('slider brew pressure end -> $cmd connected=$connected');
                ble.sendCommand(cmd);
              },
            ),
            _sliderBlock(
              title: 'Soft pressure release',
              display: spr <= 0.01 ? 'OFF' : '${spr.toStringAsFixed(1)} s',
              value: spr,
              min: _tMin,
              max: _tMax,
              divisions: 12,
              enabled: connected,
              onChanged: (v) {
                setState(() {
                  _dragSpr = true;
                  _spr = v;
                });
                ref.read(machineDataProvider.notifier).setSoftPressureReleaseTimeLocal(v);
              },
              onChangeEnd: (v) {
                setState(() {
                  _dragSpr = false;
                  _spr = v;
                });
                ref.read(machineDataProvider.notifier).setSoftPressureReleaseTimeLocal(v);
                final cmd = 'srt:${v.toStringAsFixed(1)}';
                DLog.ui('slider spr end -> $cmd connected=$connected');
                ble.sendCommand(cmd);
              },
            ),
          ],
        ),
        _buildSection(
          key: const Key('section_steam'),
          title: 'Steam',
          icon: Icons.cloud_outlined,
          iconColor: Colors.cyanAccent,
          children: [
            _sliderBlock(
              title: 'Steam temperature',
              display: '${steamTemp.toStringAsFixed(1)} °C',
              value: steamTemp,
              min: 120,
              max: 140,
              divisions: 20,
              enabled: connected,
              onChanged: (v) {
                setState(() {
                  _dragSteamTemp = true;
                  _steamTemp = v;
                });
                ref.read(machineDataProvider.notifier).setSteamTemperatureLocal(v);
              },
              onChangeEnd: (v) {
                setState(() {
                  _dragSteamTemp = false;
                  _steamTemp = v;
                });
                ref.read(machineDataProvider.notifier).setSteamTemperatureLocal(v);
                final cmd = 'steam:${v.toStringAsFixed(1)}';
                DLog.ui('slider steam temp end -> $cmd connected=$connected');
                ble.sendCommand(cmd);
              },
            ),
            _sliderBlock(
              title: 'Steam max temp',
              display: '${steamTempMax.toStringAsFixed(1)} °C',
              value: steamTempMax,
              min: 125,
              max: 145,
              divisions: 40,
              enabled: connected,
              onChanged: (v) {
                setState(() {
                  _dragSteamTempMax = true;
                  _steamTempMax = v;
                });
                ref.read(machineDataProvider.notifier).setSteamTemperatureMaxLocal(v);
              },
              onChangeEnd: (v) {
                setState(() {
                  _dragSteamTempMax = false;
                  _steamTempMax = v;
                });
                ref.read(machineDataProvider.notifier).setSteamTemperatureMaxLocal(v);
                final cmd = 'stmax:${v.toStringAsFixed(1)}';
                DLog.ui('slider steam max temp end -> $cmd connected=$connected');
                ble.sendCommand(cmd);
              },
            ),
            _sliderBlock(
              title: 'Steam valve trigger',
              display: '${steamValveTrigger.toStringAsFixed(1)} bar',
              value: steamValveTrigger,
              min: 0.5,
              max: 3.0,
              divisions: 25,
              enabled: connected,
              onChanged: (v) {
                setState(() {
                  _dragSteamValveTrigger = true;
                  _steamValveTrigger = v;
                });
                ref.read(machineDataProvider.notifier).setSteamValveTriggerLocal(v);
              },
              onChangeEnd: (v) {
                setState(() {
                  _dragSteamValveTrigger = false;
                  _steamValveTrigger = v;
                });
                ref.read(machineDataProvider.notifier).setSteamValveTriggerLocal(v);
                final cmd = 'svt:${v.toStringAsFixed(1)}';
                DLog.ui('slider steam valve trigger end -> $cmd connected=$connected');
                ble.sendCommand(cmd);
              },
            ),
            _sliderBlock(
              title: 'Steam valve release',
              display: '${steamValveRelease.toStringAsFixed(1)} bar',
              value: steamValveRelease,
              min: 0.6,
              max: 3.2,
              divisions: 26,
              enabled: connected,
              onChanged: (v) {
                setState(() {
                  _dragSteamValveRelease = true;
                  _steamValveRelease = v;
                });
                ref.read(machineDataProvider.notifier).setSteamValveReleaseLocal(v);
              },
              onChangeEnd: (v) {
                setState(() {
                  _dragSteamValveRelease = false;
                  _steamValveRelease = v;
                });
                ref.read(machineDataProvider.notifier).setSteamValveReleaseLocal(v);
                final cmd = 'svr:${v.toStringAsFixed(1)}';
                DLog.ui('slider steam valve release end -> $cmd connected=$connected');
                ble.sendCommand(cmd);
              },
            ),
            _sliderBlock(
              title: 'Steam pressure max',
              display: '${steamPressHigh.toStringAsFixed(1)} bar',
              value: steamPressHigh,
              min: 1.0,
              max: 3.5,
              divisions: 25,
              enabled: connected,
              onChanged: (v) {
                setState(() {
                  _dragSteamPressHigh = true;
                  _steamPressHigh = v;
                });
                ref.read(machineDataProvider.notifier).setSteamPressureHighLocal(v);
              },
              onChangeEnd: (v) {
                setState(() {
                  _dragSteamPressHigh = false;
                  _steamPressHigh = v;
                });
                ref.read(machineDataProvider.notifier).setSteamPressureHighLocal(v);
                final cmd = 'sph:${v.toStringAsFixed(1)}';
                DLog.ui('slider steam press high end -> $cmd connected=$connected');
                ble.sendCommand(cmd);
              },
            ),
          ],
        ),
        _buildSection(
          key: const Key('section_sleep'),
          title: 'Sleep',
          icon: Icons.bedtime_rounded,
          iconColor: Colors.purpleAccent.shade100,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade900.withValues(alpha: 0.6),
                    foregroundColor: Colors.purpleAccent.shade100,
                    side: BorderSide(
                      color: Colors.purpleAccent.shade100.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.bedtime_rounded, size: 20),
                  label: const Text(
                    'Siirry lepotilaan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  onPressed: connected && !data.standby
                      ? () => ref.read(machineDataProvider.notifier).enterStandby()
                      : null,
                ),
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            '0 s = feature off · values save on the Pico',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required Key key,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(icon, color: iconColor),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          initiallyExpanded: false,
          childrenPadding: const EdgeInsets.only(bottom: 10),
          children: children,
        ),
      ),
    );
  }

  Widget _sliderBlock({
    required String title,
    required String display,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required bool enabled,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Expanded(child: Text(title)),
              Text(
                display,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: display,
          onChanged: enabled ? onChanged : null,
          onChangeEnd: enabled ? onChangeEnd : null,
        ),
      ],
    );
  }
}
