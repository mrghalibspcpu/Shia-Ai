import 'prayer_calculator.dart';

/// The four skies behind the prayer card. Chosen from the day's own prayer
/// times rather than the clock, so the wallpaper turns to dawn at Fajr in
/// winter and in summer alike.
enum SkyPhase {
  /// Fajr until a little after sunrise.
  dawn('سحر', 'assets/images/sky_dawn.jpg'),

  /// Morning and midday, until Asr.
  day('دوپہر', 'assets/images/sky_day.jpg'),

  /// Asr until the sunset glow fades after Maghrib.
  evening('شام', 'assets/images/sky_evening.jpg'),

  /// From dusk until Fajr.
  night('رات', 'assets/images/sky_night.jpg');

  const SkyPhase(this.labelUrdu, this.asset);

  final String labelUrdu;
  final String asset;
}

/// How long after sunrise the sky still reads as dawn.
const Duration kDawnAfterSunrise = Duration(minutes: 40);

/// How long after Maghrib the sky still reads as evening.
const Duration kEveningAfterMaghrib = Duration(minutes: 25);

/// The sky for [now] (the location's wall clock, like every schedule time).
SkyPhase skyPhaseFor(PrayerSchedule schedule, DateTime now) {
  final fajr = schedule.entryFor(PrayerMarker.fajr).time;
  final sunrise = schedule.entryFor(PrayerMarker.sunrise).time;
  final asr = schedule.entryFor(PrayerMarker.asr).time;
  final maghrib = schedule.entryFor(PrayerMarker.maghrib).time;
  if (now.isBefore(fajr)) return SkyPhase.night;
  if (now.isBefore(sunrise.add(kDawnAfterSunrise))) return SkyPhase.dawn;
  if (now.isBefore(asr)) return SkyPhase.day;
  if (now.isBefore(maghrib.add(kEveningAfterMaghrib))) return SkyPhase.evening;
  return SkyPhase.night;
}
