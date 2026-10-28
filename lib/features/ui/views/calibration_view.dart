// ============================================================================
// calibration_view.dart — scale quick fix + full dual-cell wizard
// ============================================================================
//
// Design (phone-driven, Pico does the math):
//
// QUICK CORRECTION
//   1) Tray on, nothing else on scale
//   2) User enters true mass of a known object (g)
//   3) App sends cal:quick:<g> → Pico tares, then waits for a stable load
//   4) When stable, Pico sets scale = counts/known_g and saves scale_cal.json
//
// FULL PROGRAM (same physics as scale_calibration.py)
//   empty tare → corner mass LEFT → same mass RIGHT (trim_b)
//   → empty tray centered (scale factor, default tray mass 454.5 g)
//   User taps Next after each placement; Pico measures on Next.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug_log.dart';
import '../../../core/providers.dart';

class CalibrationView extends ConsumerStatefulWidget {
  const CalibrationView({super.key});

  @override
  ConsumerState<CalibrationView> createState() => _CalibrationViewState();
}

class _CalibrationViewState extends ConsumerState<CalibrationView> {
  final _massCtrl = TextEditingController(text: '100');
  StreamSubscription? _sub;

  String _phase = 'idle';
  String _msg = '';
  String _err = '';
  double _liveW = 0;
  double _liveAbs = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(machineLinkProvider);
    _sub = repo.dataStream.listen((json) {
      if (!mounted) return;
      setState(() {
        if (json.containsKey('cal_phase')) {
          _phase = json['cal_phase']?.toString() ?? _phase;
        }
        if (json.containsKey('cal_msg')) {
          _msg = json['cal_msg']?.toString() ?? _msg;
        }
        if (json.containsKey('cal_err')) {
          _err = json['cal_err']?.toString() ?? _err;
        }
        if (json.containsKey('weight_g')) {
          _liveW = (json['weight_g'] as num?)?.toDouble() ?? _liveW;
        }
        if (json.containsKey('weight_abs_g')) {
          _liveAbs = (json['weight_abs_g'] as num?)?.toDouble() ?? _liveAbs;
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _massCtrl.dispose();
    super.dispose();
  }

  void _cmd(String c) {
    DLog.ui('cal cmd $c');
    ref.read(bleNotifierProvider.notifier).sendCommand(c);
  }

  Future<void> _startQuick() async {
    final connected = ref.read(bleNotifierProvider);
    if (!connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect Bluetooth first')),
      );
      return;
    }
    final m = double.tryParse(_massCtrl.text.replaceAll(',', '.'));
    if (m == null || m < 5 || m > 5000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter mass between 5 and 5000 g')),
      );
      return;
    }
    setState(() => _busy = true);
    _cmd('cal:quick:${m.toStringAsFixed(1)}');
    setState(() => _busy = false);
  }

  void _startFull() {
    if (!ref.read(bleNotifierProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect Bluetooth first')),
      );
      return;
    }
    _cmd('cal:full:start');
  }

  void _next() => _cmd('cal:next');
  void _cancel() => _cmd('cal:cancel');

  bool get _inProgress =>
      _phase != 'idle' &&
      _phase != 'quick_done' &&
      _phase != 'full_done' &&
      _phase != 'error' &&
      _phase.isNotEmpty;

  bool get _canNext =>
      _phase == 'full_empty' ||
      _phase == 'full_left_ready' ||
      _phase == 'full_right_ready' ||
      _phase == 'full_tray_ready' ||
      _phase == 'quick_done' ||
      _phase == 'full_done' ||
      _phase == 'error';

  String get _fullHint {
    switch (_phase) {
      case 'full_empty':
        return 'Remove everything from the platform (no tray).';
      case 'full_tare_run':
        return 'Measuring empty zero…';
      case 'full_left_ready':
        return 'Place the CORNER weight (~118 g) on the LEFT load cell only.';
      case 'full_left_measure':
        return 'Measuring left…';
      case 'full_right_ready':
        return 'Move the same weight onto the RIGHT load cell only.';
      case 'full_right_measure':
        return 'Measuring right…';
      case 'full_tray_ready':
        return 'Remove corner weight. Place EMPTY tray centered (ref ~454.5 g).';
      case 'full_tray_measure':
        return 'Measuring tray…';
      case 'full_done':
        return 'Full calibration finished and saved on Pico.';
      default:
        return _msg.isNotEmpty ? _msg : 'Follow steps, tap Next when ready.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(bleNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scale calibration'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (_inProgress) _cancel();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Icon(Icons.bluetooth, color: connected ? Colors.green : Colors.red),
              const SizedBox(width: 8),
              Text(connected ? 'Linked to Pico' : 'Not connected'),
              const Spacer(),
              Text('W ${_liveW.toStringAsFixed(1)} g',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Abs ${_liveAbs.toStringAsFixed(1)} g · phase: $_phase',
              style: Theme.of(context).textTheme.bodySmall),
          if (_msg.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_msg, style: const TextStyle(color: Colors.lightBlueAccent)),
          ],
          if (_err.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_err, style: const TextStyle(color: Colors.redAccent)),
          ],
          const Divider(height: 32),

          // ---- Quick correction ----
          Text('Quick correction', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Tray on the scale. Enter the true mass of an object, start, '
            'then place that object on the tray. Pico tares first, waits for a '
            'stable reading, and adjusts the scale factor (counts/g).',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _massCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Known mass (g)',
              border: OutlineInputBorder(),
              suffixText: 'g',
            ),
            enabled: !_inProgress || _phase.startsWith('quick'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (_inProgress && !_phase.startsWith('quick')) ? null : _startQuick,
            icon: const Icon(Icons.tune),
            label: Text(_busy ? 'Starting…' : 'Start quick correction'),
          ),

          const Divider(height: 40),

          // ---- Full program ----
          Text('Full calibration', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(_fullHint),
          const SizedBox(height: 8),
          const Text(
            'Balances left/right cells (trim) then sets counts/g from empty tray. '
            'Use the same corner weight for both sides. Default tray mass 454.5 g '
            '(same as on-device cal).',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _inProgress ? null : _startFull,
                  child: const Text('Start full program'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _canNext ? _next : null,
                  child: Text(
                    (_phase == 'quick_done' ||
                            _phase == 'full_done' ||
                            _phase == 'error')
                        ? 'Done'
                        : 'Next',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _inProgress || _phase == 'error' ? _cancel : null,
            child: const Text('Cancel calibration'),
          ),
        ],
      ),
    );
  }
}
