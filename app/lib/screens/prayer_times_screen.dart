import 'dart:async';

import 'package:flutter/material.dart';

import '../astro/compass_math.dart' show compassPointUrdu;
import '../astro/prayer_calculator.dart';
import '../astro/prayer_format.dart';
import '../services/prayer_controller.dart';
import '../services/prayer_locations.dart';
import '../services/prayer_scope.dart';
import '../widgets/glass_panel.dart';
import 'qibla_screen.dart';
import 'tasbeeh_screen.dart';

/// Shia (Jafari) prayer timings for the reader's own location: a hero header
/// painted over the mosque wallpaper, the day's times on glass, the live
/// countdown to the next prayer, and the alert controls.
class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  Future<void> _refreshLocation() async {
    await PrayerScope.of(context).refreshLocation();
  }

  Future<void> _openLocationSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LocationPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final controller = PrayerScope.of(context);
    final schedule = controller.schedule;

    return Scaffold(
      backgroundColor: palette.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('نماز کے اوقات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: <Widget>[
          IconButton(
            tooltip: 'قبلہ نما',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const QiblaScreen()),
            ),
            icon: const Icon(Icons.explore_outlined),
          ),
          IconButton(
            tooltip: 'میرا مقام تازہ کریں',
            onPressed: controller.loadingLocation ? null : _refreshLocation,
            icon: controller.loadingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 26),
        children: <Widget>[
          _HeroHeader(schedule: schedule, controller: controller),
          const SizedBox(height: 12),
          _NextPrayerCard(controller: controller, schedule: schedule),
          const SizedBox(height: 12),
          _DetailTiles(schedule: schedule, controller: controller),
          const SizedBox(height: 12),
          _AlertControls(controller: controller, onPickLocation: _openLocationSheet),
          const SizedBox(height: 12),
          _FiqhNote(schedule: schedule),
        ],
      ),
    );
  }
}

/// The hero wallpaper: mosque silhouette under a soft dawn sky, the place and
/// the next prayer written over it, and the day's times on a glass row along
/// the bottom edge.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.schedule, required this.controller});

  final PrayerSchedule schedule;
  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(
              'assets/images/prayer_hero.jpg',
              fit: BoxFit.cover,
              // Decoded at roughly the size it is painted: the asset is 760 px
              // wide and the card never shows more than ~400 logical pixels.
              cacheWidth: 960,
              errorBuilder: (_, __, ___) => ColoredBox(color: palette.solid),
            ),
          ),
          // A cream veil that fades downward, so the header text keeps its
          // contrast while the mosque at the bottom stays visible under glass.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    palette.scaffold.withValues(alpha: 0.92),
                    palette.scaffold.withValues(alpha: 0.55),
                    palette.scaffold.withValues(alpha: 0.06),
                  ],
                  stops: const <double>[0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _HeroTitleRow(controller: controller),
                const SizedBox(height: 8),
                _HeroLocationRow(controller: controller),
                const SizedBox(height: 10),
                _HeroNextPrayer(controller: controller),
                const SizedBox(height: 14),
                _TimingGlassRow(schedule: schedule, controller: controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTitleRow extends StatelessWidget {
  const _HeroTitleRow({required this.controller});

  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return Row(
      children: <Widget>[
        Icon(Icons.mosque, size: 18, color: palette.accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'شیعہ اثنا عشری — جعفری اوقات',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
        ),
        const SizedBox(width: 6),
        GlassChip(
          label: 'تسبیح',
          icon: Icons.touch_app_outlined,
          dense: true,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const TasbeehScreen()),
          ),
        ),
      ],
    );
  }
}

class _HeroLocationRow extends StatelessWidget {
  const _HeroLocationRow({required this.controller});

  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final location = controller.location;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.place_outlined, size: 14, color: palette.gold),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                location.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              location.source.labelUrdu,
              style: TextStyle(fontSize: 10, color: palette.muted),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${formatDateUrdu(controller.now.value)}  •  '
          '${formatCoordinatesUrdu(location.latitude, location.longitude)}',
          maxLines: 2,
          style: TextStyle(fontSize: 10.5, height: 1.35, color: palette.muted),
        ),
      ],
    );
  }
}

/// The "next prayer" headline with its live countdown and the window progress.
class _HeroNextPrayer extends StatelessWidget {
  const _HeroNextPrayer({required this.controller});

  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return ValueListenableBuilder<DateTime>(
      valueListenable: controller.now,
      builder: (context, now, _) {
        final schedule = controller.schedule;
        final next = schedule.nextEntry(now);
        final window = schedule.window(now);
        final remaining = next.time.difference(now);
        final windowProgress = _windowProgress(schedule, window, now);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'اگلی نماز',
                    style: TextStyle(fontSize: 10.5, color: palette.muted),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    next.marker.labelUrdu,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: palette.accent,
                    ),
                  ),
                  Text(
                    formatCountdownUrdu(remaining),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: palette.gold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 108,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${window.previousNight ? 'گزشتہ ' : ''}${window.marker.labelUrdu} کا وقت',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: palette.muted),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: windowProgress,
                      minHeight: 5,
                      backgroundColor: palette.track,
                      valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'اختتام ${formatClockUrdu(window.endsAt)}',
                    style: TextStyle(fontSize: 9.5, color: palette.muted),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The five obligatory prayers on one glass row, plus the astronomical markers
/// underneath. Built so the row can never clip: every cell shrinks its own
/// digits rather than overflowing, and the markers wrap instead of pushing.
class _TimingGlassRow extends StatelessWidget {
  const _TimingGlassRow({required this.schedule, required this.controller});

  final PrayerSchedule schedule;
  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: controller.now,
      builder: (context, now, _) {
        final window = schedule.window(now);
        final next = schedule.nextEntry(now);
        return GlassPanel(
          radius: 20,
          blur: 12,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final entry in schedule.obligatory)
                    Expanded(
                      child: _PrayerCell(
                        entry: entry,
                        active: !window.previousNight && window.marker == entry.marker,
                        next: next.marker == entry.marker && !next.tomorrow,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  for (final entry in schedule.markers)
                    GlassChip(
                      label: '${entry.labelUrdu} ${formatClockDigitsUrdu(entry.time)}',
                      icon: switch (entry.marker) {
                        PrayerMarker.sunrise => Icons.wb_twilight,
                        PrayerMarker.sunset => Icons.nights_stay_outlined,
                        _ => Icons.dark_mode_outlined,
                      },
                      dense: true,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrayerCell extends StatelessWidget {
  const _PrayerCell({required this.entry, required this.active, required this.next});

  final PrayerEntry entry;
  final bool active;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final tint = active ? palette.accent : (next ? palette.gold : palette.muted);
    final digits = formatClockDigitsUrdu(entry.time);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
      decoration: BoxDecoration(
        color: active ? palette.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? palette.accent.withValues(alpha: 0.4)
              : (next ? palette.gold.withValues(alpha: 0.3) : Colors.transparent),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            entry.labelUrdu,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.25,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? palette.accent : palette.ink,
            ),
          ),
          const SizedBox(height: 3),
          // The digits are resized rather than wrapped: an Urdu label plus a
          // clock never grows wider than a fifth of the card.
          SizedBox(
            height: 18,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                digits,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: tint,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dayPartUrdu(entry.time.hour),
            maxLines: 1,
            style: TextStyle(fontSize: 9.5, height: 1.2, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

/// The live card under the hero: which window is running, how long is left of
/// it, the post-prayer shortcut to Tasbeeh-e-Zahra (s.a.), and the Qibla.
class _NextPrayerCard extends StatelessWidget {
  const _NextPrayerCard({required this.controller, required this.schedule});

  final PrayerController controller;
  final PrayerSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return ValueListenableBuilder<DateTime>(
      valueListenable: controller.now,
      builder: (context, now, _) {
        final window = schedule.window(now);
        final next = schedule.nextEntry(now);
        final justPrayed = schedule.justPrayed(now);
        final remaining = window.endsAt.difference(now);

        return GlassPanel(
          radius: 20,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: palette.accentSoft,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.timelapse, size: 14, color: palette.accent),
                        const SizedBox(width: 5),
                        Text(
                          '${window.marker.labelUrdu} کا وقت جاری',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: palette.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'اگلی: ${next.marker.labelUrdu}',
                    style: TextStyle(fontSize: 11.5, color: palette.muted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'اس وقفے کے اختتام میں',
                          style: TextStyle(fontSize: 10.5, color: palette.muted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatCountdownUrdu(remaining),
                          style: TextStyle(
                            fontSize: 22,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: palette.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        'کل سے باقی',
                        style: TextStyle(fontSize: 10.5, color: palette.muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatClockUrdu(window.endsAt),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.gold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: palette.track),
              const SizedBox(height: 10),
              _QiblaStrip(controller: controller, schedule: schedule),
              if (justPrayed != null) ...<Widget>[
                const SizedBox(height: 12),
                _PostPrayerBanner(marker: justPrayed),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _QiblaStrip extends StatelessWidget {
  const _QiblaStrip({required this.controller, required this.schedule});

  final PrayerController controller;
  final PrayerSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final bearing = controller.qiblaBearing;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const QiblaScreen()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.goldSoft,
                border: Border.all(color: palette.gold.withValues(alpha: 0.4)),
              ),
              child: Icon(Icons.explore, size: 19, color: palette.gold),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'سمتِ قبلہ: ${formatBearingUrdu(bearing, compassPointUrdu(bearing))}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                  Text(
                    'کعبہ سے فاصلہ ${urduDigits(controller.distanceToKaabaKm.round().toString())} کلومیٹر',
                    style: TextStyle(fontSize: 10.5, color: palette.muted),
                  ),
                ],
              ),
            ),
            Text(
              'کھولیں',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: palette.accent,
              ),
            ),
            Icon(Icons.chevron_left, size: 18, color: palette.accent),
          ],
        ),
      ),
    );
  }
}

/// "You have just prayed — start Tasbeeh-e-Zahra (s.a.)", offered by itself in
/// the half hour after a prayer begins or after Fajr's window closes.
class _PostPrayerBanner extends StatelessWidget {
  const _PostPrayerBanner({required this.marker});

  final PrayerMarker marker;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: palette.goldSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.notifications_active, size: 18, color: palette.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${marker.labelUrdu} کا وقت ہو گیا',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
                Text(
                  'نماز کے بعد تسبیحِ زہرا (س) پڑھیں',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.accent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TasbeehScreen(startWithZahra: true),
              ),
            ),
            child: const Text('شروع کریں', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// The day's finer numbers: Nisf al-Layl, the last third of the night, the
/// method and its angles, the Qibla, and where the coordinates came from.
class _DetailTiles extends StatelessWidget {
  const _DetailTiles({required this.schedule, required this.controller});

  final PrayerSchedule schedule;
  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final fajr = schedule.entryFor(PrayerMarker.fajr).time;
    final maghrib = schedule.entryFor(PrayerMarker.maghrib).time;
    final nightSeconds = schedule.fajrTomorrow.difference(maghrib).inSeconds;
    final lastThird = maghrib.add(Duration(seconds: (nightSeconds * 2 / 3).round()));
    final midnight = schedule.entryFor(PrayerMarker.midnight).time;
    final location = controller.location;

    final maghribMidnight = PrayerCalculator.maghribMidnight(
      schedule.entryFor(PrayerMarker.maghrib).time,
      schedule.fajrTomorrow,
    );

    final tiles = <(IconData, String, String, String?)>[
      (
        Icons.brightness_3,
        'نصف شب (شرعی)',
        formatClockUrdu(midnight),
        'غروبِ آفتاب تا فجر کا وسط',
      ),
      (
        Icons.brightness_3_outlined,
        'نصف شب (مغرب سے)',
        formatClockUrdu(maghribMidnight),
        'مغرب تا فجر — احتیاطاً',
      ),
      (
        Icons.nightlight_round,
        'آخری تہائی رات',
        formatClockUrdu(lastThird),
        'نمازِ شب کا وقت',
      ),
      (
        Icons.calculate_outlined,
        'طریقۂ حساب',
        schedule.methodLabel.split('—').first.trim(),
        'مغرب ${urduDigits(schedule.maghribAngle.toStringAsFixed(1))}° پر',
      ),
      (
        Icons.explore_outlined,
        'قبلہ (شمالِ حقیقی سے)',
        formatBearingUrdu(controller.qiblaBearing, compassPointUrdu(controller.qiblaBearing)),
        'فاصلہ ${urduDigits(controller.distanceToKaabaKm.round().toString())} کلومیٹر',
      ),
      (
        Icons.my_location,
        'مقام کا ماخذ',
        location.source.labelUrdu,
        location.accuracyMeters == null
            ? 'محفوظ شدہ متناسقات'
            : 'درستگی ~${urduDigits(location.accuracyMeters!.round().toString())} میٹر',
      ),
      (
        Icons.schedule,
        'فجر تا طلوع',
        formatCountdownUrdu(
          schedule.entryFor(PrayerMarker.sunrise).time.difference(fajr),
        ),
        'صبح کا پہلا وقفہ',
      ),
    ];

    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const GlassSectionHeader(title: 'مزید اوقات و تفصیل'),
          const SizedBox(height: 10),
          for (int index = 0; index < tiles.length; index += 2) ...<Widget>[
            // IntrinsicHeight measures the taller of the two tiles and gives
            // the shorter one the same height, so a pair stays level without
            // asking a Row to stretch inside an unbounded Column.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: _DetailTile(tile: tiles[index], palette: palette)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: index + 1 < tiles.length
                        ? _DetailTile(tile: tiles[index + 1], palette: palette)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            if (index + 2 < tiles.length) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.tile, required this.palette});

  final (IconData, String, String, String?) tile;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    final (icon, title, value, note) = tile;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.solid.withValues(alpha: palette.isDark ? 0.55 : 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.track),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 14, color: palette.accent),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: palette.ink,
              ),
            ),
          ),
          if (note != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              note,
              maxLines: 2,
              style: TextStyle(fontSize: 10, height: 1.3, color: palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sound, vibration, calculation method, and the manual location picker.
class _AlertControls extends StatelessWidget {
  const _AlertControls({required this.controller, required this.onPickLocation});

  final PrayerController controller;
  final VoidCallback onPickLocation;

  Future<void> _pickPreset(BuildContext context) async {
    final chosen = await showModalBottomSheet<(String, String)>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = GlassPalette.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GlassPanel(
              radius: 22,
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const GlassSectionHeader(title: 'طریقۂ حساب'),
                  const SizedBox(height: 10),
                  for (final (key, label, params) in PrayerCalculator.presets())
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        label,
                        style: TextStyle(fontSize: 13.5, color: palette.ink),
                      ),
                      subtitle: Text(
                        'مغرب: سورج ${urduDigits((params.maghribAngle ?? 4).toStringAsFixed(1))}° '
                        'نیچے — زوالِ سرخی',
                        style: TextStyle(fontSize: 11, color: palette.muted),
                      ),
                      trailing: controller.presetKey == key
                          ? Icon(Icons.check_circle, color: palette.accent)
                          : Icon(Icons.circle_outlined, color: palette.muted),
                      onTap: () => Navigator.of(sheetContext).pop((key, label)),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'دونوں طریقے شیعہ اثنا عشری (لیوا Institute، قم) کے مطابق ہیں؛ '
                    'فرق صرف فجر کے زاویے اور احتیاط میں ہے۔',
                    style: TextStyle(fontSize: 10.5, height: 1.4, color: palette.muted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (chosen == null) return;
    controller.setPreset(chosen.$1);
  }

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const GlassSectionHeader(title: 'الرٹ اور ترتیبات'),
          const SizedBox(height: 6),
          _ToggleRow(
            icon: Icons.notifications_active_outlined,
            label: 'نماز کے وقت اطلاع (چائم + وائبریشن)',
            value: controller.alertsEnabled,
            onChanged: controller.setAlertsEnabled,
            palette: palette,
          ),
          _ToggleRow(
            icon: Icons.volume_up_outlined,
            label: 'اذان بجائے نرم چائم',
            value: controller.soundEnabled,
            onChanged: controller.setSoundEnabled,
            palette: palette,
          ),
          _ToggleRow(
            icon: Icons.vibration,
            label: 'وائبریشن (ہلکا جھٹکا)',
            value: controller.hapticsEnabled,
            onChanged: controller.setHapticsEnabled,
            palette: palette,
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: GlassChip(
                  label: 'طریقہ: ${controller.presetKey == 'leva' ? 'تہران (۱۷.۷°)' : 'جعفری (۱۶°)'}',
                  icon: Icons.calculate_outlined,
                  onTap: () => unawaited(_pickPreset(context)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassChip(
                  label: 'شہر منتخب کریں',
                  icon: Icons.location_city,
                  onTap: onPickLocation,
                  tone: palette.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 17, color: value ? palette.accent : palette.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.3,
              color: palette.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 34,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ),
      ],
    );
  }
}

/// The footnote every printed timetable carries: these are computed times, and
/// the reader should know which angles produced them.
class _FiqhNote extends StatelessWidget {
  const _FiqhNote({required this.schedule});

  final PrayerSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return GlassPanel(
      radius: 18,
      padding: const EdgeInsets.all(12),
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.info_outline, size: 15, color: palette.accent),
              const SizedBox(width: 6),
              Text(
                'طریقہ اور احتیاط',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'اوقاتِ نماز سورج کے حقیقی زاویوں سے حساب ہوتے ہیں: '
            '${schedule.methodLabel}، مغرب سورج ${urduDigits(schedule.maghribAngle.toStringAsFixed(1))}° '
            'نیچے آنے پر (زوالِ سرخی)، اور شرعی نصف شب غروبِ آفتاب تا فجر کے وسط پر۔ '
            'مغرب سے نصف شب کا حساب الگ دیا گیا ہے (احتیاط)۔ '
            'شہروں کے اوقات میں چند منٹ کا فرق ممکن ہے — اپنے شہر کے سرکاری اوقات سے تصدیق کر لیں۔',
            style: TextStyle(fontSize: 11, height: 1.6, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

/// Manual location: a searchable list of cities plus raw coordinates. Used when
/// the GPS is denied, switched off, or plainly wrong.
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key});

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final controller = PrayerScope.of(context);
    final results = PrayerLocations.searchCities(_query.text);
    final coordinates = PrayerLocations.fromQuery(_query.text);
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        builder: (context, scrollController) => GlassPanel(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.location_on_outlined, size: 18, color: palette.accent),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'مقام منتخب کریں',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'بند کریں',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'شہر کا نام یا متناسقات (مثلاً 33.68, 73.04)',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(_query.clear),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  GlassActionButton(
                    icon: Icons.gps_fixed,
                    label: 'جی پی ایس',
                    onTap: controller.loadingLocation
                        ? null
                        : () async {
                            await controller.refreshLocation();
                            if (context.mounted) Navigator.of(context).pop();
                          },
                    busy: controller.loadingLocation,
                  ),
                  const SizedBox(width: 8),
                  if (coordinates != null)
                    GlassActionButton(
                      icon: Icons.pin_drop_outlined,
                      label: 'یہ متناسقات',
                      selected: true,
                      onTap: () async {
                        await controller.useCoordinates(
                          coordinates.latitude,
                          coordinates.longitude,
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final city = results[index];
                    final selected =
                        controller.location.source == LocationSource.manual &&
                            (controller.location.latitude - city.latitude).abs() < 0.01 &&
                            (controller.location.longitude - city.longitude).abs() < 0.01;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        await controller.useCity(city);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? palette.accentSoft : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? palette.accent.withValues(alpha: 0.4) : palette.track,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    city.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: palette.ink,
                                    ),
                                  ),
                                  Text(
                                    formatCoordinatesUrdu(city.latitude, city.longitude),
                                    style: TextStyle(fontSize: 10, color: palette.muted),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check_circle, size: 16, color: palette.accent)
                            else
                              Icon(Icons.chevron_left, size: 16, color: palette.muted),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How far through its window the running prayer is (0–1).
///
/// The window starts when its own prayer's time arrived and ends at the next
/// marker — Fajr closes at sunrise, Isha at Nisf al-Layl, and the night's Isha
/// window (after midnight) runs to Fajr.
double _windowProgress(
  PrayerSchedule schedule,
  PrayerWindow window,
  DateTime now,
) {
  final start = window.previousNight
      ? schedule.entryFor(PrayerMarker.isha).time.subtract(const Duration(days: 1))
      : schedule.entryFor(window.marker).time;
  final total = window.endsAt.difference(start).inSeconds;
  if (total <= 0) return 0;
  return (now.difference(start).inSeconds / total).clamp(0.0, 1.0);
}
