// ============================================================================
// safe_bouncing_scroll_physics.dart
// ============================================================================

import 'package:flutter/material.dart';

/// Scroll physics that provides iOS-like edge bouncing without the aggressive
/// rebound effect that overshoots the content boundary when flinging fast.
///
/// When the user flings or drags past an edge, it allows normal overscroll
/// ("jousto"), but as the spring pulls the content back to the boundary,
/// it smoothly clamps at the edge (min/max scroll extent) and stops cleanly,
/// rather than penetrating back into the content and scrolling in the wrong
/// direction.
class SafeBouncingScrollPhysics extends BouncingScrollPhysics {
  const SafeBouncingScrollPhysics({
    super.parent,
    super.decelerationRate = ScrollDecelerationRate.normal,
  });

  @override
  SafeBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SafeBouncingScrollPhysics(
      parent: buildParent(ancestor),
      decelerationRate: decelerationRate,
    );
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final Tolerance tolerance = toleranceFor(position);
    if (velocity.abs() >= tolerance.velocity || position.outOfRange) {
      return SafeBouncingScrollSimulation(
        position: position.pixels,
        velocity: velocity,
        leadingExtent: position.minScrollExtent,
        trailingExtent: position.maxScrollExtent,
        spring: spring,
        tolerance: tolerance,
        constantDeceleration: switch (decelerationRate) {
          ScrollDecelerationRate.fast => 1400,
          ScrollDecelerationRate.normal => 0,
        },
      );
    }
    return null;
  }
}

class SafeBouncingScrollSimulation extends Simulation {
  SafeBouncingScrollSimulation({
    required double position,
    required double velocity,
    required this.leadingExtent,
    required this.trailingExtent,
    required this.spring,
    double constantDeceleration = 0,
    Tolerance tolerance = Tolerance.defaultTolerance,
  }) : super(tolerance: tolerance) {
    // When already out of bounds, any velocity aimed back towards the boundary
    // adds excessive momentum to the spring, causing it to overshoot past the
    // boundary into the viewport. Clamp it so the spring pulls back smoothly.
    double effectiveVelocity = velocity;
    if (position < leadingExtent && velocity > 0) {
      effectiveVelocity = 0.0;
    } else if (position > trailingExtent && velocity < 0) {
      effectiveVelocity = 0.0;
    }

    _inner = BouncingScrollSimulation(
      position: position,
      velocity: effectiveVelocity,
      leadingExtent: leadingExtent,
      trailingExtent: trailingExtent,
      spring: spring,
      tolerance: tolerance,
      constantDeceleration: constantDeceleration,
    );
  }

  final double leadingExtent;
  final double trailingExtent;
  final SpringDescription spring;
  late final BouncingScrollSimulation _inner;

  bool _underscrolled = false;
  bool _overscrolled = false;
  bool _settled = false;

  @override
  double x(double time) {
    if (_settled) {
      if (_underscrolled) return leadingExtent;
      if (_overscrolled) return trailingExtent;
    }

    final double val = _inner.x(time);

    if (val < leadingExtent) {
      _underscrolled = true;
    }
    if (val > trailingExtent) {
      _overscrolled = true;
    }

    // Settled at leadingExtent (top edge)
    if (_underscrolled && val >= leadingExtent - tolerance.distance) {
      _settled = true;
      return leadingExtent;
    }

    // Settled at trailingExtent (bottom edge)
    if (_overscrolled && val <= trailingExtent + tolerance.distance) {
      _settled = true;
      return trailingExtent;
    }

    return val;
  }

  @override
  double dx(double time) {
    if (_settled) return 0.0;
    return _inner.dx(time);
  }

  @override
  bool isDone(double time) {
    if (_settled) return true;
    return _inner.isDone(time);
  }
}
