// ============================================================================
// demo_pico.dart
// ============================================================================
//
// Simulated EspressoPico for the iOS simulator, which has no CoreBluetooth.
// Compiled in only with --dart-define=EXPRESSO_DEMO=true (BLERepository.demoMode);
// device and Android builds never start it.
//
// Emits the same JSON maps BLERepository puts on dataStream: a live packet
// every 200 ms and a settings packet on 'sync' or a setting change. A shot
// starts by itself once the boiler is at temperature and has idled 30 s:
// PRE_INFUSION → BREW → SOFT_RELEASE → IDLE. The cup is emptied 20 s later.
// Each shot is sent afterwards as a brew_log multipack (meta, samples, end)
// like bluetooth_handler.send_brew_log: one frame per tick, live telemetry
// paused meanwhile; 'brew_log?' restarts it from meta until the app sends
// 'brew_log:ack:<id>'.
//
// Pressure calibration (pcal:run/m/save/end) follows classes.py: a 10 s run
// at the stage target ends 'done' with the raw average, a gauge reading
// corrects offset (one point) or gain + offset (two points), and the status
// map is sent every tick while the wizard is not idle. The simulated sensor
// reads low (true = 0.92 × raw + 0.25), so a correction has something to fix.
// Scale calibration (cal:*) has no firmware handler and stays ignored.

import 'dart:async';
import 'dart:math';

import '../../core/debug_log.dart';
import '../brew_log/brew_log_assembler.dart';

class DemoPico {
  DemoPico(this._emit);

  final void Function(Map<String, dynamic>) _emit;
  final Random _rnd = Random(7);
  Timer? _timer;
  int _txCount = 0;

  static const _tickMs = 200;
  static const _trayAbsG = 310.0; // drip tray + cup on the scale
  static const _idleBeforeShotS = 30.0;
  static const _brewS = 25.0;
  static const _cupEmptyAfterS = 20.0;

  // Settings (Pico defaults)
  double _brewTemp = 93.0;
  double _preInfPressure = 3.0;
  double _brewPressure = 9.0;
  double _preInfTime = 5.0;
  double _softReleaseTime = 2.0;
  bool _preInfOn = true;
  bool _preInfTriggerOn = false;
  double _preInfTriggerThreshold = 0.25;
  bool _softReleaseOn = true;
  bool _fastHeatupOn = false;

  // Live state
  String _mode = 'IDLE';
  double _phaseS = 0;
  double _boilerT = 24.0; // cold start: the heat-up curve is visible
  double _pressure = 0;
  double _pump = 0;
  double _cupG = 0;
  double _flow = 0;
  double _tareAbsG = _trayAbsG;

  // Shot recording for brew_log
  bool _recording = false;
  int _shotMs = 0;
  int _logId = 0;
  final List<List<num>> _rows = [];
  final List<List<Object>> _events = [];
  List<Map<String, dynamic>>? _pendingLog;
  int? _logStep; // next multipack frame; null = no multipack in flight

  // Pressure calibration wizard (classes.py pcal_*)
  static const _pcalRunS = 10.0;
  String _pcalState = 'idle'; // idle|queued|running|done|corrected|saved|error
  String _pcalStage = '';
  String _pcalMsg = '';
  double _pcalTarget = 0;
  double _pcalRawSum = 0;
  int _pcalRawN = 0;
  final Map<String, double> _pcalRaw = {};
  final Map<String, (double, double)> _pcalPoints = {};
  double _gain = 1.0, _offset = 0.0; // active calibration
  double _savedGain = 1.0, _savedOffset = 0.0; // pressure_cal.json

  bool get running => _timer != null;

  void start() {
    if (_timer != null) return;
    DLog.ble('DEMO: simulated Pico started (EXPRESSO_DEMO)');
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) => _step());
    Future<void>.microtask(_sendSettings);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    DLog.ble('DEMO: simulated Pico stopped');
  }

  void command(String cmd) {
    DLog.ble('DEMO TX: $cmd');
    final i = cmd.indexOf(':');
    final key = i < 0 ? cmd : cmd.substring(0, i);
    final arg = i < 0 ? '' : cmd.substring(i + 1);
    final v = double.tryParse(arg);
    switch (key) {
      case 'sync':
        _sendSettings();
        return;
      case 'tare':
        _tareAbsG = _trayAbsG + _cupG;
        return;
      case 'fhu':
        _fastHeatupOn = arg == 'on';
        break;
      case 'ptrig':
      case 'pitrig':
        if (arg == 'on' || arg == 'off') {
          _preInfTriggerOn = arg == 'on';
        } else if (v != null) {
          _preInfTriggerThreshold = v;
        }
        break;
      case 'bt':
        if (v != null) _brewTemp = v;
        break;
      case 'pit':
        if (v != null) _preInfTime = v;
        _preInfOn = (v ?? 0) > 0;
        break;
      case 'srt':
        if (v != null) _softReleaseTime = v;
        _softReleaseOn = (v ?? 0) > 0;
        break;
      case 'pip':
        if (v != null) _preInfPressure = v;
        break;
      case 'bp':
        if (v != null) _brewPressure = v;
        break;
      case 'brew_log?':
        _sendPendingLog();
        return;
      case 'brew_log':
        if (arg == 'ack:${_pendingLog?.first['id']}') {
          _pendingLog = null;
          _logStep = null;
        }
        return;
      case 'pcal':
        _pcalCommand(arg.split(':'));
        return;
      default:
        return; // scale calibration (cal:*): no firmware handler
    }
    _sendSettings();
  }

  void _pcalCommand(List<String> p) {
    try {
      switch (p[0]) {
        case 'run':
          if (!(p[1] == 'pre' || p[1] == 'brew') ||
              _pcalState == 'queued' ||
              _pcalState == 'running') {
            return;
          }
          _pcalStage = p[1];
          _pcalState = 'queued';
          _pcalMsg = '';
          break;
        case 'm':
          _pcalMeasured(p[1], double.parse(p[2]));
          break;
        case 'save':
          _savedGain = _gain;
          _savedOffset = _offset;
          _pcalState = 'saved';
          _pcalMsg = 'saved';
          break;
        case 'end':
          _gain = _savedGain;
          _offset = _savedOffset;
          _pcalRaw.clear();
          _pcalPoints.clear();
          _pcalState = 'idle';
          _pcalStage = '';
          _pcalMsg = '';
          break;
      }
    } catch (e) {
      _pcalState = 'error';
      _pcalMsg = 'command failed: $e';
    }
    DLog.ble('DEMO: pcal $_pcalState $_pcalStage $_pcalMsg');
  }

  void _pcalMeasured(String stage, double measured) {
    final raw = _pcalRaw[stage];
    if (raw == null) {
      _pcalState = 'error';
      _pcalMsg = 'run the test first';
      return;
    }
    _pcalPoints[stage] = (raw, measured);
    double gain, offset;
    final pre = _pcalPoints['pre'], brew = _pcalPoints['brew'];
    if (pre != null && brew != null && (brew.$1 - pre.$1).abs() > 1.0) {
      gain = (brew.$2 - pre.$2) / (brew.$1 - pre.$1);
      offset = pre.$2 - gain * pre.$1;
    } else {
      gain = _gain;
      offset = measured - gain * raw;
    }
    if (gain < 0.5 || gain > 1.5 || offset < -3.0 || offset > 3.0) {
      _pcalState = 'error';
      _pcalMsg =
          'rejected gain ${gain.toStringAsFixed(3)} offset ${offset.toStringAsFixed(2)}';
      _pcalPoints.remove(stage);
      return;
    }
    _gain = gain;
    _offset = offset;
    _pcalStage = stage;
    _pcalState = 'corrected';
    _pcalMsg =
        'gauge ${measured.toStringAsFixed(1)} / target ${_pcalTarget.toStringAsFixed(1)} bar';
  }

  /// One tick of the wizard while the machine idles; true = it owns the pump.
  bool _pcalStep(double dt) {
    if (_pcalState == 'queued') {
      _pcalTarget = _pcalStage == 'pre' ? _preInfPressure : _brewPressure;
      _pcalState = 'running';
      _pcalMsg = '';
      _pcalRawSum = 0;
      _pcalRawN = 0;
      _phaseS = 0;
    }
    if (_pcalState != 'running') return false;
    _pump = 35;
    _flow = 0;
    _pressure += (_pcalTarget - _pressure) * 0.25;
    if (_phaseS > 3) {
      // Settled: average what the uncalibrated sensor reads
      _pcalRawSum += (_pressure - _offset) / _gain;
      _pcalRawN++;
    }
    if (_phaseS >= _pcalRunS) {
      final raw = _pcalRawSum / max(1, _pcalRawN);
      _pcalRaw[_pcalStage] = raw;
      _pcalState = 'done';
      _pcalMsg = 'raw ${raw.toStringAsFixed(2)} bar';
      DLog.ble('DEMO: pcal done $_pcalStage $_pcalMsg (gauge would read '
          '${(0.92 * raw + 0.25).toStringAsFixed(2)})');
    }
    return true;
  }

  void _sendSettings() {
    _emit({
      'type': 'settings',
      'brew_temperature': _brewTemp,
      'pre_infusion_pressure': _preInfPressure,
      'brew_pressure': _brewPressure,
      'pre_infusion_time': _preInfTime,
      'pressure_soft_release_time': _softReleaseTime,
      'pre_infusion_mode': _preInfOn,
      'pressure_soft_release_mode': _softReleaseOn,
      'fast_heatup_mode': _fastHeatupOn,
      'pre_infusion_trigger_mode': _preInfTriggerOn,
      'pre_infusion_trigger_threshold': _preInfTriggerThreshold,
    });
  }

  void _setMode(String mode) {
    DLog.ble('DEMO: mode $_mode -> $mode');
    if (_mode == 'IDLE' && mode != 'IDLE') {
      _recording = true;
      _shotMs = 0;
      _rows.clear();
      _events.clear();
    }
    _mode = mode;
    _phaseS = 0;
    if (!_recording) return;
    if (mode == 'IDLE') {
      _finishLog();
    } else {
      _events.add([mode, _shotMs]);
    }
  }

  void _finishLog() {
    _recording = false;
    _logId++;
    _pendingLog = buildBrewLogParts({
      'v': 1,
      'id': _logId,
      'sample_hz': 1000 ~/ _tickMs,
      'duration_ms': _shotMs,
      'scale_at_end_g': double.parse(_cupG.toStringAsFixed(1)),
      'samples': List<List<num>>.of(_rows),
      'events': List<List<Object>>.of(_events),
    });
    DLog.ble('DEMO: brew_log id=$_logId rows=${_rows.length}');
    _sendPendingLog();
  }

  void _sendPendingLog() {
    if (_pendingLog != null) _logStep = 0;
  }

  double _noise(double amp) => (_rnd.nextDouble() * 2 - 1) * amp;

  void _step() {
    const dt = _tickMs / 1000.0;
    _phaseS += dt;

    switch (_mode) {
      case 'IDLE':
        if (_pcalStep(dt)) break;
        _pressure *= 0.8;
        _pump = 0;
        _flow = 0;
        if (_cupG > 0 && _phaseS > _cupEmptyAfterS) {
          _cupG = 0;
          _tareAbsG = _trayAbsG;
        }
        // No demo shot while the calibration wizard is open
        if (_pcalState == 'idle' &&
            (_boilerT - _brewTemp).abs() < 1.0 &&
            _phaseS > _idleBeforeShotS) {
          _setMode(_preInfOn ? 'PRE_INFUSION' : 'BREW');
        }
        break;
      case 'PRE_INFUSION':
        _pump = 35; // percent, as the firmware sends it
        _pressure += (_preInfPressure - _pressure) * 0.25;
        _flow = 0.3;
        if (_phaseS >= _preInfTime) _setMode('BREW');
        break;
      case 'BREW':
        _pump = 100;
        _pressure += (_brewPressure - _pressure) * 0.2;
        _flow = _phaseS < 4 ? 0.5 * _phaseS : 1.8 + 0.4 * sin(_phaseS / 3);
        _boilerT -= 0.025; // cold water in
        if (_phaseS >= _brewS) {
          _setMode(_softReleaseOn ? 'SOFT_RELEASE' : 'IDLE');
        }
        break;
      case 'SOFT_RELEASE':
        _pump = 0;
        _pressure *= 0.6;
        _flow = 0.2;
        if (_phaseS >= _softReleaseTime) _setMode('IDLE');
        break;
    }

    _cupG += _flow * dt;
    // First-order approach: ~40 s time constant, half that with fast heat-up
    _boilerT += (_brewTemp - _boilerT) * (_fastHeatupOn ? 0.01 : 0.005);

    final absG = _trayAbsG + _cupG + _noise(0.05);
    final parts = _pendingLog;
    final step = _logStep;
    if (parts != null && step != null) {
      _emit(Map<String, dynamic>.of(parts[step]));
      _logStep = step + 1 < parts.length ? step + 1 : null;
      return;
    }
    if (_recording) {
      _shotMs += _tickMs;
      // v1 row: t_ms, temp×10, bar×100, flow×100, weight×10, flags (1 pump)
      _rows.add([
        _shotMs,
        (_boilerT * 10).round(),
        (_pressure * 100).round(),
        (_flow * 100).round(),
        (_cupG * 10).round(),
        _pump > 0 ? 1 : 0,
      ]);
    }
    _emit({
      'boiler_temperature': double.parse((_boilerT + _noise(0.05)).toStringAsFixed(2)),
      'pressure': double.parse(max(0.0, _pressure + _noise(0.03)).toStringAsFixed(2)),
      'mode': _mode,
      'brew_temperature': _brewTemp,
      'pre_infusion_mode': _preInfOn,
      'pressure_soft_release_mode': _softReleaseOn,
      'fast_heatup_mode': _fastHeatupOn,
      'pump_ratio': _pump,
      'weight_g': double.parse((absG - _tareAbsG).toStringAsFixed(1)),
      'weight_abs_g': double.parse(absG.toStringAsFixed(1)),
      'flow_g_s': double.parse(_flow.toStringAsFixed(2)),
    });
    // Like bluetooth_handler.send_data: wizard status only while it is in use
    if (_pcalState != 'idle') {
      _emit({
        'pcal_state': _pcalState,
        'pcal_stage': _pcalStage,
        'pcal_msg': _pcalMsg.length > 40 ? _pcalMsg.substring(0, 40) : _pcalMsg,
        'pcal_gain': double.parse(_gain.toStringAsFixed(4)),
        'pcal_offset': double.parse(_offset.toStringAsFixed(3)),
      });
    }
    // Like the firmware (bluetooth_handler.py): settings every 10th tick (2 s).
    if (++_txCount % 10 == 0) _sendSettings();
  }
}
