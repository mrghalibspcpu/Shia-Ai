import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../astro/sky_phase.dart';

/// The living wallpaper behind the prayer card: a painted sky for the time of
/// day (dawn, midday, evening, night) with a light animation drawn over it —
/// twinkling and shooting stars at night, drifting clouds and passing birds by
/// day, a breathing glow at sunrise and sunset.
///
/// Everything moving is one [CustomPainter] driven by one controller, behind a
/// [RepaintBoundary], so the text on top never repaints with it. The motion
/// stops when the card is off screen (the ticker is muted) and when the phone
/// asks for reduced motion.
class SkyBackdrop extends StatefulWidget {
  const SkyBackdrop({
    super.key,
    required this.phase,
    required this.child,
    this.radius = 24,
    this.animate = true,
  });

  final SkyPhase phase;
  final Widget child;
  final double radius;
  final bool animate;

  @override
  State<SkyBackdrop> createState() => _SkyBackdropState();
}

class _SkyBackdropState extends State<SkyBackdrop> with SingleTickerProviderStateMixin {
  /// One loop of the animation. Long, so the birds and shooting stars feel
  /// occasional rather than scheduled.
  static const Duration _loop = Duration(seconds: 40);

  late final AnimationController _clock = AnimationController(vsync: this, duration: _loop);
  final List<_Star> _stars = _Star.scatter(52, seed: 11);
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncMotion();
  }

  @override
  void didUpdateWidget(SkyBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _syncMotion();
  }

  void _syncMotion() {
    final run = widget.animate && !_reduceMotion;
    if (run && !_clock.isAnimating) {
      _clock.repeat();
    } else if (!run && _clock.isAnimating) {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.phase;
    final veil = _SkyVeil.of(phase);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1400),
              child: _SkyImage(key: ValueKey<SkyPhase>(phase), phase: phase),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SkyMotionPainter(
                    phase: phase,
                    clock: _clock,
                    stars: _stars,
                  ),
                ),
              ),
            ),
          ),
          // A veil that darkens the top and bottom edges, so white text stays
          // readable on the brightest midday sky.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: veil.top),
                      Colors.black.withValues(alpha: veil.middle),
                      Colors.black.withValues(alpha: veil.bottom),
                    ],
                    stops: const <double>[0.0, 0.48, 1.0],
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _SkyImage extends StatelessWidget {
  const _SkyImage({super.key, required this.phase});

  final SkyPhase phase;

  /// Keeps the shrine of each painting inside the card's narrower frame.
  Alignment get _focus => switch (phase) {
        SkyPhase.dawn => const Alignment(0.55, 0.2),
        SkyPhase.morning => const Alignment(0.4, 0.2),
        SkyPhase.sehr => const Alignment(0.4, 0.15),
        SkyPhase.day => const Alignment(0.25, 0.2),
        SkyPhase.evening => const Alignment(-0.25, 0.2),
        SkyPhase.night => const Alignment(0.3, 0.1),
      };

  Color get _fallback => switch (phase) {
        SkyPhase.dawn => const Color(0xFF4B3F72),
        SkyPhase.morning => const Color(0xFFF2A65A),
        SkyPhase.sehr => const Color(0xFF1B2A52),
        SkyPhase.day => const Color(0xFF3F8FD2),
        SkyPhase.evening => const Color(0xFFB4532A),
        SkyPhase.night => const Color(0xFF0B1633),
      };

  @override
  Widget build(BuildContext context) {
    // Expanded explicitly: the switcher's stack hands its children loose
    // constraints, and a loose image would letterbox instead of covering.
    return SizedBox.expand(
      child: Image.asset(
        phase.asset,
        fit: BoxFit.cover,
        alignment: _focus,
        // The paintings are 1280 px wide and the card shows ~70% of one, so
        // decoding at full width keeps them sharp on a 3x screen.
        cacheWidth: 1280,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => ColoredBox(color: _fallback),
      ),
    );
  }
}

/// How dark the readability veil is for each sky.
class _SkyVeil {
  const _SkyVeil(this.top, this.middle, this.bottom);

  final double top;
  final double middle;
  final double bottom;

  static _SkyVeil of(SkyPhase phase) => switch (phase) {
        SkyPhase.dawn => const _SkyVeil(0.34, 0.12, 0.46),
        SkyPhase.morning => const _SkyVeil(0.36, 0.16, 0.48),
        SkyPhase.sehr => const _SkyVeil(0.28, 0.10, 0.46),
        SkyPhase.day => const _SkyVeil(0.42, 0.20, 0.50),
        SkyPhase.evening => const _SkyVeil(0.36, 0.14, 0.48),
        SkyPhase.night => const _SkyVeil(0.22, 0.06, 0.44),
      };
}

/// A star, in fractions of the card (so it never depends on the card's size).
class _Star {
  const _Star(this.x, this.y, this.radius, this.phase, this.speed);

  final double x;
  final double y;
  final double radius;
  final double phase;
  final double speed;

  static List<_Star> scatter(int count, {required int seed}) {
    final random = math.Random(seed);
    return List<_Star>.generate(count, (_) {
      return _Star(
        random.nextDouble(),
        // Mostly in the upper sky, thinning out towards the horizon.
        math.pow(random.nextDouble(), 1.6).toDouble() * 0.68,
        0.5 + random.nextDouble() * 1.3,
        random.nextDouble() * math.pi * 2,
        (1 + random.nextInt(4)).toDouble(),
      );
    });
  }
}

class _SkyMotionPainter extends CustomPainter {
  _SkyMotionPainter({
    required this.phase,
    required this.clock,
    required this.stars,
  }) : super(repaint: clock);

  final SkyPhase phase;
  final Animation<double> clock;
  final List<_Star> stars;

  static const double _loopSeconds = 40;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = clock.value;
    switch (phase) {
      case SkyPhase.night:
        _paintStars(canvas, size, t, count: stars.length, strength: 0.95);
        _paintShootingStar(canvas, size, t, start: 0.18, from: const Offset(0.12, 0.10), to: const Offset(0.46, 0.30));
        _paintShootingStar(canvas, size, t, start: 0.66, from: const Offset(0.58, 0.06), to: const Offset(0.86, 0.24));
      case SkyPhase.sehr:
        _paintStars(canvas, size, t, count: stars.length, strength: 0.75);
        _paintGlow(canvas, size, t, centre: const Offset(0.60, 0.88), radius: 0.65, color: const Color(0xFF7FB4C7), base: 0.08, swing: 0.06);
        _paintMist(canvas, size, t);
      case SkyPhase.morning:
        _paintGlow(canvas, size, t, centre: const Offset(0.62, 0.82), radius: 0.72, color: const Color(0xFFFFC98A), base: 0.14, swing: 0.08);
        _paintClouds(canvas, size, t, tint: const Color(0xFFFFE3C2), strength: 0.28);
        _paintBirds(canvas, size, t, start: 0.20, length: 0.40, height: 0.26, color: const Color(0xB3253040));
      case SkyPhase.dawn:
        _paintGlow(canvas, size, t, centre: const Offset(0.62, 0.86), radius: 0.75, color: const Color(0xFFFFB38A), base: 0.10, swing: 0.08);
        _paintStars(canvas, size, t, count: 18, strength: 0.45);
        _paintMist(canvas, size, t);
        _paintBirds(canvas, size, t, start: 0.45, length: 0.42, height: 0.30, color: const Color(0xCC1C1B2E));
      case SkyPhase.day:
        _paintGlow(canvas, size, t, centre: const Offset(0.10, 0.06), radius: 0.55, color: const Color(0xFFFFF4D6), base: 0.16, swing: 0.10);
        _paintRays(canvas, size, t);
        _paintClouds(canvas, size, t, tint: Colors.white, strength: 0.42);
        _paintBirds(canvas, size, t, start: 0.10, length: 0.38, height: 0.24, color: const Color(0xB3253040));
      case SkyPhase.evening:
        _paintGlow(canvas, size, t, centre: const Offset(0.58, 0.80), radius: 0.70, color: const Color(0xFFFFA24C), base: 0.14, swing: 0.10);
        _paintClouds(canvas, size, t, tint: const Color(0xFFFFC9A6), strength: 0.24);
        _paintStars(canvas, size, t, count: 7, strength: 0.35);
        _paintBirds(canvas, size, t, start: 0.30, length: 0.45, height: 0.34, color: const Color(0xD9201418));
    }
  }

  void _paintStars(Canvas canvas, Size size, double t, {required int count, required double strength}) {
    final paint = Paint()..color = Colors.white;
    final seconds = t * _loopSeconds;
    for (var index = 0; index < count && index < stars.length; index++) {
      final star = stars[index];
      // Each star breathes at its own pace: 1–4 slow cycles per loop.
      final wave = math.sin(seconds * star.speed * 2 * math.pi / _loopSeconds * 3 + star.phase);
      final alpha = (strength * (0.55 + 0.45 * wave)).clamp(0.0, 1.0);
      paint.color = Colors.white.withValues(alpha: alpha);
      final centre = Offset(star.x * size.width, star.y * size.height);
      canvas.drawCircle(centre, star.radius, paint);
      // The brightest moments get a faint cross of light.
      if (wave > 0.85 && star.radius > 1.3) {
        final glint = Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.5)
          ..strokeWidth = 0.8;
        final reach = star.radius * 3.2;
        canvas.drawLine(centre - Offset(reach, 0), centre + Offset(reach, 0), glint);
        canvas.drawLine(centre - Offset(0, reach), centre + Offset(0, reach), glint);
      }
    }
  }

  void _paintShootingStar(
    Canvas canvas,
    Size size,
    double t, {
    required double start,
    required Offset from,
    required Offset to,
  }) {
    const length = 0.035; // ~1.4 s of the 40 s loop
    final progress = (t - start) / length;
    if (progress < 0 || progress > 1) return;
    final head = Offset.lerp(from, to, progress)!;
    final tail = Offset.lerp(from, to, math.max(0.0, progress - 0.35))!;
    final a = Offset(tail.dx * size.width, tail.dy * size.height);
    final b = Offset(head.dx * size.width, head.dy * size.height);
    final fade = math.sin(progress * math.pi);
    final paint = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.9 * fade),
        ],
      ).createShader(Rect.fromPoints(a, b));
    canvas.drawLine(a, b, paint);
    canvas.drawCircle(b, 1.6, Paint()..color = Colors.white.withValues(alpha: fade));
  }

  void _paintGlow(
    Canvas canvas,
    Size size,
    double t, {
    required Offset centre,
    required double radius,
    required Color color,
    required double base,
    required double swing,
  }) {
    final breathe = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 2);
    final alpha = base + swing * breathe;
    final point = Offset(centre.dx * size.width, centre.dy * size.height);
    final reach = radius * size.width;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: point, radius: reach));
    canvas.drawCircle(point, reach, paint);
  }

  void _paintRays(Canvas canvas, Size size, double t) {
    final origin = Offset(size.width * 0.08, size.height * 0.02);
    final reach = size.width * 0.9;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.05);
    final turn = t * 2 * math.pi / 6; // a slow sixth of a turn per loop
    for (var index = 0; index < 5; index++) {
      final angle = 0.15 + index * 0.24 + 0.08 * math.sin(turn + index);
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(origin.dx + math.cos(angle - 0.035) * reach, origin.dy + math.sin(angle - 0.035) * reach)
        ..lineTo(origin.dx + math.cos(angle + 0.035) * reach, origin.dy + math.sin(angle + 0.035) * reach)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _paintClouds(Canvas canvas, Size size, double t, {required Color tint, required double strength}) {
    const clouds = <(double, double, double, double)>[
      // (start x, y, scale, speed in card widths per loop)
      (0.05, 0.16, 1.0, 0.30),
      (0.55, 0.30, 0.75, 0.22),
      (0.85, 0.08, 0.6, 0.38),
    ];
    for (final (startX, y, scale, speed) in clouds) {
      final x = ((startX + t * speed) % 1.5) - 0.25;
      _paintCloud(
        canvas,
        Offset(x * size.width, y * size.height),
        size.width * 0.16 * scale,
        tint,
        strength,
      );
    }
  }

  void _paintCloud(Canvas canvas, Offset centre, double unit, Color tint, double strength) {
    const puffs = <(double, double, double)>[
      (-1.1, 0.25, 0.75),
      (-0.35, -0.15, 1.0),
      (0.55, 0.05, 0.85),
      (1.25, 0.32, 0.6),
    ];
    for (final (dx, dy, r) in puffs) {
      final point = centre + Offset(dx * unit, dy * unit);
      final radius = r * unit;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            tint.withValues(alpha: strength),
            tint.withValues(alpha: strength * 0.55),
            tint.withValues(alpha: 0),
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: point, radius: radius));
      canvas.drawCircle(point, radius, paint);
    }
  }

  void _paintMist(Canvas canvas, Size size, double t) {
    for (var band = 0; band < 2; band++) {
      final drift = math.sin(t * 2 * math.pi + band * 1.7) * size.width * 0.06;
      final rect = Rect.fromCenter(
        center: Offset(size.width * (0.5 + band * 0.1) + drift, size.height * (0.80 + band * 0.08)),
        width: size.width * 1.3,
        height: size.height * 0.10,
      );
      final paint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.13),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect);
      canvas.drawOval(rect, paint);
    }
  }

  /// A small flock crossing the sky once per loop, wings beating.
  void _paintBirds(
    Canvas canvas,
    Size size,
    double t, {
    required double start,
    required double length,
    required double height,
    required Color color,
  }) {
    final progress = (t - start) / length;
    if (progress < 0 || progress > 1) return;
    const flock = <(double, double)>[(0.0, 0.0), (0.05, -0.035), (0.05, 0.035), (0.10, -0.06), (0.11, 0.05)];
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final seconds = t * _loopSeconds;
    for (var index = 0; index < flock.length; index++) {
      final (lag, spread) = flock[index];
      // Right to left, the way the eye reads this card, with a gentle bob.
      final x = (1.12 - (progress - lag) * 1.35) * size.width;
      final y = (height + spread + 0.015 * math.sin(progress * math.pi * 4 + index)) * size.height;
      final flap = math.sin(seconds * 9 + index * 1.3);
      final span = size.width * 0.018;
      final lift = span * (0.25 + 0.55 * flap);
      final path = Path()
        ..moveTo(x - span, y - lift)
        ..quadraticBezierTo(x - span * 0.45, y - lift * 0.2, x, y)
        ..quadraticBezierTo(x + span * 0.45, y - lift * 0.2, x + span, y - lift);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SkyMotionPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.clock != clock || oldDelegate.stars != stars;
}
