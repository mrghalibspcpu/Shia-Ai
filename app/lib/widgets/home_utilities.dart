import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../astro/compass_math.dart' show compassPointUrdu;
import '../astro/prayer_calculator.dart';
import '../astro/prayer_format.dart';
import '../screens/prayer_times_screen.dart';
import '../screens/qibla_screen.dart';
import '../screens/tasbeeh_screen.dart';
import '../services/prayer_controller.dart';
import '../services/prayer_scope.dart';
import '../text_utils.dart' show arabicNumerals;
import 'glass_panel.dart';

/// The three utilities as they appear on the home dashboard: one glass banner
/// for the prayer times (with the live countdown), and a row with the tasbeeh
/// and the Qibla. They read the same controllers as their full screens, so
/// nothing on this row can disagree with the screens behind it.
///
/// The banner's height is fixed so the home list never shifts while the
/// countdown ticks and the location resolves.
class HomePrayerBanner extends StatefulWidget {
  const HomePrayerBanner({super.key});

  static const double height = 112;

  @override
  State<HomePrayerBanner> createState() => _HomePrayerBannerState();
}

class _HomePrayerBannerState extends State<HomePrayerBanner> {
  bool _offered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A prayer whose time arrived while the app was open leaves one event for
    // the home screen to turn into the post-prayer prompt. The event is only
    // consumed here, once, so the sheet can never stack up.
    if (_offered) return;
    final alert = PrayerScope.read(context).takePendingAlert();
    if (alert == null) return;
    _offered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showPostPrayerSheet(alert));
    });
  }

  /// The post-prayer smart shortcut: right after a prayer's time arrives (or
  /// right after Fajr's window closes) the app offers Tasbeeh-e-Zahra (s.a.)
  /// instead of waiting to be asked.
  Future<void> _showPostPrayerSheet(PrayerAlertEvent alert) async {
    final marker = alert.marker;
    final palette = GlassPalette.of(context);
    final chosen = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GlassPanel(
            radius: 22,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.mosque, size: 20, color: palette.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${marker.labelUrdu} کا وقت ہو گیا',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: palette.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'بند کریں',
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'نماز کے بعد تسبیحِ زہرا (س) پڑھنا مسنون ہے — '
                  '۳۴ بار اللہ اکبر، ۳۳ بار الحمد للہ، ۳۳ بار سبحان اللہ۔',
                  style: TextStyle(fontSize: 12, height: 1.6, color: palette.muted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('بعد میں', style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: palette.accent),
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        icon: const Icon(Icons.touch_app, size: 16),
                        label: const Text('تسبیح شروع کریں', style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || chosen != true) return;
    TasbeehScope.read(context).startZahra();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TasbeehScreen(startWithZahra: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final controller = PrayerScope.of(context);

    return SizedBox(
      height: HomePrayerBanner.height,
      child: GlassPanel(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PrayerTimesScreen()),
          ),
          child: ValueListenableBuilder<DateTime>(
            valueListenable: controller.now,
            builder: (context, now, _) {
              final schedule = controller.schedule;
              final next = schedule.nextEntry(now);
              final window = schedule.window(now);
              return Row(
                children: <Widget>[
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        CircularProgressIndicator(
                          value: _windowProgress(schedule, window, now),
                          strokeWidth: 3.4,
                          backgroundColor: palette.track,
                          valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                        ),
                        Icon(Icons.access_time_filled, size: 20, color: palette.accent),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                next.marker.labelUrdu,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  color: palette.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatClockDigitsUrdu(next.time),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: palette.ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          next.tomorrow
                              ? 'کل — ${formatCountdownUrdu(next.time.difference(now))}'
                              : 'باقی ${formatCountdownUrdu(next.time.difference(now))}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.gold,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: <Widget>[
                            Icon(
                              controller.loadingLocation ? Icons.sync : Icons.place_outlined,
                              size: 11,
                              color: palette.muted,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                controller.loadingLocation
                                    ? 'مقام تلاش کیا جا رہا ہے…'
                                    : '${controller.location.label} • '
                                        '${formatClockDigitsUrdu(schedule.entryFor(window.previousNight ? PrayerMarker.isha : window.marker).time)}'
                                        ' سے ${window.marker.labelUrdu} کا وقت',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, color: palette.muted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _BannerAction(
                    icon: Icons.explore_outlined,
                    tooltip: 'قبلہ نما',
                    palette: palette,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const QiblaScreen()),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BannerAction extends StatelessWidget {
  const _BannerAction({
    required this.icon,
    required this.tooltip,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final GlassPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.goldSoft,
            border: Border.all(color: palette.gold.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, size: 18, color: palette.gold),
        ),
      ),
    );
  }
}

/// The home row's second card: today's tasbeeh at a glance, one tap to count.
class HomeTasbeehCard extends StatelessWidget {
  const HomeTasbeehCard({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final controller = TasbeehScope.of(context);
    final target = controller.target;
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TasbeehScreen()),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 38,
              height: 38,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  CircularProgressIndicator(
                    value: controller.progress,
                    strokeWidth: 3,
                    backgroundColor: palette.track,
                    valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                  ),
                  Text(
                    arabicNumerals(controller.count),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: palette.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'تسبیح',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: palette.ink,
                    ),
                  ),
                  Text(
                    target == 0
                        ? 'آج: ${arabicNumerals(controller.dailyTotal)} (لامحدود)'
                        : 'آج: ${arabicNumerals(controller.dailyTotal)} • ہدف ${arabicNumerals(target)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: palette.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, size: 18, color: palette.accent),
          ],
        ),
      ),
    );
  }
}

/// The home row's third card: the Qibla bearing as a number, with a small
/// needle drawn at the correct angle, so the reader gets an answer without
/// opening the compass (and without a magnetometer).
class HomeQiblaCard extends StatelessWidget {
  const HomeQiblaCard({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final controller = PrayerScope.of(context);
    final bearing = controller.qiblaBearing;
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const QiblaScreen()),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 38,
              height: 38,
              child: Transform.rotate(
                angle: bearing * math.pi / 180,
                child: Icon(Icons.navigation, size: 26, color: palette.gold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'قبلہ نما',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: palette.ink,
                    ),
                  ),
                  Text(
                    '${formatBearingUrdu(bearing, compassPointUrdu(bearing))} • '
                    '${urduDigits(controller.distanceToKaabaKm.round().toString())} کلومیٹر',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: palette.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, size: 18, color: palette.accent),
          ],
        ),
      ),
    );
  }
}

/// How far through its window the running prayer is (0–1) — the same rule the
/// timings screen uses, so the two rings always agree.
double _windowProgress(PrayerSchedule schedule, PrayerWindow window, DateTime now) {
  final start = window.previousNight
      ? schedule.entryFor(PrayerMarker.isha).time.subtract(const Duration(days: 1))
      : schedule.entryFor(window.marker).time;
  final total = window.endsAt.difference(start).inSeconds;
  if (total <= 0) return 0;
  return (now.difference(start).inSeconds / total).clamp(0.0, 1.0);
}
