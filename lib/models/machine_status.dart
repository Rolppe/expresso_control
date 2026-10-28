// ============================================================================
// machine_status.dart
// ============================================================================

import 'package:freezed_annotation/freezed_annotation.dart';
import 'data_point.dart';

part 'machine_status.freezed.dart';
part 'machine_status.g.dart';

// ============================================================================
// MODEL
// ============================================================================

@freezed
class MachineStatus with _$MachineStatus {
  const factory MachineStatus({
    @Default(0.0) double boilerTemperature,
    @Default(0.0) double boilerPressure,
    @Default(0.0) double pumpRatio,
    @Default(0.0) double weightG,
    /// Flow rate from Pico scale (g/s).
    @Default(0.0) double flowGs,
    /// False when drip tray removed (weight deeply negative after tare).
    @Default(true) bool trayPresent,
    /// First drop detected by Pico scale during extraction.
    @Default(false) bool firstDrop,
    /// Seconds into extraction when first drop occurred.
    int? firstDropTime,
    @Default('IDLE') String brewMode,
    /// Pico standby (VALMIUSTILA): IDLE target lowered after the idle timeout.
    @Default(false) bool standby,
    @Default(false) bool preInfusionOn,
    /// Preinfusion trigger: end pre-infusion and start brewing when coffee drops appear.
    @Default(false) bool preInfusionTriggerOn,
    /// Threshold weight (g) for preinfusion trigger (0.05 - 0.50 g).
    @Default(0.25) double preInfusionTriggerThreshold,
    @Default(false) bool softPressureReleaseOn,
    @Default(false) bool fastHeatupOn,
    /// Pressure equalization in idle (Paineen tasaus)
    @Default(false) bool pressureEqualizationOn,
    @Default(97.0) double brewTemperature,
    @Default(135.0) double steamTemperature,
    @Default(140.0) double steamTemperatureMax,
    @Default(1.8) double steamValveTrigger,
    @Default(2.1) double steamValveRelease,
    @Default(1.8) double steamPressureLow,
    @Default(2.5) double steamPressureHigh,
    @Default(2.0) double preInfusionPressure,
    @Default(8.0) double brewPressure,
    @Default(5.0) double preInfusionTime,
    @Default(4.0) double softPressureReleaseTime,
    @Default(0) int brewTimer,
    @Default(0.0) double currentTime,
    @Default(false) bool isGraphPaused,
    @Default(<DataPoint>[]) List<DataPoint> temperatureData,
    @Default(<DataPoint>[]) List<DataPoint> pressureData,
  }) = _MachineStatus;

  factory MachineStatus.fromJson(Map<String, dynamic> json) =>
      _$MachineStatusFromJson(_normalizeJson(json));
}

Map<String, dynamic> _normalizeJson(Map<String, dynamic> json) {
  final normalized = Map<String, dynamic>.from(json);
  if (json.containsKey('steam_temperature') && !json.containsKey('steamTemperature')) {
    normalized['steamTemperature'] = json['steam_temperature'];
  }
  if (json.containsKey('steam_temperature_max') && !json.containsKey('steamTemperatureMax')) {
    normalized['steamTemperatureMax'] = json['steam_temperature_max'];
  }
  if (json.containsKey('steam_valve_trigger') && !json.containsKey('steamValveTrigger')) {
    normalized['steamValveTrigger'] = json['steam_valve_trigger'];
    if (!json.containsKey('steamPressureLow') && !json.containsKey('steam_pressure_low')) {
      normalized['steamPressureLow'] = json['steam_valve_trigger'];
    }
  }
  if (json.containsKey('steam_valve_release') && !json.containsKey('steamValveRelease')) {
    normalized['steamValveRelease'] = json['steam_valve_release'];
  }
  if (json.containsKey('steam_pressure_low') && !json.containsKey('steamPressureLow')) {
    normalized['steamPressureLow'] = json['steam_pressure_low'];
  }
  if (json.containsKey('steam_pressure_high') && !json.containsKey('steamPressureHigh')) {
    normalized['steamPressureHigh'] = json['steam_pressure_high'];
  }
  if (json.containsKey('steamValveTrigger') && !json.containsKey('steamPressureLow')) {
    normalized['steamPressureLow'] = json['steamValveTrigger'];
  }
  if (json.containsKey('first_drop') && !json.containsKey('firstDrop')) {
    normalized['firstDrop'] = json['first_drop'];
  }
  if (json.containsKey('first_drop_time') && !json.containsKey('firstDropTime')) {
    normalized['firstDropTime'] = json['first_drop_time'];
  }
  if (json.containsKey('pre_infusion_trigger_mode') && !json.containsKey('preInfusionTriggerOn')) {
    normalized['preInfusionTriggerOn'] = json['pre_infusion_trigger_mode'];
  }
  if (json.containsKey('pre_infusion_trigger_threshold') && !json.containsKey('preInfusionTriggerThreshold')) {
    normalized['preInfusionTriggerThreshold'] = json['pre_infusion_trigger_threshold'];
  }
  if (json.containsKey('peq_mode') && !json.containsKey('pressureEqualizationOn')) {
    normalized['pressureEqualizationOn'] = json['peq_mode'];
  }
  if (json.containsKey('idle_pressure_equalize_mode') && !json.containsKey('pressureEqualizationOn')) {
    normalized['pressureEqualizationOn'] = json['idle_pressure_equalize_mode'];
  }
  if (json.containsKey('peq') && !json.containsKey('pressureEqualizationOn')) {
    normalized['pressureEqualizationOn'] = json['peq'];
  }
  return normalized;
}
