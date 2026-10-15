import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../services/prayer_scope.dart';
import '../services/tasbeeh_controller.dart';
import '../text_utils.dart' show arabicNumerals;
import '../widgets/glass_panel.dart';

/// The digital tasbeeh: a big tap zone that feels like a bead, the
/// Tasbeeh-e-Zahra (s.a.) workflow that advances by itself, a custom target,
/// haptics, a click sound, and progress that is never lost.
class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key, this.startWithZahra = false});

  /// Set by the post-prayer prompt: open with Tasbeeh-e-Zahra (s.a.) armed
  /// from its first step.
  final bool startWithZahra;

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen> with TickerProviderStateMixin {
  final List<_Ripple> _ripples = <_Ripple>[];
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  int _seenCompletion = 0;
  String? _justCompleted;
  Timer? _completionTimer;

  @override
  void initState() {
    super.initState();
    if (widget.startWithZahra) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        TasbeehScope.read(context).startZahra();
      });
    }
  }

  @override
  void dispose() {
    for (final ripple in _ripples) {
      ripple.controller.dispose();
    }
    _completionTimer?.cancel();
    _flash.dispose();
    super.dispose();
  }

  void _addRipple(Offset centre) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    final ripple = _Ripple(controller, centre);
    _ripples.add(ripple);
    if (_ripples.length > 6) {
      _ripples.removeAt(0).controller.dispose();
    }
    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _ripples.remove(ripple));
      controller.dispose();
    });
    controller.forward();
    setState(() {});
  }

  void _onCount(TasbeehController controller, Offset local) {
    _addRipple(local);
    controller.tap();
  }

  Future<void> _confirmReset(TasbeehController controller) async {
    final palette = GlassPalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.solid,
        title: const Text('گنتی صفر کریں؟', style: TextStyle(fontSize: 17)),
        content: const Text(
          'موجودہ گنتی صفر ہو جائے گی۔ آج کا کل اور مجموعی گنتی محفوظ رہے گی۔\n'
          '(فوری ری سیٹ کے لیے بٹن کو دبا کر رکھیں)',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('نہیں'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ری سیٹ'),
          ),
        ],
      ),
    );
    if (confirmed == true) controller.reset(whole: true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final controller = TasbeehScope.of(context);

    // A completed step flashes the ring, names the dhikr that finished, and
    // clears itself after a few seconds — the counter must not keep a stale
    // banner on screen while the reader continues with the next step.
    if (controller.completionTick != _seenCompletion) {
      _seenCompletion = controller.completionTick;
      _justCompleted = controller.step.urdu;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _flash.forward(from: 0);
      });
      _completionTimer?.cancel();
      _completionTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _justCompleted = null);
      });
    }

    return Scaffold(
      backgroundColor: palette.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('تسبیح', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: <Widget>[
          IconButton(
            tooltip: 'صفر کریں (دبا کر رکھیں)',
            onPressed: () => unawaited(_confirmReset(controller)),
            onLongPress: () {
              controller.reset(whole: true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('گنتی صفر کر دی گئی'), duration: Duration(seconds: 2)),
              );
            },
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 26),
        children: <Widget>[
          if (widget.startWithZahra) ...<Widget>[
            _PostPrayerNote(palette: palette),
            const SizedBox(height: 10),
          ],
          _ModeSelector(controller: controller),
          const SizedBox(height: 12),
          _ZikrCard(controller: controller),
          const SizedBox(height: 14),
          _TapZone(
            controller: controller,
            ripples: _ripples,
            flash: _flash,
            onTap: (local) => _onCount(controller, local),
          ),
          const SizedBox(height: 14),
          _StepTracker(controller: controller, justCompleted: _justCompleted),
          const SizedBox(height: 12),
          if (controller.preset.custom) ...<Widget>[
            _TargetSelector(controller: controller),
            const SizedBox(height: 12),
          ],
          _Totals(controller: controller),
          const SizedBox(height: 12),
          _FeedbackControls(controller: controller),
          const SizedBox(height: 12),
          _ResetRow(
            controller: controller,
            onConfirm: () => unawaited(_confirmReset(controller)),
          ),
        ],
      ),
    );
  }
}

class _Ripple {
  _Ripple(this.controller, this.centre);

  final AnimationController controller;
  final Offset centre;
}

class _PostPrayerNote extends StatelessWidget {
  const _PostPrayerNote({required this.palette});

  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 18,
      padding: const EdgeInsets.all(12),
      shadow: false,
      child: Row(
        children: <Widget>[
          Icon(Icons.auto_awesome, size: 17, color: palette.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'نماز کے بعد کا معمول: تسبیحِ زہرا (س) شروع ہے — اللہ اکبر سے آغاز کریں',
              style: TextStyle(fontSize: 12, height: 1.5, color: palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Preset picker: the Zahra sequence plus the common single zikr, plus a
/// custom counter.
class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.controller});

  final TasbeehController controller;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const GlassSectionHeader(title: 'ذکر منتخب کریں'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (final preset in TasbeehPreset.all)
                GlassChip(
                  label: preset.titleUrdu,
                  selected: preset.key == controller.preset.key,
                  icon: preset.custom ? Icons.edit_outlined : null,
                  onTap: () => controller.selectPreset(preset.key),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            controller.preset.noteUrdu,
            style: TextStyle(fontSize: 11, height: 1.5, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

/// The dhikr itself, in Arabic, with its Urdu meaning.
class _ZikrCard extends StatelessWidget {
  const _ZikrCard({required this.controller});

  final TasbeehController controller;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: Column(
              key: ValueKey<String>('${controller.preset.key}-${controller.stepIndex}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    controller.step.arabic,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: kArabicFont,
                      fontSize: 30,
                      height: 1.6,
                      color: kForest,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  controller.step.urdu,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: palette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The ring and the tap zone. Everything inside the circle is painted by the
/// ring painter, so nothing here can shift the layout when the count changes.
class _TapZone extends StatelessWidget {
  const _TapZone({
    required this.controller,
    required this.ripples,
    required this.flash,
    required this.onTap,
  });

  static const double size = 268;
  static const double tapSize = 204;

  final TasbeehController controller;
  final List<_Ripple> ripples;
  final AnimationController flash;
  final ValueChanged<Offset> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final target = controller.target;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => onTap(details.localPosition),
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[flash, ...ripples.map((r) => r.controller)]),
            builder: (context, _) {
              final flashValue = 1 - flash.value;
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: <Widget>[
                  CustomPaint(
                    size: const Size(size, size),
                    painter: _RingPainter(
                      progress: controller.progress,
                      target: target,
                      palette: palette,
                      pulse: flashValue,
                    ),
                  ),
                  for (final ripple in ripples)
                    _RippleDot(ripple: ripple, palette: palette),
                  Container(
                    width: tapSize,
                    height: tapSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          palette.accent.withValues(alpha: 0.16 + 0.16 * (1 - flashValue)),
                          palette.accent.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(
                        color: palette.accent.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          'گنتی',
                          style: TextStyle(fontSize: 11, color: palette.muted),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            arabicNumerals(controller.count),
                            style: TextStyle(
                              fontSize: 62,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                              color: flashValue > 0.6 ? palette.gold : palette.accent,
                            ),
                          ),
                        ),
                        Text(
                          target == 0
                              ? 'لامحدود — ہر سو پر نیا دور'
                              : 'ہدف ${arabicNumerals(target)}  •  باقی '
                                  '${arabicNumerals(controller.remaining ?? 0)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: palette.muted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'دبائیں',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: palette.accent.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
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

class _RippleDot extends StatelessWidget {
  const _RippleDot({required this.ripple, required this.palette});

  final _Ripple ripple;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    final value = ripple.controller.value;
    return Positioned(
      left: ripple.centre.dx - 90,
      top: ripple.centre.dy - 90,
      child: IgnorePointer(
        child: Opacity(
          opacity: (1 - value).clamp(0.0, 1.0),
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  palette.accent.withValues(alpha: 0.0),
                  palette.accent.withValues(alpha: 0.18),
                  palette.accent.withValues(alpha: 0.0),
                ],
                stops: const <double>[0.35, 0.72, 1.0],
              ),
            ),
            transform: Matrix4.identity()
              ..scale(0.65 + 0.35 * value, 0.65 + 0.35 * value),
            transformAlignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}

/// Track, progress arc, and the tick marks of the target.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.target,
    required this.palette,
    required this.pulse,
  });

  final double progress;
  final int target;
  final GlassPalette palette;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 22) / 2;
    const stroke = 11.0;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = palette.track,
    );

    // Progress: starts at twelve o'clock and sweeps clockwise.
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

    // A gold glow when a step has just been completed.
    if (pulse > 0.05) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * (0.6 + pulse)
          ..color = palette.gold.withValues(alpha: 0.16 * pulse),
      );
    }

    // Tick marks: one per repetition for the small targets, else 100.
    final ticks = target == 0 ? 100 : (target <= 100 ? target : 100);
    if (ticks > 0 && ticks <= 100) {
      final tickPaint = Paint()
        ..strokeWidth = 2
        ..color = palette.accent.withValues(alpha: 0.28);
      final completed = (progress * ticks).floor();
      for (int index = 0; index < ticks; index++) {
        final angle = -math.pi / 2 + (2 * math.pi * index / ticks);
        final inner = radius - stroke / 2 - 6;
        final outer = inner - 5;
        final paint = index < completed
            ? (Paint()
              ..strokeWidth = 2.4
              ..color = palette.accent)
            : tickPaint;
        canvas.drawLine(
          centre + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
          centre + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.target != target ||
      old.pulse != pulse ||
      old.palette.track != palette.track;
}

/// The three steps of Tasbeeh-e-Zahra (s.a.): which one is running and what
/// comes next. For single-zikr presets this shows the round count instead.
class _StepTracker extends StatelessWidget {
  const _StepTracker({required this.controller, required this.justCompleted});

  final TasbeehController controller;
  final String? justCompleted;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final steps = controller.preset.steps;
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GlassSectionHeader(
            title: controller.preset.titleUrdu,
            trailing: Text(
              'دور: ${arabicNumerals(controller.rounds)}',
              style: TextStyle(fontSize: 11.5, color: palette.muted),
            ),
          ),
          const SizedBox(height: 10),
          if (steps.length > 1)
            Row(
              children: <Widget>[
                for (int index = 0; index < steps.length; index++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _StepTile(
                        step: steps[index],
                        index: index,
                        done: index < controller.stepIndex,
                        active: index == controller.stepIndex,
                        count: index == controller.stepIndex ? controller.count : 0,
                        palette: palette,
                        onTap: () => controller.selectStep(index),
                      ),
                    ),
                  ),
              ],
            )
          else
            _ProgressLine(controller: controller, palette: palette),
          if (justCompleted != null) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(Icons.check_circle, size: 15, color: palette.gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'مرحلہ مکمل ہو گیا — «$justCompleted» پوری ہوئی',
                    style: TextStyle(fontSize: 11.5, color: palette.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _ProgressLine(controller: controller, palette: palette),
          ],
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.index,
    required this.done,
    required this.active,
    required this.count,
    required this.palette,
    required this.onTap,
  });

  final TasbeehStep step;
  final int index;
  final bool done;
  final bool active;
  final int count;
  final GlassPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = done
        ? palette.gold
        : (active ? palette.accent : palette.muted);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: active ? palette.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? palette.accent.withValues(alpha: 0.45) : palette.track,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 16,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  step.arabic,
                  style: TextStyle(
                    fontFamily: kArabicFont,
                    fontSize: 15,
                    height: 1.1,
                    color: tint,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${arabicNumerals(count)} / ${arabicNumerals(step.target)}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: tint,
              ),
            ),
            if (done)
              Icon(Icons.check, size: 12, color: palette.gold)
            else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.controller, required this.palette});

  final TasbeehController controller;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    final target = controller.target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: controller.progress,
            minHeight: 6,
            backgroundColor: palette.track,
            valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          target == 0
              ? 'لامحدود — ${arabicNumerals(controller.count)} بار'
              : '${arabicNumerals(controller.count)} / ${arabicNumerals(target)} بار مکمل',
          style: TextStyle(fontSize: 11, color: palette.muted),
        ),
      ],
    );
  }
}

/// 33 / 100 / 1000 / unlimited for the custom counter.
class _TargetSelector extends StatelessWidget {
  const _TargetSelector({required this.controller});

  final TasbeehController controller;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const GlassSectionHeader(title: 'اپنا ہدف'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final choice in TasbeehController.targetChoices)
                GlassChip(
                  label: choice == 0 ? 'لامحدود' : arabicNumerals(choice),
                  selected: controller.customTarget == choice,
                  onTap: () => controller.setTarget(choice),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ہدف تبدیل کرنے سے موجودہ گنتی صفر ہو جاتی ہے؛ آج اور مجموعی گنتی محفوظ رہتی ہے۔',
            style: TextStyle(fontSize: 10.5, height: 1.5, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

/// Today and lifetime totals — the part the reader must never lose.
class _Totals extends StatelessWidget {
  const _Totals({required this.controller});

  final TasbeehController controller;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return Row(
      children: <Widget>[
        _TotalTile(
          label: 'آج کا کل',
          value: arabicNumerals(controller.dailyTotal),
          icon: Icons.today_outlined,
          palette: palette,
        ),
        const SizedBox(width: 10),
        _TotalTile(
          label: 'مجموعی گنتی',
          value: arabicNumerals(controller.lifetimeTotal),
          icon: Icons.all_inclusive,
          palette: palette,
        ),
      ],
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.palette,
  });

  final String label;
  final String value;
  final IconData icon;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassPanel(
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 17, color: palette.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: TextStyle(fontSize: 10.5, color: palette.muted)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackControls extends StatelessWidget {
  const _FeedbackControls({required this.controller});

  final TasbeehController controller;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const GlassSectionHeader(title: 'آواز اور جھٹکا'),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: GlassChip(
                  label: 'ہر دانے پر ہلکا جھٹکا',
                  icon: controller.hapticsEnabled
                      ? Icons.vibration
                      : Icons.phonelink_erase,
                  selected: controller.hapticsEnabled,
                  onTap: controller.toggleHaptics,
                  dense: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassChip(
                  label: controller.soundEnabled ? 'کلک کی آواز: آن' : 'کلک کی آواز: آف',
                  icon: controller.soundEnabled ? Icons.volume_up_outlined : Icons.volume_off_outlined,
                  selected: controller.soundEnabled,
                  tone: palette.gold,
                  onTap: controller.toggleSound,
                  dense: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ہدف مکمل ہونے پر دوگنا جھٹکا اور نرم چائم بجتا ہے — نماز کے بعد تسبیحِ زہرا '
            'کے لیے بھی یہی ترتیب ہے۔',
            style: TextStyle(fontSize: 10.5, height: 1.5, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _ResetRow extends StatelessWidget {
  const _ResetRow({required this.controller, required this.onConfirm});

  final TasbeehController controller;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(12),
      shadow: false,
      child: Row(
        children: <Widget>[
          Expanded(
            child: GlassChip(
              label: 'ری سیٹ (تصدیق کے ساتھ)',
              icon: Icons.restart_alt,
              tone: palette.gold,
              onTap: onConfirm,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GlassChip(
              label: 'فوری ری سیٹ (دبائیں اور رکھیں)',
              icon: Icons.timer_outlined,
              onTap: () {
                controller.reset(whole: true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('گنتی صفر کر دی گئی'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
