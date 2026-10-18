import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../astro/hijri_calendar.dart';
import '../astro/lunar_hijri.dart';
import '../astro/prayer_format.dart';
import '../services/prayer_controller.dart';
import '../services/prayer_scope.dart';
import '../widgets/glass_panel.dart';

/// The crescent that opens the Hijri month, read for the reader's own sky.
///
/// The visible summary is written for everyday use; the observation times and
/// optional scientific measurements remain available below for readers who
/// want to check the calculation.
class CrescentScreen extends StatelessWidget {
  const CrescentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final controller = PrayerScope.of(context);
    final calendar = controller.lunarHijri;
    final offset = controller.schedule.zoneOffset;
    final today = controller.hijriToday.date;

    final months = <_MonthRow>[];
    var year = today.year;
    var month = today.month;
    for (var step = 0; step < 6; step++) {
      months.add(_MonthRow(
        year: year,
        month: month,
        start: calendar.civilStartOfMonth(year, month),
        length: calendar.lengthOfMonth(year, month),
        sighting: calendar.sightingOfMonth(year, month),
        conjunction: calendar.conjunctionOfMonth(year, month),
        offset: offset,
      ));
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
    final current = months.first;
    // The shared clock is a UTC-coded local wall clock. Remove the location's
    // offset before comparing it to the astronomical conjunction (UT).
    final instant = controller.now.value.toUtc().subtract(offset);
    final phase = _lunarPhase(instant, current.conjunction);

    return Scaffold(
      backgroundColor: palette.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('چاند کی رویت',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(
              'assets/images/chapter_wallpaper_dark.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(color: palette.scaffold),
            ),
          ),
          Positioned.fill(
            child: ColoredBox(
              color: palette.scaffold.withValues(alpha: palette.isDark ? 0.7 : 0.88),
            ),
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 26),
            children: <Widget>[
              _CrescentHero(
                phase: phase,
                today: today,
                location: controller.location.label,
                palette: palette,
              ),
              const SizedBox(height: 12),
              _MonthCard(month: current, palette: palette, running: true),
              const SizedBox(height: 12),
              _SightingCard(month: current, palette: palette),
              const SizedBox(height: 8),
              _MeasureCard(sighting: current.sighting, palette: palette),
              const SizedBox(height: 8),
              _ComingCard(months: months.skip(1).toList(), palette: palette),
              const SizedBox(height: 8),
              _MethodCard(controller: controller, palette: palette),
            ],
          ),
        ],
      ),
    );
  }
}

double _lunarPhase(DateTime instant, DateTime conjunction) {
  const synodicMonth = 29.530588853;
  final ageDays = instant.difference(conjunction).inMicroseconds / 86400000000.0;
  final fraction = (ageDays / synodicMonth) % 1.0;
  return (fraction + 1.0) % 1.0;
}

String _phaseNameUrdu(double phase) {
  if (phase < 0.04 || phase > 0.96) return 'نیا چاند';
  if (phase < 0.21) return 'ہلالِ افزوں';
  if (phase < 0.29) return 'تربیعِ اوّل';
  if (phase < 0.46) return 'بڑھتا ہوا چاند';
  if (phase < 0.54) return 'بدر';
  if (phase < 0.71) return 'گھٹتا ہوا چاند';
  if (phase < 0.79) return 'تربیعِ آخر';
  return 'ہلالِ گھٹتا ہوا';
}

class _CrescentHero extends StatelessWidget {
  const _CrescentHero({
    required this.phase,
    required this.today,
    required this.location,
    required this.palette,
  });

  final double phase;
  final HijriDate today;
  final String location;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    final illumination = ((1 - math.cos(phase * 2 * math.pi)) * 50).round();
    return Container(
      height: 156,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        image: const DecorationImage(
          image: AssetImage('assets/images/sky_night.jpg'),
          fit: BoxFit.cover,
        ),
        border: Border.all(color: palette.gold.withValues(alpha: 0.8)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: palette.shadow, blurRadius: 18, offset: const Offset(0, 7)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: <Color>[Color(0xE60B2929), Color(0xB20A1D25), Color(0xE607111B)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            child: Row(
              children: <Widget>[
                CustomPaint(
                  size: const Size.square(104),
                  painter: _MoonPhasePainter(phase: phase),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('آج چاند کیسا ہے؟', style: TextStyle(fontSize: 14, color: palette.gold)),
                      const SizedBox(height: 3),
                      Text(
                        _phaseNameUrdu(phase),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          height: 1.3,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تقریباً $illumination٪ روشن',
                        style: const TextStyle(fontSize: 13, color: Color(0xFFE8E5D6)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatHijriUrdu(today)} · $location',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFFCED8D3)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small vector lunar disc. The lit surface is computed from the phase's
/// illuminated fraction, so the graphic and percentage follow one model.
class _MoonPhasePainter extends CustomPainter {
  const _MoonPhasePainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.39;
    final moon = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(center, radius + 6, Paint()..color = const Color(0x33E6C885));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: <Color>[Color(0xFF46545A), Color(0xFF18252C)],
        ).createShader(moon),
    );

    final illuminated = (1 - math.cos(phase * 2 * math.pi)) / 2;
    final offset = _shadowOffset(radius, 1 - illuminated);
    final darkMoon = Path()
      ..addOval(Rect.fromCircle(
        center: center + Offset(phase < 0.5 ? -offset : offset, 0),
        radius: radius,
      ));
    final disk = Path()..addOval(moon);
    final lightPath = offset <= 0.001
        ? Path()
        : (offset >= radius * 2 - 0.001
            ? disk
            : Path.combine(PathOperation.difference, disk, darkMoon));
    if (lightPath.computeMetrics().isNotEmpty) {
      canvas.drawPath(
        lightPath,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.5),
            colors: <Color>[Color(0xFFFFF3CC), Color(0xFFE1C47E), Color(0xFFA98040)],
          ).createShader(moon),
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xAAE9D6A4),
    );
    for (final star in <Offset>[
      Offset(size.width * 0.13, size.height * 0.28),
      Offset(size.width * 0.82, size.height * 0.19),
      Offset(size.width * 0.82, size.height * 0.77),
      Offset(size.width * 0.17, size.height * 0.75),
    ]) {
      canvas.drawCircle(star, 1.4, Paint()..color = const Color(0xFFD9C992));
    }
  }

  double _shadowOffset(double radius, double overlapFraction) {
    if (overlapFraction >= 1) return 0;
    if (overlapFraction <= 0) return radius * 2;
    var low = 0.0;
    var high = radius * 2;
    for (var step = 0; step < 28; step++) {
      final distance = (low + high) / 2;
      final ratio = distance / (2 * radius);
      final overlap =
          (2 * math.acos(ratio) - 2 * ratio * math.sqrt(1 - ratio * ratio)) / math.pi;
      if (overlap > overlapFraction) {
        low = distance;
      } else {
        high = distance;
      }
    }
    return (low + high) / 2;
  }

  @override
  bool shouldRepaint(_MoonPhasePainter oldDelegate) => oldDelegate.phase != phase;
}

class _MonthRow {
  const _MonthRow({
    required this.year,
    required this.month,
    required this.start,
    required this.length,
    required this.sighting,
    required this.conjunction,
    required this.offset,
  });

  final int year;
  final int month;
  final DateTime start;
  final int length;
  final CrescentObservation? sighting;
  final DateTime conjunction;
  final Duration offset;

  String get nameUrdu => kHijriMonthsUrdu[(month - 1).clamp(0, 11)];
  String get titleUrdu => 'یکم $nameUrdu $yearھ';
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.month, required this.palette, required this.running});

  final _MonthRow month;
  final GlassPalette palette;
  final bool running;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GlassSectionHeader(title: running ? 'جاری مہینہ' : 'مہینہ'),
          const SizedBox(height: 8),
          Text(
            month.titleUrdu,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              height: 1.35,
              fontWeight: FontWeight.w800,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatDateUrdu(month.start),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: palette.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _Stat(
                  label: 'مہینے کی لمبائی',
                  value: '${formatCount(month.length)} دن',
                  icon: Icons.calendar_month_outlined,
                  palette: palette,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'مقارنہ (نیا چاند)',
                  value: formatClockUrdu(month.conjunction.add(month.offset)),
                  icon: Icons.brightness_2_outlined,
                  palette: palette,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SightingCard extends StatelessWidget {
  const _SightingCard({required this.month, required this.palette});

  final _MonthRow month;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    final sighting = month.sighting;
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const GlassSectionHeader(title: 'رویت کی شام'),
          const SizedBox(height: 8),
          if (sighting == null)
            Text(
              'اس مقام پر یہ شام مکمل نہیں ہوتی (قطبی علاقوں میں سورج ڈوبتا ہی نہیں) — '
              'ایسے مقامات کے لیے قریب ترین شہر یا مکہ کا حساب استعمال کیا جاتا ہے۔',
              style: TextStyle(fontSize: 13, height: 1.6, color: palette.muted),
            )
          else ...<Widget>[
            _InfoRow(
              label: 'شام کی تاریخ',
              value: formatDateUrdu(sighting.sunset.add(month.offset)),
              palette: palette,
              icon: Icons.event_outlined,
            ),
            _InfoRow(
              label: 'غروبِ آفتاب',
              value: formatClockUrdu(sighting.sunset.add(month.offset)),
              palette: palette,
              icon: Icons.wb_twilight,
            ),
            _InfoRow(
              label: 'غروبِ ماہتاب',
              value: formatClockUrdu(sighting.moonset.add(month.offset)),
              palette: palette,
              icon: Icons.nights_stay_outlined,
            ),
            _InfoRow(
              label: 'چاند سورج کے بعد',
              value: '${formatCount(sighting.lagMinutes.round())} منٹ',
              palette: palette,
              icon: Icons.timelapse_outlined,
            ),
            _InfoRow(
              label: 'بہترین وقتِ مشاہدہ',
              value: formatClockUrdu(sighting.bestTime.add(month.offset)),
              palette: palette,
              icon: Icons.remove_red_eye_outlined,
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Text(
                sighting.verdictUrdu(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: palette.accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MeasureCard extends StatelessWidget {
  const _MeasureCard({required this.sighting, required this.palette});

  final CrescentObservation? sighting;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    final crescent = sighting;
    if (crescent == null) return const SizedBox.shrink();
    return GlassPanel(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.science_outlined, color: palette.accent),
          title: Text('فلکیاتی پیمائشیں',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink)),
          subtitle: Text('اختیاری تفصیل', style: TextStyle(fontSize: 12, color: palette.muted)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          children: <Widget>[
            _InfoRow(
              label: 'کشیدگی (ARCL)',
              value: ltr('${crescent.arcOfLight.toStringAsFixed(2)}°'),
              palette: palette,
              icon: Icons.straighten,
            ),
            _InfoRow(
              label: 'بلندی کا فرق (ARCV)',
              value: ltr('${crescent.arcOfVision.toStringAsFixed(2)}°'),
              palette: palette,
              icon: Icons.height,
            ),
            _InfoRow(
              label: 'سمت کا فرق (DAZ)',
              value: ltr('${crescent.relativeAzimuth.toStringAsFixed(2)}°'),
              palette: palette,
              icon: Icons.explore_outlined,
            ),
            _InfoRow(
              label: 'ہلال کی چوڑائی (W)',
              value: ltr('${crescent.crescentWidth.toStringAsFixed(3)}′'),
              palette: palette,
              icon: Icons.brightness_1_outlined,
            ),
            _InfoRow(
              label: 'نظر آنے کا عدد (V)',
              value: ltr(crescent.visibility.toStringAsFixed(2)),
              palette: palette,
              icon: Icons.visibility_outlined,
            ),
            const SizedBox(height: 6),
            Text(
              'V بڑا ہو تو ہلال آسانی سے نظر آتا ہے: 5.65 سے اوپر ننگی آنکھ کے لیے، '
              '2 سے اوپر اچھے موسم میں، اور 0.96− تک دوربین سے۔',
              style: TextStyle(fontSize: 12.5, height: 1.5, color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingCard extends StatelessWidget {
  const _ComingCard({required this.months, required this.palette});

  final List<_MonthRow> months;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const GlassSectionHeader(title: 'آنے والے مہینے'),
          const SizedBox(height: 8),
          for (final month in months)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          month.titleUrdu,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatDayMonthYearUrdu(month.start),
                          style: TextStyle(fontSize: 12, color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      month.sighting?.verdictUrdu() ?? '—',
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      style: TextStyle(fontSize: 11.5, height: 1.35, color: palette.accent),
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

class _MethodCard extends StatelessWidget {
  const _MethodCard({required this.controller, required this.palette});

  final PrayerController controller;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    final location = controller.location;
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const GlassSectionHeader(title: 'طریقۂ کار'),
          const SizedBox(height: 8),
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
          const SizedBox(height: 6),
          Text(
            'چاند اور سورج کی جگہیں مکمل فلکیاتی سلسلوں (Meeus، باب 47 اور 25) سے نکالی جاتی ہیں، '
            'غروب اور ماہتاب کا غروب مقام کے افق پر، اور پھر Odeh (2004ء) کا معیار لگایا جاتا ہے: '
            'غروبِ آفتاب کے بعد پانچ اور نو کے تناسب (4/9) سے بہترین وقت نکالا جاتا ہے، اور اسی لمحے '
            'ہلال کی چوڑائی و بلندی سے V حاصل کیا جاتا ہے۔ جس شام چاند پہلی بار نظر آئے، اگلی صبح سے '
            'نیا مہینہ شروع ہوتا ہے — اور ہر مہینہ 29 یا 30 دن کا ہوتا ہے۔',
            style: TextStyle(fontSize: 12.5, height: 1.65, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon, required this.palette});

  final String label;
  final String value;
  final IconData icon;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(icon, size: 18, color: palette.accent),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: palette.ink),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: palette.muted),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.palette, required this.icon});

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
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}
