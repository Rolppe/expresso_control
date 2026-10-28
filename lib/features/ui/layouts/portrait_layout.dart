// ============================================================================
// portrait_layout.dart — values + controls only (graph is landscape-only)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/safe_bouncing_scroll_physics.dart';
import '../widgets/value_display.dart';
import '../widgets/controls_widget.dart';

// ============================================================================
// PORTRAIT LAYOUT
// ============================================================================

class PortraitLayout extends ConsumerWidget {
  const PortraitLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: SafeBouncingScrollPhysics(),
              ),
              child: Column(
                children: const [
                  ValueDisplay(),
                  SizedBox(height: 24),
                  ControlsWidget(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
