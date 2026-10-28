import 'package:flutter_test/flutter_test.dart';
import 'package:silvia_pico_ui/features/data/live_stale_policy.dart';

void main() {
  late LiveStalePolicy p;
  late DateTime t0;

  setUp(() {
    p = LiveStalePolicy(
      softReleaseTimeout: const Duration(seconds: 4),
      brewingTimeout: const Duration(seconds: 12),
    );
    t0 = DateTime.utc(2026, 8, 10, 14, 0, 0);
  });

  test('IDLE never forced idle', () {
    expect(
      p.shouldForceIdle(
        brewMode: 'IDLE',
        lastLiveAt: t0,
        now: t0.add(const Duration(minutes: 5)),
      ),
      isFalse,
    );
  });

  test('SOFT_RELEASE forces idle after 4s without live', () {
    expect(
      p.shouldForceIdle(
        brewMode: 'SOFT_RELEASE',
        lastLiveAt: t0,
        now: t0.add(const Duration(seconds: 3)),
      ),
      isFalse,
    );
    expect(
      p.shouldForceIdle(
        brewMode: 'SOFT_RELEASE',
        lastLiveAt: t0,
        now: t0.add(const Duration(seconds: 4)),
      ),
      isTrue,
    );
  });

  test('BREW tolerates longer gap than SOFT_RELEASE', () {
    expect(
      p.shouldForceIdle(
        brewMode: 'BREW',
        lastLiveAt: t0,
        now: t0.add(const Duration(seconds: 5)),
      ),
      isFalse,
    );
    expect(
      p.shouldForceIdle(
        brewMode: 'BREW',
        lastLiveAt: t0,
        now: t0.add(const Duration(seconds: 12)),
      ),
      isTrue,
    );
  });

  test('null lastLiveAt never forces', () {
    expect(
      p.shouldForceIdle(
        brewMode: 'SOFT_RELEASE',
        lastLiveAt: null,
        now: t0.add(const Duration(minutes: 1)),
      ),
      isFalse,
    );
  });

  test('PRE_INFUSION uses brewing timeout', () {
    expect(
      p.shouldForceIdle(
        brewMode: 'PRE_INFUSION',
        lastLiveAt: t0,
        now: t0.add(const Duration(seconds: 11)),
      ),
      isFalse,
    );
    expect(
      p.shouldForceIdle(
        brewMode: 'PRE_INFUSION',
        lastLiveAt: t0,
        now: t0.add(const Duration(seconds: 12)),
      ),
      isTrue,
    );
  });
}
