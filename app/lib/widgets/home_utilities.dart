import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../astro/prayer_calculator.dart';
import '../astro/prayer_format.dart';
import '../astro/sky_phase.dart';
import '../screens/prayer_times_screen.dart';
import '../screens/tasbeeh_screen.dart';
import '../services/prayer_controller.dart';
import '../services/prayer_scope.dart';
import '../services/tasbeeh_controller.dart';
import 'glass_panel.dart';
import 'sky_backdrop.dart';

/// The daily utilities as they appear on the home dashboard: the mini prayer
/// card at the top (place, Hijri date, the live clock, and the five times with
/// the running prayer marked **Now** and the next one counting down), then the
/// circular mini tasbeeh. They read the same controllers as their full
/// screens, so nothing here can disagree with the screens behind.
/// The Qibla lives in the bottom panel now.
class HomePrayerBanner extends StatefulWidget {
  const HomePrayerBanner({super.key});

  @override
  State<HomePrayerBanner> createState() => _HomePrayerBannerState();
}

class _HomePrayerBannerState extends State<HomePrayerBanner> {
  bool _offered = false;

  /// The place name and its detail show for 10 seconds after the home opens,
  /// then fade out. The pin stays, so the card keeps its shape.
  static const Duration _placeVisibleFor = Duration(seconds: 10);
  Timer? _placeTimer;
  bool _showPlace = true;

  @override
  void initState() {
    super.initState();
    _placeTimer = Timer(_placeVisibleFor, () {
      if (mounted) setState(() => _showPlace = false);
    });
  }

  @override
  void dispose() {
    _placeTimer?.cancel();
    super.dispose();
  }

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
                    Icon(Icons.mosque, size: 22, color: palette.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${marker.labelUrdu} کا وقت ہو گیا',
                        style: TextStyle(
                          fontSize: 17,
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
                  '34 بار اللہ اکبر، 33 بار الحمد للہ، 33 بار سبحان اللہ۔',
                  style: TextStyle(fontSize: 14, height: 1.6, color: palette.muted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('بعد میں', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: palette.accent),
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        icon: const Icon(Icons.touch_app, size: 17),
                        label: const Text('تسبیح شروع کریں', style: TextStyle(fontSize: 14)),
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
    final controller = PrayerScope.of(context);
    // The card's rows are fixed to one line each and the text scale is
    // capped, so the home list never shifts while the clock ticks.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: ValueListenableBuilder<DateTime>(
        valueListenable: controller.now,
        builder: (context, now, _) {
          final schedule = controller.schedule;
          return SkyBackdrop(
            phase: skyPhaseFor(schedule, now),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PrayerTimesScreen()),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: _MiniPrayerContent(
                    controller: controller,
                    schedule: schedule,
                    now: now,
                    showPlace: _showPlace,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// White text with a soft shadow, readable on every sky.
TextStyle _onSky(
  double size, {
  FontWeight weight = FontWeight.w600,
  double alpha = 1,
  Color color = Colors.white,
  bool digits = false,
  double? height,
}) =>
    TextStyle(
      fontFamily: digits ? kDigitFont : null,
      fontSize: size,
      height: height,
      fontWeight: weight,
      color: color.withValues(alpha: alpha),
      fontFeatures: digits ? const <FontFeature>[FontFeature.tabularFigures()] : null,
      shadows: const <Shadow>[
        Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 1)),
      ],
    );

class _MiniPrayerContent extends StatelessWidget {
  const _MiniPrayerContent({
    required this.controller,
    required this.schedule,
    required this.now,
    required this.showPlace,
  });

  final PrayerController controller;
  final PrayerSchedule schedule;
  final DateTime now;

  /// False once the place name has faded out (10 seconds after home opens).
  final bool showPlace;

  @override
  Widget build(BuildContext context) {
    final location = controller.location;
    final window = schedule.window(now);
    final next = schedule.nextEntry(now);
    final hijri = controller.hijriFor(now);
    const gold = Color(0xFFFFE1A1);
    const fade = Duration(milliseconds: 700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Place, centred. The refresh button sits in the top corner, out of the
        // way of the centred text.
        Stack(
          // The place sits in the middle of the card, not at the start edge.
          alignment: Alignment.topCenter,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(openLocationPicker(context)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.place, size: 20, color: Colors.white),
                        const SizedBox(width: 4),
                        Flexible(
                          child: AnimatedOpacity(
                            opacity: showPlace ? 1 : 0,
                            duration: fade,
                            child: Text(
                              controller.loadingLocation ? 'مقام تلاش کیا جا رہا ہے…' : location.label,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: _onSky(17.5, weight: FontWeight.w800, height: 1.35),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (location.detail.isNotEmpty && !controller.loadingLocation)
                      AnimatedOpacity(
                        opacity: showPlace ? 1 : 0,
                        duration: fade,
                        child: Text(
                          location.detail,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: _onSky(12.5, alpha: 0.85, height: 1.3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            PositionedDirectional(
              top: 0,
              end: 0,
              child: _SkyButton(
                icon: controller.loadingLocation
                    ? Icons.sync
                    : (controller.locationProblem != null ? Icons.location_disabled : Icons.my_location),
                tooltip: controller.locationProblem?.messageUrdu ?? 'میرا موجودہ مقام معلوم کریں',
                warning: controller.locationProblem != null && !controller.loadingLocation,
                onTap: controller.loadingLocation
                    ? null
                    : () => unawaited(refreshLocationWithFeedback(context)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // The Hijri date alone: the Gregorian day is no longer printed here.
        Text(
          hijri.labelUrdu,
          maxLines: 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: _onSky(14, weight: FontWeight.w800, color: gold),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: formatClockDigitsUrdu(now),
                  style: _onSky(38, weight: FontWeight.w700, digits: true, height: 1.0),
                ),
                TextSpan(
                  text: formatClockSeconds(now),
                  style: _onSky(18, weight: FontWeight.w600, alpha: 0.85, digits: true),
                ),
                TextSpan(
                  text: '  ${dayPartUrdu(now.hour)}',
                  style: _onSky(15, weight: FontWeight.w700, alpha: 0.9),
                ),
              ],
            ),
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        _FivePrayerStrip(schedule: schedule, now: now, window: window, next: next),
      ],
    );
  }
}

/// The five prayers on one translucent strip. The running prayer is lit and
/// tagged **Now**; the next prayer is outlined in gold and shows the time left
/// to it inside its own box.
class _FivePrayerStrip extends StatelessWidget {
  const _FivePrayerStrip({
    required this.schedule,
    required this.now,
    required this.window,
    required this.next,
  });

  final PrayerSchedule schedule;
  final DateTime now;
  final PrayerWindow window;
  final PrayerEntry next;

  @override
  Widget build(BuildContext context) {
    final running = !window.previousNight && now.isBefore(window.endsAt);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: <Widget>[
          for (final entry in schedule.obligatory)
            Expanded(
              child: _MiniPrayerCell(
                entry: entry,
                active: running && window.marker == entry.marker,
                upcoming: !(running && window.marker == entry.marker) && next.marker == entry.marker,
                remaining: next.marker == entry.marker ? next.time.difference(now) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniPrayerCell extends StatelessWidget {
  const _MiniPrayerCell({
    required this.entry,
    required this.active,
    required this.upcoming,
    this.remaining,
  });

  final PrayerEntry entry;
  final bool active;
  final bool upcoming;

  /// Time left until this prayer; only set on the next prayer's cell.
  final Duration? remaining;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFE1A1);
    final lit = active || upcoming;
    final left = remaining;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      decoration: BoxDecoration(
        color: active
            ? Colors.white.withValues(alpha: 0.24)
            : (upcoming ? gold.withValues(alpha: 0.12) : Colors.transparent),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: active
              ? Colors.white.withValues(alpha: 0.6)
              : (upcoming ? gold.withValues(alpha: 0.85) : Colors.transparent),
          width: lit ? 1.4 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            entry.marker.labelUrdu,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _onSky(14, weight: lit ? FontWeight.w800 : FontWeight.w700, height: 1.3),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatClockDigitsUrdu(entry.time),
              style: _onSky(
                16.5,
                weight: FontWeight.w800,
                digits: true,
                color: upcoming ? gold : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 17,
            child: Center(
              child: active
                  ? const _NowTag()
                  : (left != null ? _CountdownTag(remaining: left) : const SizedBox.shrink()),
            ),
          ),
        ],
      ),
    );
  }
}

/// The small gold **Now** badge on the prayer that is running.
class _NowTag extends StatelessWidget {
  const _NowTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE1A1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Now',
        maxLines: 1,
        style: TextStyle(
          fontFamily: kDigitFont,
          fontSize: 10.5,
          height: 1.25,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1B1B1B),
        ),
      ),
    );
  }
}

/// The time left until the next prayer, inside that prayer's box.
class _CountdownTag extends StatelessWidget {
  const _CountdownTag({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFE1A1);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: gold.withValues(alpha: 0.6)),
        ),
        child: Text(
          formatCountdownClock(remaining),
          maxLines: 1,
          style: _onSky(11.5, weight: FontWeight.w800, color: gold, digits: true, height: 1.25),
        ),
      ),
    );
  }
}

class _SkyButton extends StatelessWidget {
  const _SkyButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.warning = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  /// Gold, for "the GPS could not be used — tap to fix".
  final bool warning;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFE1A1);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: warning ? 0.4 : 0.26),
            border: Border.all(color: warning ? gold : Colors.white.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, size: 19, color: warning ? gold : Colors.white),
        ),
      ),
    );
  }
}

/// The circular mini tasbeeh, at a fixed height so the home list never jumps
/// when the count changes. (The Qibla moved to the bottom panel.)
class HomeUtilityRow extends StatelessWidget {
  const HomeUtilityRow({super.key});

  /// The tasbeeh is a circle, so the row is exactly as tall as it is wide.
  static const double height = 290;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: const Center(
        child: SizedBox.square(
          dimension: height,
          child: HomeTasbeehCard(),
        ),
      ),
    );
  }
}

/// The circular mini tasbeeh. Everything sits inside one circle: the title and
/// the two small buttons along the top, the count ring in the middle, reset and
/// + on either side, then the zikr and today's count at the bottom. Tap the
/// ring or the + to count.
class HomeTasbeehCard extends StatelessWidget {
  const HomeTasbeehCard({super.key});

  static const double _ringDiameter = 146;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final controller = TasbeehScope.of(context);
    final arabic = !controller.preset.custom || looksArabic(controller.step.arabic);
    return GlassPanel(
      radius: HomeUtilityRow.height / 2,
      padding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Title, centred along the top of the circle.
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.touch_app, size: 18, color: palette.accent),
                const SizedBox(width: 4),
                Text(
                  'تسبیح',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 36,
            left: 72,
            child: _TinyButton(
              icon: Icons.swap_horiz,
              tooltip: 'ذکر یا ورد بدلیں',
              onTap: () => unawaited(showWirdPicker(context)),
            ),
          ),
          Positioned(
            top: 36,
            right: 72,
            child: _TinyButton(
              icon: Icons.open_in_full,
              tooltip: 'مکمل تسبیح کھولیں',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TasbeehScreen()),
              ),
            ),
          ),
          // The count ring, centred.
          Positioned(
            top: (HomeUtilityRow.height - _ringDiameter) / 2,
            left: (HomeUtilityRow.height - _ringDiameter) / 2,
            child: _MiniBead(controller: controller, diameter: _ringDiameter),
          ),
          // Reset on the left, + on the right, both at the ring's height.
          Positioned(
            left: 22,
            top: 126,
            child: _RoundButton(
              icon: Icons.refresh,
              tooltip: 'ری سیٹ (دبا کر رکھیں: فوری)',
              size: 38,
              onTap: () => unawaited(confirmTasbeehReset(context, controller)),
              onLongPress: () {
                controller.reset(whole: true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('گنتی صفر کر دی گئی'), duration: Duration(seconds: 2)),
                );
              },
            ),
          ),
          Positioned(
            right: 22,
            top: 122,
            child: _RoundButton(
              icon: Icons.add,
              tooltip: 'ایک دانہ (+1)',
              size: 46,
              filled: true,
              onTap: controller.tap,
            ),
          ),
          // The zikr, under the ring.
          Positioned(
            top: 226,
            left: 48,
            right: 48,
            child: Text(
              controller.step.arabic,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: arabic ? kArabicFont : null,
                fontSize: arabic ? 16 : 15,
                height: 1.45,
                color: palette.isDark ? palette.accent : kForest,
              ),
            ),
          ),
          // Today's count, at the bottom of the circle.
          Positioned(
            top: 252,
            left: 72,
            right: 72,
            child: Text(
              'آج: ${formatCount(controller.dailyTotal)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.3, color: palette.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// The bead: a ring that fills towards the target, the count in the middle.
/// Tapping it counts, with a small press animation.
class _MiniBead extends StatelessWidget {
  const _MiniBead({required this.controller, required this.diameter});

  final TasbeehController controller;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final target = controller.target;
    return Semantics(
      button: true,
      label: 'تسبیح گنتی ${controller.count}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: controller.tap,
        child: TweenAnimationBuilder<double>(
          key: ValueKey<int>(controller.lifetimeTotal),
          tween: Tween<double>(begin: 0.93, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: CustomPaint(
              painter: _BeadRingPainter(progress: controller.progress, palette: palette),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(diameter * 0.14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatCount(controller.count),
                          style: TextStyle(
                            fontFamily: kDigitFont,
                            fontSize: diameter * 0.30,
                            height: 1.0,
                            fontWeight: FontWeight.w800,
                            color: palette.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          target == 0 ? '∞' : '/ ${formatCount(target)}',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontFamily: kDigitFont,
                            fontSize: diameter * 0.12,
                            fontWeight: FontWeight.w700,
                            color: palette.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BeadRingPainter extends CustomPainter {
  _BeadRingPainter({required this.progress, required this.palette});

  final double progress;
  final GlassPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final stroke = size.width * 0.075;
    final radius = size.width / 2 - stroke / 2 - 1;
    canvas.drawCircle(
      centre,
      radius - stroke / 2,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            palette.accent.withValues(alpha: 0.16),
            palette.accent.withValues(alpha: 0.04),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = palette.track,
    );
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      math.max(0.001, progress) * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = palette.accent,
    );
    // The bead travelling on the ring.
    final angle = -math.pi / 2 + progress * 2 * math.pi;
    canvas.drawCircle(
      centre + Offset(math.cos(angle), math.sin(angle)) * radius,
      stroke * 0.72,
      Paint()..color = palette.gold,
    );
  }

  @override
  bool shouldRepaint(_BeadRingPainter old) =>
      old.progress != progress || old.palette.accent != palette.accent;
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.onTap,
    this.onLongPress,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final double size;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? palette.accent : palette.fill,
        shape: CircleBorder(
          side: BorderSide(color: filled ? palette.accent : palette.accent.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.5, color: filled ? Colors.white : palette.accent),
          ),
        ),
      ),
    );
  }
}

class _TinyButton extends StatelessWidget {
  const _TinyButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.accentSoft,
          ),
          child: Icon(icon, size: 16, color: palette.accent),
        ),
      ),
    );
  }
}

