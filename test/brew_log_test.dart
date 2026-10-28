// ============================================================================
// brew_log_test.dart — model + multipack assembler + JSONL store
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silvia_pico_ui/features/brew_log/brew_log_assembler.dart';
import 'package:silvia_pico_ui/models/brew_log.dart';

void main() {
  group('BrewLogSample encoding', () {
    test('fromRow v1 decodes weight×10 and flags', () {
      final s = BrewLogSample.fromRow([1200, 973, 912, 125, 126, 3]);
      expect(s.tMs, 1200);
      expect(s.tempC, closeTo(97.3, 1e-9));
      expect(s.pressBar, closeTo(9.12, 1e-9));
      expect(s.flowGs, closeTo(1.25, 1e-9));
      expect(s.weightG, closeTo(12.6, 1e-9));
      expect(s.hxA, isNull);
      expect(s.pumpOn, isTrue);
      expect(s.heaterOn, isTrue);
    });

    test('fromRow v3 raw dual HX + weight×10', () {
      final s = BrewLogSample.fromRow(
        [1200, 973, 912, 125, 1165000, 492000, 126, 1],
      );
      expect(s.hxA, 1165000);
      expect(s.hxB, 492000);
      expect(s.weightG, closeTo(12.6, 1e-9));
      expect(s.pumpOn, isTrue);
      expect(s.heaterOn, isFalse);
    });

    test('fromRow v2 legacy dual HX reconstruct weight', () {
      final meta = {'scale': 1000.0, 'trim_b': 1.0, 'sense': 1};
      final s = BrewLogSample.fromRow(
        [1200, 973, 912, 125, 5000, 5000, 1],
        scaleMeta: meta,
      );
      expect(s.hxA, 5000);
      expect(s.hxB, 5000);
      expect(s.weightG, closeTo(10.0, 1e-9));
      expect(s.pumpOn, isTrue);
    });
  });

  group('BrewLog.fromJson', () {
    test('parses full export-like map', () {
      final json = {
        'id': 7,
        'sample_hz': 10,
        'duration_ms': 1500,
        'truncated': false,
        'scale_at_end_g': 36.2,
        'samples': [
          [0, 900, 100, 0, 0, 0],
          [100, 901, 200, 50, 10, 1],
        ],
        'events': [
          ['session_start', 0],
          ['pump_on', 50],
        ],
      };
      final log = BrewLog.fromJson(json);
      expect(log.id, 7);
      expect(log.samples.length, 2);
      expect(log.events.length, 2);
      expect(log.events.first.name, 'session_start');
      expect(log.samples[1].pumpOn, isTrue);
    });
  });

  group('BrewLogAssembler multipack', () {
    late BrewLogAssembler asm;

    setUp(() => asm = BrewLogAssembler());

    Map<String, dynamic> fakeExport({int nSamples = 95, int id = 3}) {
      final samples = <List<dynamic>>[];
      for (var i = 0; i < nSamples; i++) {
        // v3: [t, T10, P100, F100, hxA_raw, hxB_raw, W×10, flags]
        samples.add([
          i * 100,
          900 + i,
          800,
          100,
          1000000 + i,
          400000 + i,
          i,
          i.isEven ? 1 : 0,
        ]);
      }
      return {
        'id': id,
        'v': 3,
        'sample_hz': 10,
        'duration_ms': (nSamples - 1) * 100,
        'truncated': false,
        'scale_at_end_g': 40.0,
        'scale_meta': {'scale': 2175.0, 'trim_b': 1.05, 'sense': 1},
        'samples': samples,
        'events': [
          ['session_start', 0],
          ['pump_on', 100],
          ['post_start', 5000],
          ['session_end', (nSamples - 1) * 100],
        ],
      };
    }

    test('roundtrip buildBrewLogParts → assemble', () {
      final export = fakeExport(nSamples: 95);
      final parts = buildBrewLogParts(export, chunkRows: 40);
      // meta + 3 sample parts (40+40+15) + end
      expect(parts.length, 5);
      expect(parts.first['part'], 'meta');
      expect(parts.last['part'], 'end');

      BrewLog? done;
      for (final p in parts) {
        final r = asm.add(Map<String, dynamic>.from(p));
        if (r.hasCompleted) done = r.completed;
      }
      expect(done, isNotNull);
      expect(done!.samples.length, 95);
      expect(done.events.length, 4);
      expect(done.scaleAtEndG, 40.0);
      expect(done.durationMs, 9400);
      expect(done.samples.first.tMs, 0);
      expect(done.samples.last.tMs, 9400);
      // v3: raw HX preserved; weight from row (not reconstruct)
      expect(done.samples.first.hxA, 1000000);
      expect(done.samples.last.hxA, 1000000 + 94);
      expect(done.samples[10].weightG, closeTo(1.0, 1e-9));
      expect(done.schemaVersion, 3);
    });

    test('rejects end-only empty log', () {
      final r = asm.add({
        'type': 'brew_log',
        'part': 'end',
        'id': 1,
        'n_samples': 100,
      });
      expect(r.hasCompleted, isFalse);
      expect(r.rejectReason, isNotNull);
    });

    test('rejects empty samples when meta promised n>0', () {
      asm.add({
        'type': 'brew_log',
        'part': 'meta',
        'id': 2,
        'n_samples': 50,
        'n_parts': 1,
        'events': [
          ['session_start', 0]
        ],
        'scale_at_end_g': 1.0,
        'sample_hz': 10,
        'duration_ms': 0,
        'truncated': false,
      });
      // empty rows part
      asm.add({
        'type': 'brew_log',
        'part': 'samples',
        'id': 2,
        'i': 0,
        'of': 1,
        'rows': <dynamic>[],
      });
      final r = asm.add({
        'type': 'brew_log',
        'part': 'end',
        'id': 2,
        'n_samples': 50,
      });
      expect(r.hasCompleted, isFalse);
    });

    test('legacy body with samples completes', () {
      final r = asm.add({
        'type': 'brew_log',
        'part': 'body',
        'id': 9,
        'sample_hz': 10,
        'duration_ms': 100,
        'scale_at_end_g': 5.0,
        'truncated': false,
        'samples': [
          [0, 900, 100, 0, 0, 0],
          [100, 910, 200, 10, 5, 1],
        ],
        'events': [
          ['session_start', 0]
        ],
      });
      expect(r.hasCompleted, isTrue);
      expect(r.completed!.samples.length, 2);
    });

    test('legacy empty body rejected', () {
      final r = asm.add({
        'type': 'brew_log',
        'part': 'body',
        'id': 1,
        'samples': <dynamic>[],
        'events': <dynamic>[],
      });
      expect(r.hasCompleted, isFalse);
      expect(r.rejectReason, 'empty_legacy_body');
    });

    test('shuffled sample parts still merge in order', () {
      final export = fakeExport(nSamples: 50, id: 11);
      final parts = buildBrewLogParts(export, chunkRows: 20);
      // meta, s0, s1, s2, end — feed meta, then s1, s0, s2, end
      final reordered = [
        parts[0],
        parts[2],
        parts[1],
        parts[3],
        parts[4],
      ];
      BrewLog? done;
      for (final p in reordered) {
        final r = asm.add(Map<String, dynamic>.from(p));
        if (r.hasCompleted) done = r.completed;
      }
      expect(done, isNotNull);
      expect(done!.samples.length, 50);
      // chronological
      for (var i = 1; i < done.samples.length; i++) {
        expect(done.samples[i].tMs, greaterThan(done.samples[i - 1].tMs));
      }
    });
  });

  group('Permanent JSONL shape', () {
    test('row matches expected schema', () async {
      final log = BrewLog.fromJson({
        'id': 1,
        'sample_hz': 10,
        'duration_ms': 500,
        'truncated': false,
        'scale_at_end_g': 12.0,
        'samples': [
          [0, 900, 100, 0, 0, 0],
          [100, 901, 200, 50, 10, 1],
        ],
        'events': [
          ['session_start', 0]
        ],
      });

      final dir = await Directory.systemTemp.createTemp('brew_log_test_');
      final f = File('${dir.path}/brew_shots.jsonl');
      final row = {
        'saved_at': DateTime.utc(2026, 8, 7, 16, 52, 19).toIso8601String(),
        'actual_weight_g': 4.6,
        'satisfaction_level': 3,
        'satisfaction_emoji': '🙂',
        'device_log': log.toJson(),
      };
      await f.writeAsString('${jsonEncode(row)}\n');

      final decoded = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      expect(decoded['actual_weight_g'], 4.6);
      expect(decoded['satisfaction_level'], 3);
      expect(decoded['satisfaction_emoji'], '🙂');
      expect(decoded['saved_at'], isNotEmpty);
      final device = decoded['device_log'] as Map<String, dynamic>;
      expect(device['n_samples'], 2);
      expect(device['samples'], isA<List>());
      expect((device['samples'] as List).length, 2);
      expect(device['events'], isNotEmpty);

      // Must NOT look like the broken empty entry
      expect(device['n_samples'], greaterThan(0));
      expect(device['duration_ms'], greaterThan(0));

      await dir.delete(recursive: true);
    });
  });

  group('Golden non-empty entry fixture', () {
    test('saved entry with data is valid for AI pipeline', () {
      final entry = {
        'saved_at': '2026-08-07T16:52:19.512656Z',
        'actual_weight_g': 36.5,
        'device_log': {
          'id': 2,
          'sample_hz': 10,
          'duration_ms': 13500,
          'truncated': false,
          'scale_at_end_g': 35.8,
          'n_samples': 3,
          'n_events': 3,
          'samples': [
            {
              't_ms': 0,
              'temp_c': 92.0,
              'press_bar': 1.5,
              'flow_g_s': 0.0,
              'weight_g': 0.0,
              'pump_on': true,
              'heater_on': false,
            },
            {
              't_ms': 5000,
              'temp_c': 93.1,
              'press_bar': 9.0,
              'flow_g_s': 1.2,
              'weight_g': 18.0,
              'pump_on': true,
              'heater_on': true,
            },
            {
              't_ms': 13500,
              'temp_c': 92.5,
              'press_bar': 0.4,
              'flow_g_s': 0.0,
              'weight_g': 35.8,
              'pump_on': false,
              'heater_on': false,
            },
          ],
          'events': [
            {'name': 'session_start', 't_ms': 0},
            {'name': 'pump_off', 't_ms': 10000},
            {'name': 'session_end', 't_ms': 13500},
          ],
        },
      };

      expect(entry['actual_weight_g'], greaterThan(0));
      final d = entry['device_log'] as Map;
      expect(d['n_samples'], greaterThan(0));
      expect((d['samples'] as List).length, d['n_samples']);
      expect((d['events'] as List).isNotEmpty, isTrue);
    });
  });
}
