import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  });

  final double latitude;
  final double longitude;

  /// What to print on the card: a city name, or "میرا موجودہ مقام" for a fix.
  final String label;
  final LocationSource source;
  final DateTime? savedAt;

  /// Reported GPS accuracy, when there was one.
  final double? accuracyMeters;

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
  }) =>
      PrayerLocation(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        label: label ?? this.label,
        source: source ?? this.source,
        savedAt: DateTime.now(),
        accuracyMeters: accuracyMeters ?? this.accuracyMeters,
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
      };

  static PrayerLocation? fromJson(Map<String, dynamic> json) {
    final lat = _asDouble(json['lat']);
    final lon = _asDouble(json['lon']);
    if (lat == null || lon == null) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    return PrayerLocation(
      latitude: lat,
      longitude: lon,
      label: (json['label'] as String?)?.trim().isNotEmpty == true
          ? (json['label'] as String).trim()
          : 'میرا مقام',
      source: LocationSource.fromName(json['source'] as String?),
      savedAt: DateTime.tryParse((json['saved_at'] as String?) ?? ''),
      accuracyMeters: _asDouble(json['accuracy']),
    );
  }

  @override
  String toString() => 'PrayerLocation($label ${latitude.toStringAsFixed(4)}, '
      '${longitude.toStringAsFixed(4)}, ${source.wire})';
}

/// Finding, remembering, and naming the reader's location.
class PrayerLocations {
  const PrayerLocations._();

  static const String storageKey = 'prayer_location_v1';
  static const String ipEndpoint = 'https://ipapi.co/json/';
  static const String ipEndpointAlt = 'https://ipwho.is/';

  /// A GPS fix, without ever throwing: permission denied, services off, and a
  /// timeout all return null and let the caller fall through to the IP lookup.
  static Future<PrayerLocation?> fromDevice({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      ).timeout(timeout + const Duration(seconds: 3));
      if (position.latitude.abs() > 90 || position.longitude.abs() > 180) {
        return null;
      }
      return PrayerLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        label: 'میرا موجودہ مقام',
        source: LocationSource.gps,
        savedAt: DateTime.now(),
        accuracyMeters: position.accuracy,
      );
    } catch (_) {
      return null;
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

  /// The manual picker's list. A curated, offline set — the biggest Shia
  /// populations first — because a geocoding service would need the network
  /// and would fail exactly when a traveller needs it.
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

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }
}
