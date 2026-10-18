import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../astro/compass_math.dart';
import '../astro/prayer_format.dart';
import '../services/prayer_locations.dart';
import 'glass_panel.dart';

/// A location-centred, north-up map with an independent true-north Qibla ray.
///
/// The map tiles are a convenience, not the source of the direction: the ray
/// is drawn from the same saved/GPS coordinates used by the prayer schedule,
/// and continues to work when tiles or the magnetometer are unavailable.
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
  static const int _zoom = 13;
  static const double _tileSize = 256;
  static const double _mapSize = _tileSize * 3;
  static const double _mapUserCenter = _tileSize;
  static const double _mapHeight = 218;
  static const Offset _userPoint = Offset(_mapUserCenter, _mapUserCenter);

  final TransformationController _transform = TransformationController();
  bool _needsCenter = true;
  bool _refreshing = false;

  /// The map opens with the Qibla pointing straight up, so the reader has
  /// nothing to work out: the bright ray is simply "that way". Tapping
  /// شمال اوپر turns the ordinary north-up map back on, and the choice is
  /// remembered for the session.
  bool _qiblaUp = true;

  @override
  void didUpdateWidget(covariant QiblaMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.latitude != widget.location.latitude ||
        oldWidget.location.longitude != widget.location.longitude) {
      _needsCenter = true;
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.accent,
                      ),
                    )
                  : Icon(Icons.my_location, size: 19, color: palette.accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.location.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink),
          ),
          const SizedBox(height: 2),
          Text(
            sourceNote,
            style: TextStyle(fontSize: 12, height: 1.45, color: palette.muted),
          ),
          const SizedBox(height: 8),
          // One tap switches the reading, not a pinch, a drag or a protractor.
          Row(
            children: <Widget>[
              Expanded(
                child: _MapModeChip(
                  icon: Icons.navigation_rounded,
                  label: 'قبلہ اوپر',
                  selected: _qiblaUp,
                  palette: palette,
                  onTap: () => setState(() => _qiblaUp = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MapModeChip(
                  icon: Icons.explore_outlined,
                  label: 'شمال اوپر',
                  selected: !_qiblaUp,
                  palette: palette,
                  onTap: () => setState(() => _qiblaUp = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final viewport = Size(constraints.maxWidth, _mapHeight);
              if (_needsCenter && viewport.width.isFinite && viewport.width > 0) {
                _needsCenter = false;
                _centerLocation(viewport);
              }
              final tileGrid = _tileGrid(widget.location.latitude, widget.location.longitude);
              return ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: SizedBox(
                  height: _mapHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      InteractiveViewer(
                        transformationController: _transform,
                        constrained: false,
                        minScale: 0.45,
                        maxScale: 3.5,
                        boundaryMargin: const EdgeInsets.all(170),
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: _mapSize,
                          height: _mapSize,
                          child: Transform(
                            // Qibla-up rotates the whole map around the
                            // reader's own dot, so the dot never moves and
                            // the ray ends up pointing at the top edge.
                            alignment: Alignment.topLeft,
                            transform: _qiblaUp
                                ? Matrix4.translationValues(_userPoint.dx, _userPoint.dy, 0) *
                                    Matrix4.rotationZ(-widget.bearing * math.pi / 180) *
                                    Matrix4.translationValues(-_userPoint.dx, -_userPoint.dy, 0)
                                : Matrix4.identity(),
                            child: Stack(
                            children: <Widget>[
                              for (final tile in tileGrid)
                                Positioned(
                                  left: tile.left,
                                  top: tile.top,
                                  width: _tileSize,
                                  height: _tileSize,
                                  child: _MapTile(tile: tile, palette: palette),
                                ),
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _QiblaRayPainter(
                                    userPoint: _userPoint,
                                    bearing: widget.bearing,
                                    palette: palette,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _MapTag(
                          icon: _qiblaUp ? Icons.navigation_rounded : Icons.explore_outlined,
                          label: _qiblaUp ? 'قبلہ اوپر — اسی طرف' : 'شمال اوپر',
                          palette: palette,
                        ),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: _MapTag(
                          icon: Icons.zoom_in_map_outlined,
                          label: _qiblaUp ? 'تیر اسی طرف ہے' : 'نقشہ پھیلانے کے لیے دو انگلیاں',
                          palette: palette,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 9),
          Row(
            children: <Widget>[
              Icon(Icons.explore_outlined, size: 17, color: palette.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'قبلہ ${formatBearingUrdu(widget.bearing, compassPointUrdu(widget.bearing))}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: palette.ink),
                ),
              ),
              Text(
                formatKilometresUrdu(widget.distanceKm),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.muted),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _qiblaUp
                ? 'نقشہ خود قبلہ کی سمت گھما ہوا ہے — کھڑے ہو کر اوپر کی طرف منہ کریں، '
                  'کسی کمپاس یا اینگل کی ضرورت نہیں۔ ٹائلز © OpenStreetMap contributors۔'
                : 'سنہری تیر شمالِ حقیقی سے قبلہ کی طرف ہے؛ کمپاس کی ضرورت نہیں۔ '
                  'ٹائلز © OpenStreetMap contributors۔',
            style: TextStyle(fontSize: 11.5, height: 1.45, color: palette.muted),
          ),
        ],
      ),
    );
  }

  void _centerLocation(Size viewport) {
    final scale = math.min(1.0, viewport.width / 460.0).clamp(0.45, 1.0).toDouble();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _transform.value = Matrix4.translationValues(
        viewport.width / 2 - _userPoint.dx * scale,
        viewport.height / 2 - _userPoint.dy * scale,
        0,
      )..scaleByDouble(scale, scale, 1, 1);
    });
  }

  List<_MapTilePosition> _tileGrid(double latitude, double longitude) {
    final lat = latitude.clamp(-85.05112878, 85.05112878).toDouble() * math.pi / 180;
    final count = 1 << _zoom;
    final worldX = ((longitude + 180) / 360) * count;
    final worldY =
        (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * count;
    final baseX = worldX.floor();
    final baseY = worldY.floor().clamp(0, count - 1).toInt();
    final fractionX = worldX - baseX;
    final fractionY = worldY - worldY.floor();
    final tiles = <_MapTilePosition>[];

    for (var dy = -1; dy <= 1; dy++) {
      final y = baseY + dy;
      if (y < 0 || y >= count) continue;
      for (var dx = -1; dx <= 1; dx++) {
        final rawX = baseX + dx;
        final x = ((rawX % count) + count) % count;
        tiles.add(_MapTilePosition(
          x: x,
          y: y,
          zoom: _zoom,
          left: _tileSize + dx * _tileSize - fractionX * _tileSize,
          top: _tileSize + dy * _tileSize - fractionY * _tileSize,
        ));
      }
    }
    return tiles;
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

class _MapTilePosition {
  const _MapTilePosition({
    required this.x,
    required this.y,
    required this.zoom,
    required this.left,
    required this.top,
  });

  final int x;
  final int y;
  final int zoom;
  final double left;
  final double top;

  String get url => 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
}

class _MapTile extends StatelessWidget {
  const _MapTile({required this.tile, required this.palette});

  final _MapTilePosition tile;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      tile.url,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : CustomPaint(
              painter: _OfflineMapTilePainter(
                palette: palette,
                tileX: tile.x,
                tileY: tile.y,
              ),
            ),
      cacheWidth: 256,
      cacheHeight: 256,
      headers: const <String, String>{
        'User-Agent': 'ShiaVerse/1.17.0 (Qibla map; OpenStreetMap tile client)',
      },
      errorBuilder: (context, error, stackTrace) => CustomPaint(
        painter: _OfflineMapTilePainter(
          palette: palette,
          tileX: tile.x,
          tileY: tile.y,
        ),
      ),
    );
  }
}

class _OfflineMapTilePainter extends CustomPainter {
  const _OfflineMapTilePainter({
    required this.palette,
    required this.tileX,
    required this.tileY,
  });

  final GlassPalette palette;
  final int tileX;
  final int tileY;

  @override
  void paint(Canvas canvas, Size size) {
    final dark = palette.isDark;
    final background = Paint()..color = dark ? const Color(0xFF233333) : const Color(0xFFE6E9D9);
    canvas.drawRect(Offset.zero & size, background);

    final seed = (tileX * 73 + tileY * 137) % 7;
    final park = Paint()..color = const Color(0x3378A981);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(25 + seed * 3.0, 35 + seed * 2.0, 69, 45),
        const Radius.circular(16),
      ),
      park,
    );
    final road = Paint()
      ..color = dark ? const Color(0xFF59635B) : const Color(0xFFF8F4E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final mainRoad = Path()
      ..moveTo(-20, 195 - seed * 4.0)
      ..cubicTo(55, 176 - seed * 2.0, 144, 154 + seed * 2.0, 276, 118 + seed * 3.0);
    canvas.drawPath(mainRoad, road);
    final street = Paint()
      ..color = dark ? const Color(0xFF46554E) : const Color(0xFFFAF8F1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    for (var index = 0; index < 5; index++) {
      final x = 18.0 + index * 56.0 + seed;
      final path = Path()
        ..moveTo(x, -10)
        ..cubicTo(x - 7, 65, x + 10, 170, x + 2, 266);
      canvas.drawPath(path, street);
    }
    for (var index = 0; index < 4; index++) {
      final y = 25.0 + index * 58.0 + seed * 2;
      final path = Path()
        ..moveTo(-10, y)
        ..cubicTo(68, y + 8, 180, y - 7, 266, y + 4);
      canvas.drawPath(path, street);
    }
    final block = Paint()
      ..color = (dark ? Colors.white : const Color(0xFF53604F)).withValues(alpha: 0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(const Rect.fromLTWH(5, 5, 246, 246), block);
  }

  @override
  bool shouldRepaint(_OfflineMapTilePainter oldDelegate) =>
      oldDelegate.palette != palette || oldDelegate.tileX != tileX || oldDelegate.tileY != tileY;
}

class _QiblaRayPainter extends CustomPainter {
  const _QiblaRayPainter({
    required this.userPoint,
    required this.bearing,
    required this.palette,
  });

  final Offset userPoint;
  final double bearing;
  final GlassPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final angle = bearing * math.pi / 180;
    final direction = Offset(math.sin(angle), -math.cos(angle));
    const rayLength = 188.0;
    final tip = userPoint + direction * rayLength;
    final unitPerpendicular = Offset(-direction.dy, direction.dx);
    final arrowBase = tip - direction * 15;
    final arrow = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(arrowBase.dx + unitPerpendicular.dx * 10, arrowBase.dy + unitPerpendicular.dy * 10)
      ..lineTo(arrowBase.dx - unitPerpendicular.dx * 10, arrowBase.dy - unitPerpendicular.dy * 10)
      ..close();

    canvas.drawLine(
      userPoint,
      tip,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      userPoint,
      tip,
      Paint()
        ..color = palette.accent
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(arrow, Paint()..color = palette.accent);

    canvas.drawCircle(userPoint, 12, Paint()..color = Colors.white);
    canvas.drawCircle(userPoint, 9, Paint()..color = palette.accent);
    canvas.drawCircle(userPoint, 3, Paint()..color = Colors.white);

    _drawTag(canvas, 'آپ', userPoint + const Offset(0, 20), palette);
    _drawTag(canvas, 'قبلہ', tip - direction * 15, palette);
  }

  void _drawTag(Canvas canvas, String label, Offset point, GlassPalette palette) {
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: palette.ink,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    final width = text.width + 14;
    final height = text.height + 8;
    final rect = Rect.fromCenter(center: point, width: width, height: height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(9)),
      Paint()..color = palette.solid.withValues(alpha: 0.94),
    );
    text.paint(canvas, Offset(rect.left + 7, rect.top + 4));
  }

  @override
  bool shouldRepaint(_QiblaRayPainter oldDelegate) =>
      oldDelegate.bearing != bearing || oldDelegate.palette != palette;
}

class _MapTag extends StatelessWidget {
  const _MapTag({
    required this.icon,
    required this.label,
    required this.palette,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final GlassPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.solid.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: compact ? 12 : 14, color: palette.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// One half of the map's two-mode switch.
class _MapModeChip extends StatelessWidget {
  const _MapModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final GlassPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? palette.accent.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? palette.accent.withValues(alpha: 0.65) : palette.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 16, color: selected ? palette.accent : palette.muted),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? palette.ink : palette.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
