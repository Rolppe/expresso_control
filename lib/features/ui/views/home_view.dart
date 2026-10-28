// ============================================================================
// home_view.dart
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug_log.dart';
import '../../../core/providers.dart';
import '../../brew_log/brew_log_notifier.dart';
import '../../brew_log/brew_log_store.dart';
import '../layouts/portrait_layout.dart';
import '../layouts/landscape_layout.dart';
import '../widgets/standby_overlay.dart';

// ============================================================================
// HOME VIEW
// ============================================================================

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> with WidgetsBindingObserver {
  final _weightCtrl = TextEditingController();
  bool _dialogOpen = false;
  bool _standbyDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // If pending was restored / completed before listen registered, open sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(brewLogProvider);
      if (s.showPrompt && s.pending != null && !_dialogOpen) {
        DLog.ui('HomeView first frame: open pending weight sheet');
        unawaited(_promptActualWeight());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resume (e.g. from lock-screen notification or switching back):
    // If machine is in standby, present overlay again.
    if (state == AppLifecycleState.resumed) {
      if (_standbyDismissed && mounted) {
        setState(() {
          _standbyDismissed = false;
        });
      }
      unawaited(ref.read(brewLogProvider.notifier).onAppResumed());
    }
  }

  Future<void> _promptActualWeight() async {
    if (_dialogOpen || !mounted) return;
    final pending = ref.read(brewLogProvider).pending;
    if (pending == null) return;

    _dialogOpen = true;
    final prefill = pending.scaleAtEndG > 0.5
        ? pending.scaleAtEndG.toStringAsFixed(1)
        : '';
    _weightCtrl.text = prefill;

    // Only the input sheet — no red/orange banners. Scrim is solid black.
    // Satisfaction is optional (can be added later in Brew logs).
    final result = await showModalBottomSheet<({double weight, int? level, String? emoji})?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.grey.shade900,
      barrierColor: Colors.black,
      builder: (ctx) {
        int? selectedLevel;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Uutto tallennettu',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Syötä toteutunut paino (g).\n'
                    'Tyytyväisyys on valinnainen — voit lisätä sen myöhemmin Brew logsissa.\n'
                    'Kesto ${(pending.durationMs / 1000).toStringAsFixed(1)} s · '
                    '${pending.samples.length} näytettä'
                    '${pending.truncated ? ' · katkaistu' : ''}',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _weightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Todellinen paino (g)',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tyytyväisyys (valinnainen)',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final s in BrewSatisfaction.levels)
                        _SatChip(
                          emoji: s.emoji,
                          label: s.label,
                          selected: selectedLevel == s.level,
                          onTap: () => setSheet(() {
                            // Tap again to clear optional selection
                            selectedLevel =
                                selectedLevel == s.level ? null : s.level;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(null),
                        child: const Text('Ohita'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          final raw =
                              _weightCtrl.text.trim().replaceAll(',', '.');
                          final v = double.tryParse(raw);
                          if (v == null || v <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Anna kelvollinen paino'),
                              ),
                            );
                            return;
                          }
                          final emoji = selectedLevel == null
                              ? null
                              : BrewSatisfaction.emojiFor(selectedLevel);
                          Navigator.of(ctx).pop((
                            weight: v,
                            level: selectedLevel,
                            emoji: emoji,
                          ));
                        },
                        child: const Text('Tallenna'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    _dialogOpen = false;
    if (!mounted) return;

    if (result != null) {
      await ref.read(brewLogProvider.notifier).saveWithActualWeight(
            actualG: result.weight,
            satisfactionLevel: result.level,
            satisfactionEmoji: result.emoji,
          );
    } else {
      await ref.read(brewLogProvider.notifier).dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-open weight sheet whenever a new prompt is requested.
    ref.listen(brewLogProvider, (prev, next) {
      if (next.showPrompt &&
          next.pending != null &&
          next.openRequestId > (prev?.openRequestId ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _promptActualWeight();
        });
      }
    });

    final machineData = ref.watch(machineDataProvider);

    ref.listen<bool>(
      machineDataProvider.select((s) => s.standby),
      (prev, next) {
        if (next && prev == false) {
          setState(() {
            _standbyDismissed = false;
          });
        }
      },
    );

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isPortrait = constraints.maxWidth < constraints.maxHeight;
                return isPortrait
                    ? const PortraitLayout()
                    : const LandscapeLayout();
              },
            ),
            if (machineData.standby && !_standbyDismissed)
              Positioned.fill(
                child: StandbyOverlay(
                  data: machineData,
                  onClose: () {
                    setState(() {
                      _standbyDismissed = true;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SatChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SatChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
        : Border.all(color: Colors.white24);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: border,
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              : null,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
