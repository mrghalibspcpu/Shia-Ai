import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../astro/prayer_calculator.dart';
import 'alerts.dart';
import 'prayer_locations.dart';

/// The location chain the controller drives: device fix → IP lookup → null.
typedef LocationResolver = Future<PrayerLocation?> Function();

/// A prayer whose time has just arrived — what the home screen turns into a
/// "نماز کا وقت" alert with a Tasbeeh-e-Zahra (s.a.) shortcut.
class PrayerAlertEvent {
  const PrayerAlertEvent({required this.marker, required this.at});

  final PrayerMarker marker;
  final DateTime at;
}

/// One place for everything the three features share:
///
/// * the coordinates (asked for once, stored, reused by the Qibla bearing);
/// * the day's [PrayerSchedule] and the live clock the countdowns read;
/// * the reader's alert/sound/chime preferences;
/// * the prayer-time watcher that fires [PrayerAlertEvent]s.
///
/// It is created once by `main.dart` and passed down, so the Qibla screen never
/// triggers a second location request and the home banner, the timings screen
/// and the compass can never disagree about where the reader is.
class PrayerController extends ChangeNotifier with WidgetsBindingObserver {
  PrayerController({
    DateTime Function()? clock,
    FeedbackSink? feedback,
    LocationResolver? locate,
  })  : _clock = clock ?? DateTime.now,
        _feedback = feedback ?? Alerts.instance,
        _locate = locate ?? resolveLocation {
    _schedule = PrayerCalculator.schedule(
      latitude: PrayerLocation.fallback.latitude,
      longitude: PrayerLocation.fallback.longitude,
      locationLabel: PrayerLocation.fallback.label,
      clock: _clock(),
    );
    now.value = _displayNow(_clock());
  }

  /// The location chain, injectable so tests never touch the GPS or the
  /// network: a device fix first, then the IP lookup, then nothing.
  static Future<PrayerLocation?> resolveLocation() async =>
      await PrayerLocations.fromDevice() ?? await PrayerLocations.fromIp();

  static const String presetKeyStorage = 'prayer_preset_v1';
  static const String alertStorage = 'prayer_alert_v1';

  final DateTime Function() _clock;
  final FeedbackSink _feedback;
  final LocationResolver _locate;

  /// The live clock in the *location's* zone, ticking once a second. Widgets
  /// that only show a countdown listen to this instead of the whole
  /// controller, so nothing else rebuilds while the app sits open.
  final ValueNotifier<DateTime> now = ValueNotifier<DateTime>(DateTime.now());

  PrayerLocation _location = PrayerLocation.fallback;
  late PrayerSchedule _schedule;
  bool _loadingLocation = false;
  bool _started = false;
  Timer? _ticker;
  String? _lastFiredKey;
  final List<PrayerAlertEvent> _pendingAlerts = <PrayerAlertEvent>[];

  bool _alertsEnabled = true;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  String _presetKey = 'jafari';

  PrayerLocation get location => _location;
  PrayerSchedule get schedule => _schedule;
  bool get loadingLocation => _loadingLocation;
  bool get alertsEnabled => _alertsEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  String get presetKey => _presetKey;

  /// Degrees from true north to the Kaaba, from the same coordinates the
  /// timings use.
  double get qiblaBearing =>
      PrayerCalculator.qiblaBearing(_location.latitude, _location.longitude);

  double get distanceToKaabaKm =>
      PrayerCalculator.distanceToKaabaKm(_location.latitude, _location.longitude);

  /// The prayer window running right now.
  PrayerWindow get window => _schedule.window(now.value);

  /// The next countdown target (Fajr, Dhuhr, Asr, Maghrib, Isha, or Nisf al-Layl).
  PrayerEntry get nextEntry => _schedule.nextEntry(now.value);

  /// The prayer the reader has just finished, if any — the trigger for the
  /// post-prayer Tasbeeh-e-Zahra (s.a.) shortcut.
  PrayerMarker? get justPrayed => _schedule.justPrayed(now.value);

  /// Loads stored coordinates and preferences, then starts the clock. Safe to
  /// call twice.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    await _loadPreferences();
    // The clock starts before the location is known, so the card and its
    // countdown are live from the first frame; the times below simply become
    // exact once the coordinates land.
    _rebuildSchedule();
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();

    final stored = await PrayerLocations.loadStored();
    if (stored != null) {
      // A stored location means no location request at all: the app opens
      // offline and instantly with the reader's own city.
      await _applyLocation(stored, persist: false);
      return;
    }
    // First run only: a device fix, then the IP lookup, and Islamabad last.
    await refreshLocation();
  }

  /// The location chain: high-accuracy GPS → IP lookup → whatever is stored →
  /// Islamabad. Returns the location that ended up in use.
  Future<PrayerLocation> refreshLocation() async {
    if (_loadingLocation) return _location;
    _loadingLocation = true;
    notifyListeners();

    PrayerLocation? resolved = await _locate();
    if (resolved != null) {
      await PrayerLocations.store(resolved);
      await _applyLocation(resolved, persist: false);
    } else if (_location.isFallback) {
      const seeded = PrayerLocation(
        latitude: kFallbackLatitude,
        longitude: kFallbackLongitude,
        label: 'اسلام آباد (ڈیفالٹ)',
        source: LocationSource.fallback,
      );
      await PrayerLocations.store(seeded);
      await _applyLocation(seeded, persist: false);
    }

    _loadingLocation = false;
    notifyListeners();
    return _location;
  }

  /// Manual city selection from the picker.
  Future<void> useCity(PlaceSuggestion city) async {
    final location = PrayerLocation(
      latitude: city.latitude,
      longitude: city.longitude,
      label: city.nameUrdu,
      source: LocationSource.manual,
      savedAt: DateTime.now(),
    );
    await _applyLocation(location, persist: true);
  }

  /// Coordinates typed straight into the search box.
  Future<void> useCoordinates(double latitude, double longitude, {String? label}) async {
    await _applyLocation(
      PrayerLocation(
        latitude: latitude,
        longitude: longitude,
        label: label ?? 'دستی مقام',
        source: LocationSource.manual,
        savedAt: DateTime.now(),
      ),
      persist: true,
    );
  }

  Future<void> _applyLocation(PrayerLocation location, {required bool persist}) async {
    _location = location;
    _rebuildSchedule();
    if (persist) await PrayerLocations.store(location);
    notifyListeners();
  }

  void setPreset(String key) {
    if (_presetKey == key) return;
    _presetKey = key;
    _rebuildSchedule();
    unawaited(_savePreferences());
    notifyListeners();
  }

  void setAlertsEnabled(bool value) {
    _alertsEnabled = value;
    unawaited(_savePreferences());
    notifyListeners();
  }

  void setSoundEnabled(bool value) {
    _soundEnabled = value;
    unawaited(_savePreferences());
    notifyListeners();
  }

  void setHapticsEnabled(bool value) {
    _hapticsEnabled = value;
    unawaited(_savePreferences());
    notifyListeners();
  }

  /// Pops the oldest prayer alert, if the UI has not consumed it yet.
  PrayerAlertEvent? takePendingAlert() {
    if (_pendingAlerts.isEmpty) return null;
    if (now.value.difference(_pendingAlerts.first.at) > const Duration(minutes: 30)) {
      _pendingAlerts.removeAt(0);
      return takePendingAlert();
    }
    return _pendingAlerts.removeAt(0);
  }

  /// The device clock expressed as the wall clock of the reader's location.
  DateTime _displayNow(DateTime deviceClock) => _schedule.zoneWallClock(deviceClock);

  /// Rebuilds the day for the current location, preset and calendar day, and
  /// re-points the live clock at the display zone.
  void _rebuildSchedule() {
    final raw = _clock();
    _schedule = PrayerCalculator.schedule(
      latitude: _location.latitude,
      longitude: _location.longitude,
      locationLabel: _location.label,
      presetKey: _presetKey,
      clock: raw,
    );
    now.value = _displayNow(raw);
  }

  void _tick() {
    final raw = _clock();
    final previous = now.value;
    now.value = _displayNow(raw);

    // Midnight rollover and timezone/DST drift: recompute in place, so the
    // card stays correct even if the app has been open since yesterday or the
    // phone crossed into daylight saving time while it sat in a pocket.
    final crossedDay = now.value.day != previous.day;
    final zoneMoved =
        _schedule.zoneOffset != PrayerCalculator.solarZoneOffset(raw, _location.longitude);
    if (crossedDay || zoneMoved) {
      _rebuildSchedule();
      notifyListeners();
    }

    _checkPrayerAlerts();
  }

  /// One tick of the clock, without waiting for the timer — used by the tests
  /// (they cannot wait a real second).
  @visibleForTesting
  void tickNow() => _tick();

  void _checkPrayerAlerts() {
    final clock = now.value;
    for (final entry in _schedule.entries) {
      if (entry.marker.isObligatory) {
        final key = '${entry.time.toIso8601String()}:${entry.marker.name}';
        if (key == _lastFiredKey) continue;
        final elapsed = clock.difference(entry.time);
        // Fire once, inside the first minute, and never for a time that was
        // already in the past when the app opened.
        if (elapsed.isNegative || elapsed.inMinutes >= 1) continue;
        _lastFiredKey = key;
        _pendingAlerts.add(PrayerAlertEvent(marker: entry.marker, at: entry.time));
        if (_alertsEnabled) unawaited(_feedback.playPrayerChime());
        if (_hapticsEnabled) unawaited(_feedback.prayerHaptic());
        notifyListeners();
        return;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Coming back to the app: catch up on the clock, and recover the day or
    // the zone if either moved while the app slept.
    _rebuildSchedule();
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _presetKey = prefs.getString(presetKeyStorage) ?? 'jafari';
      final raw = prefs.getString(alertStorage);
      if (raw != null) {
        final stored = Uri.splitQueryString(raw);
        _alertsEnabled = stored['alerts'] != 'false';
        _soundEnabled = stored['sound'] != 'false';
        _hapticsEnabled = stored['haptics'] != 'false';
      }
    } catch (_) {
      return;
    }
    _rebuildSchedule();
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(presetKeyStorage, _presetKey);
      await prefs.setString(
        alertStorage,
        'alerts=$_alertsEnabled&sound=$_soundEnabled&haptics=$_hapticsEnabled',
      );
    } catch (_) {
      return;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    now.dispose();
    super.dispose();
  }
}
