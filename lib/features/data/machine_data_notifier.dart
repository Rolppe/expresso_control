import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/machine_status.dart';
import '../../models/data_point.dart';
import '../../core/providers.dart';
import '../../core/debug_log.dart';
import 'live_stale_policy.dart';

// ============================================================================
// DATA NOTIFIER
// ============================================================================

class MachineDataNotifier extends Notifier<MachineStatus> {
  DateTime? _startTime;
  Timer? _brewTimerTask;
  Timer? _staleCheckTimer;
  StreamSubscription<Map<String, dynamic>>? _dataSub;
  StreamSubscription<bool>? _connSub;

  // Pico modes: PRE_INFUSION / BREW / SOFT_RELEASE / IDLE
  // Legacy string modes kept for older firmware.
  final Set<String> _brewingModes = {
    'pre-infusion main',
    'brew loop',
    'PRE_INFUSION',
    'BREW',
  };

  // ----- Drip tray: absolute mass (weight_abs_g), NOT display weight_g -----
  // Calibration-zero reading: tray on ~400g+, tray off < 200g.
  static const double _trayAbsThresholdG = 200.0;
  static const int _confirmSamples = 2; // faster tray UI (abs already snappy on Pico)
  static const Duration _autoTareCooldown = Duration(seconds: 2);

  // ----- Startup tare: once per app session, first stable scale reading -----
  static const int _startupStableNeed = 8;
  static const double _startupStableSpanG = 3.0;

  final LiveStalePolicy _stalePolicy = LiveStalePolicy();
  DateTime? _lastLiveAt;

  int _noTrayHits = 0;
  int _trayBackHits = 0;
  DateTime? _lastAutoTare;

  bool _startupTareDone = false;
  final List<double> _startupWeightSamples = [];

  @override
  MachineStatus build() {
    // keepAlive: avoid dispose mid-shot when UI tree rebuilds (dual-engine churn).
    ref.keepAlive();
    // read (not watch): repository is a process singleton; watching rebuilds
    // this notifier and wipes brewMode / graph mid-session.
    final repo = ref.read(machineLinkProvider);

    _dataSub?.cancel();
    _dataSub = repo.dataStream.listen(_updateFromJson);

    // If BLE drops mid-shot, freeze-free UI: clear brew mode so we don't
    // keep showing BREW / running the brew timer forever.
    _connSub?.cancel();
    _connSub = repo.isConnectedStream.listen((connected) {
      if (!connected && state.standby) {
        state = state.copyWith(standby: false);
      }
      if (!connected && state.brewMode != 'IDLE') {
        DLog.ui('BLE down — UI mode ${state.brewMode} -> IDLE');
        _stopBrewTimer();
        state = state.copyWith(brewMode: 'IDLE', pumpRatio: 0.0);
      }
    });

    // Zombie link: connected flag stays true but live packets stop → last mode
    // (often SOFT_RELEASE) freezes forever. Poll every 2s.
    _staleCheckTimer?.cancel();
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _forceIdleIfLiveStale();
    });

    _startupTareDone = false;
    _startupWeightSamples.clear();
    _noTrayHits = 0;
    _trayBackHits = 0;
    _lastLiveAt = null;

    ref.onDispose(() {
      _dataSub?.cancel();
      _dataSub = null;
      _connSub?.cancel();
      _connSub = null;
      _brewTimerTask?.cancel();
      _staleCheckTimer?.cancel();
      _staleCheckTimer = null;
    });

    _startTime = DateTime.now();
    DLog.ui('MachineDataNotifier start — tray if abs>=${_trayAbsThresholdG}g');
    return const MachineStatus();
  }

  void _forceIdleIfLiveStale() {
    final mode = state.brewMode;
    if (!_stalePolicy.shouldForceIdle(
      brewMode: mode,
      lastLiveAt: _lastLiveAt,
      now: DateTime.now(),
    )) {
      return;
    }
    final age = _lastLiveAt == null
        ? -1
        : DateTime.now().difference(_lastLiveAt!).inMilliseconds;
    DLog.ui(
      'live stale (${age}ms) — UI mode $mode -> IDLE '
      '(no live packets; not full BLE disconnect)',
    );
    _stopBrewTimer();
    state = state.copyWith(brewMode: 'IDLE', pumpRatio: 0.0);
  }

  void _updateFromJson(Map<String, dynamic> json) {
    try {
      // Shot logs are handled by BrewLogNotifier — never treat as live telemetry.
      if (json['type'] == 'brew_log') return;

      final previousMode = state.brewMode;

      // Settings packets must never be treated as live telemetry even if mixed.
      final isSettingsPacket = json['type'] == 'settings' ||
          (json.containsKey('brew_temperature') &&
              !json.containsKey('boiler_temperature') &&
              !json.containsKey('weight_g')) ||
          (json.containsKey('steam_temperature') &&
              !json.containsKey('boiler_temperature') &&
              !json.containsKey('weight_g')) ||
          (json.containsKey('steam_temperature_max') &&
              !json.containsKey('boiler_temperature') &&
              !json.containsKey('weight_g')) ||
          (json.containsKey('steam_valve_trigger') &&
              !json.containsKey('boiler_temperature') &&
              !json.containsKey('weight_g')) ||
          (json.containsKey('steam_valve_release') &&
              !json.containsKey('boiler_temperature') &&
              !json.containsKey('weight_g')) ||
          (json.containsKey('steam_pressure_low') &&
              !json.containsKey('boiler_temperature') &&
              !json.containsKey('weight_g')) ||
          (json.containsKey('brew_pressure') &&
              !json.containsKey('boiler_temperature') &&
              !json.containsKey('weight_g')) ||
          (json.containsKey('pre_infusion_time') &&
              !json.containsKey('boiler_temperature') &&
              !json.containsKey('weight_g')) ||
          (json.containsKey('pre_infusion_trigger_mode') &&
              !json.containsKey('boiler_temperature') &&
              !json.containsKey('weight_g')) ||
          (json.containsKey('pre_infusion_trigger_threshold') &&
              !json.containsKey('boiler_temperature') &&
              !json.containsKey('weight_g')) ||
          (json.containsKey('peq_mode') &&
              !json.containsKey('boiler_temperature') &&
              !json.containsKey('weight_g')) ||
          (json.containsKey('idle_pressure_equalize_mode') &&
              !json.containsKey('boiler_temperature') &&
              !json.containsKey('weight_g'));

      final isLiveTelemetry = !isSettingsPacket &&
          (json.containsKey('boiler_temperature') ||
              json.containsKey('weight_g') ||
              json.containsKey('pressure') ||
              json.containsKey('weight_abs_g'));

      if (isLiveTelemetry) {
        _lastLiveAt = DateTime.now();
      }

      final nextMode = json['mode'] as String? ?? state.brewMode;
      if (nextMode != previousMode) {
        DLog.data('mode $previousMode -> $nextMode');
      }

      final weight = (json['weight_g'] as num?)?.toDouble() ?? state.weightG;
      // Absolute mass from Pico (cal zero). Do NOT fall back to session weight_g:
      // after tare weight_g≈0 would falsely report "No tray".
      final hasAbs = json.containsKey('weight_abs_g');
      final weightAbs =
          hasAbs ? (json['weight_abs_g'] as num?)?.toDouble() : null;

      final prevTray = state.trayPresent;
      final trayPresent = (isLiveTelemetry && weightAbs != null)
          ? _updateTrayFromAbs(weightAbs, prevTray)
          : prevTray;

      if (isLiveTelemetry && weightAbs != null) {
        _maybeStartupTare(weight, weightAbs, trayPresent);
      }

      final flowGs = (json['flow_g_s'] as num?)?.toDouble() ?? state.flowGs;

      final hasFirstDrop = json.containsKey('first_drop');
      bool nextFirstDrop = state.firstDrop;
      int? nextFirstDropTime = state.firstDropTime;

      if (hasFirstDrop && (json['first_drop'] == true || json['first_drop'] == 1)) {
        nextFirstDrop = true;
        nextFirstDropTime ??= (state.brewTimer > 0 ? state.brewTimer : null);
      }
      if (json.containsKey('first_drop_time')) {
        nextFirstDropTime = (json['first_drop_time'] as num?)?.toInt() ?? nextFirstDropTime;
      }

      var updatedStatus = state.copyWith(
        boilerTemperature:
            (json['boiler_temperature'] as num?)?.toDouble() ?? state.boilerTemperature,
        boilerPressure: (json['pressure'] as num?)?.toDouble() ?? state.boilerPressure,
        pumpRatio: (json['pump_ratio'] as num?)?.toDouble() ?? state.pumpRatio,
        weightG: weight,
        flowGs: flowGs,
        trayPresent: trayPresent,
        firstDrop: nextFirstDrop,
        firstDropTime: nextFirstDropTime,
        brewMode: nextMode,
        // Pico sends 'standby': true in the live packet only while standby holds;
        // a live packet without it means standby is off.
        standby: json.containsKey('boiler_temperature')
            ? json['standby'] == true
            : state.standby,
      );

      // Apply slider settings from dedicated settings notify (connect / after save).
      if (isSettingsPacket ||
          json.containsKey('brew_temperature') ||
          json.containsKey('steam_temperature') ||
          json.containsKey('steamTemperature') ||
          json.containsKey('steam_temperature_max') ||
          json.containsKey('steamTemperatureMax') ||
          json.containsKey('steam_valve_trigger') ||
          json.containsKey('steamValveTrigger') ||
          json.containsKey('steam_valve_release') ||
          json.containsKey('steamValveRelease') ||
          json.containsKey('steam_pressure_low') ||
          json.containsKey('steamPressureLow') ||
          json.containsKey('steam_pressure_high') ||
          json.containsKey('steamPressureHigh') ||
          json.containsKey('pre_infusion_time') ||
          json.containsKey('pressure_soft_release_time') ||
          json.containsKey('pre_infusion_mode') ||
          json.containsKey('pre_infusion_trigger_mode') ||
          json.containsKey('pre_infusion_trigger_threshold') ||
          json.containsKey('peq_mode') ||
          json.containsKey('idle_pressure_equalize_mode') ||
          json.containsKey('peq') ||
          json.containsKey('pressureEqualizationOn')) {
        // Never apply slider fields from pure live telemetry packets
        if (isSettingsPacket ||
            !isLiveTelemetry ||
            json.containsKey('brew_temperature') ||
            json.containsKey('steam_temperature') ||
            json.containsKey('steamTemperature') ||
            json.containsKey('steam_temperature_max') ||
            json.containsKey('steamTemperatureMax') ||
            json.containsKey('steam_valve_trigger') ||
            json.containsKey('steamValveTrigger') ||
            json.containsKey('steam_valve_release') ||
            json.containsKey('steamValveRelease') ||
            json.containsKey('steam_pressure_low') ||
            json.containsKey('steamPressureLow')) {
          final oldPre = state.preInfusionTime;
          final oldSpr = state.softPressureReleaseTime;
          final oldT = state.brewTemperature;
          final oldSteamT = state.steamTemperature;
          updatedStatus = updatedStatus.copyWith(
            preInfusionOn: json['pre_infusion_mode'] as bool? ?? state.preInfusionOn,
            preInfusionTriggerOn: (json['pre_infusion_trigger_mode'] ?? json['preInfusionTriggerOn']) as bool? ?? state.preInfusionTriggerOn,
            preInfusionTriggerThreshold: (json['pre_infusion_trigger_threshold'] ?? json['preInfusionTriggerThreshold'] as num?)?.toDouble() ?? state.preInfusionTriggerThreshold,
            softPressureReleaseOn:
                json['pressure_soft_release_mode'] as bool? ?? state.softPressureReleaseOn,
            fastHeatupOn: json['fast_heatup_mode'] as bool? ?? state.fastHeatupOn,
            pressureEqualizationOn: (json['peq_mode'] ??
                    json['idle_pressure_equalize_mode'] ??
                    json['peq'] ??
                    json['pressureEqualizationOn']) as bool? ??
                state.pressureEqualizationOn,
            brewTemperature:
                (json['brew_temperature'] as num?)?.toDouble() ??
                (json['brewTemperature'] as num?)?.toDouble() ??
                state.brewTemperature,
            steamTemperature:
                (json['steam_temperature'] as num?)?.toDouble() ??
                (json['steamTemperature'] as num?)?.toDouble() ??
                state.steamTemperature,
            steamTemperatureMax:
                (json['steam_temperature_max'] as num?)?.toDouble() ??
                (json['steamTemperatureMax'] as num?)?.toDouble() ??
                state.steamTemperatureMax,
            steamValveTrigger:
                (json['steam_valve_trigger'] as num?)?.toDouble() ??
                (json['steamValveTrigger'] as num?)?.toDouble() ??
                (json['steam_pressure_low'] as num?)?.toDouble() ??
                (json['steamPressureLow'] as num?)?.toDouble() ??
                state.steamValveTrigger,
            steamValveRelease:
                (json['steam_valve_release'] as num?)?.toDouble() ??
                (json['steamValveRelease'] as num?)?.toDouble() ??
                state.steamValveRelease,
            steamPressureLow:
                (json['steam_pressure_low'] as num?)?.toDouble() ??
                (json['steamPressureLow'] as num?)?.toDouble() ??
                (json['steam_valve_trigger'] as num?)?.toDouble() ??
                (json['steamValveTrigger'] as num?)?.toDouble() ??
                state.steamPressureLow,
            steamPressureHigh:
                (json['steam_pressure_high'] as num?)?.toDouble() ??
                (json['steamPressureHigh'] as num?)?.toDouble() ??
                state.steamPressureHigh,
            preInfusionPressure: (json['pre_infusion_pressure'] as num?)?.toDouble() ??
                state.preInfusionPressure,
            brewPressure:
                (json['brew_pressure'] as num?)?.toDouble() ?? state.brewPressure,
            preInfusionTime:
                (json['pre_infusion_time'] as num?)?.toDouble() ?? state.preInfusionTime,
            softPressureReleaseTime: (json['pressure_soft_release_time'] as num?)
                    ?.toDouble() ??
                state.softPressureReleaseTime,
          );
          DLog.set(
            'apply settings brewT=$oldT->${updatedStatus.brewTemperature} '
            'steamT=$oldSteamT->${updatedStatus.steamTemperature} '
            'steamTMax=${updatedStatus.steamTemperatureMax} '
            'pre=$oldPre->${updatedStatus.preInfusionTime}s '
            'spr=$oldSpr->${updatedStatus.softPressureReleaseTime}s '
            'settingsPkt=$isSettingsPacket live=$isLiveTelemetry keys=${json.keys.toList()}',
          );
        }
      }

      final isBrewingNow = _brewingModes.contains(updatedStatus.brewMode);
      final wasBrewingBefore = _brewingModes.contains(previousMode);
      final isShotDone = updatedStatus.brewMode == 'IDLE' ||
          updatedStatus.brewMode == 'SOFT_RELEASE';

      if (isBrewingNow && !wasBrewingBefore) {
        DLog.ui('brew timer START mode=${updatedStatus.brewMode}');
        _startBrewTimer();
      } else if (isShotDone && (wasBrewingBefore || previousMode == 'SOFT_RELEASE')) {
        // Stop timer at soft-release start (or IDLE) so UI does not look "stuck"
        // in brew after the switch is released.
        DLog.ui('brew timer STOP mode=${updatedStatus.brewMode}');
        _stopBrewTimer();
        if (updatedStatus.brewMode == 'IDLE') {
          _resetBrewTimerAfterDelay();
        }
      }

      // Graph samples: only real live telemetry (not settings sync), and keep a
      // time-based history — a fixed count (400) at ~10 Hz ≈ 40 s window, so when
      // the strip first hits the left edge the oldest samples were already gone
      // or dropped in a burst (~few seconds "wipe"). Prune by time instead.
      if (!updatedStatus.isGraphPaused &&
          _startTime != null &&
          isLiveTelemetry) {
        final time =
            DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;

        final newTemp = List<DataPoint>.from(updatedStatus.temperatureData)
          ..add(DataPoint(time: time, value: updatedStatus.boilerTemperature));
        final newPress = List<DataPoint>.from(updatedStatus.pressureData)
          ..add(DataPoint(time: time, value: updatedStatus.boilerPressure));

        _pruneGraphSeries(newTemp, time);
        _pruneGraphSeries(newPress, time);

        state = updatedStatus.copyWith(
          temperatureData: newTemp,
          pressureData: newPress,
          currentTime: time,
        );
      } else {
        state = updatedStatus;
      }
    } catch (e, st) {
      DLog.data('JSON update error: $e');
      DLog.sys('stack: $st');
    }
  }

  // Must cover the 40 s strip fully; margin avoids left-edge gaps when rate varies.
  static const double _graphKeepSec = 45.0;
  static const int _graphMaxPoints = 2000;

  void _pruneGraphSeries(List<DataPoint> series, double nowSec) {
    final cutoff = nowSec - _graphKeepSec;
    while (series.isNotEmpty && series.first.time < cutoff) {
      series.removeAt(0);
    }
    // Absolute safety cap (e.g. clock jump / flood)
    while (series.length > _graphMaxPoints) {
      series.removeAt(0);
    }
  }

  /// Tray from absolute mass only: |abs| < 200 g => no tray.
  /// Use magnitude so inverted HX711 polarity (negative abs with tray on)
  /// still detects tray correctly.
  bool _updateTrayFromAbs(double absG, bool currentlyPresent) {
    final trayOn = absG.abs() >= _trayAbsThresholdG;

    if (currentlyPresent) {
      if (!trayOn) {
        _noTrayHits++;
        if (_noTrayHits >= _confirmSamples) {
          _noTrayHits = 0;
          _trayBackHits = 0;
          DLog.ui('tray REMOVED abs=${absG.toStringAsFixed(1)} g (<$_trayAbsThresholdG)');
          return false;
        }
        return true;
      }
      _noTrayHits = 0;
      return true;
    }

    // Currently no tray
    if (trayOn) {
      _trayBackHits++;
      if (_trayBackHits >= _confirmSamples) {
        _trayBackHits = 0;
        _noTrayHits = 0;
        DLog.ui('tray RETURNED abs=${absG.toStringAsFixed(1)} g — auto tare');
        _requestAutoTare();
        return true;
      }
      return false;
    }
    _trayBackHits = 0;
    return false;
  }

  void _maybeStartupTare(double displayW, double absG, bool trayPresent) {
    if (_startupTareDone) return;
    // Need tray present by absolute mass (|abs| handles inverted polarity)
    if (!trayPresent || absG.abs() < _trayAbsThresholdG) {
      _startupWeightSamples.clear();
      return;
    }

    _startupWeightSamples.add(displayW);
    while (_startupWeightSamples.length > _startupStableNeed) {
      _startupWeightSamples.removeAt(0);
    }
    if (_startupWeightSamples.length < _startupStableNeed) return;

    var minW = _startupWeightSamples.first;
    var maxW = _startupWeightSamples.first;
    for (final s in _startupWeightSamples) {
      minW = math.min(minW, s);
      maxW = math.max(maxW, s);
    }
    final span = maxW - minW;
    if (span > _startupStableSpanG) return;

    _startupTareDone = true;
    _startupWeightSamples.clear();
    DLog.ui(
      'startup tare: abs=${absG.toStringAsFixed(1)} g '
      'display≈${displayW.toStringAsFixed(1)} span=${span.toStringAsFixed(2)}',
    );
    _requestAutoTare();
  }

  void _requestAutoTare() {
    final now = DateTime.now();
    if (_lastAutoTare != null && now.difference(_lastAutoTare!) < _autoTareCooldown) {
      DLog.ui('auto tare skipped (cooldown)');
      return;
    }
    _lastAutoTare = now;
    try {
      ref.read(machineLinkProvider).sendCommand('tare');
      DLog.ui('auto tare TX');
    } catch (e) {
      DLog.ui('auto tare failed: $e');
    }
  }

  Future<void> wakeFromStandby() async {
    try {
      await ref.read(machineLinkProvider).sendCommand('stby:wake');
      state = state.copyWith(standby: false);
      DLog.ui('wakeFromStandby TX');
    } catch (e) {
      DLog.ui('wakeFromStandby failed: $e');
    }
  }

  Future<void> enterStandby() async {
    try {
      await ref.read(machineLinkProvider).sendCommand('stby:on');
      state = state.copyWith(standby: true);
      DLog.ui('enterStandby TX');
    } catch (e) {
      DLog.ui('enterStandby failed: $e');
    }
  }

  void _resetStartTime() {
    _startTime = DateTime.now();
    state = state.copyWith(
      temperatureData: [],
      pressureData: [],
      currentTime: 0.0,
      brewTimer: 0,
      firstDrop: false,
      firstDropTime: null,
      isGraphPaused: false,
    );
  }

  void _startBrewTimer() {
    _stopBrewTimer();
    state = state.copyWith(firstDrop: false, firstDropTime: null);
    _brewTimerTask = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(brewTimer: state.brewTimer + 1);
    });
  }

  void _stopBrewTimer() => _brewTimerTask?.cancel();

  void _resetBrewTimerAfterDelay() {
    Future.delayed(const Duration(seconds: 10), () {
      if (state.brewMode == 'IDLE') {
        state = state.copyWith(
          brewTimer: 0,
          firstDrop: false,
          firstDropTime: null,
        );
      }
    });
  }

  void pauseGraph() => state = state.copyWith(isGraphPaused: true);

  void resetGraphForNewSession() => _resetStartTime();

  void onManualTare() {
    _noTrayHits = 0;
    _trayBackHits = 0;
    state = state.copyWith(trayPresent: true);
    DLog.ui('manual tare — trayPresent=true');
  }

  void setBrewTemperatureLocal(double celsius) {
    state = state.copyWith(brewTemperature: celsius);
  }

  void setSteamTemperatureLocal(double celsius) {
    state = state.copyWith(steamTemperature: celsius.clamp(120.0, 140.0));
  }

  void setSteamTemperatureMaxLocal(double celsius) {
    state = state.copyWith(steamTemperatureMax: celsius.clamp(125.0, 145.0));
  }

  void setSteamValveTriggerLocal(double bar) {
    final v = bar.clamp(0.5, 3.0);
    state = state.copyWith(steamValveTrigger: v, steamPressureLow: v);
  }

  void setSteamValveReleaseLocal(double bar) {
    final v = bar.clamp(0.6, 3.2);
    state = state.copyWith(steamValveRelease: v);
  }

  void setSteamPressureLowLocal(double bar) {
    setSteamValveTriggerLocal(bar);
  }

  void setSteamPressureHighLocal(double bar) {
    state = state.copyWith(steamPressureHigh: bar.clamp(1.0, 3.5));
  }

  void setPreInfusionPressureLocal(double bar) {
    state = state.copyWith(preInfusionPressure: bar.clamp(1.0, 4.0));
  }

  void setBrewPressureLocal(double bar) {
    state = state.copyWith(brewPressure: bar.clamp(5.0, 10.0));
  }

  void setPreInfusionTimeLocal(double seconds) {
    final v = seconds.clamp(0.0, 6.0);
    state = state.copyWith(preInfusionTime: v);
  }

  void setSoftPressureReleaseTimeLocal(double seconds) {
    final v = seconds.clamp(0.0, 6.0);
    state = state.copyWith(softPressureReleaseTime: v);
  }

  void setPreInfusionTriggerOnLocal(bool enabled) {
    state = state.copyWith(preInfusionTriggerOn: enabled);
  }

  void setPreInfusionTriggerThresholdLocal(double grams) {
    final v = grams.clamp(0.05, 0.50);
    state = state.copyWith(preInfusionTriggerThreshold: v);
  }

  void setPressureEqualizationOnLocal(bool enabled) {
    state = state.copyWith(pressureEqualizationOn: enabled);
  }
}
