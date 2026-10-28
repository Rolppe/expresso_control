// ============================================================================
// link_settings.dart — "Yhteys" setting, link status line and Wi-Fi key field
// ============================================================================
// Yhteys: Automaattinen / Wi-Fi / Bluetooth (provider linkModeProvider).
// The key normally arrives over BLE by itself; the hidden field is for the
// simulator (no BLE) and troubleshooting. The key is never shown or logged.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../link/link_selector.dart';
import '../../link/wifi_key_store.dart';

String linkModeLabel(LinkMode m) {
  switch (m) {
    case LinkMode.auto:
      return 'Automaattinen';
    case LinkMode.wifi:
      return 'Wi-Fi';
    case LinkMode.ble:
      return 'Bluetooth';
  }
}

/// "Aktiivinen: Wi-Fi (yhdistetty) · Pico boot 12ab · viimeisin paketti 0.4 s sitten"
String linkStatusLine(LinkStatus s, DateTime now) {
  final active = s.active == LinkKind.wifi ? 'Wi-Fi' : 'Bluetooth';
  final up = s.active == LinkKind.wifi ? s.wifiConnected : s.bleConnected;
  final parts = <String>['Aktiivinen: $active (${up ? 'yhdistetty' : 'ei yhteyttä'})'];
  if (!s.hasKey) {
    parts.add('Wi-Fi-avain puuttuu');
  } else {
    parts.add('Pico boot ${s.bootId ?? '-'}');
    final t = s.lastPacketAt;
    parts.add(t == null
        ? 'ei paketteja'
        : 'viimeisin paketti ${(now.difference(t).inMilliseconds / 1000).toStringAsFixed(1)} s sitten');
  }
  return parts.join(' · ');
}

class LinkSettings extends ConsumerStatefulWidget {
  const LinkSettings({super.key});

  @override
  ConsumerState<LinkSettings> createState() => _LinkSettingsState();
}

class _LinkSettingsState extends ConsumerState<LinkSettings> {
  final _keyCtrl = TextEditingController();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // the status line is read, not watched: packets arrive 5 times a second
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    final text = _keyCtrl.text.trim().toLowerCase();
    final messenger = ScaffoldMessenger.of(context);
    if (decodeWifiKey(text) == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Virheellinen avain (64 heksamerkkiä)')),
      );
      return;
    }
    final store = ref.read(wifiKeyStoreProvider);
    final old = await store.load();
    await store.save(WifiLinkConfig(
      keyHex: text,
      host: old?.host ?? wifiDefaultHost,
      port: old?.port ?? wifiDefaultPort,
    ));
    _keyCtrl.clear();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    messenger.showSnackBar(const SnackBar(content: Text('Wi-Fi-avain tallennettu')));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(linkModeProvider);
    final status = ref.read(machineLinkProvider).status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Yhteys'),
          subtitle: Text(linkStatusLine(status, DateTime.now())),
          trailing: DropdownButton<LinkMode>(
            value: mode,
            items: [
              for (final m in LinkMode.values)
                DropdownMenuItem<LinkMode>(
                  value: m,
                  child: Text(linkModeLabel(m)),
                ),
            ],
            onChanged: (m) {
              if (m != null) ref.read(linkModeProvider.notifier).set(m);
            },
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _keyCtrl,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                onSubmitted: (_) => _saveKey(),
                decoration: InputDecoration(
                  labelText: 'Wi-Fi-avain',
                  helperText: status.hasKey
                      ? 'Avain tallennettu'
                      : 'Haetaan automaattisesti Bluetoothilla',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Tallenna Wi-Fi-avain',
              onPressed: _saveKey,
            ),
          ],
        ),
      ],
    );
  }
}
