// ============================================================================
// brew_logs_list_view.dart — list saved shots, swipe-to-delete, open detail
// ============================================================================

import 'package:flutter/material.dart';
import '../../brew_log/brew_log_store.dart';
import 'brew_log_detail_view.dart';

class BrewLogsListView extends StatefulWidget {
  const BrewLogsListView({super.key});

  @override
  State<BrewLogsListView> createState() => _BrewLogsListViewState();
}

class _BrewLogsListViewState extends State<BrewLogsListView> {
  final _store = BrewLogStore();
  late Future<List<BrewLogEntry>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _store.loadAll();
  }

  Future<void> _delete(BrewLogEntry e) async {
    await _store.deleteAt(e.index);
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _pickSatisfaction(BrewLogEntry e) async {
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
                  e.hasSatisfaction
                      ? 'Vaihda tyytyväisyys'
                      : 'Lisää tyytyväisyys',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  e.titleTimestamp,
                  style: Theme.of(ctx).textTheme.bodySmall,
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
                            border: Border.all(
                              color: e.satisfactionLevel == s.level
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Colors.white24,
                              width: e.satisfactionLevel == s.level ? 2 : 1,
                            ),
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
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Peruuta'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (level == null || !mounted) return;
    await _store.updateSatisfactionAt(
      lineIndex: e.index,
      satisfactionLevel: level,
    );
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tyytyväisyys tallennettu ${BrewSatisfaction.emojiFor(level)}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Brew logs'),
      ),
      body: FutureBuilder<List<BrewLogEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const <BrewLogEntry>[];
          if (items.isEmpty) {
            return const Center(
              child: Text('No saved brew logs yet'),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = items[i];
              return Dismissible(
                key: ValueKey('brew-${e.index}-${e.savedAt.toIso8601String()}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  color: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
                confirmDismiss: (dir) async => true,
                onDismissed: (_) => _delete(e),
                child: ListTile(
                  title: Text(
                    e.titleTimestamp,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(e.subtitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: e.hasSatisfaction
                            ? 'Vaihda tyytyväisyys'
                            : 'Lisää tyytyväisyys',
                        icon: Text(
                          e.hasSatisfaction
                              ? (e.satisfactionEmoji ?? '🙂')
                              : '＋',
                          style: const TextStyle(fontSize: 22),
                        ),
                        onPressed: () => _pickSatisfaction(e),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BrewLogDetailView(entry: e),
                      ),
                    );
                    if (mounted) setState(_reload);
                  },
                  onLongPress: () => _pickSatisfaction(e),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
