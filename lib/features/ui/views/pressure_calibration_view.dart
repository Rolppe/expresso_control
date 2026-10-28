// ============================================================================
// pressure_calibration_view.dart — two-stage pressure sensor calibration
// ============================================================================
//
// Design (phone-driven, Pico does the math and the pump control):
//
// STAGE 1 — pre-infusion pressure
//   pcal:run:pre   → Pico gives water for 10 s at the pre-infusion target
//   user reads the reference gauge → pcal:m:pre:<bar> → Pico corrects offset
//   → repeat the run until the gauge matches, then "Reading was correct"
// STAGE 2 — brew pressure
//   same with pcal:run:brew / pcal:m:brew:<bar> (two points → gain + offset)
//   → user confirms the result → pcal:save (pressure_cal.json on the Pico)
// Leaving the view sends pcal:end (unsaved corrections are dropped).
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug_log.dart';
import '../../../core/providers.dart';

class PressureCalibrationView extends ConsumerStatefulWidget {
  const PressureCalibrationView({super.key});

  @override
  ConsumerState<PressureCalibrationView> createState() =>
      _PressureCalibrationViewState();
}

class _PressureCalibrationViewState
    extends ConsumerState<PressureCalibrationView> {
  final _gaugeCtrl = TextEditingController();
  StreamSubscription? _sub;
  late final dynamic _ble; // BleNotifier, captured so dispose() does not touch ref

  /// Wizard step on the phone: 'pre' → 'brew' → 'confirm' → 'saved'
  String _step = 'pre';
  String _state = 'idle';
  String _stage = '';
  String _msg = '';
  double _gain = 1.0;
  double _offset = 0.0;
  double _livePressure = 0;
  double _prePressure = 2.0;
  double _brewPressure = 8.0;
  DateTime? _runStarted;
  double? _lastGauge;

  @override
  void initState() {
    super.initState();
    _ble = ref.read(bleNotifierProvider.notifier);
    final repo = ref.read(machineLinkProvider);
    _sub = repo.dataStream.listen((json) {
      if (!mounted) return;
      setState(() {
        if (json.containsKey('pcal_state')) {
          final next = json['pcal_state']?.toString() ?? _state;
          if (next == 'running' && _state != 'running') _runStarted = DateTime.now();
          _state = next;
          _stage = json['pcal_stage']?.toString() ?? _stage;
          _msg = json['pcal_msg']?.toString() ?? _msg;
          _gain = (json['pcal_gain'] as num?)?.toDouble() ?? _gain;
          _offset = (json['pcal_offset'] as num?)?.toDouble() ?? _offset;
          if (_state == 'saved') _step = 'saved';
        }
        if (json.containsKey('boiler_temperature')) {
          _livePressure = (json['pressure'] as num?)?.toDouble() ?? _livePressure;
        }
        if (json.containsKey('pre_infusion_pressure')) {
          _prePressure = (json['pre_infusion_pressure'] as num?)?.toDouble() ?? _prePressure;
        }
        if (json.containsKey('brew_pressure')) {
          _brewPressure = (json['brew_pressure'] as num?)?.toDouble() ?? _brewPressure;
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _gaugeCtrl.dispose();
    // Drop unsaved corrections and free the Pico's wizard state
    _cmd('pcal:end');
    super.dispose();
  }

  void _cmd(String c) {
    DLog.ui('pcal cmd $c');
    _ble.sendCommand(c);
  }

  bool get _connected => ref.read(bleNotifierProvider);
  bool get _running => _state == 'queued' || _state == 'running';
  double get _target => _step == 'brew' ? _brewPressure : _prePressure;
  String get _stageKey => _step == 'brew' ? 'brew' : 'pre';

  /// A run for the current step has finished (successfully or corrected after it).
  bool get _runDone =>
      _stage == _stageKey && (_state == 'done' || _state == 'corrected');

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _run() {
    if (!_connected) {
      _snack('Connect Bluetooth first');
      return;
    }
    setState(() {
      _state = 'queued';
      _stage = _stageKey;
      _msg = '';
    });
    _cmd('pcal:run:$_stageKey');
  }

  Future<void> _correctAndRetest() async {
    final v = double.tryParse(_gaugeCtrl.text.replaceAll(',', '.'));
    if (v == null || v < 0 || v > 15) {
      _snack('Enter the gauge reading in bar (0–15)');
      return;
    }
    _lastGauge = v;
    _cmd('pcal:m:$_stageKey:${v.toStringAsFixed(1)}');
    // Let the Pico apply the correction before the next run
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    if (_state == 'error') return;
    _gaugeCtrl.clear();
    _run();
  }

  void _readingCorrect() {
    setState(() {
      _gaugeCtrl.clear();
      if (_step == 'pre') {
        _step = 'brew';
        _state = 'idle';
        _stage = '';
        _msg = '';
      } else {
        _step = 'confirm';
      }
    });
  }

  Future<void> _confirmSave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save pressure calibration?'),
        content: Text(
          'The gauge matched the sensor at both stages:\n'
          '• pre-infusion ${_prePressure.toStringAsFixed(1)} bar\n'
          '• brew ${_brewPressure.toStringAsFixed(1)} bar\n\n'
          'Correction: gain ${_gain.toStringAsFixed(3)}, '
          'offset ${_offset.toStringAsFixed(2)} bar.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) _cmd('pcal:save');
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(bleNotifierProvider);
    final elapsed = _runStarted == null
        ? 0
        : DateTime.now().difference(_runStarted!).inSeconds.clamp(0, 10);

    Widget body;
    if (_step == 'saved') {
      body = _card(
        'Calibration saved',
        'Gain ${_gain.toStringAsFixed(3)}, offset ${_offset.toStringAsFixed(2)} bar '
            '(pressure_cal.json on the Pico).',
        [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      );
    } else if (_step == 'confirm') {
      body = _card(
        'Confirm result',
        'Both stages matched the gauge. Save the calibration?',
        [FilledButton(onPressed: _confirmSave, child: const Text('Confirm and save'))],
      );
    } else {
      final title = _step == 'pre'
          ? 'Stage 1 of 2 — pre-infusion pressure'
          : 'Stage 2 of 2 — brew pressure';
      final children = <Widget>[];
      if (_running) {
        children.add(Text(
          'Machine is giving water at ${_target.toStringAsFixed(1)} bar… '
          '$elapsed / 10 s\nRead the gauge now. Sensor: ${_livePressure.toStringAsFixed(1)} bar',
        ));
        children.add(const SizedBox(height: 12));
        children.add(const LinearProgressIndicator());
      } else if (_runDone) {
        children.addAll([
          Text(_state == 'corrected'
              ? 'Correction applied (gauge ${_lastGauge?.toStringAsFixed(1) ?? '-'} bar). Run the test again.'
              : 'What did the gauge show during the test?'),
          const SizedBox(height: 12),
          TextField(
            controller: _gaugeCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: const InputDecoration(
              labelText: 'Gauge reading (bar)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(
              onPressed: connected ? _correctAndRetest : null,
              child: const Text('Correct and test again'),
            ),
            OutlinedButton(
              onPressed: connected ? _run : null,
              child: const Text('Test again'),
            ),
            FilledButton.tonal(
              onPressed: _state == 'done' ? _readingCorrect : null,
              child: Text(_step == 'pre'
                  ? 'Reading was correct → stage 2'
                  : 'Reading was correct → confirm'),
            ),
          ]),
        ]);
      } else {
        children.add(Text(
          'Fit the pressure gauge to the group head. '
          'The machine will give water for 10 s at ${_target.toStringAsFixed(1)} bar '
          '(${_step == 'pre' ? 'pre-infusion' : 'brew'} pressure slider). '
          'Keep all machine switches off.',
        ));
        children.add(const SizedBox(height: 12));
        children.add(FilledButton(
          onPressed: connected ? _run : null,
          child: const Text('Start 10 s test'),
        ));
      }
      if (_state == 'error' && _msg.isNotEmpty) {
        children.add(const SizedBox(height: 12));
        children.add(Text('Error: $_msg', style: const TextStyle(color: Colors.redAccent)));
        children.add(OutlinedButton(onPressed: connected ? _run : null, child: const Text('Start test again')));
      }
      body = _card(title, null, children);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pressure calibration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!connected)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Bluetooth not connected', style: TextStyle(color: Colors.orange)),
            ),
          body,
          const SizedBox(height: 16),
          Text(
            'Current correction: gain ${_gain.toStringAsFixed(3)}, offset ${_offset.toStringAsFixed(2)} bar'
            '${_msg.isNotEmpty && _state != 'error' ? '\n$_msg' : ''}',
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, String? text, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (text != null) ...[Text(text), const SizedBox(height: 12)],
            ...children,
          ],
        ),
      ),
    );
  }
}
