import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../astro/compass_math.dart';
import '../astro/prayer_format.dart';
import '../services/prayer_locations.dart';
import 'glass_panel.dart';

/// North-up street map with an exact geodesic Qibla bearing and an offline
/// diagram fallback. Online, real OpenStreetMap tiles show the selected/GPS
/// locality; offline, the original clear bearing diagram remains available.
/// The bearing is computed from coordinates to the Kaaba, not from the phone's
/// magnetometer, so it remains exact when the compass sensor is unavailable.
/// A handset's physical facing still cannot be inferred without a heading sensor.
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
  bool _streetMapAvailable = false;

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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _StreetMapTiles(
                      location: widget.location,
                      onAvailabilityChanged: (available) {
                        if (mounted && _streetMapAvailable != available) {
                          setState(() => _streetMapAvailable = available);
                        }
                      },
                    ),
                    CustomPaint(
                      key: const ValueKey<String>('qibla-map-diagram'),
                      painter: _QiblaDiagramPainter(
                        bearing: widget.bearing,
                        distanceLabel: distance,
                        palette: palette,
                        dark: palette.isDark,
                        streetMapAvailable: _streetMapAvailable,
                      ),
                      child: const SizedBox.expand(),
                    ),
                    if (_streetMapAvailable)
                      const Positioned(
                        left: 6,
                        bottom: 5,
                        child: _MapAttribution(),
                      ),
                  ],
                ),
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
            'نقشہ شمال اوپر ہے: سبز تیر آپ کے مقام سے قبلے کے درست جغرافیائی رخ کی طرف ہے۔ '
            'آن لائن حقیقی نقشہ دکھتا ہے؛ انٹرنیٹ نہ ہو تو تیر والا آف لائن نقشہ رہتا ہے۔ '
            'کمپاس نہ ہو تب بھی زاویہ درست رہتا ہے، مگر فون کس طرف رخ ہے یہ سینسر کے بغیر معلوم نہیں ہو سکتا۔',
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

/// Small north-up OpenStreetMap mosaic centered on the chosen coordinates.
/// It is deliberately dependency-free: tiles are ordinary HTTPS images and the
/// page continues to work with the built-in diagram if they are unreachable.
class _StreetMapTiles extends StatefulWidget {
  const _StreetMapTiles({required this.location, required this.onAvailabilityChanged});

  final PrayerLocation location;
  final ValueChanged<bool> onAvailabilityChanged;

  @override
  State<_StreetMapTiles> createState() => _StreetMapTilesState();
}

class _StreetMapTilesState extends State<_StreetMapTiles> {
  static const int _zoom = 13;
  static const double _tileSize = 256;
  String _gridKey = '';
  bool _reportedAvailable = false;
  bool _reportedUnavailable = false;
  int _errors = 0;
  int _visibleTiles = 0;

  void _loaded() {
    if (_reportedAvailable) return;
    _reportedAvailable = true;
    widget.onAvailabilityChanged(true);
  }

  void _failed() {
    if (_reportedAvailable || _reportedUnavailable) return;
    _errors++;
    if (_errors >= _visibleTiles) {
      _reportedUnavailable = true;
      widget.onAvailabilityChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final n = 1 << _zoom;
      final latitude = widget.location.latitude.clamp(-85.05112878, 85.05112878);
      final latRad = latitude * math.pi / 180;
      final centerX = (widget.location.longitude + 180) / 360 * n * _tileSize;
      final centerY = (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * n * _tileSize;
      final leftWorld = centerX - constraints.maxWidth / 2;
      final topWorld = centerY - constraints.maxHeight / 2;
      final firstX = (leftWorld / _tileSize).floor();
      final lastX = ((leftWorld + constraints.maxWidth) / _tileSize).floor();
      final firstY = (topWorld / _tileSize).floor();
      final lastY = ((topWorld + constraints.maxHeight) / _tileSize).floor();
      final tiles = <(int x, int y, double left, double top)>[];
      for (var y = firstY; y <= lastY; y++) {
        if (y < 0 || y >= n) continue;
        for (var x = firstX; x <= lastX; x++) {
          tiles.add((x, y, x * _tileSize - leftWorld, y * _tileSize - topWorld));
        }
      }
      final signature = '${widget.location.latitude.toStringAsFixed(4)}:'
          '${widget.location.longitude.toStringAsFixed(4)}:${constraints.maxWidth.toInt()}:'
          '${constraints.maxHeight.toInt()}';
      if (_gridKey != signature) {
        _gridKey = signature;
        _visibleTiles = tiles.length;
        _errors = 0;
        _reportedAvailable = false;
        _reportedUnavailable = false;
      }
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          for (final tile in tiles)
            Positioned(
              left: tile.left,
              top: tile.top,
              width: _tileSize,
              height: _tileSize,
              child: Image.network(
                'https://tile.openstreetmap.org/$_zoom/${((tile.x % n) + n) % n}/${tile.y}.png',
                fit: BoxFit.cover,
                headers: const <String, String>{
                  'User-Agent': 'ShiaVerse/1.20 (https://github.com/mrghalibspcpu/Shia-Ai)',
                },
                frameBuilder: (context, child, frame, synchronous) {
                  if (frame != null || synchronous) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _loaded();
                    });
                  }
                  return child;
                },
                errorBuilder: (context, error, stack) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _failed();
                  });
                  return const ColoredBox(color: Color(0xFFE8E7DE));
                },
              ),
            ),
        ],
      );
    });
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.86), borderRadius: BorderRadius.circular(5)),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 8, color: Color(0xFF343434))),
        ),
      );
}

/// The diagram itself: rings, cardinal marks, the reader's dot, the Kaaba and
/// one thick arrow between them.
class _QiblaDiagramPainter extends CustomPainter {
  const _QiblaDiagramPainter({
    required this.bearing,
    required this.distanceLabel,
    required this.palette,
    required this.dark,
    required this.streetMapAvailable,
  });

  final double bearing;
  final String distanceLabel;
  final GlassPalette palette;
  final bool dark;
  final bool streetMapAvailable;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 26;
    if (radius <= 0) return;

    if (!streetMapAvailable) {
      // The calm paper-and-grid is an honest offline fallback, not fake roads.
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

    if (streetMapAvailable) {
      // The Kaaba is thousands of kilometres away, not a point on this local
      // street map; label the map-edge arrow as a direction, never a fake pin.
      _label(
        canvas,
        'سمتِ قبلہ',
        tip - direction * 16,
        background: palette.solid,
        foreground: palette.ink,
      );
    } else {
      // On the offline schematic only, the Kaaba icon is a symbolic endpoint.
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
      oldDelegate.dark != dark ||
      oldDelegate.streetMapAvailable != streetMapAvailable;
}
