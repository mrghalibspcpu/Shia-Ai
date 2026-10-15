import '../text_utils.dart' show arabicNumerals;

// Urdu presentation of the numbers on the prayer card: clock times, the
// countdown, dates and coordinates. Kept in one file so the home banner, the
// hero header and the Qibla badges all read identically.

/// Converts the digits of a string, keeping every other character (so `05`
/// stays `۰۵` and `33.684` stays `۳۳.۶۸۴`).
String urduDigits(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    final digit = int.tryParse(character);
    buffer.write(digit == null ? character : arabicNumerals(digit));
  }
  return buffer.toString();
}

/// `17:04` → `۵:۰۴ شام`, with the part of the day spelled out rather than an
/// AM/PM suffix.
String formatClockUrdu(DateTime time) =>
    '${formatClockDigitsUrdu(time)} ${dayPartUrdu(time.hour)}';

/// Just the digits, for places where the period word is already on screen.
String formatClockDigitsUrdu(DateTime time) {
  final hour24 = time.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return urduDigits('$hour12:$minute');
}

/// صبح / دوپہر / شام / رات, from the 24-hour clock.
String dayPartUrdu(int hour24) {
  if (hour24 >= 4 && hour24 < 12) return 'صبح';
  if (hour24 >= 12 && hour24 < 16) return 'دوپہر';
  if (hour24 >= 16 && hour24 < 20) return 'شام';
  return 'رات';
}

/// A countdown with Urdu units: `۳ گھنٹے ۱۲ منٹ`, `۱۲ منٹ ۴۰ سیکنڈ`, `۴۰ سیکنڈ`.
String formatCountdownUrdu(Duration remaining) {
  final seconds = remaining.isNegative ? 0 : remaining.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  if (hours > 0) {
    return '${arabicNumerals(hours)} گھنٹے ${arabicNumerals(minutes)} منٹ';
  }
  if (minutes > 0) {
    return '${arabicNumerals(minutes)} منٹ ${arabicNumerals(secs)} سیکنڈ';
  }
  return '${arabicNumerals(secs)} سیکنڈ';
}

/// Coordinates for the header line: `۳۳.۶۸۴° شمال  ۷۳.۰۴۸° مشرق`.
String formatCoordinatesUrdu(double latitude, double longitude) {
  final latitudeText = urduDigits(latitude.abs().toStringAsFixed(3));
  final longitudeText = urduDigits(longitude.abs().toStringAsFixed(3));
  return '$latitudeText° ${latitude >= 0 ? 'شمال' : 'جنوب'}  '
      '$longitudeText° ${longitude >= 0 ? 'مشرق' : 'مغرب'}';
}

/// The Gregorian date in Urdu, e.g. `جمعرات، ۱۵ اکتوبر ۲۰۲۶`.
String formatDateUrdu(DateTime date) {
  const months = <String>[
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
  const weekdays = <String>['پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار'];
  final month = months[(date.month - 1).clamp(0, 11)];
  final weekday = weekdays[(date.weekday - 1).clamp(0, 6)];
  return '$weekday، ${arabicNumerals(date.day)} $month ${arabicNumerals(date.year)}';
}

/// `۲۵۶°` — a bearing without its compass point.
String formatDegreesUrdu(double degrees) => '${arabicNumerals(degrees.round() % 360)}°';

/// `۲۵۶° مغرب` — a bearing with it.
String formatBearingUrdu(double degrees, String pointUrdu) =>
    '${formatDegreesUrdu(degrees)} $pointUrdu';
