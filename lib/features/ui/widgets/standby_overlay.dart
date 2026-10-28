// ============================================================================
// standby_overlay.dart — Standby screen when machine is in idle standby
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../models/machine_status.dart';
import '../../ble/ble_notifier.dart';
import '../../link/link_selector.dart';
import '../views/settings_view.dart';

class StandbyOverlay extends ConsumerWidget {
  final MachineStatus data;
  final VoidCallback? onClose;

  const StandbyOverlay({super.key, required this.data, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(linkStatusProvider);
    final wifiActive = link.active == LinkKind.wifi;
    final connected = wifiActive ? link.wifiConnected : link.bleConnected;

    return Container(
      color: Colors.black.withValues(alpha: 0.90),
      child: SafeArea(
        child: Column(
          children: [
            // Top action bar: connection status + settings + close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      wifiActive ? Icons.wifi : Icons.bluetooth,
                      color: connected ? Colors.green : Colors.red,
                      size: 26,
                    ),
                    tooltip: connected ? 'Connected' : 'Disconnected — tap to scan',
                    onPressed: () =>
                        ref.read(bleNotifierProvider.notifier).startScan(),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.settings, size: 26, color: Colors.white70),
                        tooltip: 'Asetukset',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SettingsView(),
                            ),
                          );
                        },
                      ),
                      if (onClose != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          key: const Key('standby_overlay_close_button'),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                            shape: const CircleBorder(),
                          ),
                          icon: const Icon(Icons.close, size: 24, color: Colors.white),
                          tooltip: 'Sulje lepotilanäkymä',
                          onPressed: onClose,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Centered standby content
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.purpleAccent.withValues(alpha: 0.15),
                            border: Border.all(
                              color: Colors.purpleAccent.withValues(alpha: 0.4),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.bedtime_rounded,
                            size: 64,
                            color: Colors.purpleAccent,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Keitin on lepotilassa',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          child: Text(
                            'Kattilan lämpötila: ${data.boilerTemperature.toStringAsFixed(1)} °C',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          icon: const Icon(Icons.wb_sunny_rounded, size: 24),
                          label: const Text(
                            'Herätä lepotilasta',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => ref
                              .read(machineDataProvider.notifier)
                              .wakeFromStandby(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
