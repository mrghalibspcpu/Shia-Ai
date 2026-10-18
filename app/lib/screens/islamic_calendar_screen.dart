import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../astro/hijri_calendar.dart';
import '../astro/lunar_hijri.dart';
import '../astro/prayer_format.dart';
import '../services/prayer_scope.dart';
import '../widgets/glass_panel.dart';

/// One day of the Hijri year the reader keeps.
class _HolyDay {
  const _HolyDay(this.month, this.day, this.title, {this.note, this.fast = false});

  /// 1 = محرم … 12 = ذو الحجہ.
  final int month;
  final int day;
  final String title;

  /// A line on what the day is, or what is recommended in it.
  final String? note;

  /// A recommended fast, not an obligation.
  final bool fast;

  String get whenUrdu => '$day ${kHijriMonthsUrdu[(month - 1).clamp(0, 11)]}';
}

/// The days of the Hijri year that Shia readers keep, in the order of the
/// year. Where the narrations differ (the day of Sayyida Fatima's martyrdom,
/// for one) the date most widely acted upon is the one listed.
const List<_HolyDay> _kHijriHolyDays = <_HolyDay>[
  _HolyDay(1, 1, 'آغازِ سالِ ہجری', note: 'ہجرتِ نبوی ص سے ہجری تقویم کا پہلا دن۔'),
  _HolyDay(1, 10, 'یومِ عاشورہ', note: 'کربلا میں امام حسین ع اور ان کے ساتھیوں کی شہادت۔'),
  _HolyDay(2, 20, 'اربعین حسینی', note: 'چالیسواں؛ زیارتِ اربعین کا دن۔'),
  _HolyDay(2, 28, 'وفاتِ رسول اللہ ص', note: 'رسول اللہ ص کی وفات اور امام حسن ع کی شہادت۔'),
  _HolyDay(3, 17, 'ولادتِ رسول اللہ ص', note: 'اسی دن امام جعفر صادق ع کی ولادت بھی۔'),
  _HolyDay(6, 3, 'شہادتِ حضرت فاطمہ زہرا س', note: 'مشہور ترین روایت کے مطابق۔'),
  _HolyDay(7, 13, 'ولادتِ امام علی ع', note: 'خانۂ کعبہ میں ولادت۔'),
  _HolyDay(7, 27, 'یومِ مبعث', note: 'نبوتِ محمدی ص کا آغاز۔'),
  _HolyDay(8, 15, 'نیم شعبان', note: 'ولادتِ امام مہدی عج; شب بیداری اور روزہ۔', fast: true),
  _HolyDay(9, 1, 'آغازِ ماہِ رمضان', note: 'روزوں کا پہلا دن۔'),
  _HolyDay(9, 21, 'شہادتِ امام علی ع', note: 'شبِ قدر بھی اسی ماہ کی طاق راتیں ہیں۔'),
  _HolyDay(10, 1, 'عید الفطر', note: 'رمضان کے روزوں کے بعد عید; صدقۂ فطرہ واجب ہے۔'),
  _HolyDay(10, 25, 'شہادتِ امام جعفر صادق ع', note: 'فقہِ جعفری کے امام۔'),
  _HolyDay(12, 9, 'یومِ عرفہ', note: 'حج کا رکنِ اعظم; دعائے عرفہ۔'),
  _HolyDay(12, 10, 'عید الاضحیٰ', note: 'قربانی کا دن۔'),
  _HolyDay(12, 18, 'عیدِ غدیر', note: 'امامت کا اعلان; عیدِ اکبر۔'),
  _HolyDay(12, 24, 'یومِ مباہلہ', note: 'آیتِ مباہلہ کا نزول۔'),
];

/// The year's days, dated in the reader's own calendar.
///
/// The Hijri date is the one the crescent gives (see `CrescentScreen`), so
/// every occasion below falls where it will actually fall for this city — not
/// where a printed table put it.
class IslamicCalendarScreen extends StatelessWidget {
  const IslamicCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = GlassPalette.of(context);
    final controller = PrayerScope.of(context);
    final calendar = controller.lunarHijri;
    final today = controller.hijriToday.date;
    // `now` is already the location's own wall clock (see `zoneWallClock`),
    // so its calendar day is the day the reader is living in.
    final now = controller.now.value;
    final civilToday = DateTime.utc(now.year, now.month, now.day);

    final rows = <_OccasionRow>[
      for (final holy in _kHijriHolyDays)
        _OccasionRow(
          holy: holy,
          // The same day of the month, in the Hijri year that is running.
          civil: _civilFor(calendar, holy, today, civilToday),
        ),
    ];
    rows.sort((a, b) => a.civil.compareTo(b.civil));
    final next = rows.indexWhere((row) => !row.civil.isBefore(civilToday));

    return Scaffold(
      backgroundColor: palette.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('اسلامی تقویم',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 26),
        children: <Widget>[
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
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  'ہر تاریخ اسی شہر سے چاند نظر آنے کے حساب سے ہے، اس لیے کسی '
                  'چھپی ہوئی جدول سے ایک دن پہلے یا بعد ہو سکتی ہے۔',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, height: 1.55, color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < rows.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OccasionCard(
                row: rows[index],
                upcoming: index == next,
                palette: palette,
                days: rows[index].civil.difference(civilToday).inDays,
              ),
            ),
          GlassPanel(
            radius: 20,
            padding: const EdgeInsets.all(13),
            child: Text(
              'جہاں مختلف روایات ہیں وہاں مشہور ترین قول درج ہے۔ ایام البیض '
              '(ہر مہینے کی 13، 14، 15) اور ماہِ رجب و شعبان کے روزے مستحب ہیں۔',
              style: TextStyle(fontSize: 12.5, height: 1.6, color: palette.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// The civil day a Hijri occasion falls on: in the year running now, or — once
/// the day has gone by — in the year that follows.
DateTime _civilFor(LunarHijri calendar, _HolyDay holy, HijriDate today, DateTime civilToday) {
  DateTime forYear(int year) =>
      calendar.civilStartOfMonth(year, holy.month).add(Duration(days: holy.day - 1));
  final thisYear = forYear(today.year);
  if (!thisYear.isBefore(civilToday)) return thisYear;
  return forYear(today.year + 1);
}

class _OccasionRow {
  const _OccasionRow({required this.holy, required this.civil});

  final _HolyDay holy;
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
                  row.holy.title,
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
                  row.holy.whenUrdu,
                  style: TextStyle(fontSize: 12, color: palette.muted),
                ),
                if (row.holy.note != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    row.holy.note!,
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
                days == 0
                    ? 'آج'
                    : (days > 0 ? '${formatCount(days)} دن' : 'گزشتہ'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colour,
                ),
              ),
              if (row.holy.fast) ...<Widget>[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'روزہ',
                    style: TextStyle(fontSize: 10.5, color: palette.gold),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
