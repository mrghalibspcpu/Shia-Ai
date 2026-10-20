import 'dart:math' as math;

// Compass maths for the Qibla screen: smoothing, alignment, and the needle
// angle. Pure functions so the behaviour can be tested without a magnetometer.

/// How well the phone is pointing at the Kaaba.
enum CompassAlignment {
  /// Within the tolerance — the "Aligned / Calibrated" state.
  aligned,

  /// A few degrees off, close enough to steer with.
  close,

  /// Pointing somewhere else entirely.
  off,
}

/// A low-pass filter for a heading that is measured in circles.
///
/// A raw magnetometer reading jitters by several degrees between events, which
/// a naive `0.2 * new + 0.8 * old` makes worse at the 359°→0° seam, where the
/// averaged value snaps the needle through a full turn. This filter keeps an
/// unwrapped (continuous) angle and only ever moves it by the short way round,
/// so the needle is smooth *and* correct across north.
class HeadingFilter {
  HeadingFilter({this.smoothing = 0.16});

  /// 0 = never move, 1 = follow the sensor exactly.
  final double smoothing;

  double _continuous = 0;
  bool _primed = false;

  /// The filtered heading, 0–360.
  double get heading => _wrap(_continuous);

  /// The same angle *unwrapped*: it may read 370° or −10°, which is exactly
  /// what an animated rotation needs. Feeding a 0–360 value to a tween makes
  /// the rose spin the long way round every time the heading crosses north.
  double get continuousHeading => _continuous;

  bool get isPrimed => _primed;

  /// Seeds the filter without any smoothing (first reading wins outright).
  double prime(double raw) {
    _continuous = _wrap(raw);
    _primed = true;
    return heading;
  }

  /// Feeds one reading in and returns the filtered heading.
  double add(double raw) {
    if (!_primed) return prime(raw);
    final target = _wrap(raw);
    final delta = shortestTurn(heading, target);
    _continuous += delta * smoothing;
    return heading;
  }

  static double _wrap(double degrees) => ((degrees % 360.0) + 360.0) % 360.0;

  /// Signed shortest turn from [from] to [to], in −180…180.
  static double shortestTurn(double from, double to) {
    var delta = (to - from) % 360.0;
    if (delta > 180.0) delta -= 360.0;
    if (delta < -180.0) delta += 360.0;
    return delta;
  }
}

/// Everything the Qibla card draws, derived from a heading and a bearing.
class CompassReading {
  const CompassReading({
    required this.qiblaBearing,
    required this.heading,
    required this.hasHeading,
  });

  /// Degrees from true north to the Kaaba (the formula in
  /// `prayer_calculator.dart`).
  final double qiblaBearing;

  /// Where the top of the phone points, 0–360 from magnetic north (the rose is
  /// drawn rotated by this, which is what makes it read as *true* north once
  /// the phone's declination has been handled by the platform).
  final double heading;

  /// False while the sensor has not reported yet.
  final bool hasHeading;

  /// How far the phone has to turn to face the Kaaba: positive is clockwise
  /// (turn right), negative is anticlockwise. This is also the angle the Qibla
  /// needle is drawn at inside the rose.
  double get turn => HeadingFilter.shortestTurn(heading, qiblaBearing);

  /// Rotation for the Qibla needle inside the rose (alias of [turn], named for
  /// what it means where it is used).
  double get needleAngle => turn;

  CompassAlignment get alignment {
    if (!hasHeading) return CompassAlignment.off;
    final delta = turn.abs();
    if (delta <= 5.0) return CompassAlignment.aligned;
    if (delta <= 18.0) return CompassAlignment.close;
    return CompassAlignment.off;
  }

  /// Which way to turn, in words.
  String get instructionUrdu => switch (alignment) {
        CompassAlignment.aligned => 'قبلہ کی طرف رخ ہے',
        CompassAlignment.close => turn > 0 ? 'تھوڑا دائیں گھمائیں' : 'تھوڑا بائیں گھمائیں',
        _ => turn > 0 ? 'دائیں گھمائیں' : 'بائیں گھمائیں',
      };
}

/// The rose is drawn as an arc rather than a jump: a CSS-style transition on
/// the needle only looks right if it never takes the long way round.
Duration needleTransition(double from, double to) {
  final delta = HeadingFilter.shortestTurn(from, to).abs();
  if (delta < 1) return const Duration(milliseconds: 140);
  if (delta < 30) return const Duration(milliseconds: 220);
  return const Duration(milliseconds: 320);
}

/// Clamps a degree value into 0–360 (used by the rose painting).
double normalizeDegrees(double degrees) => ((degrees % 360.0) + 360.0) % 360.0;

/// The eight compass points in Urdu, indexed from north.
const List<String> kCompassPointsUrdu = <String>[
  'شمال',
  'شمال مشرق',
  'مشرق',
  'جنوب مشرق',
  'جنوب',
  'جنوب مغرب',
  'مغرب',
  'شمال مغرب',
];

/// Urdu compass point for any heading.
String compassPointUrdu(double degrees) {
  final index = (normalizeDegrees(degrees) / 45.0).round() % kCompassPointsUrdu.length;
  return kCompassPointsUrdu[index];
}

/// The cosine of the tilt, used to tell the reader to lay the phone flat: a
/// compass card is only trustworthy while the phone is close to horizontal.
double flatnessFromPitch(double pitchDegrees) =>
    math.cos(pitchDegrees.abs() * math.pi / 180.0);
