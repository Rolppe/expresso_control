import '../../../core/providers.dart';
// ============================================================================
// value_display.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../views/settings_view.dart';
import '../../link/link_selector.dart';
import 'tare_button.dart';

// ============================================================================
// VALUE DISPLAY WIDGET
// ============================================================================

class ValueDisplay extends ConsumerWidget {
  const ValueDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(machineDataProvider);
    final connected = ref.watch(bleNotifierProvider);
    final wifiActive = ref.watch(
        linkStatusProvider.select((s) => s.active == LinkKind.wifi));

    return Column(
      children: [
        // Top row: Standby button on left, BT centered, settings gear on the right
        SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(
                    Icons.bedtime_rounded,
                    color: Colors.purpleAccent,
                    size: 26,
                  ),
                  tooltip: 'Siirry lepotilaan',
                  onPressed: connected
                      ? () => ref.read(machineDataProvider.notifier).enterStandby()
                      : null,
                ),
              ),
              IconButton(
                icon: Icon(
                  wifiActive ? Icons.wifi : Icons.bluetooth,
                  color: connected ? Colors.green : Colors.red,
                  size: 28,
                ),
                tooltip: connected ? 'Connected' : 'Disconnected — tap to scan',
                onPressed: () =>
                    ref.read(bleNotifierProvider.notifier).startScan(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.settings, size: 28),
                  tooltip: 'Settings',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsView(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        _ValueRow(
          label: 'First drop',
          value: data.firstDrop
              ? (data.firstDropTime != null
                  ? '💧 DETECTED (${data.firstDropTime} s)'
                  : '💧 DETECTED')
              : (data.brewMode != 'IDLE' ? 'Waiting...' : '—'),
          color: data.firstDrop
              ? Colors.greenAccent
              : (data.brewMode != 'IDLE' ? Colors.amberAccent : Colors.grey),
        ),
        _ValueRow(label: 'Temperature', value: '${data.boilerTemperature.toStringAsFixed(1)}°C', color: Colors.red),
        _ValueRow(label: 'Pressure', value: '${data.boilerPressure.toStringAsFixed(1)} bar', color: Colors.blue),
        _ValueRow(
          label: 'Mode',
          value: data.standby ? '${data.brewMode} · STANDBY' : data.brewMode,
          color: Colors.purpleAccent,
        ),
        _ValueRow(label: 'Pump ratio', value: '${data.pumpRatio.toStringAsFixed(1)}%', color: Colors.cyan),
        _ValueRow(label: 'Brew Timer', value: '${data.brewTimer} s', color: Colors.orange),
        _ValueRow(
          label: 'Flow',
          value: '${data.flowGs.toStringAsFixed(1)} g/s',
          color: Colors.tealAccent,
        ),
        // Weight: label + value same row; Tare button alone on next row
        // Font size matches Fast heatup (ListTile title = titleMedium)
        Builder(
          builder: (context) {
            final titleStyle = Theme.of(context).textTheme.titleMedium;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Weight', style: titleStyle),
                      Text(
                        data.trayPresent
                            ? '${data.weightG.toStringAsFixed(1)} g'
                            : 'No tray',
                        style: titleStyle?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: data.trayPresent
                              ? Colors.green
                              : Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TareButton(enabled: data.trayPresent),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ValueRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Match SwitchListTile "Fast heatup" title size (titleMedium)
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: titleStyle),
          Text(
            value,
            style: titleStyle?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
