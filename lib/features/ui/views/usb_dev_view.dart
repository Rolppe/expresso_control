// ============================================================================
// usb_dev_view.dart — Dev USB: Pico serial, bridge, flash (+ battery guard)
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../usb/pico_usb_channel.dart';

class UsbDevView extends StatefulWidget {
  const UsbDevView({super.key});

  @override
  State<UsbDevView> createState() => _UsbDevViewState();
}

class _UsbDevViewState extends State<UsbDevView> {
  final _log = StringBuffer();
  final _scroll = ScrollController();
  StreamSubscription? _sub;
  Timer? _batTimer;
  List<PicoUsbDevice> _devices = [];
  bool _open = false;
  bool _bridge = false;
  bool _busy = false;
  String _status = '';
  Map<String, dynamic> _battery = const {};

  int get _level => (_battery['level'] as num?)?.toInt() ?? -1;
  bool get _charging => _battery['charging'] == true;
  int get _minFlash => (_battery['minFlashPct'] as num?)?.toInt() ?? 20;
  int get _warnPct => (_battery['warnPct'] as num?)?.toInt() ?? 30;
  bool get _batteryLow => _level >= 0 && _level < _warnPct && !_charging;
  bool get _batteryBlocksFlash =>
      _level >= 0 && _level < _minFlash && !_charging;

  @override
  void initState() {
    super.initState();
    _sub = PicoUsbChannel.events.listen((ev) {
      final t = ev['type'];
      if (t == 'data') {
        final b64 = ev['b64'] as String? ?? '';
        try {
          final s = utf8.decode(base64Decode(b64), allowMalformed: true);
          _append(s);
        } catch (_) {}
      } else if (t == 'error') {
        _append('\n[USB error] ${ev['message']}\n');
      } else if (t == 'closed') {
        _append('\n[USB closed]\n');
        setState(() => _open = false);
      }
    });
    _refresh();
    _batTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshBattery());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _batTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _append(String s) {
    setState(() {
      _log.write(s);
      if (_log.length > 40000) {
        final t = _log.toString();
        _log
          ..clear()
          ..write(t.substring(t.length - 30000));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _refreshBattery() async {
    final b = await PicoUsbChannel.batteryStatus();
    if (!mounted) return;
    setState(() => _battery = b);
  }

  Future<void> _refresh() async {
    final d = await PicoUsbChannel.listDevices();
    final o = await PicoUsbChannel.isOpen();
    final b = await PicoUsbChannel.bridgeStatus();
    final bat = await PicoUsbChannel.batteryStatus();
    setState(() {
      _devices = d;
      _open = o;
      _bridge = b['running'] == true;
      _battery = bat;
      final lvl = bat['level'];
      final ch = bat['charging'] == true ? 'charging' : 'NOT charging';
      _status =
          'devices=${d.length} open=$o bridge=${b['running']} | battery=$lvl% ($ch)';
    });
  }

  Future<void> _openUsb() async {
    setState(() => _busy = true);
    if (_batteryLow) {
      _append(
        '\n[WARN] Battery $_level% and not charging. '
        'OTG powers Pico from phone — use powered hub or separate 5 V for Pico.\n',
      );
    }
    final ok = await PicoUsbChannel.openFirst();
    _append(ok ? '\n[USB open]\n' : '\n[USB open failed — grant permission?]\n');
    await _refresh();
    setState(() => _busy = false);
  }

  Future<void> _closeUsb() async {
    await PicoUsbChannel.stopBridge();
    await PicoUsbChannel.close();
    _append('\n[USB closed — phone no longer sourcing OTG power]\n');
    await _refresh();
  }

  Future<void> _toggleBridge() async {
    setState(() => _busy = true);
    if (_bridge) {
      await PicoUsbChannel.stopBridge();
      _append('\n[bridge stop]\n');
    } else {
      final ok = await PicoUsbChannel.startBridge(port: 2217);
      _append(ok
          ? '\n[bridge ON :2217 — mpremote connect rfc2217://PHONE_IP:2217]\n'
          : '\n[bridge failed — open USB first]\n');
    }
    await _refresh();
    setState(() => _busy = false);
  }

  Future<void> _flash() async {
    await _refreshBattery();
    var force = false;
    if (_batteryBlocksFlash) {
      final go = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Battery low ($_level%)'),
          content: Text(
            'Phone is not charging while OTG-hosting Pico. '
            'Flash blocked below $_minFlash%.\n\n'
            'Prefer: powered USB-C hub (charge + OTG) or Pico on separate 5 V.\n\n'
            'Force flash only if you accept shutdown risk.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'force'), child: const Text('Force flash')),
          ],
        ),
      );
      if (go != 'force') return;
      force = true;
    } else {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Flash Pico core?'),
          content: Text(
            'Writes main.py, brew_logger.py, bluetooth_handler.py, classes.py '
            'from app firmware/ over USB, then soft-resets.\n\n'
            'Battery: $_level%${_charging ? " (charging)" : " (not charging — OTG drains phone)"}.\n'
            'Use only when idle (not brewing).',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Flash')),
          ],
        ),
      );
      if (go != true) return;
    }
    setState(() => _busy = true);
    _append('\n[flash start force=$force…]\n');
    try {
      final r = await PicoUsbChannel.flashFromAppFiles(force: force);
      _append('[flash] ${r['message']} ok=${r['ok']}\n');
    } catch (e) {
      _append('[flash error] $e\n');
    }
    await _refresh();
    setState(() => _busy = false);
  }

  Future<void> _restore() async {
    final backups = await PicoUsbChannel.listBackups();
    if (!mounted) return;
    if (backups.isEmpty) {
      _append('\n[restore] no backups in files/firmware_backup\n');
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Restore Pico backup'),
        children: [
          for (final b in backups.reversed)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, b), child: Text(b)),
        ],
      ),
    );
    if (name == null || !mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restore $name?'),
        content: const Text(
          'UNPLUG THE MACHINE FROM MAINS FIRST.\n\n'
          'Stopping the firmware can leave the heater relay ON. '
          'Relays are forced OFF right after the interrupt, then every file of the backup '
          'is written (SHA-256 checked) and the Pico soft-resets.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Machine unplugged — restore'),
          ),
        ],
      ),
    );
    if (go != true) return;
    setState(() => _busy = true);
    _append('\n[restore $name…]\n');
    try {
      final r = await PicoUsbChannel.restoreBackup(name);
      _append('[restore] ${r['message']} ok=${r['ok']}\n');
    } catch (e) {
      _append('[restore error] $e\n');
    }
    await _refresh();
    setState(() => _busy = false);
  }

  Color get _batColor {
    if (_level < 0) return Colors.grey;
    if (_charging) return Colors.green;
    if (_level < _minFlash) return Colors.red;
    if (_level < _warnPct) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    if (!PicoUsbChannel.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('USB Pico (dev)')),
        body: const Center(child: Text('USB host only on Android')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('USB Pico (dev)'),
        actions: [
          IconButton(onPressed: _busy ? null : _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_batteryLow || _batteryBlocksFlash)
            MaterialBanner(
              content: Text(
                _batteryBlocksFlash
                    ? 'Battery $_level% — not charging. OTG powers Pico from phone. '
                        'Flash blocked until ≥$_minFlash% or charge (powered hub).'
                    : 'Battery $_level% — not charging under OTG. Prefer powered hub / Pico 5 V.',
              ),
              backgroundColor: _batColor.withValues(alpha: 0.25),
              actions: [
                TextButton(onPressed: _refreshBattery, child: const Text('Refresh')),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.battery_std, color: _batColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _status,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          if (_devices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('No USB serial device — plug Pico via OTG (or powered hub)'),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_devices.map((d) => d.toString()).join('\n')),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy || _open ? null : _openUsb,
                  child: const Text('Open USB'),
                ),
                OutlinedButton(
                  onPressed: _busy || !_open ? null : _closeUsb,
                  child: const Text('Close'),
                ),
                FilledButton.tonal(
                  onPressed: _busy || !_open ? null : _toggleBridge,
                  child: Text(_bridge ? 'Stop bridge' : 'Start bridge :2217'),
                ),
                FilledButton(
                  onPressed: _busy || !_open ? null : _flash,
                  child: Text(
                    _batteryBlocksFlash ? 'Flash (blocked/force)' : 'Flash core',
                  ),
                ),
                OutlinedButton(
                  onPressed: _busy || !_open ? null : _restore,
                  child: const Text('Restore backup'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                controller: _scroll,
                child: Text(
                  _log.isEmpty ? 'Serial log…' : _log.toString(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
