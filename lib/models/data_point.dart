// ============================================================================
// data_point.dart
// ============================================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'data_point.freezed.dart';
part 'data_point.g.dart';

// ============================================================================
// MODEL
// ============================================================================

/// Single data point for the real-time graph.
/// - `time`: seconds since the current brewing session started
/// - `value`: temperature (°C) or pressure (bar)
@freezed
class DataPoint with _$DataPoint {
  const factory DataPoint({
    required double time,
    required double value,
  }) = _DataPoint;

  factory DataPoint.fromJson(Map<String, dynamic> json) => _$DataPointFromJson(json);
}
