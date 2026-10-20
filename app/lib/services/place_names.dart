import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A human name for a coordinate: what the prayer card prints ("جی الیون،
/// اسلام آباد") and the line under it ("اسلام آباد، پاکستان").
class PlaceName {
  const PlaceName({required this.label, this.detail = ''});

  final String label;
  final String detail;

  @override
  String toString() => 'PlaceName($label | $detail)';
}

/// Where a row of the location picker came from.
enum PlaceOrigin {
  /// The hand-written list with Urdu names (Shia centres, Pakistani cities).
  curated,

  /// The bundled GeoNames list (offline).
  offline,

  /// An online geocoder (Open-Meteo / OpenStreetMap).
  online,
}

/// One row of the location picker.
class PlaceResult {
  const PlaceResult({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    required this.origin,
    this.population = 0,
  });

  /// The name, printed bold and used as the prayer card's label.
  final String title;

  /// Province and country.
  final String subtitle;
  final double latitude;
  final double longitude;
  final PlaceOrigin origin;
  final int population;

  /// True when two rows are the same place under two spellings (the curated
  /// "کراچی" and GeoNames' "Karachi"), so the picker can list it once.
  bool sameSpotAs(PlaceResult other, {double toleranceDegrees = 0.12}) =>
      (latitude - other.latitude).abs() < toleranceDegrees &&
      (longitude - other.longitude).abs() < toleranceDegrees;

  @override
  String toString() => 'PlaceResult($title, $subtitle, ${origin.name})';
}

/// The online half of the location chain: naming a GPS fix precisely
/// (reverse geocoding) and finding villages the bundled list does not have.
///
/// Every call is best-effort and bounded by a timeout: no network means the
/// offline name stays, never an error on screen. The parsers are pure and
/// tested, because the services' payloads differ and change.
class OnlinePlaces {
  const OnlinePlaces._();

  /// OpenStreetMap's usage policy asks every client to identify itself.
  static const String userAgent =
      'ShiaVerse/1.9 (Android prayer times; https://github.com/mrghalibspcpu/Shia-Ai)';

  static const Map<String, String> _headers = <String, String>{
    'User-Agent': userAgent,
    'Accept': 'application/json',
    'Accept-Language': 'ur,en;q=0.7',
  };

  /// The exact place of a fix: OpenStreetMap (Nominatim) first, BigDataCloud
  /// second. Null when both fail or the device is offline.
  static Future<PlaceName?> reverse(
    double latitude,
    double longitude, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final lat = latitude.toStringAsFixed(6);
    final lon = longitude.toStringAsFixed(6);
    final nominatim = await _getJson(
      Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon'
        '&zoom=16&addressdetails=1&accept-language=ur,en',
      ),
      timeout,
    );
    if (nominatim is Map) {
      final parsed = parseNominatimReverse(nominatim.cast<String, dynamic>());
      if (parsed != null) return parsed;
    }
    final bigData = await _getJson(
      Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat'
        '&longitude=$lon&localityLanguage=ur',
      ),
      timeout,
    );
    if (bigData is Map) return parseBigDataCloud(bigData.cast<String, dynamic>());
    return null;
  }

  /// Towns and villages matching [query]: Open-Meteo's GeoNames search, plus
  /// OpenStreetMap when [deep] (the reader pressed "search online").
  static Future<List<PlaceResult>> search(
    String query, {
    bool deep = false,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const <PlaceResult>[];
    final encoded = Uri.encodeQueryComponent(trimmed);
    final results = <PlaceResult>[];
    final meteo = await _getJson(
      Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=$encoded&count=20&language=ur&format=json',
      ),
      timeout,
    );
    if (meteo is Map) results.addAll(parseOpenMeteo(meteo.cast<String, dynamic>()));
    if (deep || results.isEmpty) {
      final osm = await _getJson(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$encoded&format=jsonv2'
          '&addressdetails=1&limit=15&accept-language=ur,en',
        ),
        timeout,
      );
      if (osm is List) {
        for (final place in parseNominatimSearch(osm)) {
          if (!results.any((known) => known.sameSpotAs(place, toleranceDegrees: 0.02))) {
            results.add(place);
          }
        }
      }
    }
    return results;
  }

  static Future<Object?> _getJson(Uri uri, Duration timeout) async {
    try {
      final response = await http.get(uri, headers: _headers).timeout(timeout);
      if (response.statusCode != 200) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  /// First non-empty string among [keys] of [map].
  static String? _pick(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static String _join(Iterable<String?> parts, {Set<String> skip = const <String>{}}) {
    final seen = <String>{...skip};
    final kept = <String>[];
    for (final part in parts) {
      if (part == null || part.isEmpty || !seen.add(part)) continue;
      kept.add(part);
    }
    return kept.join('، ');
  }

  /// "Neighbourhood، City" from an OpenStreetMap reverse lookup.
  static PlaceName? parseNominatimReverse(Map<String, dynamic> json) {
    if (json['error'] != null) return null;
    final rawAddress = json['address'];
    final address = rawAddress is Map ? rawAddress.cast<String, dynamic>() : <String, dynamic>{};
    // The area people name ("G-11", "Gulshan-e-Iqbal") before the block.
    final locality = _pick(address, const <String>[
      'suburb',
      'quarter',
      'neighbourhood',
      'residential',
      'village',
      'hamlet',
      'city_district',
    ]);
    final city = _pick(address, const <String>[
      'city',
      'town',
      'municipality',
      'village',
      'county',
      'state_district',
    ]);
    final state = _pick(address, const <String>['state', 'region', 'province']);
    final country = _pick(address, const <String>['country']);
    final String label;
    if (city != null && locality != null && locality != city) {
      label = '$locality، $city';
    } else {
      label = city ?? locality ?? state ?? _pick(json, const <String>['name']) ?? country ?? '';
    }
    if (label.isEmpty) return null;
    return PlaceName(label: label, detail: _join(<String?>[state, country], skip: <String>{if (city != null) city}));
  }

  /// The same from BigDataCloud's client-side endpoint.
  static PlaceName? parseBigDataCloud(Map<String, dynamic> json) {
    final city = _pick(json, const <String>['city']);
    final locality = _pick(json, const <String>['locality']);
    final state = _pick(json, const <String>['principalSubdivision']);
    final country = _pick(json, const <String>['countryName']);
    final String label;
    if (city != null && locality != null && locality != city) {
      label = '$locality، $city';
    } else {
      label = city ?? locality ?? state ?? country ?? '';
    }
    if (label.isEmpty) return null;
    return PlaceName(label: label, detail: _join(<String?>[state, country], skip: <String>{if (city != null) city}));
  }

  /// Open-Meteo's geocoding search (GeoNames, names in Urdu when known).
  static List<PlaceResult> parseOpenMeteo(Map<String, dynamic> json) {
    final results = json['results'];
    if (results is! List) return const <PlaceResult>[];
    final places = <PlaceResult>[];
    for (final raw in results) {
      if (raw is! Map) continue;
      final row = raw.cast<String, dynamic>();
      final name = _pick(row, const <String>['name']);
      final latitude = _number(row['latitude']);
      final longitude = _number(row['longitude']);
      if (name == null || latitude == null || longitude == null) continue;
      if (latitude.abs() > 90 || longitude.abs() > 180) continue;
      places.add(PlaceResult(
        title: name,
        subtitle: _join(<String?>[
          _pick(row, const <String>['admin2']),
          _pick(row, const <String>['admin1']),
          _pick(row, const <String>['country']),
        ], skip: <String>{name}),
        latitude: latitude,
        longitude: longitude,
        origin: PlaceOrigin.online,
        population: _number(row['population'])?.round() ?? 0,
      ));
    }
    return places;
  }

  /// OpenStreetMap's search: anything with a name, down to villages.
  static List<PlaceResult> parseNominatimSearch(List<dynamic> json) {
    final places = <PlaceResult>[];
    for (final raw in json) {
      if (raw is! Map) continue;
      final row = raw.cast<String, dynamic>();
      final latitude = _number(row['lat']);
      final longitude = _number(row['lon']);
      if (latitude == null || longitude == null) continue;
      if (latitude.abs() > 90 || longitude.abs() > 180) continue;
      final rawAddress = row['address'];
      final address = rawAddress is Map ? rawAddress.cast<String, dynamic>() : <String, dynamic>{};
      final display = _pick(row, const <String>['display_name']) ?? '';
      final name = _pick(row, const <String>['name']) ??
          display.split(',').map((part) => part.trim()).firstWhere(
                (part) => part.isNotEmpty,
                orElse: () => '',
              );
      if (name.isEmpty) continue;
      places.add(PlaceResult(
        title: name,
        subtitle: _join(<String?>[
          _pick(address, const <String>['city', 'town', 'county', 'state_district']),
          _pick(address, const <String>['state', 'region', 'province']),
          _pick(address, const <String>['country']),
        ], skip: <String>{name}),
        latitude: latitude,
        longitude: longitude,
        origin: PlaceOrigin.online,
      ));
    }
    return places;
  }
}
