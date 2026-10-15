import 'dart:math' as math;

import 'package:adhan_dart/adhan_dart.dart';

import 'compass_math.dart' show compassPointUrdu;

// Shia (Jafari) prayer time maths, shared by the timings screen, the Qibla
// compass, the home banner, and the tests.
//
// This file deliberately contains no Flutter and no platform channel: every
// value it returns comes from coordinates, a date, and two Shia presets, so the
// whole thing can be exercised with `flutter test` and never needs a phone, a
// GPS fix, or a network call.
//
// ## Dates and display zones
//
// `adhan_dart` returns each prayer as a **UTC** `DateTime` for the Gregorian
// date it was handed. Two things follow from that:
//
//  * the date handed over is the *device's* calendar date (`DateTime.utc(y, m, d)`
//    of `DateTime.now()`), which is the day the reader is living through;
//  * the times must be shifted by the zone of the *place* the coordinates are
//    in, not by the zone of the phone. A phone travelling, or set to a timezone
//    that does not match its location, would otherwise show Fajr at the wrong
//    hour — the classic "the app says Isha at 3 in the afternoon" bug.
//    `solarZoneOffset` derives that zone from the longitude and only falls back
//    to the device offset when it plausibly agrees with it.

/// The Kaaba, as the specification pins it.
const double kKaabaLatitude = 21.422487;
const double kKaabaLongitude = 39.826206;

/// Islamabad — used only when there is no stored and no fresh location, so the
/// screen always has something to show instead of failing.
const double kFallbackLatitude = 33.6844;
const double kFallbackLongitude = 73.0479;
const String kFallbackCity = 'اسلام آباد';

/// One of the day's eight markers: five obligatory prayers plus the three
/// astronomical ones the Shia day is measured by.
enum PrayerMarker {
  fajr('فجر', 'الفجر'),
  sunrise('طلوعِ آفتاب', 'الشروق'),
  dhuhr('ظہر', 'الظهر'),
  asr('عصر', 'العصر'),
  sunset('غروبِ آفتاب', 'الغروب'),
  maghrib('مغرب', 'المغرب'),
  isha('عشاء', 'العشاء'),
  midnight('نصف شب', 'منتصف اللیل');

  const PrayerMarker(this.labelUrdu, this.labelArabic);

  /// Urdu name shown in the app.
  final String labelUrdu;

  /// Arabic name, shown under the Urdu one on the hero row.
  final String labelArabic;

  /// The five prayers that carry a prayer-time alert.
  bool get isObligatory => switch (this) {
        PrayerMarker.fajr ||
        PrayerMarker.dhuhr ||
        PrayerMarker.asr ||
        PrayerMarker.maghrib ||
        PrayerMarker.isha =>
          true,
        _ => false,
      };

  /// Whether this marker is a step the "next prayer" countdown walks through.
  /// Sunrise is a marker on the card, not a countdown target.
  bool get isCountdownStep => this != PrayerMarker.sunrise;
}

/// A single time on the day's card.
class PrayerEntry {
  const PrayerEntry({
    required this.marker,
    required this.time,
    this.tomorrow = false,
  });

  final PrayerMarker marker;

  /// The wall-clock time in the *display zone* of the schedule's location.
  final DateTime time;

  /// True when this entry belongs to the next calendar day (the Fajr that
  /// closes tonight, shown once the reader has passed midnight).
  final bool tomorrow;

  String get labelUrdu => marker.labelUrdu;
  String get labelArabic => marker.labelArabic;

  @override
  String toString() => '${marker.name}@${time.toIso8601String()}';
}

/// Which prayer's time window is running right now, and when it closes.
class PrayerWindow {
  const PrayerWindow({
    required this.marker,
    required this.endsAt,
    this.previousNight = false,
  });

  final PrayerMarker marker;

  /// The next marker that ends this window (Fajr closes at sunrise, `isha` at
  /// Nisf al-Layl, and so on).
  final DateTime endsAt;

  /// True between midnight and Fajr, when the running window is the previous
  /// night's Isha window.
  final bool previousNight;
}

/// A day of times for one place, ready for the UI.
class PrayerSchedule {
  const PrayerSchedule({
    required this.locationLabel,
    required this.latitude,
    required this.longitude,
    required this.zoneOffset,
    required this.methodLabel,
    required this.maghribAngle,
    required this.entries,
    required this.fajrTomorrow,
  });

  final String locationLabel;
  final double latitude;
  final double longitude;

  /// Offset from UTC used to print every time on the card.
  final Duration zoneOffset;

  /// Urdu name of the calculation preset ("جعفری (لیوا قم)" and friends).
  final String methodLabel;

  /// The sun angle Maghrib was taken at, shown as a footnote.
  final double maghribAngle;

  /// The display day in order: fajr, sunrise, dhuhr, asr, sunset, maghrib,
  /// isha, midnight.
  final List<PrayerEntry> entries;

  /// The next day's Fajr, used by the countdown after Nisf al-Layl.
  final DateTime fajrTomorrow;

  List<PrayerEntry> get obligatory =>
      entries.where((entry) => entry.marker.isObligatory).toList(growable: false);

  List<PrayerEntry> get markers => entries
      .where((entry) => !entry.marker.isObligatory)
      .toList(growable: false);

  PrayerEntry entryFor(PrayerMarker marker) =>
      entries.firstWhere((entry) => entry.marker == marker);

  /// The wall clock of this schedule's location at the instant [deviceClock].
  ///
  /// `PrayerController` publishes exactly this value as "now", which is why a
  /// phone set to the wrong timezone still shows (and counts down to) the right
  /// prayer: everything on the card is in the location's zone.
  DateTime zoneWallClock(DateTime deviceClock) => deviceClock.toUtc().add(zoneOffset);

  /// The next countdown target after [now], never null: when the day is spent
  /// it is the next day's Fajr.
  PrayerEntry nextEntry(DateTime now) {
    for (final entry in _countdownSequence) {
      if (entry.time.isAfter(now)) return entry;
    }
    return PrayerEntry(marker: PrayerMarker.fajr, time: fajrTomorrow, tomorrow: true);
  }

  /// The prayer window running at [now].
  PrayerWindow window(DateTime now) {
    final fajr = entryFor(PrayerMarker.fajr).time;
    if (now.isBefore(fajr)) {
      // Before today's Fajr the reader is still inside the night that began at
      // yesterday's Maghrib: the window that ends at Fajr is Isha's.
      return PrayerWindow(
        marker: PrayerMarker.isha,
        endsAt: fajr,
        previousNight: true,
      );
    }
    PrayerEntry? active;
    DateTime? endsAt;
    for (final entry in entries) {
      if (!entry.marker.isObligatory) continue;
      if (entry.time.isAfter(now)) break;
      active = entry;
      endsAt = _windowEndFor(entry.marker, now);
    }
    if (active == null) {
      // Only reachable if Fajr is exactly now; treat it as Fajr.
      return PrayerWindow(marker: PrayerMarker.fajr, endsAt: entryFor(PrayerMarker.sunrise).time);
    }
    return PrayerWindow(marker: active.marker, endsAt: endsAt!);
  }

  /// The prayer the reader has most likely just finished, if any — the moment
  /// the app offers Tasbeeh-e-Zahra (s.a.) without being asked.
  ///
  /// Two situations count: the prayer's time arrived within [grace], and the
  /// Fajr window closing at sunrise within [grace] (the reader who prayed late
  /// still deserves the offer).
  PrayerMarker? justPrayed(
    DateTime now, {
    Duration grace = const Duration(minutes: 30),
  }) {
    PrayerMarker? started;
    DateTime? startedAt;
    for (final entry in entries) {
      if (!entry.marker.isObligatory) continue;
      final elapsed = now.difference(entry.time);
      if (elapsed.isNegative || elapsed > grace) continue;
      if (startedAt == null || entry.time.isAfter(startedAt)) {
        started = entry.marker;
        startedAt = entry.time;
      }
    }
    if (started != null) return started;

    final sunrise = entryFor(PrayerMarker.sunrise).time;
    final sinceSunrise = now.difference(sunrise);
    if (!sinceSunrise.isNegative && sinceSunrise <= grace) return PrayerMarker.fajr;
    return null;
  }

  List<PrayerEntry> get _countdownSequence => <PrayerEntry>[
        entryFor(PrayerMarker.fajr),
        entryFor(PrayerMarker.dhuhr),
        entryFor(PrayerMarker.asr),
        entryFor(PrayerMarker.maghrib),
        entryFor(PrayerMarker.isha),
        entryFor(PrayerMarker.midnight),
        PrayerEntry(marker: PrayerMarker.fajr, time: fajrTomorrow, tomorrow: true),
      ];

  DateTime _windowEndFor(PrayerMarker marker, DateTime now) {
    final isha = entryFor(PrayerMarker.isha);
    final midnight = entryFor(PrayerMarker.midnight);
    return switch (marker) {
      PrayerMarker.fajr => entryFor(PrayerMarker.sunrise).time,
      PrayerMarker.dhuhr => entryFor(PrayerMarker.asr).time,
      PrayerMarker.asr => entryFor(PrayerMarker.maghrib).time,
      PrayerMarker.maghrib => entryFor(PrayerMarker.isha).time,
      // After Nisf al-Layl the Isha window runs to Fajr.
      PrayerMarker.isha => now.isAfter(midnight.time)
          ? entryFor(PrayerMarker.fajr).time.add(const Duration(days: 1))
          : midnight.time,
      _ => isha.time,
    };
  }
}

/// The two Shia presets, the Qibla formula, the zone helper, and formatting.
class PrayerCalculator {
  const PrayerCalculator._();

  /// Shia Ithna-Ashari, Leva Institute, Qum — Fajr 16°, Isha 14°, Maghrib at
  /// 4° (the disappearance of the eastern red twilight, al-hamra al-mashriqiyya).
  static CalculationParameters jafariQum() {
    final params = CalculationMethodParameters.jafari();
    params.madhab = Madhab.shafi;
    params.highLatitudeRule = HighLatitudeRule.middleOfTheNight;
    return params;
  }

  /// Institute of Geophysics, University of Tehran — the "Leva Qum standard"
  /// of the specification: Fajr 17.7°, Isha 14°, Maghrib at 4.5°.
  static CalculationParameters levaQum() {
    final params = CalculationMethodParameters.tehran();
    params.madhab = Madhab.shafi;
    params.highLatitudeRule = HighLatitudeRule.middleOfTheNight;
    return params;
  }

  static const List<String> presetKeys = <String>['jafari', 'leva'];

  /// Presets with their Urdu labels, in the order the settings picker shows them.
  static List<(String key, String label, CalculationParameters params)> presets() => <(
        String,
        String,
        CalculationParameters
      )>[
        ('jafari', 'جعفری (لیوا قم) — فجر 16°', jafariQum()),
        ('leva', 'تہران (لیوا قم) — فجر 17.7°', levaQum()),
      ];

  static CalculationParameters parametersFor(String? key) =>
      key == 'leva' ? levaQum() : jafariQum();

  static String labelFor(String? key) =>
      key == 'leva' ? 'تہران (لیوا قم) — فجر 17.7°' : 'جعفری (لیوا قم) — فجر 16°';

  static double maghribAngleOf(CalculationParameters params) =>
      params.maghribAngle ?? 4.0;

  /// The Qibla bearing in degrees from **true** north, per the specification:
  ///
  /// ```
  /// θ = atan2( sin(Δλ)·cos(φ₂),  cos(φ₁)·sin(φ₂) − sin(φ₁)·cos(φ₂)·cos(Δλ) )
  /// ```
  ///
  /// normalised to 0°–360°.
  static double qiblaBearing(double latitude, double longitude) {
    final phi1 = _radians(latitude);
    final phi2 = _radians(kKaabaLatitude);
    final dLambda = _radians(kKaabaLongitude - longitude);
    final y = math.sin(dLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
    final theta = math.atan2(y, x) * 180.0 / math.pi;
    return (theta + 360.0) % 360.0;
  }

  /// The great-circle distance to the Kaaba in kilometres — shown as a
  /// reassurance that the bearing belongs to this reader's city.
  static double distanceToKaabaKm(double latitude, double longitude) {
    const earthRadiusKm = 6371.0088;
    final dLat = _radians(kKaabaLatitude - latitude);
    final dLon = _radians(kKaabaLongitude - longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(latitude)) *
            math.cos(_radians(kKaabaLatitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * earthRadiusKm * math.asin(math.min(1.0, math.sqrt(a)));
  }

  /// The hint of the compass: how long a full turn is between [from] and [to],
  /// always taking the short way round so the needle never spins the long way.
  static double shortestTurn(double from, double to) {
    var delta = (to - from) % 360.0;
    if (delta > 180.0) delta -= 360.0;
    if (delta < -180.0) delta += 360.0;
    return delta;
  }

  /// One-eighth-of-the-compass label for a heading, in Urdu.
  static String compassPoint(double degrees) => compassPointUrdu(degrees);

  /// Nisf al-Layl: exactly half of the night that runs from Maghrib (the
  /// Shia night begins at Maghrib, not at sunset) to the next Fajr.
  static DateTime midpoint(DateTime from, DateTime to) =>
      from.add(Duration(microseconds: to.difference(from).inMicroseconds ~/ 2));

  /// The precautionary reading of the same moment: the midpoint of Maghrib to
  /// the next Fajr, which several tables use because it treats the night as
  /// beginning once the eastern redness has gone. It lands a few minutes after
  /// [midpoint]`(sunset, fajrTomorrow)`, and the timings screen prints both so
  /// the reader can follow either.
  static DateTime maghribMidnight(DateTime maghrib, DateTime fajrTomorrow) =>
      midpoint(maghrib, fajrTomorrow);

  /// The zone offset a place's clock should be printed in.
  ///
  /// The device's own offset is preferred whenever it can plausibly belong to
  /// these coordinates; otherwise the longitude is used in whole hours. That
  /// keeps a phone whose timezone is set to UTC (or is wrong) from printing
  /// Islamabad's Fajr at 11:30 at night, while leaving India's half-hour offset
  /// and any real DST alone.
  static Duration solarZoneOffset(
    DateTime now,
    double longitude, {
    Duration? deviceOffset,
  }) {
    final solarHours = longitude / 15.0;
    // `DateTime.timeZoneOffset` is always zero for a UTC `DateTime`, so the
    // device's own offset can be passed in explicitly (tests, and callers that
    // already hold a zoned time).
    final known = deviceOffset ?? now.timeZoneOffset;
    final knownHours = known.inMinutes / 60.0;
    final deviceLooksUnset = known == Duration.zero && solarHours.abs() > 1.0;
    if (!deviceLooksUnset && (knownHours - solarHours).abs() <= 3.5) return known;
    final wholeHours = solarHours.round().clamp(-12, 14);
    return Duration(hours: wholeHours);
  }

  /// The whole day, ready for the UI. [parameters] defaults to the Jafari
  /// preset; [zoneOffset] overrides the derived display zone (tests use it).
  ///
  /// [clock] is the *device* clock — "now", in whatever zone the phone is set
  /// to. The calendar day is taken from that instant **at the location**, and
  /// every time in the schedule is the wall clock of the location, so the whole
  /// app can compare "now" with the day's times without ever mixing zones.
  static PrayerSchedule schedule({
    required double latitude,
    required double longitude,
    required String locationLabel,
    CalculationParameters? parameters,
    String? presetKey,
    DateTime? clock,
    Duration? zoneOffset,
  }) {
    final raw = clock ?? DateTime.now();
    final offset = zoneOffset ?? solarZoneOffset(raw, longitude);
    final wallClock = raw.toUtc().add(offset);
    final day = DateTime.utc(wallClock.year, wallClock.month, wallClock.day);
    final params = parameters ?? parametersFor(presetKey);

    DateTime local(DateTime utc) => utc.add(offset);

    final today = PrayerTimes(
      coordinates: Coordinates(latitude, longitude),
      date: day,
      calculationParameters: params,
    );
    final tomorrow = PrayerTimes(
      coordinates: Coordinates(latitude, longitude),
      date: day.add(const Duration(days: 1)),
      calculationParameters: params,
    );

    final isha = local(today.isha);
    final sunset = local(today.sunset);
    final fajrTomorrow = local(tomorrow.fajr);
    // Nisf al-Layl (شرعی نصف شب): the midpoint of sunset to the next Fajr, the
    // reading the marja' publish (the night is counted from غروبِ آفتاب). The
    // maghrib-based midpoint, which several tables prefer as a precaution, lands
    // a few minutes later — the screen prints it next to this one.
    final midnight = midpoint(sunset, fajrTomorrow);

    final entries = <PrayerEntry>[
      PrayerEntry(marker: PrayerMarker.fajr, time: local(today.fajr)),
      PrayerEntry(marker: PrayerMarker.sunrise, time: local(today.sunrise)),
      PrayerEntry(marker: PrayerMarker.dhuhr, time: local(today.dhuhr)),
      PrayerEntry(marker: PrayerMarker.asr, time: local(today.asr)),
      PrayerEntry(marker: PrayerMarker.sunset, time: sunset),
      PrayerEntry(marker: PrayerMarker.maghrib, time: local(today.maghrib)),
      PrayerEntry(marker: PrayerMarker.isha, time: isha),
      PrayerEntry(marker: PrayerMarker.midnight, time: midnight),
    ];

    return PrayerSchedule(
      locationLabel: locationLabel,
      latitude: latitude,
      longitude: longitude,
      zoneOffset: offset,
      methodLabel: labelFor(presetKey),
      maghribAngle: maghribAngleOf(params),
      entries: entries,
      fajrTomorrow: fajrTomorrow,
    );
  }

  /// `NULL`-safe lookup: nine of ten rows of a schedule are the same shape, so
  /// the helper keeps call sites honest.
  static double _radians(double degrees) => degrees * math.pi / 180.0;
}
