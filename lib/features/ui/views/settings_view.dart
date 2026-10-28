// ============================================================================
// settings_view.dart — Scale calibration + Brew logs entry points
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/keep_screen_on.dart';
import '../../../core/standby_timeout.dart';
import 'calibration_view.dart';
import 'pressure_calibration_view.dart';
import 'brew_logs_list_view.dart';
import 'usb_dev_view.dart';
import '../../usb/pico_usb_channel.dart';
import '../widgets/link_settings.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keepScreenOn = ref.watch(keepScreenOnProvider);
    final standbyStartupMin = ref.watch(standbyStartupTimeoutProvider);
    final standbyBrewMin = ref.watch(standbyBrewTimeoutProvider);
    final standbyTemp = ref.watch(standbyTemperatureProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pidä näyttö päällä'),
            subtitle: const Text('Näyttö ei sammu, kun äppi on auki'),
            value: keepScreenOn,
            onChanged: (v) =>
                ref.read(keepScreenOnProvider.notifier).set(v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Valmiustila käynnistyksen jälkeen'),
            subtitle: const Text('Aika käynnistyksestä lepotilaan ilman uuttoa tai höyrytystä (1 h – 4 h)'),
            trailing: DropdownButton<int>(
              value: standbyStartupMin,
              items: [
                for (final m in standbyStartupTimeoutChoices)
                  DropdownMenuItem<int>(
                    value: m,
                    child: Text(standbyTimeoutLabel(m)),
                  ),
              ],
              onChanged: (m) {
                if (m != null) ref.read(standbyStartupTimeoutProvider.notifier).set(m);
              },
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Valmiustila uuton tai höyrytyksen jälkeen'),
            subtitle: const Text('Aika uuton tai höyrytyksen päättymisestä lepotilaan (15 min – 2 h)'),
            trailing: DropdownButton<int>(
              value: standbyBrewMin,
              items: [
                for (final m in standbyBrewTimeoutChoices)
                  DropdownMenuItem<int>(
                    value: m,
                    child: Text(standbyTimeoutLabel(m)),
                  ),
              ],
              onChanged: (m) {
                if (m != null) ref.read(standbyBrewTimeoutProvider.notifier).set(m);
              },
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Valmiustilan lämpötila'),
            subtitle: const Text('Kattilan lämpötila valmiustilassa (enintään uuttolämpötila)'),
            trailing: DropdownButton<int>(
              value: standbyTemp,
              items: [
                for (final c in standbyTemperatureChoices)
                  DropdownMenuItem<int>(
                    value: c,
                    child: Text('$c °C'),
                  ),
              ],
              onChanged: (c) {
                if (c != null) ref.read(standbyTemperatureProvider.notifier).set(c);
              },
            ),
          ),
          const LinkSettings(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.scale),
              label: const Text('Scale calibration'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CalibrationView(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.speed),
              label: const Text('Pressure calibration'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PressureCalibrationView(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.list_alt),
              label: const Text('Brew logs'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BrewLogsListView(),
                  ),
                );
              },
            ),
          ),
          // USB host is Android-only; on iOS the page would be a dead end.
          if (PicoUsbChannel.isAndroid) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.usb),
                label: const Text('USB Pico (dev)'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const UsbDevView(),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
