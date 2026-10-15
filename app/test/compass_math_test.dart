import 'package:flutter_test/flutter_test.dart';
import 'package:shia_ai/astro/compass_math.dart';

/// The compass behaviour that is easy to get wrong on a phone: the north seam,
/// the alignment thresholds, and the direction of the "turn this way" hint.
void main() {
  group('heading filter', () {
    test('the first reading is taken as-is', () {
      final filter = HeadingFilter();
      expect(filter.isPrimed, isFalse);
      expect(filter.prime(255), 255);
      expect(filter.isPrimed, isTrue);
      expect(filter.heading, 255);
    });

    test('smooths a jittery signal without ever oscillating', () {
      final filter = HeadingFilter(smoothing: 0.25)..prime(100);
      double previous = filter.heading;
      for (final reading in <double>[104, 96, 103, 97, 102, 98, 101, 99]) {
        final next = filter.add(reading);
        // Never jumps the whole way to the reading, and never runs away.
        expect((next - previous).abs(), lessThanOrEqualTo(4.0));
        previous = next;
      }
      expect(filter.heading, closeTo(100, 6));
    });

    test('crosses north without snapping backwards through 180°', () {
      final filter = HeadingFilter(smoothing: 0.5)..prime(358);
      final steps = <double>[
        filter.add(1),
        filter.add(4),
        filter.add(2),
        filter.add(0),
      ];
      // Every step stays near the seam: 358 → 359 → 1 → 3 → 2, never 358 → 180.
      for (final heading in steps) {
        expect(heading > 340 || heading < 20, isTrue, reason: 'heading $heading');
      }
      expect(steps.last, lessThan(20));
    });

    test('unwraps the angle for a rotation tween', () {
      final filter = HeadingFilter(smoothing: 0.4)..prime(350);
      filter.add(5);
      filter.add(10);
      // The continuous value passes through 360 rather than jumping to 0,
      // which is what keeps the animated rose from spinning the long way.
      expect(filter.continuousHeading, greaterThan(350));
      expect(filter.heading, lessThan(20));
    });

    test('shortestTurn always picks the near side of the circle', () {
      expect(HeadingFilter.shortestTurn(0, 10), closeTo(10, 1e-9));
      expect(HeadingFilter.shortestTurn(10, 0), closeTo(-10, 1e-9));
      expect(HeadingFilter.shortestTurn(350, 10), closeTo(20, 1e-9));
      expect(HeadingFilter.shortestTurn(10, 350), closeTo(-20, 1e-9));
      expect(HeadingFilter.shortestTurn(0, 180), closeTo(180, 1e-9));
    });
  });

  group('alignment', () {
    CompassReading reading(double heading, {double bearing = 255.9}) => CompassReading(
          qiblaBearing: bearing,
          heading: heading,
          hasHeading: true,
        );

    test('aligned within five degrees', () {
      expect(reading(255.9).alignment, CompassAlignment.aligned);
      expect(reading(251).alignment, CompassAlignment.aligned);
      expect(reading(260.5).alignment, CompassAlignment.aligned);
      // Across north: 2° off the bearing is still aligned.
      final north = CompassReading(qiblaBearing: 2, heading: 358, hasHeading: true);
      expect(north.alignment, CompassAlignment.aligned);
    });

    test('close within eighteen degrees, otherwise off', () {
      expect(reading(266).alignment, CompassAlignment.close);
      expect(reading(270).alignment, CompassAlignment.close);
      expect(reading(285).alignment, CompassAlignment.off);
    });

    test('without a heading it is never aligned', () {
      const none = CompassReading(qiblaBearing: 255.9, heading: 255.9, hasHeading: false);
      expect(none.alignment, CompassAlignment.off);
    });

    test('the hint points the right way, and stays short', () {
      expect(reading(255.9).instructionUrdu, 'قبلہ کی طرف رخ ہے');
      // Bearing is 255.9 and the phone points at 240: turn clockwise (right).
      expect(reading(240).instructionUrdu, 'تھوڑا دائیں گھمائیں');
      expect(reading(272).instructionUrdu, 'تھوڑا بائیں گھمائیں');
      expect(reading(180).instructionUrdu, 'دائیں گھمائیں');
      expect(reading(330).instructionUrdu, 'بائیں گھمائیں');
    });

    test('the needle angle is the signed turn', () {
      expect(reading(255.9).needleAngle, closeTo(0, 0.001));
      expect(reading(240).needleAngle, closeTo(15.9, 0.001));
      expect(reading(300).needleAngle, closeTo(-44.1, 0.001));
      // Signed the short way when the turn crosses the north seam.
      expect(
        CompassReading(qiblaBearing: 5, heading: 355, hasHeading: true).needleAngle,
        closeTo(10, 0.001),
      );
    });
  });

  group('needle transition and helpers', () {
    test('a big jump gets a longer tween than a small one', () {
      expect(needleTransition(0, 0.5).inMilliseconds, lessThan(needleTransition(0, 20).inMilliseconds));
      expect(needleTransition(0, 120).inMilliseconds, greaterThanOrEqualTo(300));
    });

    test('degrees are normalised, however they arrive', () {
      expect(normalizeDegrees(-10), 350);
      expect(normalizeDegrees(370), 10);
      expect(normalizeDegrees(0), 0);
    });

    test('flatness falls away as the phone tilts', () {
      expect(flatnessFromPitch(0), closeTo(1, 1e-9));
      expect(flatnessFromPitch(60), closeTo(0.5, 1e-9));
      expect(flatnessFromPitch(-60), closeTo(0.5, 1e-9));
    });

    test('the Urdu rose has eight points starting at north', () {
      expect(kCompassPointsUrdu.length, 8);
      expect(kCompassPointsUrdu.first, 'شمال');
      expect(compassPointUrdu(180), 'جنوب');
    });
  });
}
