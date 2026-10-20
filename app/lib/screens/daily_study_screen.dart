import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../daily_study.dart';
import '../library_repository.dart';
import '../models.dart';
import '../text_utils.dart' show arabicNumerals;
import 'balagha_screen.dart';
import 'quran_screen.dart';

/// **روزانہ مطالعہ** — the Xplore feature that turns the library into a habit.
///
/// A reader picks one book (the Quran, or one section of Nahj al-Balagha) and a
/// length in days; the screen works out today's portion from the plan's start
/// day, opens the reader at exactly that page/entry, and keeps the streak.
/// Nothing is downloaded and nothing leaves the phone — the portion is pure
/// arithmetic over the book's own length, so it keeps working offline forever.
class DailyStudyScreen extends StatefulWidget {
  const DailyStudyScreen({super.key, required this.library});

  final LibraryRepository library;

  @override
  State<DailyStudyScreen> createState() => _DailyStudyScreenState();
}

class _DailyStudyScreenState extends State<DailyStudyScreen> {
  final StudyPlanStore _store = StudyPlanStore();

  StudyPlan? _plan;
  bool _loading = true;

  /// Entries of the chosen Nahj al-Balagha section, used for the length and for
  /// naming the entry a day opens on.
  List<BalaghaEntry> _entries = const <BalaghaEntry>[];
  int _units = 0;
  String? _dataMissing;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final plan = await _store.load();
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _loading = false;
    });
    if (plan != null) await _measure(plan.track);
  }

  /// How many units the chosen track has, asked of the library itself so the
  /// plan never promises a length the installed data cannot fill.
  Future<void> _measure(StudyTrack track) async {
    if (track.isQuran) {
      final installed = widget.library.installedBooks.any((book) => book.source == CorpusSource.quran);
      if (!mounted) return;
      setState(() {
        _units = installed ? kQuranPages : 0;
        _entries = const <BalaghaEntry>[];
        _dataMissing = installed ? null : 'قرآنِ کریم کا متن ابھی انسٹال نہیں — ڈیٹا سیکشن سے ڈاؤن لوڈ کریں۔';
      });
      return;
    }
    final type = track.balaghaType;
    final installed = widget.library.installedBooks.any((book) => book.source == CorpusSource.balagha);
    if (type == null || !installed) {
      if (!mounted) return;
      setState(() {
        _units = 0;
        _entries = const <BalaghaEntry>[];
        _dataMissing = 'نہج البلاغہ ابھی انسٹال نہیں — ڈیٹا سیکشن سے ڈاؤن لوڈ کریں۔';
      });
      return;
    }
    List<BalaghaEntry> entries = const <BalaghaEntry>[];
    try {
      entries = await widget.library.getBalaghaEntries(type);
    } catch (_) {
      entries = const <BalaghaEntry>[];
    }
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _units = entries.length;
      _dataMissing = entries.isEmpty ? 'اس حصے کا متن ابھی دستیاب نہیں۔' : null;
    });
  }

  Future<void> _start(StudyTrack track, int days) async {
    final plan = StudyPlan(
      track: track,
      days: days,
      startedOn: studyDayKey(DateTime.now()),
    );
    await _store.save(plan);
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _units = 0;
      _entries = const <BalaghaEntry>[];
      _dataMissing = null;
    });
    await _measure(track);
  }

  Future<void> _toggleDay(int day) async {
    final plan = _plan;
    if (plan == null) return;
    final next = plan.toggledDay(day);
    setState(() => _plan = next);
    await _store.save(next);
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const JustifiedText('منصوبہ ختم کریں؟'),
        content: const JustifiedText(
          'آپ کی پڑھائی کا ریکارڈ مٹ جائے گا اور آپ نیا منصوبہ بنا سکیں گے۔ کتابیں اور بک مارکس محفوظ رہیں گے۔',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('نہیں')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('ختم کریں')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.clear();
    if (!mounted) return;
    setState(() {
      _plan = null;
      _entries = const <BalaghaEntry>[];
      _units = 0;
      _dataMissing = null;
    });
  }

  Future<void> _openPortion(StudyPlan plan, StudyPortion portion) async {
    if (plan.track.isQuran) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => QuranPageReaderScreen(library: widget.library, page: portion.first),
      ));
      return;
    }
    final type = plan.track.balaghaType;
    if (type == null) return;
    String? title;
    for (final entry in _entries) {
      if (entry.typeNo == portion.first) {
        title = entry.title;
        break;
      }
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BalaghaReaderScreen(
        library: widget.library,
        type: type,
        typeNo: portion.first,
        title: title ?? '${plan.track.titleUrdu} ${arabicNumerals(portion.first)}',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0A1512),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        title: const JustifiedText(
          'روزانہ مطالعہ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: <Color>[Color(0xFF123A31), Color(0xFF0B1D19), Color(0xFF07100E)],
            stops: <double>[0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: <Widget>[
                    const _StudyIntro(),
                    const SizedBox(height: 16),
                    if (_plan == null)
                      _PlanBuilder(active: false, onStart: _start)
                    else
                      ..._planBody(_plan!),
                  ],
                ),
        ),
      ),
    );
  }

  List<Widget> _planBody(StudyPlan plan) {
    final now = DateTime.now();
    final today = StudyPortion.dayNumberFor(plan.startedOn, now);
    final units = _units;
    if (units <= 0) {
      return <Widget>[
        if (_dataMissing != null) _Notice(_dataMissing!),
        const SizedBox(height: 14),
        _PlanBuilder(active: true, onStart: _start, initialTrack: plan.track, initialDays: plan.days),
      ];
    }
    // A plan day beyond the book's length (the reader finished early or the
    // clock moved) simply shows the last portion instead of an empty card.
    final portion = StudyPortion.forDay(
      day: today,
      days: plan.days,
      totalUnits: units,
      unitLabelUrdu: plan.track.unitLabelUrdu,
    );
    final done = plan.completedDays.length;
    final streak = studyStreak(plan, today);
    final finished = today > plan.days || (done >= plan.days);
    return <Widget>[
      _TodayCard(
        plan: plan,
        portion: portion,
        today: today,
        finished: plan.completedDays.contains(portion.day) || finished,
        onOpen: () => unawaited(_openPortion(plan, portion)),
        onToggle: () => unawaited(_toggleDay(portion.day)),
      ),
      const SizedBox(height: 14),
      Row(
        children: <Widget>[
          Expanded(
            child: _StatTile(
              icon: Icons.local_fire_department_rounded,
              value: arabicNumerals(streak),
              label: 'مسلسل دن',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              icon: Icons.check_circle_outline_rounded,
              value: '${arabicNumerals(done)} / ${arabicNumerals(plan.days)}',
              label: 'مکمل دن',
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _ProgressCard(plan: plan, today: today, onToggleDay: (day) => unawaited(_toggleDay(day))),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: _reset,
        icon: const Icon(Icons.restart_alt, size: 18),
        label: const JustifiedText('نیا منصوبہ بنائیں'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE9D8FF),
          side: BorderSide(color: kGold.withValues(alpha: 0.55)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    ];
  }
}

class _StudyIntro extends StatelessWidget {
  const _StudyIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[Color(0xFF1E4F42), Color(0xFF14332C)],
        ),
        border: Border.all(color: kGold.withValues(alpha: 0.42), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(colors: <Color>[Color(0xFFC59A50), Color(0xFF8E6A2C)]),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Color(0xFF1B1206), size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: JustifiedText(
                  'ایک کتاب، مقررہ دنوں میں',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const JustifiedText(
            'بڑی کتابیں کھول کر دو صفحے پڑھنا آسان ہے، مکمل کرنا مشکل۔ یہاں اپنی کتاب اور مدت چنیں: '
            'ایپ ہر دن کا حصہ خود مقرر کر دے گی، آپ صرف آج کا حصہ کھولیں اور مکمل ہونے پر نشان لگا دیں۔ '
            'حصے آپ کے شروع کرنے کے دن سے شمار ہوتے ہیں، اور سارا حساب آف لائن چلتا ہے۔',
            style: TextStyle(fontSize: 13.5, height: 1.8, color: Color(0xFFD9EAE2)),
          ),
        ],
      ),
    );
  }
}

/// Track + length picker. Used both for a fresh plan and for a plan whose data
/// is not installed yet.
class _PlanBuilder extends StatefulWidget {
  const _PlanBuilder({
    required this.active,
    required this.onStart,
    this.initialTrack,
    this.initialDays,
  });

  final bool active;
  final void Function(StudyTrack track, int days) onStart;
  final StudyTrack? initialTrack;
  final int? initialDays;

  @override
  State<_PlanBuilder> createState() => _PlanBuilderState();
}

class _PlanBuilderState extends State<_PlanBuilder> {
  static const List<int> _lengths = <int>[7, 14, 30, 60, 90, 180];

  late StudyTrack _track = widget.initialTrack ?? StudyTrack.quran;
  late int _days = widget.initialDays ?? 90;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const JustifiedText(
            'کون سی کتاب؟',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFFFE1A1)),
          ),
          const SizedBox(height: 10),
          for (final track in StudyTrack.values) ...<Widget>[
            _TrackRow(
              track: track,
              selected: track == _track,
              onTap: () => setState(() => _track = track),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          const JustifiedText(
            'کتنی مدت میں؟',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFFFE1A1)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final days in _lengths)
                ChoiceChip(
                  label: Text('${arabicNumerals(days)} دن'),
                  selected: _days == days,
                  onSelected: (_) => setState(() => _days = days),
                  selectedColor: kGold.withValues(alpha: 0.30),
                  labelStyle: TextStyle(
                    color: _days == days ? const Color(0xFFFFE1A1) : const Color(0xFFCFE3D9),
                    fontWeight: FontWeight.w700,
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  side: BorderSide(color: kGold.withValues(alpha: 0.35)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => widget.onStart(_track, _days),
            icon: const Icon(Icons.play_arrow_rounded),
            label: JustifiedText(widget.active ? 'منصوبہ نئے سرے سے شروع کریں' : 'منصوبہ شروع کریں'),
            style: FilledButton.styleFrom(
              backgroundColor: kGold,
              foregroundColor: const Color(0xFF1B1206),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (widget.active) ...<Widget>[
            const SizedBox(height: 8),
            const JustifiedText(
              'نئے منصوبے سے پرانا ریکارڈ بدل جائے گا۔',
              style: TextStyle(fontSize: 12, color: Color(0xFFB9CEC4)),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.track, required this.selected, required this.onTap});

  final StudyTrack track;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kGold.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? kGold.withValues(alpha: 0.75) : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: selected ? kGold : const Color(0xFF8FA79C),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    JustifiedText(
                      track.titleUrdu,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? const Color(0xFFFFE1A1) : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    JustifiedText(
                      track.subtitleUrdu,
                      style: const TextStyle(fontSize: 11.5, height: 1.5, color: Color(0xFFB9CEC4)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Today's portion, with its two actions.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.plan,
    required this.portion,
    required this.today,
    required this.finished,
    required this.onOpen,
    required this.onToggle,
  });

  final StudyPlan plan;
  final StudyPortion portion;
  final int today;
  final bool finished;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final label = portion.isLastDay && today >= plan.days
        ? 'آخری حصہ'
        : 'آج کا حصہ — دن ${arabicNumerals(portion.day)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[Color(0xFF3B2358), Color(0xFF14586B)],
        ),
        border: Border.all(color: kGold.withValues(alpha: 0.65), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.32), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          JustifiedText(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFCFE3D9)),
          ),
          const SizedBox(height: 6),
          JustifiedText(
            plan.track.titleUrdu,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 6),
          JustifiedText(
            portion.rangeUrdu(arabicNumerals),
            style: const TextStyle(
              fontFamily: kDigitFont,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFFE1A1),
            ),
          ),
          const SizedBox(height: 4),
          JustifiedText(
            'کل ${arabicNumerals(portion.totalUnits)} میں سے، ${arabicNumerals(portion.days)} دن کے منصوبے میں',
            style: const TextStyle(fontSize: 12, color: Color(0xFFB9CEC4)),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.auto_stories_rounded, size: 18),
                  label: const JustifiedText('پڑھنا شروع کریں'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kGold,
                    foregroundColor: const Color(0xFF1B1206),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: finished ? 'نشان ہٹائیں' : 'آج کا حصہ مکمل',
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onToggle,
                  child: Container(
                    width: 50,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: finished ? kForest : Colors.white.withValues(alpha: 0.10),
                      border: Border.all(color: finished ? Colors.white : kGold.withValues(alpha: 0.55)),
                    ),
                    child: Icon(
                      finished ? Icons.check_rounded : Icons.check_circle_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 22, color: kGold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: kDigitFont,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                JustifiedText(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFFB9CEC4))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The whole plan as a grid of days: tap a day to mark it, so a reader who read
/// ahead (or caught up on a missed day) can fix the record without hunting.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.plan, required this.today, required this.onToggleDay});

  final StudyPlan plan;
  final int today;
  final void Function(int day) onToggleDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          JustifiedText(
            'منصوبے کے دن',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kGold),
          ),
          const SizedBox(height: 4),
          const JustifiedText(
            'کسی بھی دن پر انگلی رکھ کر اسے مکمل یا ادھورا کر سکتے ہیں۔',
            style: TextStyle(fontSize: 11.5, color: Color(0xFFB9CEC4)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (var day = 1; day <= plan.days; day++)
                _DayDot(
                  day: day,
                  done: plan.completedDays.contains(day),
                  isToday: day == today,
                  onTap: () => onToggleDay(day),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.done, required this.isToday, required this.onTap});

  final int day;
  final bool done;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: done
              ? kForest
              : (isToday ? kGold.withValues(alpha: 0.24) : Colors.white.withValues(alpha: 0.06)),
          border: Border.all(
            color: isToday
                ? kGold
                : (done ? Colors.white.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.12)),
            width: isToday ? 1.6 : 1,
          ),
        ),
        child: Text(
          '$day',
          style: TextStyle(
            fontFamily: kDigitFont,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: done || isToday ? Colors.white : const Color(0xFF9FB6AB),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF6B2F2F).withValues(alpha: 0.45),
        border: Border.all(color: const Color(0xFFE7B9A1).withValues(alpha: 0.5)),
      ),
      child: JustifiedText(
        message,
        style: const TextStyle(fontSize: 13, height: 1.7, color: Color(0xFFFFE7DA)),
      ),
    );
  }
}
