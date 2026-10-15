import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'city_index.dart';
import 'place_names.dart';

/// Reads a number that a JSON payload may have sent as a number, a string, or
/// not at all. File-level because both `PrayerLocation` and `PrayerLocations`
/// parse payloads (the two IP providers disagree on types).
double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

/// Where the coordinates on screen came from. The UI says so plainly, so a
/// reader can tell a GPS fix from a guess.
enum LocationSource {
  gps('جی پی ایس'),
  ip('انٹرنیٹ (IP)'),
  manual('منتخب کردہ شہر'),
  fallback('ڈیفالٹ');

  const LocationSource(this.labelUrdu);

  final String labelUrdu;

  static LocationSource fromName(String? name) => switch (name) {
        'gps' => LocationSource.gps,
        'ip' => LocationSource.ip,
        'manual' => LocationSource.manual,
        _ => LocationSource.fallback,
      };

  String get wire => switch (this) {
        LocationSource.gps => 'gps',
        LocationSource.ip => 'ip',
        LocationSource.manual => 'manual',
        LocationSource.fallback => 'fallback',
      };
}

/// Why a GPS fix could not be taken — each one has a different fix for the
/// reader, so the screen can offer the right button instead of a vague error.
enum LocationProblem {
  /// The phone's location (GPS) switch is off.
  servicesOff(
    'فون کی لوکیشن (GPS) بند ہے — آن کریں تاکہ آپ کا درست مقام معلوم ہو سکے',
    'لوکیشن آن کریں',
  ),

  /// The reader declined the permission prompt.
  permissionDenied(
    'لوکیشن کی اجازت نہیں ملی — درست مقام کے لیے اجازت دیں',
    'اجازت دیں',
  ),

  /// "Don't ask again": only the app settings can undo it.
  permissionDeniedForever(
    'لوکیشن کی اجازت بند ہے — ایپ کی ترتیبات میں جا کر اجازت دیں',
    'ترتیبات کھولیں',
  ),

  /// Permission and switch are fine, but no fix arrived in time.
  noFix(
    'جی پی ایس سگنل نہیں ملا — کھلی جگہ پر دوبارہ کوشش کریں',
    'دوبارہ کوشش',
  );

  const LocationProblem(this.messageUrdu, this.actionUrdu);

  final String messageUrdu;
  final String actionUrdu;
}

/// The outcome of one attempt at a device fix.
class DeviceFix {
  const DeviceFix(this.location) : problem = null;

  const DeviceFix.failed(LocationProblem this.problem) : location = null;

  final PrayerLocation? location;
  final LocationProblem? problem;
}

/// One city the manual picker can jump to.
class PlaceSuggestion {
  const PlaceSuggestion(this.nameUrdu, this.nameLatin, this.latitude, this.longitude);

  final String nameUrdu;
  final String nameLatin;
  final double latitude;
  final double longitude;

  String get label => '$nameUrdu ($nameLatin)';

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return nameLatin.toLowerCase().contains(needle) ||
        nameUrdu.contains(query.trim()) ||
        _romanised(nameLatin).contains(needle);
  }

  /// Loose transliteration so "karachi"/"krachi"/"karaci" all find Karachi.
  static String _romanised(String value) {
    final buffer = StringBuffer();
    for (final rune in value.toLowerCase().runes) {
      final character = String.fromCharCode(rune);
      switch (character) {
        case 'k':
        case 'q':
          buffer.write('k');
        case 'c':
          buffer.write('k');
        case 'x':
          buffer.write('ks');
        case 'z':
        case 's':
          buffer.write('s');
        default:
          buffer.write(character);
      }
    }
    return buffer.toString().replaceAll(RegExp('[^a-z]'), '');
  }
}

/// The coordinates the prayer card and the Qibla bearing are computed from.
class PrayerLocation {
  const PrayerLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.source,
    this.savedAt,
    this.accuracyMeters,
    this.detail = '',
    this.refined = false,
  });

  final double latitude;
  final double longitude;

  /// What to print on the card: the town (or neighbourhood, town) of a fix,
  /// or the city the reader picked.
  final String label;
  final LocationSource source;
  final DateTime? savedAt;

  /// Reported GPS accuracy, when there was one.
  final double? accuracyMeters;

  /// The line under the label: province and country.
  final String detail;

  /// True once the label came from the online reverse geocoder (or the reader
  /// chose it): an offline guess is upgraded the next time the phone is online.
  final bool refined;

  /// Islamabad — the last resort that keeps the card working with no
  /// permission, no network, and no stored location.
  static const PrayerLocation fallback = PrayerLocation(
    latitude: 33.6844,
    longitude: 73.0479,
    label: 'اسلام آباد (ڈیفالٹ)',
    source: LocationSource.fallback,
  );

  bool get isFallback => source == LocationSource.fallback;

  PrayerLocation copyWith({
    double? latitude,
    double? longitude,
    String? label,
    LocationSource? source,
    double? accuracyMeters,
    String? detail,
    bool? refined,
  }) =>
      PrayerLocation(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        label: label ?? this.label,
        source: source ?? this.source,
        savedAt: DateTime.now(),
        accuracyMeters: accuracyMeters ?? this.accuracyMeters,
        detail: detail ?? this.detail,
        refined: refined ?? this.refined,
      );

  /// Coordinates with more precision than a phone ever needs, printed under
  /// the city name so the reader can verify where the times belong.
  String get coordinatesUrdu =>
      '${latitude.toStringAsFixed(3)}°N  ${longitude.toStringAsFixed(3)}°E';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lat': latitude,
        'lon': longitude,
        'label': label,
        'source': source.wire,
        'saved_at': (savedAt ?? DateTime.now()).toIso8601String(),
        'accuracy': accuracyMeters,
        'detail': detail,
        'refined': refined,
      };

  static PrayerLocation? fromJson(Map<String, dynamic> json) {
    final lat = _asDouble(json['lat']);
    final lon = _asDouble(json['lon']);
    if (lat == null || lon == null) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    final detail = json['detail'];
    return PrayerLocation(
      latitude: lat,
      longitude: lon,
      label: (json['label'] as String?)?.trim().isNotEmpty == true
          ? (json['label'] as String).trim()
          : 'میرا مقام',
      source: LocationSource.fromName(json['source'] as String?),
      savedAt: DateTime.tryParse((json['saved_at'] as String?) ?? ''),
      accuracyMeters: _asDouble(json['accuracy']),
      detail: detail is String ? detail.trim() : '',
      refined: json['refined'] == true,
    );
  }

  @override
  String toString() => 'PrayerLocation($label ${latitude.toStringAsFixed(4)}, '
      '${longitude.toStringAsFixed(4)}, ${source.wire})';
}

/// Urdu names for the countries most readers live in or travel to. Anything
/// else keeps its English name from the bundled list.
const Map<String, String> kCountryNamesUrdu = <String, String>{
  'PK': 'پاکستان',
  'IN': 'بھارت',
  'AF': 'افغانستان',
  'IR': 'ایران',
  'IQ': 'عراق',
  'SA': 'سعودی عرب',
  'AE': 'متحدہ عرب امارات',
  'BH': 'بحرین',
  'KW': 'کویت',
  'QA': 'قطر',
  'OM': 'عمان',
  'YE': 'یمن',
  'SY': 'شام',
  'LB': 'لبنان',
  'JO': 'اردن',
  'PS': 'فلسطین',
  'IL': 'مقبوضہ فلسطین',
  'EG': 'مصر',
  'TR': 'ترکی',
  'AZ': 'آذربائیجان',
  'GE': 'جارجیا',
  'AM': 'آرمینیا',
  'BD': 'بنگلہ دیش',
  'NP': 'نیپال',
  'LK': 'سری لنکا',
  'MV': 'مالدیپ',
  'TJ': 'تاجکستان',
  'UZ': 'ازبکستان',
  'TM': 'ترکمانستان',
  'KG': 'کرغزستان',
  'KZ': 'قازقستان',
  'CN': 'چین',
  'JP': 'جاپان',
  'KR': 'جنوبی کوریا',
  'MY': 'ملائیشیا',
  'ID': 'انڈونیشیا',
  'SG': 'سنگاپور',
  'TH': 'تھائی لینڈ',
  'PH': 'فلپائن',
  'GB': 'برطانیہ',
  'IE': 'آئرلینڈ',
  'US': 'امریکہ',
  'CA': 'کینیڈا',
  'MX': 'میکسیکو',
  'BR': 'برازیل',
  'AR': 'ارجنٹائن',
  'AU': 'آسٹریلیا',
  'NZ': 'نیوزی لینڈ',
  'DE': 'جرمنی',
  'FR': 'فرانس',
  'IT': 'اٹلی',
  'ES': 'اسپین',
  'PT': 'پرتگال',
  'NL': 'نیدرلینڈز',
  'BE': 'بیلجیم',
  'LU': 'لکسمبرگ',
  'CH': 'سوئٹزرلینڈ',
  'AT': 'آسٹریا',
  'SE': 'سویڈن',
  'NO': 'ناروے',
  'DK': 'ڈنمارک',
  'FI': 'فن لینڈ',
  'PL': 'پولینڈ',
  'GR': 'یونان',
  'RU': 'روس',
  'UA': 'یوکرین',
  'KE': 'کینیا',
  'TZ': 'تنزانیہ',
  'UG': 'یوگنڈا',
  'NG': 'نائجیریا',
  'ZA': 'جنوبی افریقہ',
  'MA': 'مراکش',
  'DZ': 'الجزائر',
  'TN': 'تیونس',
  'LY': 'لیبیا',
  'SD': 'سوڈان',
};

/// Pakistan's provinces and territories in Urdu (GeoNames' English names).
const Map<String, String> kPakistanProvincesUrdu = <String, String>{
  'Punjab': 'پنجاب',
  'Sindh': 'سندھ',
  'Khyber Pakhtunkhwa': 'خیبر پختونخوا',
  'Balochistan': 'بلوچستان',
  'Islamabad': 'اسلام آباد',
  'Azad Kashmir': 'آزاد کشمیر',
  'Gilgit-Baltistan': 'گلگت بلتستان',
  'Federally Administered Tribal Areas': 'قبائلی اضلاع',
};

/// Finding, remembering, and naming the reader's location.
class PrayerLocations {
  const PrayerLocations._();

  static const String storageKey = 'prayer_location_v1';
  static const String ipEndpoint = 'https://ipapi.co/json/';
  static const String ipEndpointAlt = 'https://ipwho.is/';

  /// The label of a fix that could not be named at all.
  static const String unnamedFixLabel = 'میرا موجودہ مقام';

  /// A GPS fix, without ever throwing: permission denied, services off, and a
  /// timeout all return null and let the caller fall through to the IP lookup.
  static Future<PrayerLocation?> fromDevice({
    Duration timeout = const Duration(seconds: 12),
  }) async =>
      (await deviceFix(timeout: timeout)).location;

  /// A device fix with the reason when there is none.
  ///
  /// [interactive] may show the permission prompt; a background refresh
  /// passes false and only uses a permission the reader already granted.
  /// The fix is high accuracy first (GPS), then the network position, then
  /// the last known position — and is named from the offline list at once.
  static Future<DeviceFix> deviceFix({
    bool interactive = true,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const DeviceFix.failed(LocationProblem.servicesOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && interactive) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const DeviceFix.failed(LocationProblem.permissionDeniedForever);
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return const DeviceFix.failed(LocationProblem.permissionDenied);
      }
      final position = await _position(LocationAccuracy.high, timeout) ??
          await _position(LocationAccuracy.medium, const Duration(seconds: 8)) ??
          await _lastKnown();
      if (position == null ||
          position.latitude.abs() > 90 ||
          position.longitude.abs() > 180) {
        return const DeviceFix.failed(LocationProblem.noFix);
      }
      final name = await nameOffline(position.latitude, position.longitude);
      return DeviceFix(
        PrayerLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          label: name?.label ?? unnamedFixLabel,
          detail: name?.detail ?? '',
          source: LocationSource.gps,
          savedAt: DateTime.now(),
          accuracyMeters: position.accuracy,
        ),
      );
    } catch (_) {
      return const DeviceFix.failed(LocationProblem.noFix);
    }
  }

  static Future<Position?> _position(LocationAccuracy accuracy, Duration timeout) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy, timeLimit: timeout),
      ).timeout(timeout + const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }

  static Future<Position?> _lastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  /// Opens the phone's location switch (for [LocationProblem.servicesOff]).
  static Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {
      return;
    }
  }

  /// Opens this app's settings page (for a permission denied forever).
  static Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {
      return;
    }
  }

  /// The IP-geolocation fallback used when the GPS says no.
  static Future<PrayerLocation?> fromIp({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    for (final endpoint in <String>[ipEndpoint, ipEndpointAlt]) {
      try {
        final response = await http
            .get(Uri.parse(endpoint), headers: const {'Accept': 'application/json'})
            .timeout(timeout);
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map) continue;
        final parsed = fromIpPayload(decoded.cast<String, dynamic>());
        if (parsed != null) return parsed;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Parses either provider's payload. Kept pure (and tested) because the two
  /// services disagree on both shape and types — `latitude` is a number in one
  /// and a string in the other, and the city can arrive as `city` or `region`.
  static PrayerLocation? fromIpPayload(Map<String, dynamic> json) {
    if (json['error'] == true || json['success'] == false) return null;
    final lat = _asDouble(json['latitude']) ?? _asDouble(json['lat']);
    final lon = _asDouble(json['longitude']) ?? _asDouble(json['lon']);
    if (lat == null || lon == null) return null;
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    final city = (json['city'] as String?)?.trim();
    final region = (json['region'] as String?)?.trim();
    final country = (json['country_name'] as String?)?.trim() ??
        (json['country'] as String?)?.trim();
    final label = <String>[
      if (city != null && city.isNotEmpty) city,
      if (country != null && country.isNotEmpty) country,
    ].join(', ');
    return PrayerLocation(
      latitude: lat,
      longitude: lon,
      label: label.isNotEmpty ? label : (region?.isNotEmpty == true ? region! : 'انٹرنیٹ مقام'),
      source: LocationSource.ip,
      savedAt: DateTime.now(),
    );
  }

  /// An IP location named the way the rest of the app names places: the
  /// curated Urdu name when the provider's city is one of them ("Islamabad,
  /// Pakistan" → "اسلام آباد").
  static PrayerLocation localiseIp(PrayerLocation location) {
    final curated = curatedNear(location.latitude, location.longitude, maxKm: 30);
    if (curated == null) return location;
    final city = location.label.split(',').first.trim();
    if (city.isEmpty || !namesAgree(curated.nameLatin, city)) return location;
    return PrayerLocation(
      latitude: location.latitude,
      longitude: location.longitude,
      label: curated.nameUrdu,
      source: location.source,
      savedAt: location.savedAt,
      detail: location.label,
    );
  }

  /// A coordinate pair typed into the search box ("33.68, 73.04").
  static PrayerLocation? fromQuery(String query) {
    final parts = query.split(RegExp(r'[,\s]+')).where((part) => part.isNotEmpty).toList();
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0]);
    final lon = double.tryParse(parts[1]);
    if (lat == null || lon == null) return null;
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return PrayerLocation(
      latitude: lat,
      longitude: lon,
      label: 'دستی مقام',
      source: LocationSource.manual,
      savedAt: DateTime.now(),
    );
  }

  static Future<PrayerLocation?> loadStored() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return PrayerLocation.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  static Future<void> store(PrayerLocation location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(location.toJson()));
    } catch (_) {
      return;
    }
  }

  /// Kilometres between two locations.
  static double distanceKm(PrayerLocation a, PrayerLocation b) =>
      CityIndex.distanceKm(a.latitude, a.longitude, b.latitude, b.longitude);

  // ---------------------------------------------------------------------------
  // Naming places offline.

  /// Urdu country name, or the English one from the bundled list.
  static String countryLabel(String code, [String english = '']) =>
      kCountryNamesUrdu[code] ?? (english.isNotEmpty ? english : code);

  /// Province (Urdu for Pakistan) and country, joined for a subtitle.
  static String regionLabel(GeoCity city) {
    final province = city.countryCode == 'PK'
        ? (kPakistanProvincesUrdu[city.province] ?? city.province)
        : city.province;
    final country = countryLabel(city.countryCode, city.countryName);
    if (province.isEmpty || province == city.name) return country;
    return '$province، $country';
  }

  /// The curated city closest to a point, when one is within [maxKm].
  static PlaceSuggestion? curatedNear(double latitude, double longitude, {double maxKm = 15}) {
    PlaceSuggestion? best;
    var bestKm = maxKm;
    for (final city in cities) {
      final km = CityIndex.distanceKm(latitude, longitude, city.latitude, city.longitude);
      if (km <= bestKm) {
        best = city;
        bestKm = km;
      }
    }
    return best;
  }

  /// Whether a curated Latin name and a GeoNames name are the same town
  /// ("Hyderabad, Sindh" / "Hyderabad", "Mirpur (AJK)" / "New Mirpur City").
  static bool namesAgree(String curatedLatin, String geoName) {
    final pattern = RegExp('[^a-z]+');
    final latinWords =
        curatedLatin.toLowerCase().split(pattern).where((word) => word.length >= 3).toList();
    final nameWords = geoName.toLowerCase().split(pattern).where((word) => word.length >= 3).toList();
    if (latinWords.isEmpty || nameWords.isEmpty) return false;
    return nameWords.any(latinWords.contains) || geoName.toLowerCase().contains(latinWords.first);
  }

  /// The curated twin of a GeoNames place ("Karachi" → "کراچی"): the same
  /// spot under an agreeing name.
  static PlaceSuggestion? curatedTwin(GeoCity city) {
    final curated = curatedNear(city.latitude, city.longitude, maxKm: 15);
    if (curated == null || !namesAgree(curated.nameLatin, city.name)) return null;
    return curated;
  }

  /// Names a fix from the bundled list: the town it belongs to (in Urdu when
  /// the town is a curated one), "… کے قریب" when the fix is outside it.
  static Future<PlaceName?> nameOffline(double latitude, double longitude) async {
    final index = await CityIndexLoader.load();
    if (index == null) {
      final curated = curatedNear(latitude, longitude, maxKm: 20);
      return curated == null ? null : PlaceName(label: curated.nameUrdu);
    }
    return describeMatch(index.nearest(latitude, longitude));
  }

  /// Turns a nearest-town match into a label (pure, so it is unit-tested).
  static PlaceName? describeMatch(CityMatch? match) {
    if (match == null) return null;
    final city = match.city;
    final twin = curatedTwin(city);
    final name = twin?.nameUrdu ?? city.name;
    final label = match.distanceKm > 12 ? '$name کے قریب' : name;
    final region = regionLabel(city);
    // "اسلام آباد" over "اسلام آباد، پاکستان" says the city twice.
    final detail = region.startsWith('$name،')
        ? countryLabel(city.countryCode, city.countryName)
        : region;
    return PlaceName(label: label, detail: detail);
  }

  /// A curated city as a picker row.
  static PlaceResult resultForSuggestion(PlaceSuggestion city) => PlaceResult(
        title: city.nameUrdu,
        subtitle: city.nameLatin,
        latitude: city.latitude,
        longitude: city.longitude,
        origin: PlaceOrigin.curated,
      );

  /// A GeoNames place as a picker row.
  static PlaceResult resultForCity(GeoCity city) => PlaceResult(
        title: city.name,
        subtitle: regionLabel(city),
        latitude: city.latitude,
        longitude: city.longitude,
        origin: PlaceOrigin.offline,
        population: city.population,
      );

  /// Everything the picker can show without the network: the curated cities
  /// that match first (they have Urdu names), then the bundled list, with the
  /// curated twins of GeoNames rows removed so no city appears twice.
  static List<PlaceResult> searchOffline(String query, CityIndex? index, {int limit = 60}) {
    final curated = searchCities(query).map(resultForSuggestion).toList();
    if (index == null || query.trim().isEmpty) return curated;
    final results = <PlaceResult>[...curated];
    for (final city in index.search(query, limit: limit)) {
      final row = resultForCity(city);
      final duplicate = curated.any(
        (known) => known.sameSpotAs(row) && namesAgree(known.subtitle, city.name),
      );
      if (!duplicate) results.add(row);
      if (results.length >= limit) break;
    }
    return results;
  }

  /// The picker's hand-written list, with Urdu names: Pakistan's cities and
  /// towns first, then the Shia centres and the cities of the diaspora. The
  /// bundled GeoNames list (73,000 places) and the online search cover
  /// everything else.
  static const List<PlaceSuggestion> cities = <PlaceSuggestion>[
    PlaceSuggestion('کراچی', 'Karachi', 24.8607, 67.0011),
    PlaceSuggestion('لاہور', 'Lahore', 31.5204, 74.3587),
    PlaceSuggestion('اسلام آباد', 'Islamabad', 33.6844, 73.0479),
    PlaceSuggestion('راولپنڈی', 'Rawalpindi', 33.5651, 73.0169),
    PlaceSuggestion('کوئٹہ', 'Quetta', 30.1798, 66.9750),
    PlaceSuggestion('پشاور', 'Peshawar', 34.0151, 71.5249),
    PlaceSuggestion('ملتان', 'Multan', 30.1575, 71.5249),
    PlaceSuggestion('فیصل آباد', 'Faisalabad', 31.4180, 73.0790),
    PlaceSuggestion('حیدرآباد، سندھ', 'Hyderabad, Sindh', 25.3960, 68.3578),
    PlaceSuggestion('گلگت', 'Gilgit', 35.9208, 74.3144),
    PlaceSuggestion('سکردو', 'Skardu', 35.2971, 75.6333),
    PlaceSuggestion('گوجرانوالہ', 'Gujranwala', 32.156, 74.187),
    PlaceSuggestion('سیالکوٹ', 'Sialkot', 32.493, 74.531),
    PlaceSuggestion('سرگودھا', 'Sargodha', 32.086, 72.674),
    PlaceSuggestion('بہاولپور', 'Bahawalpur', 29.398, 71.675),
    PlaceSuggestion('سکھر', 'Sukkur', 27.703, 68.859),
    PlaceSuggestion('لاڑکانہ', 'Larkana', 27.559, 68.212),
    PlaceSuggestion('جھنگ', 'Jhang', 31.270, 72.317),
    PlaceSuggestion('چنیوٹ', 'Chiniot', 31.721, 72.978),
    PlaceSuggestion('ڈیرہ غازی خان', 'Dera Ghazi Khan', 30.046, 70.640),
    PlaceSuggestion('ڈیرہ اسماعیل خان', 'Dera Ismail Khan', 31.831, 70.902),
    PlaceSuggestion('پاراچنار', 'Parachinar', 33.900, 70.100),
    PlaceSuggestion('ہنگو', 'Hangu', 33.532, 71.059),
    PlaceSuggestion('کوہاٹ', 'Kohat', 33.582, 71.449),
    PlaceSuggestion('مردان', 'Mardan', 34.198, 72.050),
    PlaceSuggestion('ایبٹ آباد', 'Abbottabad', 34.146, 73.212),
    PlaceSuggestion('مظفرآباد', 'Muzaffarabad', 34.370, 73.471),
    PlaceSuggestion('میرپور، آزاد کشمیر', 'Mirpur (AJK)', 33.148, 73.752),
    PlaceSuggestion('چکوال', 'Chakwal', 32.933, 72.854),
    PlaceSuggestion('تلہ گنگ', 'Talagang', 32.928, 72.416),
    PlaceSuggestion('جہلم', 'Jhelum', 32.934, 73.731),
    PlaceSuggestion('گجرات', 'Gujrat', 32.574, 74.075),
    PlaceSuggestion('شیخوپورہ', 'Sheikhupura', 31.713, 73.986),
    PlaceSuggestion('قصور', 'Kasur', 31.119, 74.450),
    PlaceSuggestion('اوکاڑہ', 'Okara', 30.810, 73.452),
    PlaceSuggestion('ساہیوال', 'Sahiwal', 30.666, 73.102),
    PlaceSuggestion('رحیم یار خان', 'Rahim Yar Khan', 28.420, 70.303),
    PlaceSuggestion('صادق آباد', 'Sadiqabad', 28.309, 70.127),
    PlaceSuggestion('خانیوال', 'Khanewal', 30.302, 71.932),
    PlaceSuggestion('وہاڑی', 'Vehari', 30.044, 72.356),
    PlaceSuggestion('میانوالی', 'Mianwali', 32.578, 71.528),
    PlaceSuggestion('بھکر', 'Bhakkar', 31.627, 71.065),
    PlaceSuggestion('لیہ', 'Layyah', 30.961, 70.939),
    PlaceSuggestion('مظفرگڑھ', 'Muzaffargarh', 30.073, 71.194),
    PlaceSuggestion('اٹک', 'Attock', 33.767, 72.360),
    PlaceSuggestion('واہ کینٹ', 'Wah Cantt', 33.771, 72.751),
    PlaceSuggestion('مری', 'Murree', 33.908, 73.390),
    PlaceSuggestion('حافظ آباد', 'Hafizabad', 32.071, 73.688),
    PlaceSuggestion('منڈی بہاؤالدین', 'Mandi Bahauddin', 32.587, 73.491),
    PlaceSuggestion('نارووال', 'Narowal', 32.102, 74.873),
    PlaceSuggestion('پاکپتن', 'Pakpattan', 30.343, 73.389),
    PlaceSuggestion('لودھراں', 'Lodhran', 29.534, 71.632),
    PlaceSuggestion('بہاولنگر', 'Bahawalnagar', 29.998, 73.253),
    PlaceSuggestion('راجن پور', 'Rajanpur', 29.104, 70.330),
    PlaceSuggestion('کوٹ ادو', 'Kot Addu', 30.469, 70.967),
    PlaceSuggestion('تونسہ', 'Taunsa', 30.704, 70.651),
    PlaceSuggestion('نوشہرہ', 'Nowshera', 34.016, 71.981),
    PlaceSuggestion('چارسدہ', 'Charsadda', 34.148, 71.741),
    PlaceSuggestion('صوابی', 'Swabi', 34.120, 72.470),
    PlaceSuggestion('مانسہرہ', 'Mansehra', 34.330, 73.197),
    PlaceSuggestion('ہری پور', 'Haripur', 33.998, 72.935),
    PlaceSuggestion('مینگورہ، سوات', 'Mingora (Swat)', 34.779, 72.363),
    PlaceSuggestion('چترال', 'Chitral', 35.852, 71.786),
    PlaceSuggestion('بنوں', 'Bannu', 32.985, 70.604),
    PlaceSuggestion('کوٹلی', 'Kotli', 33.518, 73.902),
    PlaceSuggestion('راولاکوٹ', 'Rawalakot', 33.858, 73.760),
    PlaceSuggestion('باغ', 'Bagh', 33.981, 73.776),
    PlaceSuggestion('خپلو', 'Khaplu', 35.162, 76.334),
    PlaceSuggestion('شگر', 'Shigar', 35.424, 75.739),
    PlaceSuggestion('کریم آباد، ہنزہ', 'Karimabad (Hunza)', 36.327, 74.661),
    PlaceSuggestion('گاہکوچ', 'Gahkuch', 36.177, 73.764),
    PlaceSuggestion('چلاس', 'Chilas', 35.413, 74.104),
    PlaceSuggestion('نواب شاہ', 'Nawabshah', 26.239, 68.404),
    PlaceSuggestion('میرپور خاص', 'Mirpur Khas', 25.528, 69.013),
    PlaceSuggestion('جیکب آباد', 'Jacobabad', 28.282, 68.438),
    PlaceSuggestion('شکارپور', 'Shikarpur', 27.956, 68.638),
    PlaceSuggestion('خیرپور', 'Khairpur', 27.529, 68.762),
    PlaceSuggestion('دادو', 'Dadu', 26.730, 67.777),
    PlaceSuggestion('سیہون شریف', 'Sehwan Sharif', 26.425, 67.861),
    PlaceSuggestion('ٹھٹھہ', 'Thatta', 24.747, 67.924),
    PlaceSuggestion('بدین', 'Badin', 24.656, 68.837),
    PlaceSuggestion('سانگھڑ', 'Sanghar', 26.047, 68.949),
    PlaceSuggestion('گھوٹکی', 'Ghotki', 28.004, 69.316),
    PlaceSuggestion('کندھکوٹ', 'Kandhkot', 28.246, 69.180),
    PlaceSuggestion('ٹنڈو آدم', 'Tando Adam', 25.768, 68.662),
    PlaceSuggestion('ٹنڈو الہ یار', 'Tando Allahyar', 25.460, 68.717),
    PlaceSuggestion('ہالہ', 'Hala', 25.815, 68.422),
    PlaceSuggestion('مٹھی', 'Mithi', 24.737, 69.797),
    PlaceSuggestion('خضدار', 'Khuzdar', 27.812, 66.611),
    PlaceSuggestion('سبی', 'Sibi', 29.543, 67.877),
    PlaceSuggestion('ژوب', 'Zhob', 31.341, 69.449),
    PlaceSuggestion('لورالائی', 'Loralai', 30.371, 68.598),
    PlaceSuggestion('چمن', 'Chaman', 30.918, 66.453),
    PlaceSuggestion('زیارت', 'Ziarat', 30.382, 67.726),
    PlaceSuggestion('گوادر', 'Gwadar', 25.122, 62.325),
    PlaceSuggestion('تربت', 'Turbat', 26.001, 63.048),
    PlaceSuggestion('مشہد', 'Mashhad', 36.2605, 59.6168),
    PlaceSuggestion('قم', 'Qom', 34.6416, 50.8746),
    PlaceSuggestion('تہران', 'Tehran', 35.6892, 51.3890),
    PlaceSuggestion('نجف اشرف', 'Najaf', 32.0000, 44.3333),
    PlaceSuggestion('کربلا', 'Karbala', 32.6160, 44.0249),
    PlaceSuggestion('بغداد', 'Baghdad', 33.3152, 44.3661),
    PlaceSuggestion('کاظمین', 'Kadhimiya', 33.3833, 44.3333),
    PlaceSuggestion('سامرہ', 'Samarra', 34.1983, 43.8740),
    PlaceSuggestion('دمشق', 'Damascus', 33.5138, 36.2765),
    PlaceSuggestion('بیروت', 'Beirut', 33.8938, 35.5018),
    PlaceSuggestion('بحرین، منامہ', 'Manama', 26.2285, 50.5860),
    PlaceSuggestion('دوحہ', 'Doha', 25.2854, 51.5310),
    PlaceSuggestion('مکہ مکرمہ', 'Makkah', 21.4225, 39.8262),
    PlaceSuggestion('مدینہ منورہ', 'Madinah', 24.4686, 39.6142),
    PlaceSuggestion('ریاض', 'Riyadh', 24.7136, 46.6753),
    PlaceSuggestion('مسقط', 'Muscat', 23.5880, 58.3829),
    PlaceSuggestion('دبئی', 'Dubai', 25.2048, 55.2708),
    PlaceSuggestion('ابوظبی', 'Abu Dhabi', 24.4539, 54.3773),
    PlaceSuggestion('استنبول', 'Istanbul', 41.0082, 28.9784),
    PlaceSuggestion('کابل', 'Kabul', 34.5553, 69.2075),
    PlaceSuggestion('مزار شریف', 'Mazar-i-Sharif', 36.7090, 67.1109),
    PlaceSuggestion('دہلی', 'Delhi', 28.6139, 77.2090),
    PlaceSuggestion('لکھنؤ', 'Lucknow', 26.8467, 80.9462),
    PlaceSuggestion('ممبئی', 'Mumbai', 19.0760, 72.8777),
    PlaceSuggestion('حیدرآباد، دکن', 'Hyderabad, Deccan', 17.3850, 78.4867),
    PlaceSuggestion('بنگلور', 'Bengaluru', 12.9716, 77.5946),
    PlaceSuggestion('چنئی', 'Chennai', 13.0827, 80.2707),
    PlaceSuggestion('کولکتہ', 'Kolkata', 22.5726, 88.3639),
    PlaceSuggestion('سری نگر', 'Srinagar', 34.0837, 74.7973),
    PlaceSuggestion('علی گڑھ', 'Aligarh', 27.8974, 78.0880),
    PlaceSuggestion('لندن', 'London', 51.5074, -0.1278),
    PlaceSuggestion('مانچسٹر', 'Manchester', 53.4808, -2.2426),
    PlaceSuggestion('برمنگھم', 'Birmingham', 52.4862, -1.8904),
    PlaceSuggestion('ٹورنٹو', 'Toronto', 43.6532, -79.3832),
    PlaceSuggestion('مونٹریال', 'Montreal', 45.5019, -73.5674),
    PlaceSuggestion('نیویارک', 'New York', 40.7128, -74.0060),
    PlaceSuggestion('شکاگو', 'Chicago', 41.8781, -87.6298),
    PlaceSuggestion('ہیوسٹن', 'Houston', 29.7604, -95.3698),
    PlaceSuggestion('ڈیئربورن', 'Dearborn', 42.3223, -83.1763),
    PlaceSuggestion('ڈیٹرائٹ', 'Detroit', 42.3314, -83.0458),
    PlaceSuggestion('لاس اینجلس', 'Los Angeles', 34.0522, -118.2437),
    PlaceSuggestion('سڈنی', 'Sydney', -33.8688, 151.2093),
    PlaceSuggestion('میلبورن', 'Melbourne', -37.8136, 144.9631),
    PlaceSuggestion('پیرس', 'Paris', 48.8566, 2.3522),
    PlaceSuggestion('برلن', 'Berlin', 52.5200, 13.4050),
    PlaceSuggestion('سٹاک ہوم', 'Stockholm', 59.3293, 18.0686),
    PlaceSuggestion('اوسلو', 'Oslo', 59.9139, 10.7522),
    PlaceSuggestion('کوپن ہیگن', 'Copenhagen', 55.6761, 12.5683),
    PlaceSuggestion('مارسیلز', 'Marseille', 43.2965, 5.3698),
    PlaceSuggestion('لکسمبرگ', 'Luxembourg', 49.6116, 6.1319),
    PlaceSuggestion('گلاسگو', 'Glasgow', 55.8642, -4.2518),
    PlaceSuggestion('لاگوس', 'Lagos', 6.5244, 3.3792),
    PlaceSuggestion('نیروبی', 'Nairobi', -1.2921, 36.8219),
    PlaceSuggestion('دارالسلام', 'Dar es Salaam', -6.7924, 39.2083),
    PlaceSuggestion('کوالالمپور', 'Kuala Lumpur', 3.1390, 101.6869),
    PlaceSuggestion('جکارتہ', 'Jakarta', -6.2088, 106.8456),
    PlaceSuggestion('باکو', 'Baku', 40.4093, 49.8671),
    PlaceSuggestion('تبلیسی', 'Tbilisi', 41.7151, 44.8271),
    PlaceSuggestion('کوفہ', 'Kufa', 32.051, 44.440),
    PlaceSuggestion('حلہ', 'Hillah', 32.464, 44.420),
    PlaceSuggestion('بصرہ', 'Basra', 30.509, 47.780),
    PlaceSuggestion('زینبیہ، دمشق', 'Sayyidah Zaynab', 33.445, 36.341),
    PlaceSuggestion('اصفہان', 'Isfahan', 32.652, 51.675),
    PlaceSuggestion('شیراز', 'Shiraz', 29.610, 52.531),
    PlaceSuggestion('تبریز', 'Tabriz', 38.080, 46.292),
    PlaceSuggestion('اہواز', 'Ahvaz', 31.319, 48.684),
    PlaceSuggestion('نیشاپور', 'Neyshabur', 36.213, 58.796),
    PlaceSuggestion('یزد', 'Yazd', 31.897, 54.367),
    PlaceSuggestion('کرمان', 'Kerman', 30.283, 57.079),
    PlaceSuggestion('جدہ', 'Jeddah', 21.490, 39.186),
    PlaceSuggestion('دمام', 'Dammam', 26.434, 50.103),
    PlaceSuggestion('قطیف', 'Qatif', 26.565, 50.009),
    PlaceSuggestion('الاحساء (ہفوف)', 'Al-Ahsa (Hofuf)', 25.365, 49.588),
    PlaceSuggestion('کویت', 'Kuwait City', 29.367, 47.974),
    PlaceSuggestion('شارجہ', 'Sharjah', 25.334, 55.412),
    PlaceSuggestion('ہرات', 'Herat', 34.348, 62.200),
    PlaceSuggestion('بامیان', 'Bamyan', 34.822, 67.827),
    PlaceSuggestion('قندھار', 'Kandahar', 31.613, 65.710),
    PlaceSuggestion('جلال آباد', 'Jalalabad', 34.426, 70.452),
    PlaceSuggestion('کارگل', 'Kargil', 34.558, 76.126),
    PlaceSuggestion('لیہ، لداخ', 'Leh', 34.165, 77.584),
    PlaceSuggestion('جموں', 'Jammu', 32.735, 74.862),
    PlaceSuggestion('بھوپال', 'Bhopal', 23.255, 77.403),
    PlaceSuggestion('پٹنہ', 'Patna', 25.594, 85.136),
    PlaceSuggestion('ڈھاکہ', 'Dhaka', 23.710, 90.407),
  ];

  static List<PlaceSuggestion> searchCities(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return cities;
    // Exact-ish matches first so "kar" opens Karachi rather than crashing past it.
    final starts = cities.where(
      (city) =>
          city.nameLatin.toLowerCase().startsWith(trimmed.toLowerCase()) ||
          city.nameUrdu.startsWith(trimmed),
    );
    final contains = cities.where(
      (city) => city.matches(trimmed) && !starts.contains(city),
    );
    return <PlaceSuggestion>[...starts, ...contains];
  }
}
