import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../astro/hijri_calendar.dart';
import '../astro/islamic_events.dart';
import '../astro/lunar_hijri.dart';
import '../astro/prayer_format.dart';
import '../services/prayer_scope.dart';
import '../widgets/glass_panel.dart';

/// The year's days, dated in the reader's own calendar, with a Gregorian →
/// Hijri converter driven by the same local crescent model as the home card.
class IslamicCalendarScreen extends StatelessWidget {
  const IslamicCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final controller = PrayerScope.of(context);
    final calendar = controller.lunarHijri;
    final today = controller.hijriToday.date;
    // `now` is already the location's wall clock, so this is the civil day the
    // reader is living in, even when the device timezone differs.
    final now = controller.now.value;
    final civilToday = DateTime.utc(now.year, now.month, now.day);
    final adjustment = controller.hijriAdjustment ?? 0;

    final rows = <_OccasionRow>[
      for (final event in kShiaIslamicEvents)
        _OccasionRow(
          event: event,
          civil: _civilFor(calendar, event, today, civilToday, adjustDays: adjustment),
        ),
    ]..sort((a, b) => a.civil.compareTo(b.civil));
    final next = rows.indexWhere((row) => !row.civil.isBefore(civilToday));
    final nextDate = next < 0 ? null : rows[next].civil;

    return Scaffold(
      backgroundColor: palette.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('اسلامی تقویم',
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
              color: palette.scaffold.withValues(alpha: palette.isDark ? 0.76 : 0.9),
            ),
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 26),
            children: <Widget>[
              _CalendarHero(today: today, palette: palette),
              const SizedBox(height: 12),
              _GregorianDateConverter(
                calendar: calendar,
                adjustment: adjustment,
                initialDate: civilToday,
                palette: palette,
              ),
              const SizedBox(height: 12),
              GlassPanel(
                radius: 20,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const GlassSectionHeader(title: 'اس سال کے ایام'),
                    const SizedBox(height: 8),
                    Text(
                      '${formatHijriUrdu(today)} — ${controller.location.label}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تاریخیں اسی شہر کے فلکیاتی ہلال کے مطابق ہیں؛ '
                      'مقامی رؤیت اور مرجع کے اعلان سے ایک دن فرق ہو سکتا ہے۔',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, height: 1.55, color: palette.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _OccasionCard(
                    row: row,
                    upcoming: nextDate != null && row.civil == nextDate,
                    palette: palette,
                    days: row.civil.difference(civilToday).inDays,
                  ),
                ),
              GlassPanel(
                radius: 20,
                padding: const EdgeInsets.all(13),
                child: Text(
                  'جہاں تاریخی روایات مختلف ہیں وہاں معروف قول اور اختلاف کی وضاحت دی گئی ہے۔ '
                  'روزے اور عبادات کے فقہی حکم کے لیے اپنے مرجعِ تقلید کی رہنمائی دیکھیں۔',
                  style: TextStyle(fontSize: 12.5, height: 1.6, color: palette.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarHero extends StatelessWidget {
  const _CalendarHero({required this.today, required this.palette});

  final HijriDate today;
  final GlassPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 142,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        image: const DecorationImage(
          image: AssetImage('assets/images/sky_night.jpg'),
          fit: BoxFit.cover,
        ),
        border: Border.all(color: palette.gold.withValues(alpha: 0.75)),
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
              colors: <Color>[Color(0xE6122928), Color(0xA611252B), Color(0xE609141B)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.gold.withValues(alpha: 0.13),
                    border: Border.all(color: palette.gold.withValues(alpha: 0.7)),
                  ),
                  child: Icon(Icons.nights_stay_rounded, size: 42, color: palette.gold),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('اسلامی تاریخ',
                          style: TextStyle(fontSize: 14, color: palette.gold)),
                      const SizedBox(height: 3),
                      Text(
                        formatHijriUrdu(today),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 23,
                          height: 1.35,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'اہلِ بیت ع کی اہم مناسبتیں اور تاریخ تبدیل کرنے کا آلہ',
                        maxLines: 2,
                        style: TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFFE1E7DC)),
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

/// A compact, editable Gregorian → Hijri converter. The date picker is a
/// convenience, while the text field also accepts dates directly as
/// DD/MM/YYYY or YYYY-MM-DD (1900–2100, the validated astronomy range).
class _GregorianDateConverter extends StatefulWidget {
  const _GregorianDateConverter({
    required this.calendar,
    required this.adjustment,
    required this.initialDate,
    required this.palette,
  });

  final LunarHijri calendar;
  final int adjustment;
  final DateTime initialDate;
  final GlassPalette palette;

  @override
  State<_GregorianDateConverter> createState() => _GregorianDateConverterState();
}

class _GregorianDateConverterState extends State<_GregorianDateConverter> {
  late final TextEditingController _input;
  late DateTime _gregorian;
  late HijriDate _hijri;
  String? _error;

  @override
  void initState() {
    super.initState();
    _gregorian = DateTime.utc(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    _hijri = widget.calendar.dateFor(_gregorian, adjustDays: widget.adjustment);
    _input = TextEditingController(text: _dateInput(_gregorian));
  }

  @override
  void didUpdateWidget(_GregorianDateConverter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.calendar != widget.calendar || oldWidget.adjustment != widget.adjustment) {
      _hijri = widget.calendar.dateFor(_gregorian, adjustDays: widget.adjustment);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String _dateInput(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  DateTime? _parseDate(String text) {
    final value = displayDigits(text.trim());
    final match = RegExp(r'^(\d{1,4})[./-](\d{1,2})[./-](\d{1,4})$').firstMatch(value);
    if (match == null) return null;
    final first = match.group(1)!;
    final second = int.tryParse(match.group(2)!);
    final third = match.group(3)!;
    final yearFirst = first.length == 4;
    final year = int.tryParse(yearFirst ? first : third);
    final month = second;
    final day = int.tryParse(yearFirst ? third : first);
    if (year == null || month == null || day == null || year < 1900 || year > 2100) return null;
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) return null;
    return date;
  }

  void _convert([DateTime? date]) {
    final parsed = date ?? _parseDate(_input.text);
    if (parsed == null) {
      setState(() => _error = 'تاریخ DD/MM/YYYY یا YYYY-MM-DD میں درج کریں (سال 1900 تا 2100)۔');
      return;
    }
    setState(() {
      _gregorian = DateTime.utc(parsed.year, parsed.month, parsed.day);
      _hijri = widget.calendar.dateFor(_gregorian, adjustDays: widget.adjustment);
      _input.text = _dateInput(_gregorian);
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _gregorian,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'عیسوی تاریخ منتخب کریں',
    );
    if (selected != null) _convert(selected);
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final events = kShiaIslamicEvents
        .where((event) => event.month == _hijri.month && event.day == _hijri.day)
        .toList(growable: false);
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const GlassSectionHeader(title: 'عیسوی سے ہجری تاریخ'),
          const SizedBox(height: 5),
          Text(
            'کوئی بھی تاریخ لکھیں یا کیلنڈر سے چنیں۔',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: palette.muted),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey<String>('gregorian-date-input'),
            controller: _input,
            keyboardType: TextInputType.datetime,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: 'عیسوی تاریخ',
              hintText: '18/10/2026',
              suffixIcon: IconButton(
                tooltip: 'کیلنڈر سے تاریخ منتخب کریں',
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
              ),
            ),
            onSubmitted: (_) => _convert(),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 5),
            Text(_error!, style: TextStyle(fontSize: 12.5, color: palette.gold)),
          ],
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _convert(widget.initialDate),
                  icon: const Icon(Icons.today_outlined, size: 18),
                  label: const Text('آج'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _convert,
                  icon: const Icon(Icons.sync_alt, size: 18),
                  label: const Text('تبدیل کریں'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: palette.solid.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  formatDateUrdu(_gregorian),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: palette.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  formatHijriUrdu(_hijri),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    color: palette.accent,
                  ),
                ),
                Text(
                  'دن: ${weekdayUrdu(_gregorian)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.ink),
                ),
                const SizedBox(height: 6),
                if (events.isEmpty)
                  Text(
                    'اس تاریخ کے لیے درج شدہ کوئی خاص مناسبت نہیں۔',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, height: 1.4, color: palette.muted),
                  )
                else
                  for (final event in events) ...<Widget>[
                    Text(
                      event.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: palette.gold),
                    ),
                    if (event.note != null)
                      Text(
                        event.note!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, height: 1.4, color: palette.muted),
                      ),
                  ],
                const SizedBox(height: 5),
                Text(
                  'یہ مقامی فلکیاتی تخمینہ ہے؛ اصل رؤیت، مرجع اور برادری کے اعلان سے تاریخ ایک دن مختلف ہو سکتی ہے۔',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: palette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The civil day a Hijri occasion falls on: in the year running now, or — once
/// the day has gone by — in the year that follows.
DateTime _civilFor(
  LunarHijri calendar,
  IslamicEvent event,
  HijriDate today,
  DateTime civilToday, {
  int adjustDays = 0,
}) {
  // `dateFor(day, adjustDays: n)` shifts the Hijri day forward by n, so the
  // inverse mapping subtracts n from the civil start.
  DateTime forYear(int year) => calendar
      .civilStartOfMonth(year, event.month)
      .add(Duration(days: event.day - 1 - adjustDays));
  final thisYear = forYear(today.year);
  if (!thisYear.isBefore(civilToday)) return thisYear;
  return forYear(today.year + 1);
}

class _OccasionRow {
  const _OccasionRow({required this.event, required this.civil});

  final IslamicEvent event;
  final DateTime civil;
}

class _OccasionCard extends StatelessWidget {
  const _OccasionCard({
    required this.row,
    required this.upcoming,
    required this.palette,
    required this.days,
  });

  final _OccasionRow row;
  final bool upcoming;
  final GlassPalette palette;
  final int days;

  @override
  Widget build(BuildContext context) {
    final colour = upcoming ? palette.accent : palette.muted;
    return GlassPanel(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: upcoming ? palette.accent.withValues(alpha: 0.14) : palette.track,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  '${row.civil.day}',
                  style: TextStyle(
                    fontFamily: kDigitFont,
                    fontSize: 20,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: upcoming ? palette.accent : palette.ink,
                  ),
                ),
                Text(
                  kGregorianMonthsUrdu[(row.civil.month - 1).clamp(0, 11)],
                  style: TextStyle(fontSize: 11, color: colour),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  row.event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.event.dateUrdu,
                  style: TextStyle(fontSize: 12, color: palette.muted),
                ),
                if (row.event.note != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    row.event.note!,
                    style: TextStyle(fontSize: 12.5, height: 1.5, color: palette.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                days == 0 ? 'آج' : (days > 0 ? '${formatCount(days)} دن' : 'گزشتہ'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colour),
              ),
              if (row.event.recommendedFast) ...<Widget>[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('روزہ مستحب', style: TextStyle(fontSize: 10.5, color: palette.gold)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
