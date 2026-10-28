// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_point.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DataPointImpl _$$DataPointImplFromJson(Map<String, dynamic> json) =>
    _$DataPointImpl(
      time: (json['time'] as num).toDouble(),
      value: (json['value'] as num).toDouble(),
    );

Map<String, dynamic> _$$DataPointImplToJson(_$DataPointImpl instance) =>
    <String, dynamic>{
      'time': instance.time,
      'value': instance.value,
    };
