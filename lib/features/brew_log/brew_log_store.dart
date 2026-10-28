// ============================================================================
// brew_log_store.dart — permanent JSONL shot archive
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../../core/debug_log.dart';
import '../../models/brew_log.dart';

/// Four satisfaction levels shown in the post-shot prompt (emoji + rank 1–4).
class BrewSatisfaction {
  static const levels = <({int level, String emoji, String label})>[
    (level: 1, emoji: '😞', label: 'Huono'),
    (level: 2, emoji: '😐', label: 'OK'),
    (level: 3, emoji: '🙂', label: 'Hyvä'),
    (level: 4, emoji: '😄', label: 'Erinomaista'),
  ];

  static String emojiFor(int? level) {
    if (level == null) return '';
    for (final l in levels) {
      if (l.level == level) return l.emoji;
    }
    return '';
  }
}

/// One permanent row in brew_shots.jsonl
class BrewLogEntry {
  final int index; // 0-based line index in file
  final DateTime savedAt;
  final double actualWeightG;
  /// 1–4 satisfaction, null if older entry without rating
  final int? satisfactionLevel;
  final String? satisfactionEmoji;
  final BrewLog deviceLog;
  final Map<String, dynamic> raw;

  const BrewLogEntry({
    required this.index,
    required this.savedAt,
    required this.actualWeightG,
    this.satisfactionLevel,
    this.satisfactionEmoji,
    required this.deviceLog,
    required this.raw,
  });

  String get titleTimestamp {
    final l = savedAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} '
        '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }

  String get subtitle {
    final dur = (deviceLog.durationMs / 1000).toStringAsFixed(1);
    final sat = satisfactionEmoji != null && satisfactionEmoji!.isNotEmpty
        ? ' · $satisfactionEmoji'
        : ' · ei tyytyväisyyttä';
    return '${actualWeightG.toStringAsFixed(1)} g · ${dur}s · '
        '${deviceLog.samples.length} samples$sat';
  }

  bool get hasSatisfaction =>
      satisfactionLevel != null && satisfactionLevel! >= 1;
}

class BrewLogStore {
  static const _fileName = 'brew_shots.jsonl';
  /// Incomplete shot waiting for user actual weight (survives lock/kill).
  static const _pendingFileName = 'pending_brew_log.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/$_fileName');
    if (!await f.exists()) {
      await f.create(recursive: true);
    }
    return f;
  }

  Future<File> _pendingFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_pendingFileName');
  }

  /// Persist pending device log until user saves weight or dismisses.
  Future<void> savePending(BrewLog log) async {
    final f = await _pendingFile();
    await f.writeAsString(jsonEncode({
      'received_at': DateTime.now().toUtc().toIso8601String(),
      'device_log': log.toJson(),
    }));
    DLog.ui('brew log pending saved id=${log.id} n=${log.samples.length}');
  }

  Future<BrewLog?> loadPending() async {
    final f = await _pendingFile();
    if (!await f.exists()) return null;
    try {
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final device =
          Map<String, dynamic>.from(map['device_log'] as Map? ?? {});
      final log = BrewLog.fromJson(device);
      if (log.samples.isEmpty) {
        await clearPending();
        return null;
      }
      return log;
    } catch (e) {
      DLog.ui('brew log pending load fail: $e');
      return null;
    }
  }

  Future<void> clearPending() async {
    final f = await _pendingFile();
    if (await f.exists()) {
      await f.delete();
      DLog.ui('brew log pending cleared');
    }
  }

  /// Append one permanent row (weight required; satisfaction optional).
  Future<void> append({
    required BrewLog log,
    required double actualWeightG,
    int? satisfactionLevel,
    String? satisfactionEmoji,
  }) async {
    final row = <String, dynamic>{
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'actual_weight_g': actualWeightG,
      'device_log': log.toJson(),
    };
    if (satisfactionLevel != null && satisfactionLevel >= 1) {
      final level = satisfactionLevel.clamp(1, 4);
      final emoji = (satisfactionEmoji != null && satisfactionEmoji.isNotEmpty)
          ? satisfactionEmoji
          : BrewSatisfaction.emojiFor(level);
      row['satisfaction_level'] = level;
      row['satisfaction_emoji'] = emoji;
    }
    final f = await _file();
    await f.writeAsString('${jsonEncode(row)}\n', mode: FileMode.append);
    DLog.ui(
      'brew log saved id=${log.id} actual=${actualWeightG}g '
      'sat=${row['satisfaction_level'] ?? 'none'} path=${f.path}',
    );
  }

  /// Update satisfaction on an existing JSONL line (add later from Brew logs).
  Future<void> updateSatisfactionAt({
    required int lineIndex,
    required int satisfactionLevel,
    String? satisfactionEmoji,
  }) async {
    final level = satisfactionLevel.clamp(1, 4);
    final emoji = (satisfactionEmoji != null && satisfactionEmoji.isNotEmpty)
        ? satisfactionEmoji
        : BrewSatisfaction.emojiFor(level);
    final f = await _file();
    if (!await f.exists()) return;
    final lines = await f.readAsLines();
    if (lineIndex < 0 || lineIndex >= lines.length) return;
    final line = lines[lineIndex].trim();
    if (line.isEmpty) return;
    try {
      final map = jsonDecode(line) as Map<String, dynamic>;
      map['satisfaction_level'] = level;
      map['satisfaction_emoji'] = emoji;
      lines[lineIndex] = jsonEncode(map);
      await f.writeAsString('${lines.where((l) => l.trim().isNotEmpty).join('\n')}\n');
      DLog.ui('brew log sat updated line=$lineIndex level=$level$emoji');
    } catch (e) {
      DLog.ui('brew log sat update fail line=$lineIndex: $e');
      rethrow;
    }
  }

  /// All entries, newest first.
  Future<List<BrewLogEntry>> loadAll() async {
    final f = await _file();
    if (!await f.exists()) return const [];
    final lines = await f.readAsLines();
    final out = <BrewLogEntry>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      try {
        final map = jsonDecode(line) as Map<String, dynamic>;
        final savedRaw = map['saved_at'] as String? ?? '';
        final savedAt = DateTime.tryParse(savedRaw)?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final deviceMap =
            Map<String, dynamic>.from(map['device_log'] as Map? ?? {});
        final satLevel = (map['satisfaction_level'] as num?)?.toInt();
        final satEmoji = map['satisfaction_emoji'] as String? ??
            BrewSatisfaction.emojiFor(satLevel);
        out.add(
          BrewLogEntry(
            index: i,
            savedAt: savedAt,
            actualWeightG: (map['actual_weight_g'] as num?)?.toDouble() ?? 0,
            satisfactionLevel: satLevel,
            satisfactionEmoji: satEmoji.isEmpty ? null : satEmoji,
            deviceLog: BrewLog.fromJson(deviceMap),
            raw: map,
          ),
        );
      } catch (e) {
        DLog.ui('brew log skip line $i: $e');
      }
    }
    // Newest first for the list UI
    return out.reversed.toList();
  }

  /// Delete by original line index; rewrites the JSONL file.
  Future<void> deleteAt(int lineIndex) async {
    final f = await _file();
    if (!await f.exists()) return;
    final lines = await f.readAsLines();
    if (lineIndex < 0 || lineIndex >= lines.length) return;
    final kept = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (i == lineIndex) continue;
      final t = lines[i].trim();
      if (t.isEmpty) continue;
      kept.add(lines[i].endsWith('\n') ? lines[i].trimRight() : lines[i]);
    }
    await f.writeAsString(
      kept.isEmpty ? '' : '${kept.join('\n')}\n',
    );
    DLog.ui('brew log deleted line=$lineIndex remaining=${kept.length}');
  }
}
