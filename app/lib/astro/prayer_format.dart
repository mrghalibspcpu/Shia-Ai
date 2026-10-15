// The numbers on the prayer card, the Qibla compass and the tasbeeh: clock
// times, countdowns, dates, coordinates and counts. Readers asked for English
// digits (0-9) in these three features, so every helper here writes them —
// with the Urdu words around them unchanged. Kept in one file so the home
// card, the hero header and the Qibla badges all read identically.

/// Any Arabic-Indic (٠-٩) or Urdu/Persian (۰-۹) digit as its English digit,
/// every other character untouched.
String displayDigits(String value) {
  final buffer = StringBuffer();
  for (final unit in value.codeUnits) {
    if (unit >= 0x0660 && unit <= 0x0669) {
      buffer.writeCharCode(0x30 + unit - 0x0660);
    } else if (unit >= 0x06F0 && unit <= 0x06F9) {
      buffer.writeCharCode(0x30 + unit - 0x06F0);
    } else {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

/// Kept for the call sites written before 1.9; the digits are English now.
String urduDigits(String value) => displayDigits(value);

/// Wraps [text] in a left-to-right isolate (U+2066 … U+2069). Inside an Urdu
/// (right-to-left) line the degree sign would otherwise jump to the wrong
/// side of its number ("°16" instead of "16°"); the isolate marks are
/// invisible.
String ltr(String text) => '\u2066$text\u2069';

/// `1234567` → `1,234,567`.
String formatCount(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return negative ? '-$buffer' : buffer.toString();
}

/// `17:04` → `5:04 شام`, with the part of the day spelled out rather than an
/// AM/PM suffix.
String formatClockUrdu(DateTime time) =>
    '${formatClockDigitsUrdu(time)} ${dayPartUrdu(time.hour)}';

/// Just the digits, 12-hour, for places where the period word is already on
/// screen: `5:04`.
String formatClockDigitsUrdu(DateTime time) {
  final hour24 = time.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour12:$minute';
}

/// The seconds of a clock, for the live clock's small trailing digits: `:09`.
String formatClockSeconds(DateTime time) => ':${time.second.toString().padLeft(2, '0')}';

/// صبح / دوپہر / شام / رات, from the 24-hour clock.
String dayPartUrdu(int hour24) {
  if (hour24 >= 4 && hour24 < 12) return 'صبح';
  if (hour24 >= 12 && hour24 < 16) return 'دوپہر';
  if (hour24 >= 16 && hour24 < 20) return 'شام';
  return 'رات';
}

/// A countdown with Urdu units: `3 گھنٹے 12 منٹ`, `12 منٹ 40 سیکنڈ`, `40 سیکنڈ`.
String formatCountdownUrdu(Duration remaining) {
  final seconds = remaining.isNegative ? 0 : remaining.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  if (hours > 0) return '$hours گھنٹے $minutes منٹ';
  if (minutes > 0) return '$minutes منٹ $secs سیکنڈ';
  return '$secs سیکنڈ';
}

/// A countdown as a stopwatch: `2:07:45`, or `7:45` under an hour.
String formatCountdownClock(Duration remaining) {
  final seconds = remaining.isNegative ? 0 : remaining.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final secs = (seconds % 60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$secs' : '${(seconds % 3600) ~/ 60}:$secs';
}

/// Coordinates for the header line: `33.684° شمال  73.048° مشرق` (each
/// number isolated left-to-right).
String formatCoordinatesUrdu(double latitude, double longitude) {
  final latitudeText = ltr('${latitude.abs().toStringAsFixed(3)}°');
  final longitudeText = ltr('${longitude.abs().toStringAsFixed(3)}°');
  return '$latitudeText ${latitude >= 0 ? 'شمال' : 'جنوب'}  '
      '$longitudeText ${longitude >= 0 ? 'مشرق' : 'مغرب'}';
}

/// Urdu month names of the Gregorian calendar.
const List<String> kGregorianMonthsUrdu = <String>[
  'جنوری',
  'فروری',
  'مارچ',
  'اپریل',
  'مئی',
  'جون',
  'جولائی',
  'اگست',
  'ستمبر',
  'اکتوبر',
  'نومبر',
  'دسمبر',
];

/// Urdu weekday names, Monday first (the order of `DateTime.weekday`).
const List<String> kWeekdaysUrdu = <String>['پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار'];

/// `جمعرات`
String weekdayUrdu(DateTime date) => kWeekdaysUrdu[(date.weekday - 1).clamp(0, 6)];

/// `15 اکتوبر 2026`
String formatDayMonthYearUrdu(DateTime date) =>
    '${date.day} ${kGregorianMonthsUrdu[(date.month - 1).clamp(0, 11)]} ${date.year}';

/// The Gregorian date in Urdu, e.g. `جمعرات، 15 اکتوبر 2026`.
String formatDateUrdu(DateTime date) => '${weekdayUrdu(date)}، ${formatDayMonthYearUrdu(date)}';

/// `256°` — a bearing without its compass point.
String formatDegreesUrdu(double degrees) => ltr('${degrees.round() % 360}°');

/// `256° مغرب` — a bearing with it.
String formatBearingUrdu(double degrees, String pointUrdu) =>
    '${formatDegreesUrdu(degrees)} $pointUrdu';

/// `3,528 کلومیٹر`
String formatKilometresUrdu(double kilometres) => '${formatCount(kilometres.round())} کلومیٹر';
