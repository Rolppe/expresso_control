// ============================================================================
// brew_log_assembler.dart — pure multi-part BLE brew_log reassembly (testable)
// ============================================================================

import '../../models/brew_log.dart';

/// Result of feeding one JSON map into the assembler.
class BrewLogAssembleResult {
  final BrewLog? completed;
  final String? rejectReason;
  final String? info;

  const BrewLogAssembleResult({this.completed, this.rejectReason, this.info});

  bool get hasCompleted => completed != null;
  bool get rejected => rejectReason != null;
}

class _Assembly {
  Map<String, dynamic> meta = {};
  final Map<int, List<dynamic>> sampleParts = {};
  int expectedParts = 0;
  int expectedSamples = 0;
  bool hasMeta = false;
}

/// Stateless-enough assembler: holds partial frames by log id.
class BrewLogAssembler {
  final Map<int, _Assembly> _asm = {};

  void clear() => _asm.clear();

  int get pendingIds => _asm.length;

  BrewLogAssembleResult add(Map<String, dynamic> json) {
    if (json['type'] != 'brew_log') {
      return const BrewLogAssembleResult(info: 'ignored_non_brew_log');
    }

    final part = (json['part'] as String?) ?? 'body';
    final id = (json['id'] as num?)?.toInt() ?? 0;

    // Legacy single-body
    if (part == 'body' || (json.containsKey('samples') && part != 'samples')) {
      try {
        final log = BrewLog.fromJson(json);
        if (log.samples.isEmpty && log.events.isEmpty) {
          return const BrewLogAssembleResult(rejectReason: 'empty_legacy_body');
        }
        return BrewLogAssembleResult(completed: log, info: 'legacy_body');
      } catch (e) {
        return BrewLogAssembleResult(rejectReason: 'legacy_parse:$e');
      }
    }

    final a = _asm.putIfAbsent(id, _Assembly.new);

    if (part == 'meta') {
      a.meta = Map<String, dynamic>.from(json);
      a.hasMeta = true;
      a.expectedParts = (json['n_parts'] as num?)?.toInt() ?? 0;
      a.expectedSamples = (json['n_samples'] as num?)?.toInt() ?? 0;
      return BrewLogAssembleResult(
        info: 'meta id=$id n=${a.expectedSamples} parts=${a.expectedParts}',
      );
    }

    if (part == 'samples') {
      final i = (json['i'] as num?)?.toInt() ?? 0;
      final of = (json['of'] as num?)?.toInt() ?? a.expectedParts;
      if (of > 0) a.expectedParts = of;
      final rows = json['rows'] as List<dynamic>? ?? const [];
      a.sampleParts[i] = List<dynamic>.from(rows);
      if (a.hasMeta &&
          a.expectedParts > 0 &&
          a.sampleParts.length >= a.expectedParts) {
        return _tryComplete(id, force: false);
      }
      return BrewLogAssembleResult(
        info:
            'samples id=$id i=$i/${a.expectedParts} rows=${rows.length} have=${a.sampleParts.length}',
      );
    }

    if (part == 'end') {
      return _tryComplete(id, force: true);
    }

    return BrewLogAssembleResult(info: 'unknown_part:$part');
  }

  BrewLogAssembleResult _tryComplete(int id, {required bool force}) {
    final a = _asm[id];
    if (a == null) {
      return BrewLogAssembleResult(rejectReason: 'missing_assembly id=$id');
    }

    if (!a.hasMeta) {
      if (force) _asm.remove(id);
      return BrewLogAssembleResult(
        rejectReason: 'no_meta id=$id force=$force',
      );
    }

    final nParts = a.expectedParts;
    if (nParts > 0 && a.sampleParts.length < nParts) {
      if (!force) {
        return BrewLogAssembleResult(
          info: 'incomplete id=$id have=${a.sampleParts.length}/$nParts',
        );
      }
      if (a.sampleParts.isEmpty) {
        _asm.remove(id);
        return BrewLogAssembleResult(
          rejectReason: 'end_with_zero_parts id=$id',
        );
      }
    }

    final rows = <dynamic>[];
    final keys = a.sampleParts.keys.toList()..sort();
    for (final k in keys) {
      rows.addAll(a.sampleParts[k]!);
    }

    if (rows.isEmpty && a.expectedSamples > 0) {
      _asm.remove(id);
      return BrewLogAssembleResult(
        rejectReason:
            'expected_${a.expectedSamples}_samples_got_0 id=$id',
      );
    }

    if (rows.isEmpty) {
      _asm.remove(id);
      return BrewLogAssembleResult(rejectReason: 'empty_rows id=$id');
    }

    final merged = Map<String, dynamic>.from(a.meta);
    merged['type'] = 'brew_log';
    merged['id'] = id;
    merged['samples'] = rows;
    if (!merged.containsKey('events')) {
      merged['events'] = const [];
    }
    merged['n_samples'] = rows.length;
    if (rows.isNotEmpty) {
      merged['duration_ms'] = (rows.last as List)[0];
    }

    _asm.remove(id);
    try {
      final log = BrewLog.fromJson(merged);
      if (log.samples.isEmpty && log.events.isEmpty) {
        return const BrewLogAssembleResult(rejectReason: 'empty_log');
      }
      return BrewLogAssembleResult(completed: log, info: 'complete id=$id');
    } catch (e) {
      return BrewLogAssembleResult(rejectReason: 'parse:$e');
    }
  }
}

/// Build multiparts the way Pico bluetooth_handler.send_brew_log does (for tests).
List<Map<String, dynamic>> buildBrewLogParts(
  Map<String, dynamic> export, {
  int chunkRows = 40,
}) {
  final samples = (export['samples'] as List<dynamic>? ?? const []);
  final events = (export['events'] as List<dynamic>? ?? const []);
  final n = samples.length;
  if (n == 0) return const [];

  var nParts = (n + chunkRows - 1) ~/ chunkRows;
  if (nParts < 1) nParts = 1;
  final lid = export['id'];

  final parts = <Map<String, dynamic>>[
    {
      'type': 'brew_log',
      'part': 'meta',
      'v': export['v'] ?? 1,
      'id': lid,
      'sample_hz': export['sample_hz'] ?? 10,
      'duration_ms': export['duration_ms'] ?? 0,
      'n_samples': n,
      'n_events': events.length,
      'n_parts': nParts,
      'truncated': export['truncated'] ?? false,
      'scale_at_end_g': export['scale_at_end_g'] ?? 0,
      'events': events,
    },
  ];

  for (var pi = 0; pi < nParts; pi++) {
    final a = pi * chunkRows;
    var b = a + chunkRows;
    if (b > n) b = n;
    parts.add({
      'type': 'brew_log',
      'part': 'samples',
      'id': lid,
      'i': pi,
      'of': nParts,
      'rows': samples.sublist(a, b),
    });
  }

  parts.add({
    'type': 'brew_log',
    'part': 'end',
    'id': lid,
    'n_samples': n,
  });
  return parts;
}
