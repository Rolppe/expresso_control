// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'data_point.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DataPoint _$DataPointFromJson(Map<String, dynamic> json) {
  return _DataPoint.fromJson(json);
}

/// @nodoc
mixin _$DataPoint {
  double get time => throw _privateConstructorUsedError;
  double get value => throw _privateConstructorUsedError;

  /// Serializes this DataPoint to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DataPoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DataPointCopyWith<DataPoint> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DataPointCopyWith<$Res> {
  factory $DataPointCopyWith(DataPoint value, $Res Function(DataPoint) then) =
      _$DataPointCopyWithImpl<$Res, DataPoint>;
  @useResult
  $Res call({double time, double value});
}

/// @nodoc
class _$DataPointCopyWithImpl<$Res, $Val extends DataPoint>
    implements $DataPointCopyWith<$Res> {
  _$DataPointCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DataPoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? time = null,
    Object? value = null,
  }) {
    return _then(_value.copyWith(
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as double,
      value: null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DataPointImplCopyWith<$Res>
    implements $DataPointCopyWith<$Res> {
  factory _$$DataPointImplCopyWith(
          _$DataPointImpl value, $Res Function(_$DataPointImpl) then) =
      __$$DataPointImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double time, double value});
}

/// @nodoc
class __$$DataPointImplCopyWithImpl<$Res>
    extends _$DataPointCopyWithImpl<$Res, _$DataPointImpl>
    implements _$$DataPointImplCopyWith<$Res> {
  __$$DataPointImplCopyWithImpl(
      _$DataPointImpl _value, $Res Function(_$DataPointImpl) _then)
      : super(_value, _then);

  /// Create a copy of DataPoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? time = null,
    Object? value = null,
  }) {
    return _then(_$DataPointImpl(
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as double,
      value: null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DataPointImpl implements _DataPoint {
  const _$DataPointImpl({required this.time, required this.value});

  factory _$DataPointImpl.fromJson(Map<String, dynamic> json) =>
      _$$DataPointImplFromJson(json);

  @override
  final double time;
  @override
  final double value;

  @override
  String toString() {
    return 'DataPoint(time: $time, value: $value)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DataPointImpl &&
            (identical(other.time, time) || other.time == time) &&
            (identical(other.value, value) || other.value == value));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, time, value);

  /// Create a copy of DataPoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DataPointImplCopyWith<_$DataPointImpl> get copyWith =>
      __$$DataPointImplCopyWithImpl<_$DataPointImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DataPointImplToJson(
      this,
    );
  }
}

abstract class _DataPoint implements DataPoint {
  const factory _DataPoint(
      {required final double time,
      required final double value}) = _$DataPointImpl;

  factory _DataPoint.fromJson(Map<String, dynamic> json) =
      _$DataPointImpl.fromJson;

  @override
  double get time;
  @override
  double get value;

  /// Create a copy of DataPoint
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DataPointImplCopyWith<_$DataPointImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
