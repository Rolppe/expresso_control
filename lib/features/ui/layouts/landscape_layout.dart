import '../../../core/providers.dart';
// ============================================================================
// landscape_layout.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/machine_data_notifier.dart';
import '../../ble/ble_notifier.dart';
import '../widgets/graph_widget.dart';
import '../../link/link_selector.dart';

// ============================================================================
// LANDSCAPE LAYOUT
// ============================================================================

class LandscapeLayout extends ConsumerWidget {
  const LandscapeLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(machineDataProvider);
    final connected = ref.watch(bleNotifierProvider);
    final wifiActive = ref.watch(
        linkStatusProvider.select((s) => s.active == LinkKind.wifi));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        data.firstDrop
                            ? (data.firstDropTime != null
                                ? '💧 DROP ${data.firstDropTime}s'
                                : '💧 DROP')
                            : (data.brewMode != 'IDLE' ? 'WAIT DROP' : 'DROP —'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: data.firstDrop
                              ? Colors.greenAccent
                              : (data.brewMode != 'IDLE'
                                  ? Colors.amberAccent
                                  : Colors.grey.withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Labels match slider titles (default body text)
                    // scaleDown: on iPhone landscape the column is narrower than the word.
                    const FittedBox(fit: BoxFit.scaleDown, child: Text('Temperature')),
                    Text('${data.boilerTemperature.toStringAsFixed(1)}°C',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    // Pico standby (VALMIUSTILA): IDLE target lowered after the idle timeout.
                    if (data.standby)
                      const Text('STANDBY',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text('Pressure (bar)'),
                    Text('${data.boilerPressure.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text('Flow'),
                    Text(
                      '${data.flowGs.toStringAsFixed(1)} g/s',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.tealAccent,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text('Weight'),
                    Text(
                      data.trayPresent
                          ? '${data.weightG.toStringAsFixed(1)} g'
                          : 'No tray',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: data.trayPresent ? Colors.green : Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text('Pump ratio'),
                    Text('${data.pumpRatio.toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text('Brew Timer'),
                    Text('${data.brewTimer} s',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontFamilyFallback: ['Menlo', 'Courier'], color: Colors.orange)),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  data.standby ? Icons.wb_sunny_rounded : Icons.bedtime_rounded,
                  color: data.standby ? Colors.amberAccent : Colors.purpleAccent,
                  size: 26,
                ),
                tooltip: data.standby ? 'Herätä lepotilasta' : 'Siirry lepotilaan',
                onPressed: connected
                    ? () => data.standby
                        ? ref.read(machineDataProvider.notifier).wakeFromStandby()
                        : ref.read(machineDataProvider.notifier).enterStandby()
                    : null,
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  wifiActive ? Icons.wifi : Icons.bluetooth,
                  color: connected ? Colors.green : Colors.red,
                  size: 28,
                ),
                tooltip: connected ? 'Connected' : 'Disconnected — tap to scan',
                onPressed: () => ref.read(bleNotifierProvider.notifier).startScan(),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => data.isGraphPaused
                    ? ref.read(machineDataProvider.notifier).resetGraphForNewSession()
                    : ref.read(machineDataProvider.notifier).pauseGraph(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: Text(data.isGraphPaused ? 'Draw Graph' : 'Freeze Graph'),
              ),
            ],
          ),
          // Comfortable gap under status row; graph takes all remaining height
          const SizedBox(height: 16),
          Expanded(
            child: GraphWidget(
              temperatureData: data.temperatureData,
              pressureData: data.pressureData,
              currentTime: data.currentTime,
            ),
          ),
        ],
      ),
    );
  }
}
