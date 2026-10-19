import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../app_theme.dart';
import '../astro/compass_math.dart';
import '../astro/prayer_format.dart';
import '../services/alerts.dart';
import '../services/prayer_controller.dart';
import '../services/prayer_scope.dart';
import '../widgets/glass_panel.dart';
import '../widgets/qibla_map_card.dart';
import '../widgets/qibla_street_map.dart';
import '../widgets/section_background.dart';

/// Where the compass is in its life cycle.
enum _CompassStatus {
  /// Subscribed, no reading yet.
  waiting,

  /// A heading is arriving.
  live,

  /// No heading after the grace period — no magnetometer, or the reader said no.
  unavailable,
}

/// Hardware magnetometer Qibla compass: the phone's own heading, the bearing to
/// the Kaaba computed from the coordinates the prayer card uses, and a needle
/// that is aligned/not-aligned instead of a number to interpret.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key, this.autoStartCompass = true});

  /// Off only for a sensor-free preview/test: the bearing and Kaaba marker
  /// must still render even when a device cannot supply a heading.
  final bool autoStartCompass;

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  final HeadingFilter _filter = HeadingFilter(smoothing: 0.18);
  StreamSubscription<CompassEvent>? _subscription;
  Timer? _graceTimer;

  _CompassStatus _status = _CompassStatus.waiting;
  double? _continuousHeading;
  double? _accuracy;
  double _lastPainted = -999;
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    if (!widget.autoStartCompass) {
      _status = _CompassStatus.unavailable;
      return;
    }
    // The location (and therefore the bearing) may still be resolving; when it
    // lands, the dial redraws on its own because the scope notifies.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_enable(silent: true));
    });
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    unawaited(_cancelCompass());
    super.dispose();
  }

  Future<void> _cancelCompass() async {
    final subscription = _subscription;
    _subscription = null;
    if (subscription == null) return;
    try {
      await subscription.cancel();
    } catch (_) {
      // A platform stream may disappear while Android is closing the page;
      // cancellation must never surface as an unhandled UI exception.
    }
  }

  /// Subscribes to the magnetometer (and, on iOS, makes sure the location
  /// permission the platform needs for heading updates has been asked for).
  Future<void> _enable({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      final controller = PrayerScope.read(context);
      if (controller.location.isFallback) {
        unawaited(controller.refreshLocation());
      }
    }
    await _cancelCompass();
    if (!mounted) return;
    final events = FlutterCompass.events;
    if (events == null) {
      setState(() => _status = _CompassStatus.unavailable);
      return;
    }
    setState(() => _status = _CompassStatus.waiting);
    _subscription = events.listen(
      (event) {
        final heading = event.heading;
        if (heading == null) {
          // Android reports null when the device has no usable sensor.
          if (mounted && _status != _CompassStatus.unavailable && !_filter.isPrimed) {
            setState(() => _status = _CompassStatus.unavailable);
          }
          return;
        }
        final smoothed = _filter.isPrimed ? _filter.add(heading) : _filter.prime(heading);
        // Repaint only when it would visibly move, and never more than the
        // sensor's own rate: a setState per raw event would burn the frame
        // budget for a needle nobody can see move.
        final moved = (smoothed - _lastPainted).abs() >= 0.4 ||
            _wheel(smoothed) != _wheel(_lastPainted);
        if (!mounted) return;
        setState(() {
          _continuousHeading = _filter.continuousHeading;
          _accuracy = event.accuracy;
          _status = _CompassStatus.live;
          if (moved) _lastPainted = smoothed;
        });
        _maybeHapticOnAlignment(smoothed);
      },
      onError: (_) {
        if (mounted) setState(() => _status = _CompassStatus.unavailable);
      },
      cancelOnError: false,
    );
    _graceTimer?.cancel();
    _graceTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_status == _CompassStatus.waiting) {
        setState(() => _status = _CompassStatus.unavailable);
      }
    });
  }

  double _wheel(double degrees) => (degrees / 45).roundToDouble();

  void _maybeHapticOnAlignment(double heading) {
    final controller = PrayerScope.maybeOf(context);
    if (controller == null) return;
    final reading = CompassReading(
      qiblaBearing: controller.qiblaBearing,
      heading: heading,
      hasHeading: true,
    );
    final aligned = reading.alignment == CompassAlignment.aligned;
    if (aligned && !_wasAligned) {
      unawaited(Alerts.instance.tapHaptic());
    }
    _wasAligned = aligned;
  }

  @override
  Widget build(BuildContext context) {
    final controller = PrayerScope.of(context);
    final bearing = controller.qiblaBearing;
    final hasHeading = _status == _CompassStatus.live && _continuousHeading != null;
    final reading = CompassReading(
      qiblaBearing: bearing,
      heading: (hasHeading ? _filter.heading : bearing),
      hasHeading: hasHeading,
    );
    final mapFallback = QiblaMapCard(
      location: controller.location,
      bearing: bearing,
      distanceKm: controller.distanceToKaabaKm,
      onRefreshLocation: () async {
        await controller.refreshLocation();
      },
    );

    return SectionBackground(
      asset: 'assets/images/wall_qibla.jpg',
      dim: 0.46,
      builder: (context) {
      final palette = GlassPalette.of(context);
      return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        // The wallpaper is always dark, so the status-bar icons are always
        // light, in both app themes.
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text('قبلہ نما', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        actions: <Widget>[
          IconButton(
            tooltip: 'کمپاس دوبارہ فعال کریں',
            onPressed: () => unawaited(_enable()),
            icon: const Icon(Icons.explore_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 26),
        children: <Widget>[
          if (_status == _CompassStatus.unavailable) ...<Widget>[
            _EnableCompassBanner(
              palette: palette,
              onEnable: () => unawaited(_enable()),
            ),
            const SizedBox(height: 12),
          ],
          // The real map comes first: it is the one view that still gives an
          // exact direction when the magnetometer is missing or uncalibrated,
          // which is the case readers kept writing in about.
          QiblaStreetMapCard(
            location: controller.location,
            bearing: bearing,
            distanceKm: controller.distanceToKaabaKm,
            heading: hasHeading ? _filter.heading : null,
            hasHeading: hasHeading,
            onRefreshLocation: () async {
              await controller.refreshLocation();
            },
          ),
          const SizedBox(height: 12),
          _CompassCard(
            reading: reading,
            status: _status,
            continuousHeading: _continuousHeading,
            palette: palette,
          ),
          const SizedBox(height: 12),
          mapFallback,
          const SizedBox(height: 12),
          _LocationCard(controller: controller, palette: palette),
          const SizedBox(height: 12),
          _CalibrationCard(
            accuracy: _accuracy,
            hasHeading: hasHeading,
            palette: palette,
          ),
          const SizedBox(height: 12),
          _HowToCard(palette: palette, bearing: bearing),
        ],
      ),
      );
      },
    );
  }
}

/// The dial itself: a compass rose that turns with the phone, the Qibla needle,
/// a fixed index at the top, and the reading in the middle.
class _CompassCard extends StatelessWidget {
  const _CompassCard({
    required this.reading,
    required this.status,
    required this.continuousHeading,
    required this.palette,
  });

  static const double dial = 268;

  final CompassReading reading;
  final _CompassStatus status;
  final double? continuousHeading;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    final aligned = reading.alignment == CompassAlignment.aligned;
    final live = status == _CompassStatus.live && continuousHeading != null;
    // AnimatedRotation takes the continuous (unwrapped) angle, which is what
    // keeps the rose from spinning the long way round when the heading crosses
    // north. A tenth of a second linear tween fills the gap between sensor
    // events without adding visible lag.
    final turns = -(continuousHeading ?? reading.heading) / 360.0;

    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                live ? Icons.sensors : Icons.sensors_off,
                size: 15,
                color: live ? palette.accent : palette.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  switch (status) {
                    _CompassStatus.live => 'مقناطیسی کمپاس فعال',
                    _CompassStatus.waiting => 'کمپاس کی پہلی ریڈنگ کا انتظار…',
                    _CompassStatus.unavailable => 'کمپاس دستیاب نہیں — نیچے سمتِ قبلہ موجود ہے',
                  },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: palette.muted),
                ),
              ),
              _StatusPill(reading: reading, palette: palette),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            final diameter = math.min(dial, constraints.maxWidth);
            final bearingAngle = reading.qiblaBearing * math.pi / 180 - math.pi / 2;
            final markerRadius = diameter / 2 - 36;
            final marker = Offset(
              diameter / 2 + math.cos(bearingAngle) * markerRadius,
              diameter / 2 + math.sin(bearingAngle) * markerRadius,
            );
            return Center(
              child: SizedBox(
                width: diameter,
                height: diameter + 18,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[
                    Positioned(
                      top: 18,
                      child: AnimatedRotation(
                        turns: turns,
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.linear,
                        child: SizedBox.square(
                          dimension: diameter,
                          child: Stack(
                            children: <Widget>[
                              CustomPaint(
                                size: Size.square(diameter),
                                painter: _CompassRosePainter(
                                  bearing: reading.qiblaBearing,
                                  aligned: aligned,
                                ),
                              ),
                              Positioned(
                                left: marker.dx - 21,
                                top: marker.dy - 21,
                                child: AnimatedRotation(
                                  // As the rose turns, the PNG stays upright.
                                  turns: -turns,
                                  duration: const Duration(milliseconds: 120),
                                  child: Image.asset(
                                    'assets/images/kaaba_icon.png',
                                    key: const ValueKey<String>('qibla-kaaba-marker'),
                                    width: 42,
                                    height: 42,
                                    cacheWidth: 144,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // The fixed index is the direction the PHONE faces.
                    Positioned(
                      top: 0,
                      child: Icon(
                        Icons.arrow_drop_down,
                        size: 22,
                        color: aligned ? palette.accent : palette.gold,
                      ),
                    ),
                    Positioned(
                      top: 18 + diameter / 2 - 44,
                      child: _DialCentre(reading: reading, live: live),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          _AlignmentReadout(reading: reading, live: live, palette: palette),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.reading, required this.palette});

  final CompassReading reading;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    if (!reading.hasHeading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: palette.track,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: palette.border),
        ),
        child: Text(
          'سینسر کا انتظار',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: palette.muted),
        ),
      );
    }
    final (label, color) = switch (reading.alignment) {
      CompassAlignment.aligned => ('الائن / کیلیبریٹڈ', palette.accent),
      CompassAlignment.close => ('قریب ہے', palette.gold),
      CompassAlignment.off => ('نہیں', palette.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Inside the dial: the heading the phone currently points at.
class _DialCentre extends StatelessWidget {
  const _DialCentre({required this.reading, required this.live});

  final CompassReading reading;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 94,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.38, -0.55),
          colors: <Color>[Color(0xFFFFF9E9), Color(0xFFE7D9B8), Color(0xFF9E8050)],
          stops: <double>[0, 0.70, 1],
        ),
        border: Border.all(color: const Color(0xFFD6AE67), width: 2.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0xAA000000), blurRadius: 11, offset: Offset(2, 5)),
          BoxShadow(color: Color(0xC0FFFFFF), blurRadius: 2, offset: Offset(-2, -2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(live ? 'رخ' : 'قبلہ',
            style: const TextStyle(fontSize: 11, color: Color(0xFF405348))),
          Text(
            formatDegreesUrdu(live ? reading.heading : reading.qiblaBearing),
            style: const TextStyle(
              fontFamily: kDigitFont,
              fontSize: 26,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: Color(0xFF192B26),
            ),
          ),
          Text(
            compassPointUrdu(live ? reading.heading : reading.qiblaBearing),
            style: const TextStyle(fontSize: 11, height: 1.05, color: Color(0xFF405348)),
          ),
        ],
      ),
    );
  }
}

class _AlignmentReadout extends StatelessWidget {
  const _AlignmentReadout({
    required this.reading,
    required this.live,
    required this.palette,
  });

  final CompassReading reading;
  final bool live;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    final aligned = reading.alignment == CompassAlignment.aligned;
    final color = aligned ? palette.accent : palette.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            aligned ? Icons.check_circle : Icons.rotate_right,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  aligned ? 'الائن / کیلیبریٹڈ — رخ قبلہ پر ہے' : reading.instructionUrdu,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                  ),
                ),
                Text(
                  live
                      ? 'کعبہ کی سمت شمالِ حقیقی سے '
                        '${formatBearingUrdu(reading.qiblaBearing, compassPointUrdu(reading.qiblaBearing))} '
                        '— انحراف ${formatDegreesUrdu(reading.turn.abs())}'
                      : 'فون کو سیدھا (افقی) رکھیں اور کمپاس فعال کریں',
                  maxLines: 2,
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: palette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The rose: ticks, the four directions in Urdu, and the Kaaba needle.
class _CompassRosePainter extends CustomPainter {
  _CompassRosePainter({required this.bearing, required this.aligned});

  final double bearing;
  final bool aligned;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Three engraved metal rings, a recessed charcoal dial, and a subtle
    // embossed compass rose. These stay in the rose's sensor-driven rotation;
    // only the furniture changed, never the Qibla bearing or heading math.
    final outer = Rect.fromCircle(center: centre, radius: radius);
    canvas.drawShadow(Path()..addOval(outer), const Color(0xA4000000), 12, true);
    canvas.drawCircle(centre, radius, Paint()..shader = const RadialGradient(
      center: Alignment(-0.6, -0.8),
      radius: 1.3,
      colors: <Color>[Color(0xFFFFE0A0), Color(0xFFB8904B), Color(0xFF5A431F)],
      stops: <double>[0, 0.62, 1],
    ).createShader(outer));
    canvas.drawCircle(centre, radius - 3, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = const Color(0xFFFDF4D4));
    canvas.drawCircle(centre, radius - 9, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = const Color(0xFF302B28));
    final face = Rect.fromCircle(center: centre, radius: radius - 14);
    canvas.drawCircle(centre, radius - 14, Paint()..shader = const RadialGradient(
      center: Alignment(-0.38, -0.45),
      radius: 1.25,
      colors: <Color>[Color(0xFF364C4B), Color(0xFF1B302E), Color(0xFF0A1718)],
      stops: <double>[0, 0.58, 1],
    ).createShader(face));
    canvas.drawCircle(centre, radius - 16, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = const Color(0xFFAD8A4D));
    canvas.drawCircle(centre, radius - 52, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0x5589A99A));

    for (var point = 0; point < 8; point++) {
      final angle = point * math.pi / 4 - math.pi / 2;
      final tip = centre + Offset(math.cos(angle), math.sin(angle)) * (radius - 56);
      final left = centre + Offset(math.cos(angle + 0.65), math.sin(angle + 0.65)) * 24;
      final right = centre + Offset(math.cos(angle - 0.65), math.sin(angle - 0.65)) * 24;
      canvas.drawPath(
        Path()..moveTo(tip.dx, tip.dy)..lineTo(left.dx, left.dy)
          ..lineTo(right.dx, right.dy)..close(),
        Paint()..color = (point.isEven ? const Color(0xFFCEAD72) : const Color(0xFFB5D2C3))
            .withValues(alpha: point.isEven ? 0.12 : 0.06),
      );
    }

    // Ticks every 15°, longer every 45°.
    for (int step = 0; step < 24; step++) {
      final angle = step * 15 * math.pi / 180 - math.pi / 2;
      final major = step % 3 == 0;
      final outer = radius - 19;
      final inner = outer - (major ? 12 : 6);
      canvas.drawLine(
        centre + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        centre + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        Paint()
          ..strokeWidth = major ? 1.6 : 1
          ..color = (step == 0 ? const Color(0xFFF5DCA4) : const Color(0xFFB9D3C8))
              .withValues(alpha: major ? 0.8 : 0.45),
      );
    }

    // The four directions, in Urdu, upright on the rose as it turns.
    const labels = <String>['شم', 'مش', 'جن', 'مغ'];
    for (int index = 0; index < 4; index++) {
      final angle = index * 90 * math.pi / 180 - math.pi / 2;
      final position = centre + Offset(math.cos(angle), math.sin(angle)) * (radius - 55);
      _paintText(
        canvas,
        labels[index],
        position,
        index == 0 ? const Color(0xFFF3CB7E) : const Color(0xFFF1F3DD),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      );
    }

    // The Qibla needle, drawn inside the rose at the bearing from true north.
    final bearingRadians = bearing * math.pi / 180 - math.pi / 2;
    final tip = centre + Offset(math.cos(bearingRadians), math.sin(bearingRadians)) * (radius - 31);
    final base = centre + Offset(math.cos(bearingRadians), math.sin(bearingRadians)) * 42;
    final needleColor = aligned ? const Color(0xFF8EE2B9) : const Color(0xFFE4B96A);
    final needleRect = Rect.fromPoints(base, tip).inflate(6);
    canvas.drawLine(
      base + const Offset(1.8, 2.5),
      tip + const Offset(1.8, 2.5),
      Paint()
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x99000000),
    );
    canvas.drawLine(base, tip, Paint()
      ..strokeWidth = aligned ? 7 : 6
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: <Color>[const Color(0xFFFFF4D3), needleColor, const Color(0xFF765624)],
      ).createShader(needleRect));
    canvas.drawLine(base, tip, Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xD9FFFFFF));
    // The realistic, isolated Kaaba PNG is placed over this tip by the widget
    // above the painter (and counter-rotated so it always stays upright).
    canvas.drawCircle(centre, 5, Paint()..color = const Color(0xFFF1D59B));
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset centre,
    Color color, {
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: kUrduFont,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_CompassRosePainter old) =>
      old.bearing != bearing || old.aligned != aligned;
}

/// Shown when the magnetometer never reported: one tap to try again, and a
/// plain statement of what the reader can do instead.
class _EnableCompassBanner extends StatelessWidget {
  const _EnableCompassBanner({required this.palette, required this.onEnable});

  final GlassPalette palette;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.explore, size: 18, color: palette.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'کمپاس سینسر دستیاب نہیں',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'یہ فون مقناطیسی سینسر کی رپورٹ نہیں دے رہا (یا اجازت نہیں دی گئی)۔ '
            'نیچے دی گئی سمتِ قبلہ کے مطابق نماز پڑھیں، یا دوبارہ کوشش کریں — '
            'آئی او ایس پر پہلے مقام اور حرکت کی اجازت درکار ہوتی ہے۔',
            style: TextStyle(fontSize: 13, height: 1.55, color: palette.muted),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: const Size(0, 36),
              ),
              onPressed: onEnable,
              icon: const Icon(Icons.touch_app, size: 16),
              label: const Text('کمپاس فعال کریں', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the bearing came from: the same stored coordinates as the timings.
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.controller, required this.palette});

  final PrayerController controller;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    final location = controller.location;
    final bearing = controller.qiblaBearing;
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const GlassSectionHeader(title: 'مقام اور سمت'),
          const SizedBox(height: 10),
          _InfoRow(
            label: 'مقام',
            value: location.label,
            palette: palette,
            icon: Icons.place_outlined,
          ),
          _InfoRow(
            label: 'متناسقات',
            value: formatCoordinatesUrdu(location.latitude, location.longitude),
            palette: palette,
            icon: Icons.gps_fixed,
          ),
          _InfoRow(
            label: 'سمتِ قبلہ',
            value: formatBearingUrdu(bearing, compassPointUrdu(bearing)),
            palette: palette,
            icon: Icons.explore_outlined,
          ),
          _InfoRow(
            label: 'کعبہ سے فاصلہ',
            value: formatKilometresUrdu(controller.distanceToKaabaKm),
            palette: palette,
            icon: Icons.straighten,
          ),
          _InfoRow(
            label: 'ماخذ',
            value: location.source.labelUrdu,
            palette: palette,
            icon: Icons.verified_outlined,
          ),
          const SizedBox(height: 6),
          Text(
            'یہی متناسقات نماز کے اوقات کے لیے بھی استعمال ہوتے ہیں — دوبارہ مقام نہیں پوچھا جاتا۔',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.palette,
    required this.icon,
  });

  final String label;
  final String value;
  final GlassPalette palette;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: palette.accent),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontSize: 13, color: palette.muted)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sensor accuracy and the figure-8 calibration hint.
class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard({
    required this.accuracy,
    required this.hasHeading,
    required this.palette,
  });

  final double? accuracy;
  final bool hasHeading;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    final (quality, detail) = switch (accuracy) {
      null => ('نامعلوم', 'کیلیبریشن کے لیے فون کو 8 کی شکل میں گھمائیں'),
      final value when value <= 15 => ('عمدہ', 'کمپاس کی درستگی بہتر ہے'),
      final value when value <= 30 => ('درمیانہ', 'دھات، کیس یا چابیاں کمپاس کو متاثر کرتی ہیں'),
      _ => ('ناقص', 'فون کو 8 کی شکل میں گھما کر کیلیبریٹ کریں'),
    };
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const GlassSectionHeader(title: 'کیلیبریشن'),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(
                hasHeading ? Icons.adjust : Icons.help_outline,
                size: 16,
                color: hasHeading ? palette.accent : palette.muted,
              ),
              const SizedBox(width: 7),
              Text(
                'درستگی: $quality',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(fontSize: 13, height: 1.5, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _HowToCard extends StatelessWidget {
  const _HowToCard({required this.palette, required this.bearing});

  final GlassPalette palette;
  final double bearing;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(13),
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const GlassSectionHeader(title: 'طریقہ'),
          const SizedBox(height: 8),
          for (final line in <String>[
            'فون کو ہاتھ میں سیدھا (افقی) رکھیں، سکرین اوپر۔',
            'سوئی (سبز) کعبہ کی طرف اشارہ کرتی ہے؛ اوپر والا نشان رخ بتاتا ہے۔',
            'جب سبز نشان اوپر والے نشان کے نیچے آ جائے تو رخ قبلہ پر ہے '
                '(${formatBearingUrdu(bearing, compassPointUrdu(bearing))} شمالِ حقیقی سے)۔',
            'ابتدائی رخ ٹائم زون یا GPS کے بغیر بھی محفوظ رہتا ہے۔',
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Icon(Icons.circle, size: 5, color: palette.gold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(fontSize: 13.5, height: 1.6, color: palette.ink),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
