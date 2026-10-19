import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../astro/compass_math.dart';
import '../astro/prayer_format.dart';
import '../services/prayer_locations.dart';
import 'glass_panel.dart';

/// A **real street map** for the Qibla page, drawn from OpenStreetMap tiles.
///
/// The schematic card below it answers "which way is the Kaaba" without any
/// network or sensor. This card answers the harder question readers kept
/// asking — *which wall of this building do I face?* — by showing the actual
/// streets around the reader with a thick emerald line running from their
/// position towards the Kaaba.
///
/// Why it matters when the compass is missing: the map is **north-up** and the
/// Qibla line is drawn at the true bearing, so a reader can put the phone flat,
/// match two nearby streets on the screen with the streets in front of them,
/// and face the line. No magnetometer, no calibration, no guesswork — the same
/// fallback the popular Sajda-style Qibla maps use.
///
/// When the magnetometer *is* working, a translucent gold cone shows where the
/// phone currently points; turning until the cone covers the emerald line is
/// the same gesture as the compass above.
class QiblaStreetMapCard extends StatefulWidget {
  const QiblaStreetMapCard({
    super.key,
    required this.location,
    required this.bearing,
    required this.distanceKm,
    required this.onRefreshLocation,
    this.heading,
    this.hasHeading = false,
  });

  final PrayerLocation location;

  /// Degrees from true north to the Kaaba.
  final double bearing;

  final double distanceKm;

  final Future<void> Function() onRefreshLocation;

  /// Where the top of the phone points, when the sensor is live.
  final double? heading;

  final bool hasHeading;

  @override
  State<QiblaStreetMapCard> createState() => _QiblaStreetMapCardState();
}

class _QiblaStreetMapCardState extends State<QiblaStreetMapCard> {
  /// 17 is roughly "a few streets"; 13 shows the whole town. The two buttons
  /// move one step at a time and the offline diagram stays underneath, so the
  /// reader never loses the bearing while the tiles arrive.
  static const int _minZoom = 12;
  static const int _maxZoom = 18;
  int _zoom = 16;
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await widget.onRefreshLocation();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _setZoom(int value) {
    final next = value.clamp(_minZoom, _maxZoom);
    if (next != _zoom) setState(() => _zoom = next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final bearing = widget.bearing;
    final shading = palette.isDark;

    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.map_outlined, size: 19, color: scheme.secondary),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'اصل نقشہ — کعبہ کی سمت',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                ),
              ),
              _MapButton(
                tooltip: 'نقشہ چھوٹا کریں',
                icon: Icons.remove,
                palette: palette,
                onTap: _zoom <= _minZoom ? null : () => _setZoom(_zoom - 1),
              ),
              const SizedBox(width: 4),
              _MapButton(
                tooltip: 'نقشہ بڑا کریں',
                icon: Icons.add,
                palette: palette,
                onTap: _zoom >= _maxZoom ? null : () => _setZoom(_zoom + 1),
              ),
              const SizedBox(width: 4),
              _MapButton(
                tooltip: 'GPS سے مقام تازہ کریں',
                icon: Icons.my_location,
                palette: palette,
                busy: _refreshing,
                onTap: _refreshing ? null : _refresh,
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: <Widget>[
              Icon(Icons.place, size: 13, color: palette.gold),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  widget.location.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.ink),
                ),
              ),
              Text(
                'قبلہ ${formatBearingUrdu(bearing, compassPointUrdu(bearing))}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: palette.accent),
              ),
              const SizedBox(width: 8),
              Text(
                formatKilometresUrdu(widget.distanceKm),
                style: TextStyle(fontSize: 11.5, color: palette.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              height: 244,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ColoredBox(
                        color: shading ? const Color(0xFF0C1713) : const Color(0xFFE8EFE5),
                      ),
                      _TileLayer(
                        latitude: widget.location.latitude,
                        longitude: widget.location.longitude,
                        zoom: _zoom,
                        size: size,
                        shading: shading,
                      ),
                      CustomPaint(
                        key: const ValueKey<String>('qibla-street-map'),
                        painter: _QiblaMapOverlayPainter(
                          bearing: bearing,
                          heading: widget.heading,
                          hasHeading: widget.hasHeading,
                          distanceLabel: formatKilometresUrdu(widget.distanceKm),
                          accent: palette.accent,
                          gold: palette.gold,
                          ink: shading ? Colors.white : const Color(0xFF17251F),
                          shading: shading,
                        ),
                        child: const SizedBox.expand(),
                      ),
                      // The tile server asks for visible attribution; keep it
                      // unobtrusive but always on screen.
                      Positioned(
                        left: 6,
                        bottom: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: (shading ? Colors.black : Colors.white).withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            child: Text(
                              '© OpenStreetMap contributors',
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontSize: 8.5,
                                color: shading ? Colors.white70 : const Color(0xFF33443B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.hasHeading
                ? 'نقشہ شمال اوپر ہے۔ سنہری پنکھا فون کا رخ دکھاتا ہے — جب وہ سبز لکیر پر آ جائے تو رخ قبلہ پر ہے۔ '
                  'کمپاس بند ہو جائے تو بھی نقشہ اور لکیر ویسے ہی درست رہتے ہیں۔'
                : 'نقشہ شمال اوپر ہے اور سبز لکیر آپ کے مقام سے کعبہ کی طرف ہے۔ کمپاس کے بغیر بھی: '
                  'ارد گرد کی دو گلیاں نقشے سے ملائیں اور اسی لکیر کی طرف منہ کریں۔',
            style: TextStyle(fontSize: 11.5, height: 1.5, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.tooltip,
    required this.icon,
    required this.palette,
    this.onTap,
    this.busy = false,
  });

  final String tooltip;
  final IconData icon;
  final GlassPalette palette;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: palette.fill,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: palette.border),
          ),
          child: Center(
            child: busy
                ? SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: palette.accent),
                  )
                : Icon(icon, size: 17, color: onTap == null ? palette.muted : palette.ink),
          ),
        ),
      ),
    );
  }
}

/// One screenful of 256 px OSM tiles around the reader.
///
/// The widget is deliberately dumb: it computes which XYZ tiles cover the
/// viewport and positions them. Flutter's image cache keeps them in memory, so
/// opening the page again — or stepping a zoom level back and forth — does not
/// download the same squares twice. `errorBuilder` paints a quiet placeholder
/// instead of a red error box, which is what an offline phone sees.
class _TileLayer extends StatelessWidget {
  const _TileLayer({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.size,
    required this.shading,
  });

  final double latitude;
  final double longitude;
  final int zoom;
  final Size size;
  final bool shading;

  static const double _tileSize = 256;

  /// Widget tests run without a network (and without wanting one). The grid
  /// placeholder keeps the layout and the Qibla line testable.
  static bool get _offlineForTests {
    try {
      return Platform.environment['FLUTTER_TEST'] == 'true';
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_offlineForTests || size.isEmpty) {
      return CustomPaint(
        painter: _TileGridPainter(shading: shading),
        child: const SizedBox.expand(),
      );
    }
    final tiles = 1 << zoom;
    final world = tiles * _tileSize;
    final centerX = ((longitude + 180) / 360) * world;
    final latitudeRadians = latitude * math.pi / 180;
    final centerY = (1 -
            math.log(math.tan(latitudeRadians) + 1 / math.cos(latitudeRadians)) / math.pi) /
        2 *
        world;
    final left = centerX - size.width / 2;
    final top = centerY - size.height / 2;
    final firstX = (left / _tileSize).floor();
    final lastX = ((left + size.width) / _tileSize).floor();
    final firstY = (top / _tileSize).floor().clamp(0, tiles - 1).toInt();
    final lastY = ((top + size.height) / _tileSize).floor().clamp(0, tiles - 1).toInt();

    return Stack(
      children: <Widget>[
        for (var y = firstY; y <= lastY; y++)
          for (var x = firstX; x <= lastX; x++)
            Positioned(
              left: x * _tileSize - left,
              top: y * _tileSize - top,
              width: _tileSize,
              height: _tileSize,
              child: Image.network(
                'https://tile.openstreetmap.org/$zoom/${_wrap(x, tiles)}/$y.png',
                key: ValueKey<String>('osm-$zoom-${_wrap(x, tiles)}-$y'),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
                headers: const <String, String>{
                  'User-Agent': 'ShiaVerse/1.20 (Android Qibla map; offline-first Islamic library)',
                },
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : ColoredBox(
                        color: shading ? const Color(0xFF101C17) : const Color(0xFFE3EBE1),
                      ),
                errorBuilder: (context, error, stack) => ColoredBox(
                  color: shading ? const Color(0xFF101C17) : const Color(0xFFE3EBE1),
                  child: CustomPaint(painter: _TileGridPainter(shading: shading)),
                ),
              ),
            ),
      ],
    );
  }

  static int _wrap(int value, int tiles) => ((value % tiles) + tiles) % tiles;
}

/// A faint graticule used while tiles load, when offline, and in tests.
class _TileGridPainter extends CustomPainter {
  const _TileGridPainter({required this.shading});

  final bool shading;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1
      ..color = (shading ? Colors.white : const Color(0xFF145B45)).withValues(alpha: 0.06);
    for (var x = 0.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_TileGridPainter old) => old.shading != shading;
}

/// The reader, the Kaaba line, and (when the sensor is live) the heading cone.
class _QiblaMapOverlayPainter extends CustomPainter {
  _QiblaMapOverlayPainter({
    required this.bearing,
    required this.heading,
    required this.hasHeading,
    required this.distanceLabel,
    required this.accent,
    required this.gold,
    required this.ink,
    required this.shading,
  });

  final double bearing;
  final double? heading;
  final bool hasHeading;
  final String distanceLabel;
  final Color accent;
  final Color gold;
  final Color ink;
  final bool shading;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.44;
    final bearingRadians = bearing * math.pi / 180;

    if (hasHeading && heading != null) {
      _drawHeadingCone(canvas, centre, radius * 0.78, heading!);
    }

    _drawQiblaLine(canvas, centre, radius, bearingRadians);

    // North marker: a small «ش» with an arrow, so north-up is never assumed.
    _drawNorth(canvas, size);

    // The reader.
    canvas.drawCircle(centre, 11, Paint()..color = Colors.white.withValues(alpha: 0.95));
    canvas.drawCircle(centre, 7.5, Paint()..color = accent);
    canvas.drawCircle(centre, 3.4, Paint()..color = Colors.white);
    _label(
      canvas,
      'آپ',
      centre + const Offset(0, 24),
      background: (shading ? const Color(0xFF16231E) : Colors.white).withValues(alpha: 0.94),
      foreground: ink,
      small: true,
    );
  }

  void _drawHeadingCone(Canvas canvas, Offset centre, double radius, double headingDegrees) {
    final angle = headingDegrees * math.pi / 180;
    const spread = 0.30; // ~17° either side: a cone, not a laser.
    final cone = Path()
      ..moveTo(centre.dx, centre.dy)
      ..arcTo(
        Rect.fromCircle(center: centre, radius: radius),
        angle - math.pi / 2 - spread,
        spread * 2,
        false,
      )
      ..close();
    canvas.drawPath(cone, Paint()..color = gold.withValues(alpha: 0.22));
    final edge = Paint()
      ..strokeWidth = 1.2
      ..color = gold.withValues(alpha: 0.55);
    canvas.drawLine(
      centre,
      centre + Offset(math.cos(angle - math.pi / 2), math.sin(angle - math.pi / 2)) * radius,
      edge,
    );
  }

  void _drawQiblaLine(Canvas canvas, Offset centre, double radius, double radians) {
    // 0° is north (up), 90° east (right).
    final direction = Offset(math.sin(radians), -math.cos(radians));
    final tip = centre + direction * radius;
    final perpendicular = Offset(-direction.dy, direction.dx);
    final headBase = tip - direction * 22;

    canvas.drawLine(
      centre,
      headBase,
      Paint()
        ..color = Colors.black.withValues(alpha: shading ? 0.55 : 0.22)
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      centre,
      headBase,
      Paint()
        ..color = accent
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round,
    );
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(headBase.dx + perpendicular.dx * 13, headBase.dy + perpendicular.dy * 13)
      ..lineTo(headBase.dx - perpendicular.dx * 13, headBase.dy - perpendicular.dy * 13)
      ..close();
    canvas.drawPath(head, Paint()..color = accent);

    // A tiny Kaaba where the line leaves the viewport.
    final cube = Rect.fromCenter(center: tip - direction * 24, width: 20, height: 20);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cube, const Radius.circular(4)),
      Paint()..color = const Color(0xFF14100C),
    );
    canvas.drawRect(
      Rect.fromLTWH(cube.left, cube.top + 6.6, cube.width, 3),
      Paint()..color = const Color(0xFFE4BC70),
    );
    _label(
      canvas,
      'کعبہ • $distanceLabel',
      tip + direction * 4 + Offset(0, 24),
      background: (shading ? const Color(0xFF16231E) : Colors.white).withValues(alpha: 0.94),
      foreground: ink,
      small: true,
    );
  }

  void _drawNorth(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, 12);
    final background = (shading ? Colors.black : Colors.white).withValues(alpha: 0.66);
    canvas.drawCircle(centre, 11, Paint()..color = background);
    _paintText(canvas, 'ش', centre, ink, size: 12, weight: FontWeight.w800);
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
          fontFamily: kUrduFont,
          fontSize: small ? 10 : 11.5,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    final rect = Rect.fromCenter(center: point, width: painter.width + 14, height: painter.height + 7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = background,
    );
    painter.paint(canvas, Offset(rect.left + 7, rect.top + 3.5));
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset centre,
    Color color, {
    double size = 12,
    FontWeight weight = FontWeight.w600,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: kUrduFont, fontSize: size, fontWeight: weight, color: color),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(canvas, centre - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_QiblaMapOverlayPainter old) =>
      old.bearing != bearing ||
      old.heading != heading ||
      old.hasHeading != hasHeading ||
      old.distanceLabel != distanceLabel ||
      old.ink != ink ||
      old.shading != shading;
}
