import 'prayer_calculator.dart';

/// The six skies behind the prayer card. Chosen from the day's own prayer
/// times rather than the clock, so the wallpaper turns to dawn at Fajr in
/// winter and in summer alike.
enum SkyPhase {
  /// From dusk until the sehri window before Fajr.
  night('رات', 'assets/images/sky_night.jpg'),

  /// Sehri: the last stretch of the night, up to Fajr.
  sehr('سحری', 'assets/images/sky_sehr.jpg'),

  /// Fajr until a little after sunrise.
  dawn('فجر', 'assets/images/sky_dawn.jpg'),

  /// Morning after sunrise.
  morning('صبح / طلوع', 'assets/images/sky_morning.jpg'),

  /// Midday (dopahar), until Asr.
  day('دوپہر', 'assets/images/sky_day.jpg'),

  /// Asr until the sunset glow fades after Maghrib (Maghrib/evening).
  evening('مغرب / شام', 'assets/images/sky_evening.jpg');

  const SkyPhase(this.labelUrdu, this.asset);

  final String labelUrdu;
  final String asset;
}

/// How long after sunrise the sky still reads as dawn (Fajr).
const Duration kDawnAfterSunrise = Duration(minutes: 40);

/// How long before Fajr the sehri sky begins.
const Duration kSehrBeforeFajr = Duration(minutes: 90);

/// How long after the dawn glow the morning (sunrise) sky lasts.
const Duration kMorningAfterDawn = Duration(hours: 3);

/// How long after Maghrib the sky still reads as evening.
const Duration kEveningAfterMaghrib = Duration(minutes: 25);

/// The sky for [now] (the location's wall clock, like every schedule time).
SkyPhase skyPhaseFor(PrayerSchedule schedule, DateTime now) {
  final fajr = schedule.entryFor(PrayerMarker.fajr).time;
  final sunrise = schedule.entryFor(PrayerMarker.sunrise).time;
  final asr = schedule.entryFor(PrayerMarker.asr).time;
  final maghrib = schedule.entryFor(PrayerMarker.maghrib).time;
  if (now.isBefore(fajr.subtract(kSehrBeforeFajr))) return SkyPhase.night;
  if (now.isBefore(fajr)) return SkyPhase.sehr;
  if (now.isBefore(sunrise.add(kDawnAfterSunrise))) return SkyPhase.dawn;
  if (now.isBefore(sunrise.add(kDawnAfterSunrise + kMorningAfterDawn))) {
    return SkyPhase.morning;
  }
  if (now.isBefore(asr)) return SkyPhase.day;
  if (now.isBefore(maghrib.add(kEveningAfterMaghrib))) return SkyPhase.evening;
  return SkyPhase.night;
}
