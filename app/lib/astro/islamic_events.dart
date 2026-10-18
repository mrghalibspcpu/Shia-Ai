import 'hijri_calendar.dart';

/// A widely observed Twelver Shia occasion on a Hijri month/day.
///
/// Historical reports and local moon-sighting decisions can differ. The
/// calendar therefore keeps the commonly observed date and explains reported
/// variations in [note] rather than presenting every anniversary as universal.
class IslamicEvent {
  const IslamicEvent(
    this.month,
    this.day,
    this.title, {
    this.note,
    this.recommendedFast = false,
  });

  /// Hijri month number: 1 = Muharram … 12 = Dhu al-Hijjah.
  final int month;
  final int day;
  final String title;
  final String? note;
  final bool recommendedFast;

  String get dateUrdu => '$day ${kHijriMonthsUrdu[(month - 1).clamp(0, 11)]}';
}

/// Commonly observed Shia dates, reviewed against the event calendars of
/// IMAM-US and Wikishia. Dates tied to disputed historical reports are marked
/// in the note; actual Gregorian dates still depend on each community's hilal.
const List<IslamicEvent> kShiaIslamicEvents = <IslamicEvent>[
  IslamicEvent(1, 1, 'آغازِ سالِ ہجری', note: 'ہجرتِ نبوی ص سے ہجری تقویم کا پہلا دن۔'),
  IslamicEvent(1, 10, 'یومِ عاشورہ', note: 'کربلا میں امام حسین ع اور ان کے ساتھیوں کی شہادت۔'),
  IslamicEvent(2, 20, 'اربعین حسینی', note: 'چالیسواں؛ زیارتِ اربعین کا دن۔'),
  IslamicEvent(2, 28, 'وفاتِ رسول اللہ ص اور شہادتِ امام حسن ع',
      note: 'مشہور شیعہ تقویم میں 28 صفر؛ بعض تاریخی روایات دوسری تاریخیں بھی دیتی ہیں۔'),
  IslamicEvent(3, 8, 'شہادتِ امام حسن عسکری ع', note: 'آٹھویں ربیع الاول کی معروف تاریخ۔'),
  IslamicEvent(3, 17, 'ولادتِ رسول اللہ ص و امام جعفر صادق ع',
      note: 'مشہور قول کے مطابق دونوں ولادتیں اسی دن ہیں۔'),
  IslamicEvent(5, 5, 'ولادتِ حضرت زینب س', note: 'مدینہ میں ولادت؛ تاریخ معروف تقویم کے مطابق۔'),
  IslamicEvent(6, 3, 'شہادتِ حضرت فاطمہ زہرا س',
      note: 'مشہور ترین روایت کے مطابق؛ 75 اور 95 دن والی روایات سے تاریخ میں فرق آتا ہے۔'),
  IslamicEvent(6, 20, 'ولادتِ حضرت فاطمہ زہرا س', note: 'جمادی الثانی کی معروف تقویمی تاریخ۔'),
  IslamicEvent(7, 1, 'ولادتِ امام محمد باقر ع'),
  IslamicEvent(7, 2, 'ولادتِ امام علی نقی ع', note: 'ولادت کی تاریخ میں روایتی اختلاف ہے۔'),
  IslamicEvent(7, 3, 'شہادتِ امام علی نقی ع', note: 'مشہور شیعہ تقویم میں 3 رجب۔'),
  IslamicEvent(7, 10, 'ولادتِ امام محمد تقی جواد ع'),
  IslamicEvent(7, 13, 'ولادتِ امام علی ع', note: 'خانۂ کعبہ میں ولادت۔'),
  IslamicEvent(7, 15, 'وفاتِ حضرت زینب س', note: 'رائج قول؛ تاریخی روایات میں اختلاف موجود ہے۔'),
  IslamicEvent(7, 25, 'شہادتِ امام موسیٰ کاظم ع'),
  IslamicEvent(7, 27, 'یومِ مبعث', note: 'نبوتِ محمدی ص کا آغاز۔'),
  IslamicEvent(8, 3, 'ولادتِ امام حسین ع'),
  IslamicEvent(8, 4, 'ولادتِ حضرت عباس ع'),
  IslamicEvent(8, 5, 'ولادتِ امام زین العابدین ع'),
  IslamicEvent(8, 11, 'ولادتِ حضرت علی اکبر ع'),
  IslamicEvent(8, 15, 'نیم شعبان',
      note: 'ولادتِ امام مہدی عج؛ شبِ عبادت۔ روزہ مستحب ہے، واجب نہیں۔',
      recommendedFast: true),
  IslamicEvent(9, 10, 'وفاتِ حضرت خدیجہ کبریٰ س', note: 'دس رمضان کی معروف روایت۔'),
  IslamicEvent(9, 15, 'ولادتِ امام حسن مجتبیٰ ع'),
  IslamicEvent(9, 19, 'ضربتِ امام علی ع', note: 'شبِ قدر کی راتوں میں سے ایک۔'),
  IslamicEvent(9, 21, 'شہادتِ امام علی ع', note: 'شبِ قدر کی راتوں میں سے ایک۔'),
  IslamicEvent(9, 23, 'شبِ قدر', note: 'تین اہم طاق راتوں میں 23 رمضان کو خاص اہمیت حاصل ہے۔'),
  IslamicEvent(10, 1, 'عید الفطر', note: 'رمضان کے روزوں کے بعد عید؛ صدقۂ فطرہ کے احکام اپنے مرجع سے دیکھیں۔'),
  IslamicEvent(10, 8, 'یومِ یادِ شہدائے بقیع', note: 'جنت البقیع کے مزارات کی مسماری کی یاد۔'),
  IslamicEvent(10, 25, 'شہادتِ امام جعفر صادق ع', note: 'فقہِ جعفری کے امام۔'),
  IslamicEvent(11, 1, 'ولادتِ حضرت فاطمہ معصومہ س'),
  IslamicEvent(11, 11, 'ولادتِ امام علی رضا ع'),
  IslamicEvent(11, 25, 'دحو الارض', note: 'عبادت اور روزے کا مستحب دن؛ فقہی تفصیل اپنے مرجع سے دیکھیں۔',
      recommendedFast: true),
  IslamicEvent(12, 1, 'عقدِ امام علی ع و حضرت فاطمہ س', note: 'ذوالحجہ کی پہلی تاریخ معروف تقویمی قول ہے۔'),
  IslamicEvent(12, 7, 'شہادتِ امام محمد باقر ع'),
  IslamicEvent(12, 9, 'یومِ عرفہ', note: 'حج کا رکنِ اعظم؛ دعائے عرفہ۔'),
  IslamicEvent(12, 10, 'عید الاضحیٰ', note: 'قربانی کے احکام اپنے مرجعِ تقلید سے معلوم کریں۔'),
  IslamicEvent(12, 18, 'عیدِ غدیر', note: 'اعلانِ ولایت؛ عیدِ اکبر۔'),
  IslamicEvent(12, 24, 'یومِ مباہلہ', note: 'آیتِ مباہلہ کے واقعے کی یاد۔'),
];
