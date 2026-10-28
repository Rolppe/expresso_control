// ============================================================================
// brew_log_detail_view.dart — human-readable full entry
// ============================================================================

import 'package:flutter/material.dart';
import '../../brew_log/brew_log_store.dart';

class BrewLogDetailView extends StatefulWidget {
  final BrewLogEntry entry;

  const BrewLogDetailView({super.key, required this.entry});

  @override
  State<BrewLogDetailView> createState() => _BrewLogDetailViewState();
}

class _BrewLogDetailViewState extends State<BrewLogDetailView> {
  late BrewLogEntry _entry;
  final _store = BrewLogStore();

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  Future<void> _editSatisfaction() async {
    final level = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.grey.shade900,
      barrierColor: Colors.black,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _entry.hasSatisfaction
                      ? 'Vaihda tyytyväisyys'
                      : 'Lisää tyytyväisyys',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final s in BrewSatisfaction.levels)
                      InkWell(
                        onTap: () => Navigator.of(ctx).pop(s.level),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 72,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            children: [
                              Text(s.emoji, style: const TextStyle(fontSize: 28)),
                              const SizedBox(height: 4),
                              Text(s.label, style: Theme.of(ctx).textTheme.labelSmall),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (level == null || !mounted) return;
    await _store.updateSatisfactionAt(
      lineIndex: _entry.index,
      satisfactionLevel: level,
    );
    final emoji = BrewSatisfaction.emojiFor(level);
    setState(() {
      _entry = BrewLogEntry(
        index: _entry.index,
        savedAt: _entry.savedAt,
        actualWeightG: _entry.actualWeightG,
        satisfactionLevel: level,
        satisfactionEmoji: emoji,
        deviceLog: _entry.deviceLog,
        raw: {
          ..._entry.raw,
          'satisfaction_level': level,
          'satisfaction_emoji': emoji,
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final log = _entry.deviceLog;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Brew log'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(theme, 'Summary', [
            _kv('Saved', _entry.titleTimestamp),
            _kv('Actual weight', '${_entry.actualWeightG.toStringAsFixed(1)} g'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      'Satisfaction',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _entry.hasSatisfaction
                          ? '${_entry.satisfactionEmoji ?? ''} '
                              '(level ${_entry.satisfactionLevel})'
                          : '— ei asetettu',
                    ),
                  ),
                  TextButton(
                    onPressed: _editSatisfaction,
                    child: Text(
                      _entry.hasSatisfaction ? 'Vaihda' : 'Lisää',
                    ),
                  ),
                ],
              ),
            ),
            _kv('Session id', '${log.id}'),
            _kv('Duration', '${(log.durationMs / 1000).toStringAsFixed(1)} s'),
            _kv('Samples', '${log.samples.length} @ ${log.sampleHz} Hz'),
            _kv('Events', '${log.events.length}'),
            _kv('Scale at end', '${log.scaleAtEndG.toStringAsFixed(2)} g'),
            _kv('Truncated', log.truncated ? 'yes' : 'no'),
          ]),
          const SizedBox(height: 16),
          _section(theme, 'Events', [
            if (log.events.isEmpty)
              const Text('— none —')
            else
              ...log.events.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${_fmtMs(e.tMs).padRight(8)}  ${e.name}',
                    style: const TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Menlo', 'Courier'], fontSize: 13),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          _section(theme, 'Samples (every point)', [
            if (log.samples.isEmpty)
              const Text('— none —')
            else ...[
              Text(
                log.schemaVersion >= 2
                    ? '   t(s)    T°C     P bar   flow     hxA     hxB   Wg  pu ht'
                    : '  t(s)     T°C    P bar     flow   weight pu ht',
                style: const TextStyle(
                  fontFamily: 'monospace', fontFamilyFallback: ['Menlo', 'Courier'],
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ...log.samples.map((s) {
                final t = (s.tMs / 1000).toStringAsFixed(1).padLeft(6);
                final T = s.tempC.toStringAsFixed(1).padLeft(6);
                final P = s.pressBar.toStringAsFixed(2).padLeft(7);
                final f = s.flowGs.toStringAsFixed(2).padLeft(7);
                final w = s.weightG.toStringAsFixed(1).padLeft(7);
                final pu = s.pumpOn ? ' 1' : ' 0';
                final h = s.heaterOn ? ' 1' : ' 0';
                if (s.hxA != null && s.hxB != null) {
                  final a = s.hxA.toString().padLeft(7);
                  final b = s.hxB.toString().padLeft(7);
                  return Text(
                    '$t  $T  $P  $f $a $b $w$pu$h',
                    style: const TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Menlo', 'Courier'], fontSize: 11),
                  );
                }
                return Text(
                  '$t  $T  $P  $f  $w $pu $h',
                  style: const TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Menlo', 'Courier'], fontSize: 11),
                );
              }),
            ],
          ]),
        ],
      ),
    );
  }

  static String _fmtMs(int ms) {
    final s = ms / 1000.0;
    return '${s.toStringAsFixed(2)}s';
  }

  Widget _section(ThemeData theme, String title, List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
