import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_ai/astro/prayer_calculator.dart';
import 'package:shia_ai/services/alerts.dart';
import 'package:shia_ai/services/prayer_controller.dart';
import 'package:shia_ai/services/prayer_locations.dart';

/// The controller that ties the three features together: the shared location
/// (asked for once), the display-zone clock, the prayer-time watcher that
/// raises the post-prayer Tasbeeh-e-Zahra (s.a.) prompt, and the stored
/// preferences.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A controller with no GPS, no network and no sound.
  Future<PrayerController> controllerFor(
    DateTime Function() clock, {
    PrayerLocation? location,
  }) async {
    final controller = PrayerController(
      clock: clock,
      feedback: const SilentFeedback(),
      locate: () async =>
          location ??
          const PrayerLocation(
            latitude: 33.6844,
            longitude: 73.0479,
            label: 'اسلام آباد',
            source: LocationSource.gps,
          ),
    );
    await controller.start();
    return controller;
  }

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('the published clock is the device instant in the location’s zone', () async {
    // The zone itself is derived from the longitude (see the engine test for
    // the rule); what matters here is that *every* comparison in the app uses
    // that zone rather than the phone's own.
    var device = DateTime.utc(2026, 10, 15, 7, 30);
    final controller = await controllerFor(() => device);
    final offset = controller.schedule.zoneOffset;
    expect(controller.now.value, controller.schedule.zoneWallClock(device));
    expect(controller.now.value.isAtSameMomentAs(device.add(offset)), isTrue);
    // And it ticks with the device clock.
    device = device.add(const Duration(seconds: 1));
    controller.tickNow();
    expect(controller.now.value.second, controller.schedule.zoneWallClock(device).second);
    expect(controller.now.value.difference(controller.schedule.zoneWallClock(DateTime.utc(2026, 10, 15, 7, 30))).inSeconds, 1);
  });

  test('the coordinates feed the Qibla bearing and the distance in one step', () async {
    final controller = await controllerFor(() => DateTime.utc(2026, 10, 15, 6));
    expect(controller.qiblaBearing, closeTo(255.91, 0.05));
    expect(controller.distanceToKaabaKm, closeTo(3528, 150));
    expect(controller.location.label, 'اسلام آباد');
    expect(controller.location.source, LocationSource.gps);
  });

  test('a prayer time arriving raises exactly one alert', () async {
    var device = DateTime.utc(2026, 10, 15, 6);
    final controller = await controllerFor(() => device);
    final offset = controller.schedule.zoneOffset;
    final dhuhr = controller.schedule.entryFor(PrayerMarker.dhuhr).time;

    // Two seconds after Dhuhr, in the device's own terms.
    device = dhuhr.subtract(offset).add(const Duration(seconds: 2));
    controller.tickNow();

    final alert = controller.takePendingAlert();
    expect(alert, isNotNull);
    expect(alert!.marker, PrayerMarker.dhuhr);
    expect(alert.at, dhuhr);
    // Drained: the prompt must not reappear on the next tick.
    expect(controller.takePendingAlert(), isNull);
    device = device.add(const Duration(seconds: 1));
    controller.tickNow();
    expect(controller.takePendingAlert(), isNull);
  });

  test('the watcher ignores prayers that were already past when the app opened', () async {
    var device = DateTime.utc(2026, 10, 15, 6);
    final controller = await controllerFor(() => device);
    final offset = controller.schedule.zoneOffset;
    final dhuhr = controller.schedule.entryFor(PrayerMarker.dhuhr).time;
    // Open the app two hours after Dhuhr: the time is history, not news.
    device = dhuhr.subtract(offset).add(const Duration(hours: 2));
    controller.tickNow();
    expect(controller.takePendingAlert(), isNull);
    expect(controller.justPrayed, isNull, reason: 'the grace period is long over');
  });

  test('the alert follows the chosen preset', () async {
    var device = DateTime.utc(2026, 10, 15, 6);
    final controller = await controllerFor(() => device);
    final offset = controller.schedule.zoneOffset;
    final jafariFajr = controller.schedule.entryFor(PrayerMarker.fajr).time;

    controller.setPreset('leva');
    expect(controller.presetKey, 'leva');
    final levaFajr = controller.schedule.entryFor(PrayerMarker.fajr).time;
    expect(levaFajr.isBefore(jafariFajr), isTrue);

    // The Tehran preset moves Fajr about eight minutes earlier, so a clock
    // that was waiting for the Jafari Fajr is already inside its window.
    device = levaFajr.subtract(offset).add(const Duration(seconds: 3));
    controller.tickNow();
    final alert = controller.takePendingAlert();
    expect(alert?.marker, PrayerMarker.fajr);
    expect(alert?.at, levaFajr);
  });

  test('a manual city replaces the fix without another location request', () async {
    var requests = 0;
    final controller = PrayerController(
      clock: () => DateTime.utc(2026, 10, 15, 6),
      feedback: const SilentFeedback(),
      locate: () async {
        requests++;
        return const PrayerLocation(
          latitude: 33.6844,
          longitude: 73.0479,
          label: 'اسلام آباد',
          source: LocationSource.gps,
        );
      },
    );
    await controller.start();
    expect(requests, 1);
    await controller.useCity(
      const PlaceSuggestion('کربلا', 'Karbala', 32.6160, 44.0249),
    );
    expect(controller.location.label, 'کربلا');
    expect(controller.location.source, LocationSource.manual);
    expect(controller.qiblaBearing, closeTo(199.47, 0.1));
    expect(requests, 1, reason: 'picking a city must not re-run the location chain');
  });

  test('a stored location is used on the next launch, offline and instantly', () async {
    await PrayerLocations.store(
      const PrayerLocation(
        latitude: 24.8607,
        longitude: 67.0011,
        label: 'کراچی',
        source: LocationSource.manual,
      ),
    );
    var requests = 0;
    final controller = PrayerController(
      clock: () => DateTime.utc(2026, 10, 15, 6),
      feedback: const SilentFeedback(),
      locate: () async {
        requests++;
        return null;
      },
    );
    await controller.start();
    expect(controller.location.label, 'کراچی');
    expect(controller.qiblaBearing, closeTo(267.74, 0.05));
    expect(requests, 0, reason: 'a stored location means no location request at all');
  });

  test('with no fix, no IP and nothing stored, the fallback keeps the card alive', () async {
    final controller = PrayerController(
      clock: () => DateTime.utc(2026, 10, 15, 6),
      feedback: const SilentFeedback(),
      locate: () async => null,
    );
    await controller.start();
    expect(controller.location.isFallback, isTrue);
    expect(controller.location.latitude, closeTo(33.6844, 1e-9));
    final resolved = await controller.refreshLocation();
    expect(resolved.isFallback, isTrue);
    expect(controller.schedule.entries.length, 8);
  });

  test('the alert, sound and vibration switches persist', () async {
    final controller = await controllerFor(() => DateTime.utc(2026, 10, 15, 6));
    expect(controller.alertsEnabled, isTrue);
    expect(controller.soundEnabled, isTrue);
    controller.setAlertsEnabled(false);
    controller.setSoundEnabled(false);
    controller.setHapticsEnabled(false);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final reloaded = PrayerController(
      clock: () => DateTime.utc(2026, 10, 15, 6),
      feedback: const SilentFeedback(),
      locate: () async => null,
    );
    await reloaded.start();
    expect(reloaded.alertsEnabled, isFalse);
    expect(reloaded.soundEnabled, isFalse);
    expect(reloaded.hapticsEnabled, isFalse);
  });

  test('justPrayed exposes the post-prayer shortcut for the home screen', () async {
    var device = DateTime.utc(2026, 10, 15, 6);
    final controller = await controllerFor(() => device);
    final offset = controller.schedule.zoneOffset;
    final maghrib = controller.schedule.entryFor(PrayerMarker.maghrib).time;

    expect(controller.justPrayed, isNull);
    device = maghrib.subtract(offset).add(const Duration(minutes: 4));
    controller.tickNow();
    expect(controller.justPrayed, PrayerMarker.maghrib);
    expect(controller.window.marker, PrayerMarker.maghrib);
    expect(controller.nextEntry.marker, PrayerMarker.isha);
  });
}
