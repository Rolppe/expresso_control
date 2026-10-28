// ============================================================================
// brew_log.dart — on-device shot log received over BLE
// ============================================================================

/// One sample row from Pico.
///
/// **v1:** `[t_ms, T*10, P*100, flow*100, W*10, flags]` (6)
/// **v2 legacy:** `[t_ms, T*10, P*100, flow*100, hx_a, hx_b, flags]` (7)
///   hx were session-tare deltas; weight reconstructed if scale_meta present.
/// **v3:** `[t_ms, T*10, P*100, flow*100, hx_a_raw, hx_b_raw, W*10, flags]` (8)
///   hx = raw HX711 ADC (never tare); W = session-tared display weight.
class BrewLogSample {
  final int tMs;
  final double tempC;
  final double pressBar;
  final double flowGs;
  /// Session-tared display weight (g). Primary pour curve source.
  final double weightG;
  /// HX711 A raw (v3) or legacy delta (v2); null on v1 rows.
  final int? hxA;
  /// HX711 B raw (v3) or legacy delta (v2); null on v1 rows.
  final int? hxB;
  final bool pumpOn;
  final bool heaterOn;

  const BrewLogSample({
    required this.tMs,
    required this.tempC,
    required this.pressBar,
    required this.flowGs,
    required this.weightG,
    this.hxA,
    this.hxB,
    required this.pumpOn,
    required this.heaterOn,
  });

  factory BrewLogSample.fromRow(
    List<dynamic> row, {
    Map<String, dynamic>? scaleMeta,
  }) {
    final flags = row.isNotEmpty ? (row[row.length - 1] as num).toInt() : 0;
    final pumpOn = (flags & 1) != 0;
    final heaterOn = (flags & 2) != 0;
    final tMs = (row[0] as num).toInt();
    final tempC = (row[1] as num).toDouble() / 10.0;
    final pressBar = (row[2] as num).toDouble() / 100.0;
    final flowGs = (row[3] as num).toDouble() / 100.0;

    // v3: 8 fields — raw dual HX + weight×10 + flags
    if (row.length >= 8) {
      return BrewLogSample(
        tMs: tMs,
        tempC: tempC,
        pressBar: pressBar,
        flowGs: flowGs,
        hxA: (row[4] as num).toInt(),
        hxB: (row[5] as num).toInt(),
        weightG: (row[6] as num).toDouble() / 10.0,
        pumpOn: pumpOn,
        heaterOn: heaterOn,
      );
    }

    // v2 legacy: 7 fields — dual HX (deltas), no weight; best-effort reconstruct
    if (row.length >= 7) {
      final hxA = (row[4] as num).toInt();
      final hxB = (row[5] as num).toInt();
      return BrewLogSample(
        tMs: tMs,
        tempC: tempC,
        pressBar: pressBar,
        flowGs: flowGs,
        weightG: reconstructWeightG(hxA, hxB, scaleMeta),
        hxA: hxA,
        hxB: hxB,
        pumpOn: pumpOn,
        heaterOn: heaterOn,
      );
    }

    // v1: combined weight ×10
    return BrewLogSample(
      tMs: tMs,
      tempC: tempC,
      pressBar: pressBar,
      flowGs: flowGs,
      weightG: (row[4] as num).toDouble() / 10.0,
      pumpOn: pumpOn,
      heaterOn: heaterOn,
    );
  }

  /// Compact Pico row OR named map from permanent JSONL.
  factory BrewLogSample.fromJson(
    dynamic raw, {
    Map<String, dynamic>? scaleMeta,
  }) {
    if (raw is List) {
      return BrewLogSample.fromRow(raw, scaleMeta: scaleMeta);
    }
    final m = raw as Map<String, dynamic>;
    final hxA = (m['hx_a'] as num?)?.toInt();
    final hxB = (m['hx_b'] as num?)?.toInt();
    var weightG = (m['weight_g'] as num?)?.toDouble();
    // Only reconstruct when weight missing (legacy v2 maps).
    if (weightG == null && hxA != null && hxB != null) {
      weightG = reconstructWeightG(hxA, hxB, scaleMeta);
    }
    return BrewLogSample(
      tMs: (m['t_ms'] as num?)?.toInt() ?? 0,
      tempC: (m['temp_c'] as num?)?.toDouble() ?? 0,
      pressBar: (m['press_bar'] as num?)?.toDouble() ?? 0,
      flowGs: (m['flow_g_s'] as num?)?.toDouble() ?? 0,
      weightG: weightG ?? 0,
      hxA: hxA,
      hxB: hxB,
      pumpOn: m['pump_on'] as bool? ?? false,
      heaterOn: m['heater_on'] as bool? ?? false,
    );
  }

  /// Offline helper: weight ≈ sense * (hx_delta_a + trim_b * hx_delta_b) / scale.
  /// For v3 raw counts, pass deltas (raw - off) yourself.
  static double reconstructWeightG(
    int hxA,
    int hxB,
    Map<String, dynamic>? meta,
  ) {
    if (meta == null) return 0.0;
    final scale = (meta['scale'] as num?)?.toDouble() ?? 0.0;
    if (scale.abs() < 1e-9) return 0.0;
    final trimB = (meta['trim_b'] as num?)?.toDouble() ?? 1.0;
    final sense = (meta['sense'] as num?)?.toDouble() ?? 1.0;
    return sense * (hxA + trimB * hxB) / scale;
  }

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      't_ms': tMs,
      'temp_c': tempC,
      'press_bar': pressBar,
      'flow_g_s': flowGs,
      'weight_g': weightG,
      'pump_on': pumpOn,
      'heater_on': heaterOn,
    };
    if (hxA != null) m['hx_a'] = hxA;
    if (hxB != null) m['hx_b'] = hxB;
    return m;
  }
}

class BrewLogEvent {
  final String name;
  final int tMs;

  const BrewLogEvent({required this.name, required this.tMs});

  factory BrewLogEvent.fromRow(List<dynamic> row) => BrewLogEvent(
        name: row[0].toString(),
        tMs: (row[1] as num).toInt(),
      );

  factory BrewLogEvent.fromJson(dynamic raw) {
    if (raw is List) return BrewLogEvent.fromRow(raw);
    final m = raw as Map<String, dynamic>;
    return BrewLogEvent(
      name: m['name']?.toString() ?? '',
      tMs: (m['t_ms'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 't_ms': tMs};
}

/// Complete shot log from Pico (after BLE assembly).
class BrewLog {
  final int id;
  final int sampleHz;
  final int durationMs;
  final bool truncated;
  final double scaleAtEndG;
  final List<BrewLogSample> samples;
  final List<BrewLogEvent> events;
  final int schemaVersion;
  final Map<String, dynamic>? scaleMeta;

  const BrewLog({
    required this.id,
    required this.sampleHz,
    required this.durationMs,
    required this.truncated,
    required this.scaleAtEndG,
    required this.samples,
    required this.events,
    this.schemaVersion = 1,
    this.scaleMeta,
  });

  factory BrewLog.fromJson(Map<String, dynamic> json) {
    final v = (json['v'] as num?)?.toInt() ?? 1;
    final meta = json['scale_meta'] is Map
        ? Map<String, dynamic>.from(json['scale_meta'] as Map)
        : null;
    final samplesRaw = (json['samples'] as List<dynamic>? ?? const [])
        .map((e) => BrewLogSample.fromJson(e, scaleMeta: meta))
        .toList();
    final eventsRaw = (json['events'] as List<dynamic>? ?? const [])
        .map(BrewLogEvent.fromJson)
        .toList();
    return BrewLog(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sampleHz: (json['sample_hz'] as num?)?.toInt() ?? 10,
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      truncated: json['truncated'] as bool? ?? false,
      scaleAtEndG: (json['scale_at_end_g'] as num?)?.toDouble() ?? 0,
      samples: samplesRaw,
      events: eventsRaw,
      schemaVersion: v,
      scaleMeta: meta,
    );
  }

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'v': schemaVersion,
      'id': id,
      'sample_hz': sampleHz,
      'duration_ms': durationMs,
      'n_samples': samples.length,
      'n_events': events.length,
      'truncated': truncated,
      'scale_at_end_g': scaleAtEndG,
      'samples': samples.map((s) => s.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
    };
    if (scaleMeta != null) m['scale_meta'] = scaleMeta;
    return m;
  }
}
