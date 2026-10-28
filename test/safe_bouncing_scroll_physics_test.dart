import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:silvia_pico_ui/core/safe_bouncing_scroll_physics.dart';

void main() {
  group('SafeBouncingScrollPhysics tests', () {
    test('settles smoothly at leadingExtent when flinging past top boundary without rebound into content', () {
      final sim = SafeBouncingScrollSimulation(
        position: -50,
        velocity: 3000,
        leadingExtent: 0,
        trailingExtent: 500,
        spring: const SpringDescription(mass: 0.5, stiffness: 100.0, damping: 15.556),
        tolerance: const Tolerance(distance: 0.5, velocity: 10.0),
      );

      double maxReached = -50;
      for (double t = 0.0; t <= 1.5; t += 0.02) {
        final x = sim.x(t);
        if (x > maxReached) maxReached = x;
        if (sim.isDone(t)) break;
      }

      // Must never overshoot past leadingExtent (0.0) into positive content territory
      expect(maxReached, lessThanOrEqualTo(0.001));
    });

    test('settles smoothly at trailingExtent when flinging past bottom boundary without rebound into content', () {
      final sim = SafeBouncingScrollSimulation(
        position: 550,
        velocity: -3000,
        leadingExtent: 0,
        trailingExtent: 500,
        spring: const SpringDescription(mass: 0.5, stiffness: 100.0, damping: 15.556),
        tolerance: const Tolerance(distance: 0.5, velocity: 10.0),
      );

      double minReached = 550;
      for (double t = 0.0; t <= 1.5; t += 0.02) {
        final x = sim.x(t);
        if (x < minReached) minReached = x;
        if (sim.isDone(t)) break;
      }

      // Must never drop below trailingExtent (500) back into content territory
      expect(minReached, greaterThanOrEqualTo(499.99));
    });

    test('content fits on screen (leading == trailing == 0): fling does not oscillate across zero', () {
      final sim = SafeBouncingScrollSimulation(
        position: 0,
        velocity: 3000,
        leadingExtent: 0,
        trailingExtent: 0,
        spring: const SpringDescription(mass: 0.5, stiffness: 100.0, damping: 15.556),
        tolerance: const Tolerance(distance: 0.5, velocity: 10.0),
      );

      double minReached = 0;
      for (double t = 0.0; t <= 1.5; t += 0.02) {
        final x = sim.x(t);
        if (x < minReached) minReached = x;
        if (sim.isDone(t)) break;
      }

      // Overscroll goes positive, but must never swing into negative
      expect(minReached, greaterThanOrEqualTo(-0.001));
    });

    test('normal in-bounds scroll glides and does not trigger early settlement', () {
      final sim = SafeBouncingScrollSimulation(
        position: 100,
        velocity: 500,
        leadingExtent: 0,
        trailingExtent: 500,
        spring: const SpringDescription(mass: 0.5, stiffness: 100.0, damping: 15.556),
        tolerance: const Tolerance(distance: 0.5, velocity: 10.0),
      );

      expect(sim.x(0.2), greaterThan(150.0));
      expect(sim.x(0.5), greaterThan(240.0));
    });
  });
}
