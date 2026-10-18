import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../astro/compass_math.dart';
import '../astro/prayer_format.dart';
import '../services/prayer_locations.dart';
import 'glass_panel.dart';

/// A north-up schematic map that makes the Qibla direction unmistakable.
///
/// The previous version fetched OpenStreetMap tiles, fell back to procedural
/// "roads" when they failed, and rotated the whole map so the Qibla pointed up.
/// On a phone that read as a confusing picture: the arrow often ended off
/// screen and the fake streets looked like a real map. This version paints a
/// clean, honest diagram instead — no network, no fake geography:
///
/// * north is always the top edge, labelled «شمال»;
/// * a thick emerald arrow runs from «آپ» to a Kaaba mark on the rim;
/// * the bearing in degrees and the compass point sit right under the map.
///
/// The direction comes from the same coordinates as the prayer schedule, so it
/// works without a magnetometer, a tile server or a data connection.
class QiblaMapCard extends StatefulWidget {
  const QiblaMapCard({
    super.key,
    required this.location,
    required this.bearing,
    required this.distanceKm,
    required this.onRefreshLocation,
  });

  final PrayerLocation location;
  final double bearing;
  final double distanceKm;
  final Future<void> Function() onRefreshLocation;

  @override
  State<QiblaMapCard> createState() => _QiblaMapCardState();
}

class _QiblaMapCardState extends State<QiblaMapCard> {
  bool _refreshing = false;

  Future<void> _refreshLocation() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await widget.onRefreshLocation();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final sourceNote = _locationSourceNote(widget.location);
    final distance = formatKilometresUrdu(widget.distanceKm);

    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GlassSectionHeader(
            title: 'نقشے پر سمتِ قبلہ',
            trailing: IconButton(
              tooltip: 'GPS سے مقام تازہ کریں',
              visualDensity: VisualDensity.compact,
              onPressed: _refreshing ? null : _refreshLocation,
              icon: _refreshing
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: palette.accent),
                    )
                  : Icon(Icons.my_location, size: 19, color: palette.accent),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Icon(Icons.place, size: 14, color: palette.gold),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.location.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(sourceNote, style: TextStyle(fontSize: 11.5, height: 1.45, color: palette.muted)),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              height: 236,
              child: CustomPaint(
                key: const ValueKey<String>('qibla-map-diagram'),
                painter: _QiblaDiagramPainter(
                  bearing: widget.bearing,
                  distanceLabel: distance,
                  palette: palette,
                  dark: palette.isDark,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(Icons.navigation_rounded, size: 17, color: palette.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'قبلہ ${formatBearingUrdu(widget.bearing, compassPointUrdu(widget.bearing))}',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: palette.ink),
                ),
              ),
              Text(
                distance,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.muted),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'نقشہ شمال اوپر ہے: موٹا سبز تیر آپ کے مقام سے کعبہ کی طرف ہے۔ '
            'اسی رخ منہ کر کے نماز پڑھیں — کمپاس یا اینگل کی ضرورت نہیں، '
            'اور یہ نقشہ انٹرنیٹ کے بغیر بھی چلتا ہے۔',
            style: TextStyle(fontSize: 11.5, height: 1.45, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

String _locationSourceNote(PrayerLocation location) {
  final accuracy = location.accuracyMeters;
  return switch (location.source) {
    LocationSource.gps => accuracy == null
        ? 'GPS مقام · قبلے کا حساب اسی مقام سے'
        : 'GPS مقام · دقت تقریباً ${accuracy.round()} میٹر',
    LocationSource.ip => 'انٹرنیٹ سے شہر کا اندازہ · درست رخ کے لیے GPS بہتر ہے',
    LocationSource.manual => 'آپ کا منتخب کردہ شہر · مقام بدلنے کے لیے GPS دبائیں',
    LocationSource.fallback => 'ڈیفالٹ اسلام آباد · اپنے درست مقام کے لیے GPS دبائیں',
  };
}

/// The diagram itself: rings, cardinal marks, the reader's dot, the Kaaba and
/// one thick arrow between them.
class _QiblaDiagramPainter extends CustomPainter {
  const _QiblaDiagramPainter({
    required this.bearing,
    required this.distanceLabel,
    required this.palette,
    required this.dark,
  });

  final double bearing;
  final String distanceLabel;
  final GlassPalette palette;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 26;
    if (radius <= 0) return;

    // Paper: a calm ground with the faintest grid, so it reads as a diagram and
    // never pretends to be satellite imagery.
    final ground = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: dark
            ? const <Color>[Color(0xFF10201B), Color(0xFF0A1512)]
            : const <Color>[Color(0xFFF6F1E4), Color(0xFFE9F0E6)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, ground);

    final grid = Paint()
      ..color = (dark ? Colors.white : const Color(0xFF145B45)).withValues(alpha: 0.07)
      ..strokeWidth = 1;
    const step = 34.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Two range rings: they give the eye a scale and a horizon for the arrow.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = (dark ? Colors.white : const Color(0xFF145B45)).withValues(alpha: 0.16);
    canvas.drawCircle(center, radius, ring);
    canvas.drawCircle(center, radius * 0.55, ring);

    _drawCardinals(canvas, center, radius);
    _drawQiblaArrow(canvas, center, radius);
    _drawUser(canvas, center);
  }

  void _drawCardinals(Canvas canvas, Offset center, double radius) {
    final ink = palette.muted;
    void mark(String label, Offset point, {double size = 11.5}) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: ink,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      painter.paint(canvas, point - Offset(painter.width / 2, painter.height / 2));
    }

    mark('شمال', center + Offset(0, -radius - 15));
    mark('جنوب', center + Offset(0, radius + 15));
    mark('مشرق', center + Offset(radius + 17, 0));
    mark('مغرب', center + Offset(-radius - 17, 0));

    // A small north triangle makes "north is up" obvious even without reading.
    final north = Path()
      ..moveTo(center.dx, center.dy - radius + 2)
      ..lineTo(center.dx - 6, center.dy - radius + 14)
      ..lineTo(center.dx + 6, center.dy - radius + 14)
      ..close();
    canvas.drawPath(north, Paint()..color = palette.gold);
  }

  void _drawQiblaArrow(Canvas canvas, Offset center, double radius) {
    final angle = bearing * math.pi / 180;
    // 0° is north (up), 90° east (right) — the same convention the bearing uses.
    final direction = Offset(math.sin(angle), -math.cos(angle));
    final perpendicular = Offset(-direction.dy, direction.dx);
    final tip = center + direction * (radius - 6);
    final tail = center + direction * 12;
    final headBase = tip - direction * 20;

    final halo = Paint()
      ..color = (dark ? Colors.black : Colors.white).withValues(alpha: 0.45)
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    final shaft = Paint()
      ..color = palette.accent
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(tail, headBase, halo);
    canvas.drawLine(tail, headBase, shaft);

    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(headBase.dx + perpendicular.dx * 15, headBase.dy + perpendicular.dy * 15)
      ..lineTo(headBase.dx - perpendicular.dx * 15, headBase.dy - perpendicular.dy * 15)
      ..close();
    canvas.drawPath(head, Paint()..color = palette.accent);

    // The Kaaba: a black cube with the gold band and its door, sitting exactly
    // where the arrow ends.
    final cube = Rect.fromCenter(center: tip - direction * 26, width: 23, height: 23);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cube, const Radius.circular(4)),
      Paint()..color = const Color(0xFF14100C),
    );
    canvas.drawRect(
      Rect.fromLTWH(cube.left, cube.top + 8, cube.width, 3.4),
      Paint()..color = const Color(0xFFE4BC70),
    );
    canvas.drawRect(
      Rect.fromLTWH(cube.left + cube.width / 2 - 2, cube.top + 13, 4, cube.height - 13),
      Paint()..color = const Color(0xFF3B2C17),
    );

    _label(
      canvas,
      'کعبہ',
      tip + direction * 6 + Offset(0, 22),
      background: palette.solid,
      foreground: palette.ink,
    );
  }

  void _drawUser(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 11, Paint()..color = Colors.white);
    canvas.drawCircle(center, 8, Paint()..color = palette.gold);
    canvas.drawCircle(center, 3, Paint()..color = Colors.white);
    _label(
      canvas,
      'آپ',
      center + const Offset(0, 24),
      background: palette.solid,
      foreground: palette.ink,
    );
    _label(
      canvas,
      distanceLabel,
      center + const Offset(0, -24),
      background: palette.solid.withValues(alpha: 0.92),
      foreground: palette.muted,
      small: true,
    );
  }

  void _label(
    Canvas canvas,
    String text,
    Offset point, {
    required Color background,
    required Color foreground,
    bool small = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: small ? 10 : 11.5,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    final rect = Rect.fromCenter(
      center: point,
      width: painter.width + 14,
      height: painter.height + 7,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = background,
    );
    painter.paint(canvas, Offset(rect.left + 7, rect.top + 3.5));
  }

  @override
  bool shouldRepaint(_QiblaDiagramPainter oldDelegate) =>
      oldDelegate.bearing != bearing ||
      oldDelegate.distanceLabel != distanceLabel ||
      oldDelegate.palette != palette ||
      oldDelegate.dark != dark;
}
