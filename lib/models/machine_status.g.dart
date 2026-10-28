// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'machine_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MachineStatusImpl _$$MachineStatusImplFromJson(Map<String, dynamic> json) =>
    _$MachineStatusImpl(
      boilerTemperature: (json['boilerTemperature'] as num?)?.toDouble() ?? 0.0,
      boilerPressure: (json['boilerPressure'] as num?)?.toDouble() ?? 0.0,
      pumpRatio: (json['pumpRatio'] as num?)?.toDouble() ?? 0.0,
      weightG: (json['weightG'] as num?)?.toDouble() ?? 0.0,
      flowGs: (json['flowGs'] as num?)?.toDouble() ?? 0.0,
      trayPresent: json['trayPresent'] as bool? ?? true,
      firstDrop: json['firstDrop'] as bool? ?? false,
      firstDropTime: (json['firstDropTime'] as num?)?.toInt(),
      brewMode: json['brewMode'] as String? ?? 'IDLE',
      standby: json['standby'] as bool? ?? false,
      preInfusionOn: json['preInfusionOn'] as bool? ?? false,
      preInfusionTriggerOn: json['preInfusionTriggerOn'] as bool? ?? false,
      preInfusionTriggerThreshold:
          (json['preInfusionTriggerThreshold'] as num?)?.toDouble() ?? 0.25,
      softPressureReleaseOn: json['softPressureReleaseOn'] as bool? ?? false,
      fastHeatupOn: json['fastHeatupOn'] as bool? ?? false,
      pressureEqualizationOn: json['pressureEqualizationOn'] as bool? ?? false,
      brewTemperature: (json['brewTemperature'] as num?)?.toDouble() ?? 97.0,
      steamTemperature: (json['steamTemperature'] as num?)?.toDouble() ?? 135.0,
      steamTemperatureMax:
          (json['steamTemperatureMax'] as num?)?.toDouble() ?? 140.0,
      steamValveTrigger: (json['steamValveTrigger'] as num?)?.toDouble() ?? 1.8,
      steamValveRelease: (json['steamValveRelease'] as num?)?.toDouble() ?? 2.1,
      steamPressureLow: (json['steamPressureLow'] as num?)?.toDouble() ?? 1.8,
      steamPressureHigh: (json['steamPressureHigh'] as num?)?.toDouble() ?? 2.5,
      preInfusionPressure:
          (json['preInfusionPressure'] as num?)?.toDouble() ?? 2.0,
      brewPressure: (json['brewPressure'] as num?)?.toDouble() ?? 8.0,
      preInfusionTime: (json['preInfusionTime'] as num?)?.toDouble() ?? 5.0,
      softPressureReleaseTime:
          (json['softPressureReleaseTime'] as num?)?.toDouble() ?? 4.0,
      brewTimer: (json['brewTimer'] as num?)?.toInt() ?? 0,
      currentTime: (json['currentTime'] as num?)?.toDouble() ?? 0.0,
      isGraphPaused: json['isGraphPaused'] as bool? ?? false,
      temperatureData: (json['temperatureData'] as List<dynamic>?)
              ?.map((e) => DataPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <DataPoint>[],
      pressureData: (json['pressureData'] as List<dynamic>?)
              ?.map((e) => DataPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <DataPoint>[],
    );

Map<String, dynamic> _$$MachineStatusImplToJson(_$MachineStatusImpl instance) =>
    <String, dynamic>{
      'boilerTemperature': instance.boilerTemperature,
      'boilerPressure': instance.boilerPressure,
      'pumpRatio': instance.pumpRatio,
      'weightG': instance.weightG,
      'flowGs': instance.flowGs,
      'trayPresent': instance.trayPresent,
      'firstDrop': instance.firstDrop,
      'firstDropTime': instance.firstDropTime,
      'brewMode': instance.brewMode,
      'standby': instance.standby,
      'preInfusionOn': instance.preInfusionOn,
      'preInfusionTriggerOn': instance.preInfusionTriggerOn,
      'preInfusionTriggerThreshold': instance.preInfusionTriggerThreshold,
      'softPressureReleaseOn': instance.softPressureReleaseOn,
      'fastHeatupOn': instance.fastHeatupOn,
      'pressureEqualizationOn': instance.pressureEqualizationOn,
      'brewTemperature': instance.brewTemperature,
      'steamTemperature': instance.steamTemperature,
      'steamTemperatureMax': instance.steamTemperatureMax,
      'steamValveTrigger': instance.steamValveTrigger,
      'steamValveRelease': instance.steamValveRelease,
      'steamPressureLow': instance.steamPressureLow,
      'steamPressureHigh': instance.steamPressureHigh,
      'preInfusionPressure': instance.preInfusionPressure,
      'brewPressure': instance.brewPressure,
      'preInfusionTime': instance.preInfusionTime,
      'softPressureReleaseTime': instance.softPressureReleaseTime,
      'brewTimer': instance.brewTimer,
      'currentTime': instance.currentTime,
      'isGraphPaused': instance.isGraphPaused,
      'temperatureData': instance.temperatureData,
      'pressureData': instance.pressureData,
    };
