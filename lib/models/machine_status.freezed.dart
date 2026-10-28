// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'machine_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MachineStatus _$MachineStatusFromJson(Map<String, dynamic> json) {
  return _MachineStatus.fromJson(json);
}

/// @nodoc
mixin _$MachineStatus {
  double get boilerTemperature => throw _privateConstructorUsedError;
  double get boilerPressure => throw _privateConstructorUsedError;
  double get pumpRatio => throw _privateConstructorUsedError;
  double get weightG => throw _privateConstructorUsedError;

  /// Flow rate from Pico scale (g/s).
  double get flowGs => throw _privateConstructorUsedError;

  /// False when drip tray removed (weight deeply negative after tare).
  bool get trayPresent => throw _privateConstructorUsedError;

  /// First drop detected by Pico scale during extraction.
  bool get firstDrop => throw _privateConstructorUsedError;

  /// Seconds into extraction when first drop occurred.
  int? get firstDropTime => throw _privateConstructorUsedError;
  String get brewMode => throw _privateConstructorUsedError;

  /// Pico standby (VALMIUSTILA): IDLE target lowered after the idle timeout.
  bool get standby => throw _privateConstructorUsedError;
  bool get preInfusionOn => throw _privateConstructorUsedError;
  bool get preInfusionTriggerOn => throw _privateConstructorUsedError;
  double get preInfusionTriggerThreshold => throw _privateConstructorUsedError;
  bool get softPressureReleaseOn => throw _privateConstructorUsedError;
  bool get fastHeatupOn => throw _privateConstructorUsedError;
  bool get pressureEqualizationOn => throw _privateConstructorUsedError;
  double get brewTemperature => throw _privateConstructorUsedError;
  double get steamTemperature => throw _privateConstructorUsedError;
  double get steamTemperatureMax => throw _privateConstructorUsedError;
  double get steamValveTrigger => throw _privateConstructorUsedError;
  double get steamValveRelease => throw _privateConstructorUsedError;
  double get steamPressureLow => throw _privateConstructorUsedError;
  double get steamPressureHigh => throw _privateConstructorUsedError;
  double get preInfusionPressure => throw _privateConstructorUsedError;
  double get brewPressure => throw _privateConstructorUsedError;
  double get preInfusionTime => throw _privateConstructorUsedError;
  double get softPressureReleaseTime => throw _privateConstructorUsedError;
  int get brewTimer => throw _privateConstructorUsedError;
  double get currentTime => throw _privateConstructorUsedError;
  bool get isGraphPaused => throw _privateConstructorUsedError;
  List<DataPoint> get temperatureData => throw _privateConstructorUsedError;
  List<DataPoint> get pressureData => throw _privateConstructorUsedError;

  /// Serializes this MachineStatus to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MachineStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MachineStatusCopyWith<MachineStatus> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MachineStatusCopyWith<$Res> {
  factory $MachineStatusCopyWith(
          MachineStatus value, $Res Function(MachineStatus) then) =
      _$MachineStatusCopyWithImpl<$Res, MachineStatus>;
  @useResult
  $Res call(
      {double boilerTemperature,
      double boilerPressure,
      double pumpRatio,
      double weightG,
      double flowGs,
      bool trayPresent,
      bool firstDrop,
      int? firstDropTime,
      String brewMode,
      bool standby,
      bool preInfusionOn,
      bool preInfusionTriggerOn,
      double preInfusionTriggerThreshold,
      bool softPressureReleaseOn,
      bool fastHeatupOn,
      bool pressureEqualizationOn,
      double brewTemperature,
      double steamTemperature,
      double steamTemperatureMax,
      double steamValveTrigger,
      double steamValveRelease,
      double steamPressureLow,
      double steamPressureHigh,
      double preInfusionPressure,
      double brewPressure,
      double preInfusionTime,
      double softPressureReleaseTime,
      int brewTimer,
      double currentTime,
      bool isGraphPaused,
      List<DataPoint> temperatureData,
      List<DataPoint> pressureData});
}

/// @nodoc
class _$MachineStatusCopyWithImpl<$Res, $Val extends MachineStatus>
    implements $MachineStatusCopyWith<$Res> {
  _$MachineStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MachineStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? boilerTemperature = null,
    Object? boilerPressure = null,
    Object? pumpRatio = null,
    Object? weightG = null,
    Object? flowGs = null,
    Object? trayPresent = null,
    Object? firstDrop = null,
    Object? firstDropTime = freezed,
    Object? brewMode = null,
    Object? standby = null,
    Object? preInfusionOn = null,
    Object? preInfusionTriggerOn = null,
    Object? preInfusionTriggerThreshold = null,
    Object? softPressureReleaseOn = null,
    Object? fastHeatupOn = null,
    Object? pressureEqualizationOn = null,
    Object? brewTemperature = null,
    Object? steamTemperature = null,
    Object? steamTemperatureMax = null,
    Object? steamValveTrigger = null,
    Object? steamValveRelease = null,
    Object? steamPressureLow = null,
    Object? steamPressureHigh = null,
    Object? preInfusionPressure = null,
    Object? brewPressure = null,
    Object? preInfusionTime = null,
    Object? softPressureReleaseTime = null,
    Object? brewTimer = null,
    Object? currentTime = null,
    Object? isGraphPaused = null,
    Object? temperatureData = null,
    Object? pressureData = null,
  }) {
    return _then(_value.copyWith(
      boilerTemperature: null == boilerTemperature
          ? _value.boilerTemperature
          : boilerTemperature // ignore: cast_nullable_to_non_nullable
              as double,
      boilerPressure: null == boilerPressure
          ? _value.boilerPressure
          : boilerPressure // ignore: cast_nullable_to_non_nullable
              as double,
      pumpRatio: null == pumpRatio
          ? _value.pumpRatio
          : pumpRatio // ignore: cast_nullable_to_non_nullable
              as double,
      weightG: null == weightG
          ? _value.weightG
          : weightG // ignore: cast_nullable_to_non_nullable
              as double,
      flowGs: null == flowGs
          ? _value.flowGs
          : flowGs // ignore: cast_nullable_to_non_nullable
              as double,
      trayPresent: null == trayPresent
          ? _value.trayPresent
          : trayPresent // ignore: cast_nullable_to_non_nullable
              as bool,
      firstDrop: null == firstDrop
          ? _value.firstDrop
          : firstDrop // ignore: cast_nullable_to_non_nullable
              as bool,
      firstDropTime: freezed == firstDropTime
          ? _value.firstDropTime
          : firstDropTime // ignore: cast_nullable_to_non_nullable
              as int?,
      brewMode: null == brewMode
          ? _value.brewMode
          : brewMode // ignore: cast_nullable_to_non_nullable
              as String,
      standby: null == standby
          ? _value.standby
          : standby // ignore: cast_nullable_to_non_nullable
              as bool,
      preInfusionOn: null == preInfusionOn
          ? _value.preInfusionOn
          : preInfusionOn // ignore: cast_nullable_to_non_nullable
              as bool,
      preInfusionTriggerOn: null == preInfusionTriggerOn
          ? _value.preInfusionTriggerOn
          : preInfusionTriggerOn // ignore: cast_nullable_to_non_nullable
              as bool,
      preInfusionTriggerThreshold: null == preInfusionTriggerThreshold
          ? _value.preInfusionTriggerThreshold
          : preInfusionTriggerThreshold // ignore: cast_nullable_to_non_nullable
              as double,
      softPressureReleaseOn: null == softPressureReleaseOn
          ? _value.softPressureReleaseOn
          : softPressureReleaseOn // ignore: cast_nullable_to_non_nullable
              as bool,
      fastHeatupOn: null == fastHeatupOn
          ? _value.fastHeatupOn
          : fastHeatupOn // ignore: cast_nullable_to_non_nullable
              as bool,
      pressureEqualizationOn: null == pressureEqualizationOn
          ? _value.pressureEqualizationOn
          : pressureEqualizationOn // ignore: cast_nullable_to_non_nullable
              as bool,
      brewTemperature: null == brewTemperature
          ? _value.brewTemperature
          : brewTemperature // ignore: cast_nullable_to_non_nullable
              as double,
      steamTemperature: null == steamTemperature
          ? _value.steamTemperature
          : steamTemperature // ignore: cast_nullable_to_non_nullable
              as double,
      steamTemperatureMax: null == steamTemperatureMax
          ? _value.steamTemperatureMax
          : steamTemperatureMax // ignore: cast_nullable_to_non_nullable
              as double,
      steamValveTrigger: null == steamValveTrigger
          ? _value.steamValveTrigger
          : steamValveTrigger // ignore: cast_nullable_to_non_nullable
              as double,
      steamValveRelease: null == steamValveRelease
          ? _value.steamValveRelease
          : steamValveRelease // ignore: cast_nullable_to_non_nullable
              as double,
      steamPressureLow: null == steamPressureLow
          ? _value.steamPressureLow
          : steamPressureLow // ignore: cast_nullable_to_non_nullable
              as double,
      steamPressureHigh: null == steamPressureHigh
          ? _value.steamPressureHigh
          : steamPressureHigh // ignore: cast_nullable_to_non_nullable
              as double,
      preInfusionPressure: null == preInfusionPressure
          ? _value.preInfusionPressure
          : preInfusionPressure // ignore: cast_nullable_to_non_nullable
              as double,
      brewPressure: null == brewPressure
          ? _value.brewPressure
          : brewPressure // ignore: cast_nullable_to_non_nullable
              as double,
      preInfusionTime: null == preInfusionTime
          ? _value.preInfusionTime
          : preInfusionTime // ignore: cast_nullable_to_non_nullable
              as double,
      softPressureReleaseTime: null == softPressureReleaseTime
          ? _value.softPressureReleaseTime
          : softPressureReleaseTime // ignore: cast_nullable_to_non_nullable
              as double,
      brewTimer: null == brewTimer
          ? _value.brewTimer
          : brewTimer // ignore: cast_nullable_to_non_nullable
              as int,
      currentTime: null == currentTime
          ? _value.currentTime
          : currentTime // ignore: cast_nullable_to_non_nullable
              as double,
      isGraphPaused: null == isGraphPaused
          ? _value.isGraphPaused
          : isGraphPaused // ignore: cast_nullable_to_non_nullable
              as bool,
      temperatureData: null == temperatureData
          ? _value.temperatureData
          : temperatureData // ignore: cast_nullable_to_non_nullable
              as List<DataPoint>,
      pressureData: null == pressureData
          ? _value.pressureData
          : pressureData // ignore: cast_nullable_to_non_nullable
              as List<DataPoint>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MachineStatusImplCopyWith<$Res>
    implements $MachineStatusCopyWith<$Res> {
  factory _$$MachineStatusImplCopyWith(
          _$MachineStatusImpl value, $Res Function(_$MachineStatusImpl) then) =
      __$$MachineStatusImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {double boilerTemperature,
      double boilerPressure,
      double pumpRatio,
      double weightG,
      double flowGs,
      bool trayPresent,
      bool firstDrop,
      int? firstDropTime,
      String brewMode,
      bool standby,
      bool preInfusionOn,
      bool preInfusionTriggerOn,
      double preInfusionTriggerThreshold,
      bool softPressureReleaseOn,
      bool fastHeatupOn,
      bool pressureEqualizationOn,
      double brewTemperature,
      double steamTemperature,
      double steamTemperatureMax,
      double steamValveTrigger,
      double steamValveRelease,
      double steamPressureLow,
      double steamPressureHigh,
      double preInfusionPressure,
      double brewPressure,
      double preInfusionTime,
      double softPressureReleaseTime,
      int brewTimer,
      double currentTime,
      bool isGraphPaused,
      List<DataPoint> temperatureData,
      List<DataPoint> pressureData});
}

/// @nodoc
class __$$MachineStatusImplCopyWithImpl<$Res>
    extends _$MachineStatusCopyWithImpl<$Res, _$MachineStatusImpl>
    implements _$$MachineStatusImplCopyWith<$Res> {
  __$$MachineStatusImplCopyWithImpl(
      _$MachineStatusImpl _value, $Res Function(_$MachineStatusImpl) _then)
      : super(_value, _then);

  /// Create a copy of MachineStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? boilerTemperature = null,
    Object? boilerPressure = null,
    Object? pumpRatio = null,
    Object? weightG = null,
    Object? flowGs = null,
    Object? trayPresent = null,
    Object? firstDrop = null,
    Object? firstDropTime = freezed,
    Object? brewMode = null,
    Object? standby = null,
    Object? preInfusionOn = null,
    Object? preInfusionTriggerOn = null,
    Object? preInfusionTriggerThreshold = null,
    Object? softPressureReleaseOn = null,
    Object? fastHeatupOn = null,
    Object? pressureEqualizationOn = null,
    Object? brewTemperature = null,
    Object? steamTemperature = null,
    Object? steamTemperatureMax = null,
    Object? steamValveTrigger = null,
    Object? steamValveRelease = null,
    Object? steamPressureLow = null,
    Object? steamPressureHigh = null,
    Object? preInfusionPressure = null,
    Object? brewPressure = null,
    Object? preInfusionTime = null,
    Object? softPressureReleaseTime = null,
    Object? brewTimer = null,
    Object? currentTime = null,
    Object? isGraphPaused = null,
    Object? temperatureData = null,
    Object? pressureData = null,
  }) {
    return _then(_$MachineStatusImpl(
      boilerTemperature: null == boilerTemperature
          ? _value.boilerTemperature
          : boilerTemperature // ignore: cast_nullable_to_non_nullable
              as double,
      boilerPressure: null == boilerPressure
          ? _value.boilerPressure
          : boilerPressure // ignore: cast_nullable_to_non_nullable
              as double,
      pumpRatio: null == pumpRatio
          ? _value.pumpRatio
          : pumpRatio // ignore: cast_nullable_to_non_nullable
              as double,
      weightG: null == weightG
          ? _value.weightG
          : weightG // ignore: cast_nullable_to_non_nullable
              as double,
      flowGs: null == flowGs
          ? _value.flowGs
          : flowGs // ignore: cast_nullable_to_non_nullable
              as double,
      trayPresent: null == trayPresent
          ? _value.trayPresent
          : trayPresent // ignore: cast_nullable_to_non_nullable
              as bool,
      firstDrop: null == firstDrop
          ? _value.firstDrop
          : firstDrop // ignore: cast_nullable_to_non_nullable
              as bool,
      firstDropTime: freezed == firstDropTime
          ? _value.firstDropTime
          : firstDropTime // ignore: cast_nullable_to_non_nullable
              as int?,
      brewMode: null == brewMode
          ? _value.brewMode
          : brewMode // ignore: cast_nullable_to_non_nullable
              as String,
      standby: null == standby
          ? _value.standby
          : standby // ignore: cast_nullable_to_non_nullable
              as bool,
      preInfusionOn: null == preInfusionOn
          ? _value.preInfusionOn
          : preInfusionOn // ignore: cast_nullable_to_non_nullable
              as bool,
      preInfusionTriggerOn: null == preInfusionTriggerOn
          ? _value.preInfusionTriggerOn
          : preInfusionTriggerOn // ignore: cast_nullable_to_non_nullable
              as bool,
      preInfusionTriggerThreshold: null == preInfusionTriggerThreshold
          ? _value.preInfusionTriggerThreshold
          : preInfusionTriggerThreshold // ignore: cast_nullable_to_non_nullable
              as double,
      softPressureReleaseOn: null == softPressureReleaseOn
          ? _value.softPressureReleaseOn
          : softPressureReleaseOn // ignore: cast_nullable_to_non_nullable
              as bool,
      fastHeatupOn: null == fastHeatupOn
          ? _value.fastHeatupOn
          : fastHeatupOn // ignore: cast_nullable_to_non_nullable
              as bool,
      pressureEqualizationOn: null == pressureEqualizationOn
          ? _value.pressureEqualizationOn
          : pressureEqualizationOn // ignore: cast_nullable_to_non_nullable
              as bool,
      brewTemperature: null == brewTemperature
          ? _value.brewTemperature
          : brewTemperature // ignore: cast_nullable_to_non_nullable
              as double,
      steamTemperature: null == steamTemperature
          ? _value.steamTemperature
          : steamTemperature // ignore: cast_nullable_to_non_nullable
              as double,
      steamTemperatureMax: null == steamTemperatureMax
          ? _value.steamTemperatureMax
          : steamTemperatureMax // ignore: cast_nullable_to_non_nullable
              as double,
      steamValveTrigger: null == steamValveTrigger
          ? _value.steamValveTrigger
          : steamValveTrigger // ignore: cast_nullable_to_non_nullable
              as double,
      steamValveRelease: null == steamValveRelease
          ? _value.steamValveRelease
          : steamValveRelease // ignore: cast_nullable_to_non_nullable
              as double,
      steamPressureLow: null == steamPressureLow
          ? _value.steamPressureLow
          : steamPressureLow // ignore: cast_nullable_to_non_nullable
              as double,
      steamPressureHigh: null == steamPressureHigh
          ? _value.steamPressureHigh
          : steamPressureHigh // ignore: cast_nullable_to_non_nullable
              as double,
      preInfusionPressure: null == preInfusionPressure
          ? _value.preInfusionPressure
          : preInfusionPressure // ignore: cast_nullable_to_non_nullable
              as double,
      brewPressure: null == brewPressure
          ? _value.brewPressure
          : brewPressure // ignore: cast_nullable_to_non_nullable
              as double,
      preInfusionTime: null == preInfusionTime
          ? _value.preInfusionTime
          : preInfusionTime // ignore: cast_nullable_to_non_nullable
              as double,
      softPressureReleaseTime: null == softPressureReleaseTime
          ? _value.softPressureReleaseTime
          : softPressureReleaseTime // ignore: cast_nullable_to_non_nullable
              as double,
      brewTimer: null == brewTimer
          ? _value.brewTimer
          : brewTimer // ignore: cast_nullable_to_non_nullable
              as int,
      currentTime: null == currentTime
          ? _value.currentTime
          : currentTime // ignore: cast_nullable_to_non_nullable
              as double,
      isGraphPaused: null == isGraphPaused
          ? _value.isGraphPaused
          : isGraphPaused // ignore: cast_nullable_to_non_nullable
              as bool,
      temperatureData: null == temperatureData
          ? _value._temperatureData
          : temperatureData // ignore: cast_nullable_to_non_nullable
              as List<DataPoint>,
      pressureData: null == pressureData
          ? _value._pressureData
          : pressureData // ignore: cast_nullable_to_non_nullable
              as List<DataPoint>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MachineStatusImpl implements _MachineStatus {
  const _$MachineStatusImpl(
      {this.boilerTemperature = 0.0,
      this.boilerPressure = 0.0,
      this.pumpRatio = 0.0,
      this.weightG = 0.0,
      this.flowGs = 0.0,
      this.trayPresent = true,
      this.firstDrop = false,
      this.firstDropTime,
      this.brewMode = 'IDLE',
      this.standby = false,
      this.preInfusionOn = false,
      this.preInfusionTriggerOn = false,
      this.preInfusionTriggerThreshold = 0.25,
      this.softPressureReleaseOn = false,
      this.fastHeatupOn = false,
      this.pressureEqualizationOn = false,
      this.brewTemperature = 97.0,
      this.steamTemperature = 135.0,
      this.steamTemperatureMax = 140.0,
      this.steamValveTrigger = 1.8,
      this.steamValveRelease = 2.1,
      this.steamPressureLow = 1.8,
      this.steamPressureHigh = 2.5,
      this.preInfusionPressure = 2.0,
      this.brewPressure = 8.0,
      this.preInfusionTime = 5.0,
      this.softPressureReleaseTime = 4.0,
      this.brewTimer = 0,
      this.currentTime = 0.0,
      this.isGraphPaused = false,
      final List<DataPoint> temperatureData = const <DataPoint>[],
      final List<DataPoint> pressureData = const <DataPoint>[]})
      : _temperatureData = temperatureData,
        _pressureData = pressureData;

  factory _$MachineStatusImpl.fromJson(Map<String, dynamic> json) =>
      _$$MachineStatusImplFromJson(json);

  @override
  @JsonKey()
  final double boilerTemperature;
  @override
  @JsonKey()
  final double boilerPressure;
  @override
  @JsonKey()
  final double pumpRatio;
  @override
  @JsonKey()
  final double weightG;

  /// Flow rate from Pico scale (g/s).
  @override
  @JsonKey()
  final double flowGs;

  /// False when drip tray removed (weight deeply negative after tare).
  @override
  @JsonKey()
  final bool trayPresent;

  /// First drop detected by Pico scale during extraction.
  @override
  @JsonKey()
  final bool firstDrop;

  /// Seconds into extraction when first drop occurred.
  @override
  final int? firstDropTime;
  @override
  @JsonKey()
  final String brewMode;

  /// Pico standby (VALMIUSTILA): IDLE target lowered after the idle timeout.
  @override
  @JsonKey()
  final bool standby;
  @override
  @JsonKey()
  final bool preInfusionOn;
  @override
  @JsonKey()
  final bool preInfusionTriggerOn;
  @override
  @JsonKey()
  final double preInfusionTriggerThreshold;
  @override
  @JsonKey()
  final bool softPressureReleaseOn;
  @override
  @JsonKey()
  final bool fastHeatupOn;
  @override
  @JsonKey()
  final bool pressureEqualizationOn;
  @override
  @JsonKey()
  final double brewTemperature;
  @override
  @JsonKey()
  final double steamTemperature;
  @override
  @JsonKey()
  final double steamTemperatureMax;
  @override
  @JsonKey()
  final double steamValveTrigger;
  @override
  @JsonKey()
  final double steamValveRelease;
  @override
  @JsonKey()
  final double steamPressureLow;
  @override
  @JsonKey()
  final double steamPressureHigh;
  @override
  @JsonKey()
  final double preInfusionPressure;
  @override
  @JsonKey()
  final double brewPressure;
  @override
  @JsonKey()
  final double preInfusionTime;
  @override
  @JsonKey()
  final double softPressureReleaseTime;
  @override
  @JsonKey()
  final int brewTimer;
  @override
  @JsonKey()
  final double currentTime;
  @override
  @JsonKey()
  final bool isGraphPaused;
  final List<DataPoint> _temperatureData;
  @override
  @JsonKey()
  List<DataPoint> get temperatureData {
    if (_temperatureData is EqualUnmodifiableListView) return _temperatureData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_temperatureData);
  }

  final List<DataPoint> _pressureData;
  @override
  @JsonKey()
  List<DataPoint> get pressureData {
    if (_pressureData is EqualUnmodifiableListView) return _pressureData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pressureData);
  }

  @override
  String toString() {
    return 'MachineStatus(boilerTemperature: $boilerTemperature, boilerPressure: $boilerPressure, pumpRatio: $pumpRatio, weightG: $weightG, flowGs: $flowGs, trayPresent: $trayPresent, firstDrop: $firstDrop, firstDropTime: $firstDropTime, brewMode: $brewMode, standby: $standby, preInfusionOn: $preInfusionOn, preInfusionTriggerOn: $preInfusionTriggerOn, preInfusionTriggerThreshold: $preInfusionTriggerThreshold, softPressureReleaseOn: $softPressureReleaseOn, fastHeatupOn: $fastHeatupOn, pressureEqualizationOn: $pressureEqualizationOn, brewTemperature: $brewTemperature, steamTemperature: $steamTemperature, steamTemperatureMax: $steamTemperatureMax, steamValveTrigger: $steamValveTrigger, steamValveRelease: $steamValveRelease, steamPressureLow: $steamPressureLow, steamPressureHigh: $steamPressureHigh, preInfusionPressure: $preInfusionPressure, brewPressure: $brewPressure, preInfusionTime: $preInfusionTime, softPressureReleaseTime: $softPressureReleaseTime, brewTimer: $brewTimer, currentTime: $currentTime, isGraphPaused: $isGraphPaused, temperatureData: $temperatureData, pressureData: $pressureData)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MachineStatusImpl &&
            (identical(other.boilerTemperature, boilerTemperature) ||
                other.boilerTemperature == boilerTemperature) &&
            (identical(other.boilerPressure, boilerPressure) ||
                other.boilerPressure == boilerPressure) &&
            (identical(other.pumpRatio, pumpRatio) ||
                other.pumpRatio == pumpRatio) &&
            (identical(other.weightG, weightG) || other.weightG == weightG) &&
            (identical(other.flowGs, flowGs) || other.flowGs == flowGs) &&
            (identical(other.trayPresent, trayPresent) ||
                other.trayPresent == trayPresent) &&
            (identical(other.firstDrop, firstDrop) ||
                other.firstDrop == firstDrop) &&
            (identical(other.firstDropTime, firstDropTime) ||
                other.firstDropTime == firstDropTime) &&
            (identical(other.brewMode, brewMode) ||
                other.brewMode == brewMode) &&
            (identical(other.standby, standby) || other.standby == standby) &&
            (identical(other.preInfusionOn, preInfusionOn) ||
                other.preInfusionOn == preInfusionOn) &&
            (identical(other.preInfusionTriggerOn, preInfusionTriggerOn) ||
                other.preInfusionTriggerOn == preInfusionTriggerOn) &&
            (identical(other.preInfusionTriggerThreshold,
                    preInfusionTriggerThreshold) ||
                other.preInfusionTriggerThreshold ==
                    preInfusionTriggerThreshold) &&
            (identical(other.softPressureReleaseOn, softPressureReleaseOn) ||
                other.softPressureReleaseOn == softPressureReleaseOn) &&
            (identical(other.fastHeatupOn, fastHeatupOn) ||
                other.fastHeatupOn == fastHeatupOn) &&
            (identical(other.pressureEqualizationOn, pressureEqualizationOn) ||
                other.pressureEqualizationOn == pressureEqualizationOn) &&
            (identical(other.brewTemperature, brewTemperature) ||
                other.brewTemperature == brewTemperature) &&
            (identical(other.steamTemperature, steamTemperature) ||
                other.steamTemperature == steamTemperature) &&
            (identical(other.steamTemperatureMax, steamTemperatureMax) ||
                other.steamTemperatureMax == steamTemperatureMax) &&
            (identical(other.steamValveTrigger, steamValveTrigger) ||
                other.steamValveTrigger == steamValveTrigger) &&
            (identical(other.steamValveRelease, steamValveRelease) ||
                other.steamValveRelease == steamValveRelease) &&
            (identical(other.steamPressureLow, steamPressureLow) ||
                other.steamPressureLow == steamPressureLow) &&
            (identical(other.steamPressureHigh, steamPressureHigh) ||
                other.steamPressureHigh == steamPressureHigh) &&
            (identical(other.preInfusionPressure, preInfusionPressure) ||
                other.preInfusionPressure == preInfusionPressure) &&
            (identical(other.brewPressure, brewPressure) ||
                other.brewPressure == brewPressure) &&
            (identical(other.preInfusionTime, preInfusionTime) ||
                other.preInfusionTime == preInfusionTime) &&
            (identical(
                    other.softPressureReleaseTime, softPressureReleaseTime) ||
                other.softPressureReleaseTime == softPressureReleaseTime) &&
            (identical(other.brewTimer, brewTimer) ||
                other.brewTimer == brewTimer) &&
            (identical(other.currentTime, currentTime) ||
                other.currentTime == currentTime) &&
            (identical(other.isGraphPaused, isGraphPaused) ||
                other.isGraphPaused == isGraphPaused) &&
            const DeepCollectionEquality()
                .equals(other._temperatureData, _temperatureData) &&
            const DeepCollectionEquality()
                .equals(other._pressureData, _pressureData));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        boilerTemperature,
        boilerPressure,
        pumpRatio,
        weightG,
        flowGs,
        trayPresent,
        firstDrop,
        firstDropTime,
        brewMode,
        standby,
        preInfusionOn,
        preInfusionTriggerOn,
        preInfusionTriggerThreshold,
        softPressureReleaseOn,
        fastHeatupOn,
        pressureEqualizationOn,
        brewTemperature,
        steamTemperature,
        steamTemperatureMax,
        steamValveTrigger,
        steamValveRelease,
        steamPressureLow,
        steamPressureHigh,
        preInfusionPressure,
        brewPressure,
        preInfusionTime,
        softPressureReleaseTime,
        brewTimer,
        currentTime,
        isGraphPaused,
        const DeepCollectionEquality().hash(_temperatureData),
        const DeepCollectionEquality().hash(_pressureData)
      ]);

  /// Create a copy of MachineStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MachineStatusImplCopyWith<_$MachineStatusImpl> get copyWith =>
      __$$MachineStatusImplCopyWithImpl<_$MachineStatusImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MachineStatusImplToJson(
      this,
    );
  }
}

abstract class _MachineStatus implements MachineStatus {
  const factory _MachineStatus(
      {final double boilerTemperature,
      final double boilerPressure,
      final double pumpRatio,
      final double weightG,
      final double flowGs,
      final bool trayPresent,
      final bool firstDrop,
      final int? firstDropTime,
      final String brewMode,
      final bool standby,
      final bool preInfusionOn,
      final bool preInfusionTriggerOn,
      final double preInfusionTriggerThreshold,
      final bool softPressureReleaseOn,
      final bool fastHeatupOn,
      final bool pressureEqualizationOn,
      final double brewTemperature,
      final double steamTemperature,
      final double steamTemperatureMax,
      final double steamValveTrigger,
      final double steamValveRelease,
      final double steamPressureLow,
      final double steamPressureHigh,
      final double preInfusionPressure,
      final double brewPressure,
      final double preInfusionTime,
      final double softPressureReleaseTime,
      final int brewTimer,
      final double currentTime,
      final bool isGraphPaused,
      final List<DataPoint> temperatureData,
      final List<DataPoint> pressureData}) = _$MachineStatusImpl;

  factory _MachineStatus.fromJson(Map<String, dynamic> json) =
      _$MachineStatusImpl.fromJson;

  @override
  double get boilerTemperature;
  @override
  double get boilerPressure;
  @override
  double get pumpRatio;
  @override
  double get weightG;

  /// Flow rate from Pico scale (g/s).
  @override
  double get flowGs;

  /// False when drip tray removed (weight deeply negative after tare).
  @override
  bool get trayPresent;

  /// First drop detected by Pico scale during extraction.
  @override
  bool get firstDrop;

  /// Seconds into extraction when first drop occurred.
  @override
  int? get firstDropTime;
  @override
  String get brewMode;

  /// Pico standby (VALMIUSTILA): IDLE target lowered after the idle timeout.
  @override
  bool get standby;
  @override
  bool get preInfusionOn;
  @override
  bool get preInfusionTriggerOn;
  @override
  double get preInfusionTriggerThreshold;
  @override
  bool get softPressureReleaseOn;
  @override
  bool get fastHeatupOn;
  @override
  bool get pressureEqualizationOn;
  @override
  double get brewTemperature;
  @override
  double get steamTemperature;
  @override
  double get steamTemperatureMax;
  @override
  double get steamValveTrigger;
  @override
  double get steamValveRelease;
  @override
  double get steamPressureLow;
  @override
  double get steamPressureHigh;
  @override
  double get preInfusionPressure;
  @override
  double get brewPressure;
  @override
  double get preInfusionTime;
  @override
  double get softPressureReleaseTime;
  @override
  int get brewTimer;
  @override
  double get currentTime;
  @override
  bool get isGraphPaused;
  @override
  List<DataPoint> get temperatureData;
  @override
  List<DataPoint> get pressureData;

  /// Create a copy of MachineStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MachineStatusImplCopyWith<_$MachineStatusImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
