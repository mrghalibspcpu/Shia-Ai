import 'package:flutter/material.dart';

import '../astro/hijri_calendar.dart';
import '../astro/lunar_hijri.dart';
import '../astro/prayer_format.dart';
import '../services/prayer_controller.dart';
import '../services/prayer_scope.dart';
import '../widgets/glass_panel.dart';

/// The crescent that opens the Hijri month, read for the reader's own sky.
///
/// Nothing here is set by hand: the month begins on the morning after the
/// evening the new moon was visible from the coordinates the prayer card
/// already uses. The page shows its working — the conjunction, the evening it
/// was looked for, and the numbers the sighting committees measure — so the
/// date on the card can be checked against the sky outside.
class CrescentScreen extends StatelessWidget {
  const CrescentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final controller = PrayerScope.of(context);
    final calendar = controller.lunarHijri;
    // Every instant the engine returns is UT; the card speaks the reader's
    // own wall clock, which is what the schedule was built in.
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

    return Scaffold(
      backgroundColor: palette.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('چاند کی رویت',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 26),
        children: <Widget>[
          _MonthCard(month: current, palette: palette, running: true),
          const SizedBox(height: 12),
          _SightingCard(month: current, palette: palette),
          const SizedBox(height: 12),
          _MeasureCard(sighting: current.sighting, palette: palette),
          const SizedBox(height: 12),
          _ComingCard(months: months.skip(1).toList(), palette: palette),
          const SizedBox(height: 12),
          _MethodCard(controller: controller, palette: palette),
        ],
      ),
    );
  }
}

/// One Hijri month: the day it begins, how long it runs, and the evening and
/// the conjunction that decided both.
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

  /// The first civil day (00:00 UT) of the month.
  final DateTime start;

  /// 29 or 30.
  final int length;

  /// The evening the crescent was looked for — the day before [start].
  final CrescentObservation? sighting;

  /// The new moon (conjunction) that opened the month.
  final DateTime conjunction;

  /// The reader's offset from UT, to print the instants above.
  final Duration offset;

  String get nameUrdu => kHijriMonthsUrdu[(month - 1).clamp(0, 11)];

  /// `یکم رمضان 1447`
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

/// The evening the month was opened: what time the Sun went down, how long the
/// Moon hung after it, and what the sky did.
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

/// The numbers behind the verdict — the same ones the sighting committees
/// tables use, in the units they use them.
class _MeasureCard extends StatelessWidget {
  const _MeasureCard({required this.sighting, required this.palette});

  final CrescentObservation? sighting;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    final crescent = sighting;
    if (crescent == null) return const SizedBox.shrink();
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const GlassSectionHeader(title: 'ناپ'),
          const SizedBox(height: 8),
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
    );
  }
}

/// The five months that follow, so a reader can see when Ramadan or Muharram
/// will actually begin where they are.
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

/// How the date is reached, and for which sky.
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
