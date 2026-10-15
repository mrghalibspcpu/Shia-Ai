import 'package:flutter_test/flutter_test.dart';
import 'package:shia_ai/astro/compass_math.dart';
import 'package:shia_ai/astro/prayer_calculator.dart';
import 'package:shia_ai/astro/prayer_format.dart';

/// The Jafari/Leva-Qum presets, the display-zone rule, the day's logic
/// (windows, countdowns, the post-prayer moment) and the Qibla formula.
///
/// The times are checked against values the JavaScript library the Dart port is
/// based on (`adhan-js` 4.4.6) produces for the same coordinates, dates and
/// method. The tolerance is two minutes: both implementations round to the
/// nearest minute, and a rerun on another machine must not fail the build over
/// a second of rounding.
void main() {
  /// A hand-built day, so the window/countdown logic is tested on its own and
  /// not through the astronomy package.
  PrayerSchedule fixedDay() {
    DateTime at(int hour, int minute, {int day = 15}) =>
        DateTime.utc(2026, 10, day, hour, minute);
    return PrayerSchedule(
      locationLabel: 'ٹیسٹ',
      latitude: 33.6844,
      longitude: 73.0479,
      zoneOffset: Duration.zero,
      methodLabel: 'جعفری (لیوا قم) — فجر 16°',
      maghribAngle: 4,
      entries: <PrayerEntry>[
        PrayerEntry(marker: PrayerMarker.fajr, time: at(5, 0)),
        PrayerEntry(marker: PrayerMarker.sunrise, time: at(6, 30)),
        PrayerEntry(marker: PrayerMarker.dhuhr, time: at(12, 30)),
        PrayerEntry(marker: PrayerMarker.asr, time: at(15, 30)),
        PrayerEntry(marker: PrayerMarker.sunset, time: at(18, 0)),
        PrayerEntry(marker: PrayerMarker.maghrib, time: at(18, 12)),
        PrayerEntry(marker: PrayerMarker.isha, time: at(19, 20)),
        // Sunset 18:00 → Fajr 05:00: Nisf al-Layl is their midpoint.
        PrayerEntry(marker: PrayerMarker.midnight, time: at(23, 30)),
      ],
      fajrTomorrow: at(5, 0, day: 16),
    );
  }

  void expectCloseTo(DateTime actual, DateTime expected, {int minutes = 2}) {
    final difference = actual.difference(expected).inSeconds.abs();
    expect(
      difference,
      lessThanOrEqualTo(minutes * 60),
      reason: 'expected $actual to be within $minutes min of $expected',
    );
  }

  group('Shia (Jafari) preset parameters', () {
    test('Jafari is Fajr 16°, Isha 14°, Maghrib at 4°', () {
      final params = PrayerCalculator.jafariQum();
      expect(params.fajrAngle, 16);
      expect(params.ishaAngle, 14);
      expect(params.maghribAngle, 4);
    });

    test('Leva Qum standard is Fajr 17.7°, Maghrib at 4.5°', () {
      final params = PrayerCalculator.levaQum();
      expect(params.fajrAngle, 17.7);
      expect(params.ishaAngle, 14);
      expect(params.maghribAngle, 4.5);
    });

    test('both presets are offered, and only those', () {
      final presets = PrayerCalculator.presets();
      expect(presets.map((preset) => preset.$1), <String>['jafari', 'leva']);
      expect(PrayerCalculator.parametersFor('nonsense').fajrAngle, 16);
    });
  });

  group('prayer times against the reference implementation', () {
    test('Islamabad, 2026-10-15, Jafari', () {
      final schedule = PrayerCalculator.schedule(
        latitude: 33.6844,
        longitude: 73.0479,
        locationLabel: 'اسلام آباد',
        clock: DateTime.utc(2026, 10, 15, 12),
        zoneOffset: Duration.zero,
      );
      expectCloseTo(schedule.entryFor(PrayerMarker.fajr).time, DateTime.utc(2026, 10, 14, 23, 59));
      expectCloseTo(schedule.entryFor(PrayerMarker.sunrise).time, DateTime.utc(2026, 10, 15, 1, 12));
      expectCloseTo(schedule.entryFor(PrayerMarker.dhuhr).time, DateTime.utc(2026, 10, 15, 6, 54));
      expectCloseTo(schedule.entryFor(PrayerMarker.asr).time, DateTime.utc(2026, 10, 15, 10, 7));
      expectCloseTo(schedule.entryFor(PrayerMarker.sunset).time, DateTime.utc(2026, 10, 15, 12, 34));
      expectCloseTo(schedule.entryFor(PrayerMarker.maghrib).time, DateTime.utc(2026, 10, 15, 12, 50));
      expectCloseTo(schedule.entryFor(PrayerMarker.isha).time, DateTime.utc(2026, 10, 15, 13, 38));
      // Nisf al-Layl: the midpoint of sunset (12:34) to the next Fajr (≈00:00).
      expectCloseTo(schedule.entryFor(PrayerMarker.midnight).time, DateTime.utc(2026, 10, 15, 18, 17));
    });

    test('Karachi, 2026-10-15, Jafari', () {
      final schedule = PrayerCalculator.schedule(
        latitude: 24.8607,
        longitude: 67.0011,
        locationLabel: 'کراچی',
        clock: DateTime.utc(2026, 10, 15, 12),
        zoneOffset: Duration.zero,
      );
      expectCloseTo(schedule.entryFor(PrayerMarker.fajr).time, DateTime.utc(2026, 10, 15, 0, 23));
      expectCloseTo(schedule.entryFor(PrayerMarker.dhuhr).time, DateTime.utc(2026, 10, 15, 7, 18));
      expectCloseTo(schedule.entryFor(PrayerMarker.maghrib).time, DateTime.utc(2026, 10, 15, 13, 19));
      expectCloseTo(schedule.entryFor(PrayerMarker.isha).time, DateTime.utc(2026, 10, 15, 14, 4));
      // Sunset 13:05, next Fajr ≈ 00:23.
      expectCloseTo(schedule.entryFor(PrayerMarker.midnight).time, DateTime.utc(2026, 10, 15, 18, 44));
    });

    test('London, 2026-06-15, Jafari (a summer high-latitude day)', () {
      final schedule = PrayerCalculator.schedule(
        latitude: 51.5074,
        longitude: -0.1278,
        locationLabel: 'London',
        clock: DateTime.utc(2026, 6, 15, 12),
        zoneOffset: Duration.zero,
      );
      expectCloseTo(schedule.entryFor(PrayerMarker.fajr).time, DateTime.utc(2026, 6, 15, 0, 1));
      expectCloseTo(schedule.entryFor(PrayerMarker.sunrise).time, DateTime.utc(2026, 6, 15, 3, 43));
      expectCloseTo(schedule.entryFor(PrayerMarker.maghrib).time, DateTime.utc(2026, 6, 15, 20, 48));
      expectCloseTo(schedule.entryFor(PrayerMarker.isha).time, DateTime.utc(2026, 6, 15, 23, 1));
    });

    test('the Tehran preset moves Fajr earlier and Maghrib later', () {
      final jafari = PrayerCalculator.schedule(
        latitude: 33.6844,
        longitude: 73.0479,
        locationLabel: 'اسلام آباد',
        presetKey: 'jafari',
        clock: DateTime.utc(2026, 10, 15, 12),
        zoneOffset: Duration.zero,
      );
      final leva = PrayerCalculator.schedule(
        latitude: 33.6844,
        longitude: 73.0479,
        locationLabel: 'اسلام آباد',
        presetKey: 'leva',
        clock: DateTime.utc(2026, 10, 15, 12),
        zoneOffset: Duration.zero,
      );
      expect(
        leva.entryFor(PrayerMarker.fajr).time.isBefore(jafari.entryFor(PrayerMarker.fajr).time),
        isTrue,
      );
      expect(
        leva.entryFor(PrayerMarker.maghrib).time.isAfter(jafari.entryFor(PrayerMarker.maghrib).time),
        isTrue,
      );
      expect(leva.entryFor(PrayerMarker.maghrib).time.hour, 12);
      expect(leva.entryFor(PrayerMarker.maghrib).time.minute, closeTo(52, 2));
      expect(leva.maghribAngle, 4.5);
      // Dhuhr and the astronomical markers are method-independent here.
      expect(
        leva.entryFor(PrayerMarker.dhuhr).time,
        jafari.entryFor(PrayerMarker.dhuhr).time,
      );
      expect(
        leva.entryFor(PrayerMarker.sunrise).time,
        jafari.entryFor(PrayerMarker.sunrise).time,
      );
    });

    test('the day is ordered and Maghrib always follows sunset', () {
      final schedule = PrayerCalculator.schedule(
        latitude: 24.8607,
        longitude: 67.0011,
        locationLabel: 'کراچی',
        clock: DateTime.utc(2026, 10, 15, 12),
        zoneOffset: Duration.zero,
      );
      final times = <PrayerMarker, DateTime>{
        for (final entry in schedule.entries) entry.marker: entry.time,
      };
      expect(times[PrayerMarker.fajr]!.isBefore(times[PrayerMarker.sunrise]!), isTrue);
      expect(times[PrayerMarker.sunrise]!.isBefore(times[PrayerMarker.dhuhr]!), isTrue);
      expect(times[PrayerMarker.dhuhr]!.isBefore(times[PrayerMarker.asr]!), isTrue);
      expect(times[PrayerMarker.asr]!.isBefore(times[PrayerMarker.sunset]!), isTrue);
      expect(times[PrayerMarker.sunset]!.isBefore(times[PrayerMarker.maghrib]!), isTrue);
      expect(times[PrayerMarker.maghrib]!.isBefore(times[PrayerMarker.isha]!), isTrue);
      expect(times[PrayerMarker.isha]!.isBefore(times[PrayerMarker.midnight]!), isTrue);
      expect(times[PrayerMarker.midnight]!.isBefore(schedule.fajrTomorrow), isTrue);
      // Shia Maghrib waits for the red twilight to go: a few minutes, not an
      // hour, and never before sunset.
      final gap = times[PrayerMarker.maghrib]!.difference(times[PrayerMarker.sunset]!);
      expect(gap.inMinutes, inInclusiveRange(5, 30));
    });

    test('the midpoint helper splits a span exactly in two', () {
      final from = DateTime.utc(2026, 10, 15, 18, 12);
      final to = DateTime.utc(2026, 10, 16, 5, 2);
      final middle = PrayerCalculator.midpoint(from, to);
      expect(middle.difference(from), to.difference(middle));
      expect(middle, DateTime.utc(2026, 10, 15, 23, 37));
    });

    test('the schedule’s Nisf al-Layl is the midpoint of sunset to Fajr', () {
      final schedule = PrayerCalculator.schedule(
        latitude: 33.6844,
        longitude: 73.0479,
        locationLabel: 'اسلام آباد',
        clock: DateTime.utc(2026, 10, 15, 12),
        zoneOffset: Duration.zero,
      );
      final sunset = schedule.entryFor(PrayerMarker.sunset).time;
      final midnight = schedule.entryFor(PrayerMarker.midnight).time;
      expect(midnight.difference(sunset), schedule.fajrTomorrow.difference(midnight));
      // The precautionary, maghrib-based reading is a few minutes later — the
      // two are printed side by side rather than silently mixed up.
      final maghribMidnight = PrayerCalculator.maghribMidnight(
        schedule.entryFor(PrayerMarker.maghrib).time,
        schedule.fajrTomorrow,
      );
      expect(maghribMidnight.isAfter(midnight), isTrue);
      expect(maghribMidnight.difference(midnight).inMinutes, inInclusiveRange(3, 20));
    });
  });

  group('Qibla bearing', () {
    test('matches the reference for six cities', () {
      final cases = <(double, double, double)>[
        (33.6844, 73.0479, 255.9123), // Islamabad
        (24.8607, 67.0011, 267.7411), // Karachi
        (51.5074, -0.1278, 118.9872), // London
        (40.7128, -74.0060, 58.4817), // New York
        (-33.8688, 151.2093, 277.4996), // Sydney
      ];
      for (final (latitude, longitude, expected) in cases) {
        expect(
          PrayerCalculator.qiblaBearing(latitude, longitude),
          closeTo(expected, 0.01),
          reason: 'qibla from $latitude, $longitude',
        );
      }
    });

    test('is always inside 0°–360°', () {
      for (double latitude = -80; latitude <= 80; latitude += 20) {
        for (double longitude = -180; longitude <= 180; longitude += 30) {
          final bearing = PrayerCalculator.qiblaBearing(latitude, longitude);
          expect(bearing, greaterThanOrEqualTo(0));
          expect(bearing, lessThan(360));
        }
      }
    });

    test('due south of Makkah the bearing is close to north', () {
      // Standing south of the Kaaba: the short way to it is north.
      final bearing = PrayerCalculator.qiblaBearing(10.0, 39.826206);
      expect(bearing, closeTo(0, 0.5));
    });

    test('the distance to the Kaaba is plausible', () {
      expect(PrayerCalculator.distanceToKaabaKm(21.4225, 39.8262), closeTo(0, 1));
      expect(
        PrayerCalculator.distanceToKaabaKm(33.6844, 73.0479),
        closeTo(3528, 150),
      );
      expect(PrayerCalculator.distanceToKaabaKm(24.8607, 67.0011), closeTo(2800, 150));
    });

    test('the shortest turn never asks for a spin the long way round', () {
      expect(PrayerCalculator.shortestTurn(350, 10), closeTo(20, 1e-9));
      expect(PrayerCalculator.shortestTurn(10, 350), closeTo(-20, 1e-9));
      expect(PrayerCalculator.shortestTurn(0, 90), closeTo(90, 1e-9));
    });
  });

  group('display zone', () {
    test('a device stuck on UTC gets the solar zone for the coordinates', () {
      final utc = DateTime.utc(2026, 10, 15, 12);
      expect(PrayerCalculator.solarZoneOffset(utc, 73.0479), const Duration(hours: 5));
      expect(PrayerCalculator.solarZoneOffset(utc, -74.0060), const Duration(hours: -5));
    });

    test('a device whose zone matches its location keeps it', () {
      // The device offset is passed in because a `DateTime.utc` always reports
      // a zero offset, whatever the machine's own timezone is.
      final instant = DateTime.utc(2026, 10, 15, 7);
      expect(
        PrayerCalculator.solarZoneOffset(instant, 67.0011, deviceOffset: const Duration(hours: 5)),
        const Duration(hours: 5),
      );
      // A half-hour zone (India) is left alone too.
      expect(
        PrayerCalculator.solarZoneOffset(instant, 77.2090, deviceOffset: const Duration(hours: 5, minutes: 30)),
        const Duration(hours: 5, minutes: 30),
      );
      // …and DST that is still plausible for the place survives.
      expect(
        PrayerCalculator.solarZoneOffset(instant, 51.5074, deviceOffset: const Duration(hours: 1)),
        const Duration(hours: 1),
      );
    });

    test('a wrong or unset device zone is replaced by the solar zone', () {
      final instant = DateTime.utc(2026, 10, 15, 7);
      // A phone set to UTC while the reader is in Pakistan: 4.87 h → +5.
      expect(
        PrayerCalculator.solarZoneOffset(instant, 73.0479, deviceOffset: Duration.zero),
        const Duration(hours: 5),
      );
      // A phone still on New York time while the reader is in Karachi.
      expect(
        PrayerCalculator.solarZoneOffset(
          instant,
          67.0011,
          deviceOffset: const Duration(hours: -5),
        ),
        const Duration(hours: 4),
      );
    });
  });

  group('windows, countdowns, and the post-prayer moment', () {
    test('before Fajr the running window is the previous night’s Isha', () {
      final window = fixedDay().window(DateTime.utc(2026, 10, 15, 3));
      expect(window.marker, PrayerMarker.isha);
      expect(window.previousNight, isTrue);
      expect(window.endsAt, DateTime.utc(2026, 10, 15, 5));
    });

    test('each window ends at the next marker', () {
      final day = fixedDay();
      expect(day.window(DateTime.utc(2026, 10, 15, 5, 30)).marker, PrayerMarker.fajr);
      expect(day.window(DateTime.utc(2026, 10, 15, 5, 30)).endsAt, DateTime.utc(2026, 10, 15, 6, 30));
      expect(day.window(DateTime.utc(2026, 10, 15, 13)).marker, PrayerMarker.dhuhr);
      expect(day.window(DateTime.utc(2026, 10, 15, 13)).endsAt, DateTime.utc(2026, 10, 15, 15, 30));
      expect(day.window(DateTime.utc(2026, 10, 15, 17)).marker, PrayerMarker.asr);
      expect(day.window(DateTime.utc(2026, 10, 15, 17)).endsAt, DateTime.utc(2026, 10, 15, 18, 12));
      expect(day.window(DateTime.utc(2026, 10, 15, 18, 30)).marker, PrayerMarker.maghrib);
      expect(day.window(DateTime.utc(2026, 10, 15, 18, 30)).endsAt, DateTime.utc(2026, 10, 15, 19, 20));
    });

    test('after Nisf al-Layl the Isha window runs to Fajr', () {
      final window = fixedDay().window(DateTime.utc(2026, 10, 15, 23, 40));
      expect(window.marker, PrayerMarker.isha);
      expect(window.endsAt, DateTime.utc(2026, 10, 16, 5));
    });

    test('the countdown steps over the prayer times in order, then to tomorrow', () {
      final day = fixedDay();
      expect(day.nextEntry(DateTime.utc(2026, 10, 15, 4)).marker, PrayerMarker.fajr);
      expect(day.nextEntry(DateTime.utc(2026, 10, 15, 6)).marker, PrayerMarker.dhuhr);
      expect(day.nextEntry(DateTime.utc(2026, 10, 15, 13)).marker, PrayerMarker.asr);
      expect(day.nextEntry(DateTime.utc(2026, 10, 15, 17)).marker, PrayerMarker.maghrib);
      expect(day.nextEntry(DateTime.utc(2026, 10, 15, 19)).marker, PrayerMarker.isha);
      expect(day.nextEntry(DateTime.utc(2026, 10, 15, 22)).marker, PrayerMarker.midnight);
      final afterMidnight = day.nextEntry(DateTime.utc(2026, 10, 15, 23, 59));
      expect(afterMidnight.marker, PrayerMarker.fajr);
      expect(afterMidnight.tomorrow, isTrue);
      expect(afterMidnight.time, DateTime.utc(2026, 10, 16, 5));
    });

    test('sunrise is a marker but never a countdown target', () {
      final day = fixedDay();
      final next = day.nextEntry(DateTime.utc(2026, 10, 15, 5, 30));
      expect(next.marker, PrayerMarker.dhuhr);
      expect(day.markers.map((entry) => entry.marker), contains(PrayerMarker.sunrise));
      expect(day.obligatory.length, 5);
    });

    test('justPrayed fires in the grace period after a prayer, and not outside', () {
      final day = fixedDay();
      expect(day.justPrayed(DateTime.utc(2026, 10, 15, 19, 25)), PrayerMarker.isha);
      expect(day.justPrayed(DateTime.utc(2026, 10, 15, 12, 35)), PrayerMarker.dhuhr);
      expect(
        day.justPrayed(DateTime.utc(2026, 10, 15, 12, 5)),
        isNull,
        reason: 'a prayer that has not arrived yet is not news',
      );
      expect(day.justPrayed(DateTime.utc(2026, 10, 15, 2)), isNull);
      expect(day.justPrayed(DateTime.utc(2026, 10, 15, 14)), isNull);
      // Fajr's window closing at sunrise counts too: a reader who prayed late.
      expect(day.justPrayed(DateTime.utc(2026, 10, 15, 6, 40)), PrayerMarker.fajr);
      expect(
        day.justPrayed(DateTime.utc(2026, 10, 15, 6, 40), grace: const Duration(minutes: 5)),
        isNull,
      );
    });

    test('wall clock conversions use the schedule’s zone, not the phone’s', () {
      final day = fixedDay();
      expect(
        day.zoneWallClock(DateTime.utc(2026, 10, 15, 12)),
        DateTime.utc(2026, 10, 15, 12),
      );
      expect(day.entries.length, 8);
      expect(day.entryFor(PrayerMarker.sunset).labelUrdu, 'غروبِ آفتاب');
    });
  });

  group('Urdu formatting with English digits', () {
    test('clock times use English digits with a spelled-out day part', () {
      expect(formatClockUrdu(DateTime(2026, 10, 15, 17, 4)), '5:04 شام');
      expect(formatClockUrdu(DateTime(2026, 10, 15, 5, 9)), '5:09 صبح');
      expect(formatClockUrdu(DateTime(2026, 10, 15, 12, 0)), '12:00 دوپہر');
      expect(formatClockDigitsUrdu(DateTime(2026, 10, 15, 0, 30)), '12:30');
      expect(formatClockSeconds(DateTime(2026, 10, 15, 0, 30, 7)), ':07');
    });

    test('no Urdu or Arabic-Indic digit survives in the prayer helpers', () {
      final samples = <String>[
        formatClockUrdu(DateTime(2026, 10, 15, 21, 58)),
        formatCountdownUrdu(const Duration(hours: 9, minutes: 7)),
        formatCountdownClock(const Duration(hours: 2, minutes: 7, seconds: 45)),
        formatCoordinatesUrdu(33.6844, 73.0479),
        formatDateUrdu(DateTime(2026, 10, 15)),
        formatBearingUrdu(255.9, 'مغرب'),
        formatKilometresUrdu(3528.4),
        displayDigits('۱۲:۳۰ — ١٢٣'),
      ];
      for (final sample in samples) {
        expect(RegExp('[\u0660-\u0669\u06F0-\u06F9]').hasMatch(sample), isFalse, reason: sample);
      }
      expect(displayDigits('۱۲:۳۰ — ١٢٣'), '12:30 — 123');
      expect(urduDigits('۵'), '5');
    });

    test('counts and stopwatch countdowns', () {
      expect(formatCount(0), '0');
      expect(formatCount(999), '999');
      expect(formatCount(1000), '1,000');
      expect(formatCount(1234567), '1,234,567');
      expect(formatCount(-14000), '-14,000');
      expect(formatCountdownClock(const Duration(hours: 2, minutes: 7, seconds: 5)), '2:07:05');
      expect(formatCountdownClock(const Duration(minutes: 7, seconds: 45)), '7:45');
      expect(formatCountdownClock(const Duration(seconds: -3)), '0:00');
      expect(formatKilometresUrdu(3528.4), '3,528 کلومیٹر');
    });

    test('day parts follow the sun, not the clock face', () {
      expect(dayPartUrdu(3), 'رات');
      expect(dayPartUrdu(4), 'صبح');
      expect(dayPartUrdu(11), 'صبح');
      expect(dayPartUrdu(12), 'دوپہر');
      expect(dayPartUrdu(16), 'شام');
      expect(dayPartUrdu(20), 'رات');
    });

    test('countdowns adapt their units', () {
      expect(formatCountdownUrdu(const Duration(hours: 3, minutes: 12)), '3 گھنٹے 12 منٹ');
      expect(formatCountdownUrdu(const Duration(minutes: 12, seconds: 40)), '12 منٹ 40 سیکنڈ');
      expect(formatCountdownUrdu(const Duration(seconds: 40)), '40 سیکنڈ');
      expect(formatCountdownUrdu(const Duration(seconds: -5)), '0 سیکنڈ');
    });

    test('coordinates and bearings keep their hemispheres and points', () {
      // Each number+degree is isolated left-to-right so the sign stays on
      // the number's right inside an Urdu line; the marks are invisible.
      String visible(String text) => text.replaceAll(RegExp('[\u2066\u2069]'), '');
      expect(formatCoordinatesUrdu(33.6844, 73.0479), '${ltr('33.684°')} شمال  ${ltr('73.048°')} مشرق');
      expect(visible(formatCoordinatesUrdu(-33.8688, -70.6)), '33.869° جنوب  70.600° مغرب');
      expect(formatDegreesUrdu(255.9), ltr('256°'));
      expect(visible(formatDegreesUrdu(255.9)), '256°');
      expect(visible(formatBearingUrdu(255.9, 'مغرب')), '256° مغرب');
      expect(ltr('16°'), '\u206616°\u2069');
      expect(compassPointUrdu(255.9), 'مغرب');
      expect(compassPointUrdu(0), 'شمال');
      expect(compassPointUrdu(359), 'شمال');
      expect(compassPointUrdu(90), 'مشرق');
    });

    test('dates are written the Urdu way', () {
      expect(formatDateUrdu(DateTime(2026, 10, 15)), 'جمعرات، 15 اکتوبر 2026');
      expect(formatDateUrdu(DateTime(2026, 1, 3)), 'ہفتہ، 3 جنوری 2026');
      expect(weekdayUrdu(DateTime(2026, 10, 16)), 'جمعہ');
      expect(formatDayMonthYearUrdu(DateTime(2026, 10, 15)), '15 اکتوبر 2026');
    });
  });
}
