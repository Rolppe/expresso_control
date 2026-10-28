// ============================================================================
// tare_button.dart — Tare with red (busy) → green (done 1s) → default
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug_log.dart';
import '../../../core/providers.dart';
import '../../data/machine_data_notifier.dart';

enum _TareVisual { idle, busy, done }

/// Press → red immediately; when tare finishes → green 1 s → normal.
class TareButton extends ConsumerStatefulWidget {
  const TareButton({super.key, this.enabled = true});

  final bool enabled;

  @override
  ConsumerState<TareButton> createState() => _TareButtonState();
}

class _TareButtonState extends ConsumerState<TareButton> {
  _TareVisual _visual = _TareVisual.idle;
  Timer? _doneTimer;
  Timer? _fallbackTimer;
  ProviderSubscription<double>? _weightSub;
  double? _weightAtPress;
  bool _awaitingZero = false;

  @override
  void dispose() {
    _doneTimer?.cancel();
    _fallbackTimer?.cancel();
    _weightSub?.close();
    super.dispose();
  }

  void _setVisual(_TareVisual v) {
    if (!mounted) return;
    setState(() => _visual = v);
  }

  void _markDone() {
    if (_visual != _TareVisual.busy) return;
    _fallbackTimer?.cancel();
    _weightSub?.close();
    _weightSub = null;
    _awaitingZero = false;
    _setVisual(_TareVisual.done);
    DLog.ui('Tare visual DONE (green)');
    _doneTimer?.cancel();
    _doneTimer = Timer(const Duration(seconds: 1), () {
      _setVisual(_TareVisual.idle);
    });
  }

  void _onPressed() {
    if (!widget.enabled || _visual == _TareVisual.busy) return;

    final connected = ref.read(bleNotifierProvider);
    if (!connected) return;

    DLog.ui('Tare pressed');
    _setVisual(_TareVisual.busy);
    _weightAtPress = ref.read(machineDataProvider).weightG;
    _awaitingZero = true;

    ref.read(machineDataProvider.notifier).onManualTare();
    ref.read(bleNotifierProvider.notifier).sendCommand('tare');

    // Watch weight: after tare, reading settles near 0
    _weightSub?.close();
    _weightSub = ref.listenManual<double>(
      machineDataProvider.select((s) => s.weightG),
      (prev, next) {
        if (!_awaitingZero) return;
        // Pico tare finished → weight near zero (or jumped toward 0)
        if (next.abs() < 1.5) {
          _markDone();
        } else if (_weightAtPress != null &&
            (next - _weightAtPress!).abs() > 5 &&
            next.abs() < _weightAtPress!.abs()) {
          // moved clearly toward lighter / zero
          if (next.abs() < 3.0) _markDone();
        }
      },
    );

    // Fallback if weight already ~0 or BLE slow (tare ~0.5–2 s on Pico)
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(milliseconds: 1800), _markDone);
  }

  Color? get _bg {
    switch (_visual) {
      case _TareVisual.busy:
        return Colors.red;
      case _TareVisual.done:
        return Colors.green;
      case _TareVisual.idle:
        return null;
    }
  }

  Color? get _fg {
    switch (_visual) {
      case _TareVisual.busy:
      case _TareVisual.done:
        return Colors.white;
      case _TareVisual.idle:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPress = widget.enabled &&
        ref.watch(bleNotifierProvider) &&
        _visual != _TareVisual.busy;

    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        backgroundColor: _bg,
        foregroundColor: _fg,
      ),
      onPressed: canPress ? _onPressed : null,
      child: const Text('Tare'),
    );
  }
}
