import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One place from the bundled GeoNames list (`assets/geo/cities.tsv.gz`, built
/// by `scripts/build_city_index.py`).
@immutable
class GeoCity {
  const GeoCity({
    required this.name,
    required this.countryCode,
    required this.countryName,
    required this.province,
    required this.latitude,
    required this.longitude,
    required this.population,
  });

  /// ASCII spelling, the way it is typed on an English keyboard ("Chakwal").
  final String name;

  /// ISO 3166 code ("PK").
  final String countryCode;

  /// English country name from the list's header ("Pakistan").
  final String countryName;

  /// English province / state name ("Punjab"), or empty.
  final String province;

  final double latitude;
  final double longitude;
  final int population;

  @override
  bool operator ==(Object other) =>
      other is GeoCity &&
      other.name == name &&
      other.countryCode == countryCode &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(name, countryCode, latitude, longitude);

  @override
  String toString() => 'GeoCity($name, $province, $countryCode)';
}

/// The answer to "which town is this fix in": the place, and how far the fix
/// is from its centre.
@immutable
class CityMatch {
  const CityMatch(this.city, this.distanceKm);

  final GeoCity city;
  final double distanceKm;
}

/// ~73,000 places in a few flat arrays: every name in one string (and its
/// lower-case twin, with identical offsets) so a search is a handful of native
/// `indexOf` calls instead of 73,000 string comparisons, and coordinates in
/// typed lists so the nearest-town scan never allocates.
class CityIndex {
  CityIndex._({
    required String names,
    required String keys,
    required Int32List starts,
    required Float32List latitudes,
    required Float32List longitudes,
    required Int32List populations,
    required Uint16List countryIds,
    required Uint16List provinceIds,
    required List<String> countryCodes,
    required Map<String, String> countryNames,
    required List<String> provinces,
  })  : _names = names,
        _keys = keys,
        _starts = starts,
        _latitudes = latitudes,
        _longitudes = longitudes,
        _populations = populations,
        _countryIds = countryIds,
        _provinceIds = provinceIds,
        _countryCodes = countryCodes,
        _countryNames = countryNames,
        _provinces = provinces;

  final String _names;
  final String _keys;

  /// Offset of each entry in [_names]/[_keys]; one extra sentinel at the end.
  final Int32List _starts;
  final Float32List _latitudes;
  final Float32List _longitudes;
  final Int32List _populations;
  final Uint16List _countryIds;
  final Uint16List _provinceIds;
  final List<String> _countryCodes;
  final Map<String, String> _countryNames;
  final List<String> _provinces;

  int get length => _latitudes.length;

  /// English name of a country code from the list's header, or the code.
  String countryName(String code) => _countryNames[code] ?? code;

  /// Decompresses and parses the bundled asset. Static so it can run in a
  /// background isolate through `compute`.
  static CityIndex fromGzip(Uint8List bytes) => parse(utf8.decode(gzip.decode(bytes)));

  /// Parses the tab-separated list. Malformed lines are skipped, never thrown.
  static CityIndex parse(String text) {
    final names = StringBuffer();
    final keys = StringBuffer();
    final starts = <int>[];
    final latitudes = <double>[];
    final longitudes = <double>[];
    final populations = <int>[];
    final countryIds = <int>[];
    final provinceIds = <int>[];
    final countryCodes = <String>[];
    final countryLookup = <String, int>{};
    final countryNames = <String, String>{};
    final provinces = <String>[];
    final provinceLookup = <String, int>{};
    var offset = 0;

    for (final line in const LineSplitter().convert(text)) {
      if (line.isEmpty) continue;
      if (line.startsWith('#')) {
        final header = line.split('\t');
        if (header.length >= 3 && header[0] == '#c') countryNames[header[1]] = header[2];
        continue;
      }
      final parts = line.split('\t');
      if (parts.length < 6) continue;
      final name = parts[0].trim();
      final latitude = double.tryParse(parts[3]);
      final longitude = double.tryParse(parts[4]);
      if (name.isEmpty || latitude == null || longitude == null) continue;
      if (latitude.abs() > 90 || longitude.abs() > 180) continue;

      starts.add(offset);
      names
        ..write(name)
        ..write('\n');
      // Lower-casing ASCII never changes the length; anything that would
      // (a stray non-Latin letter) keeps its original spelling so the two
      // strings stay offset-for-offset identical.
      final lower = name.toLowerCase();
      keys
        ..write(lower.length == name.length ? lower : name)
        ..write('\n');
      offset += name.length + 1;

      latitudes.add(latitude);
      longitudes.add(longitude);
      populations.add(int.tryParse(parts[5]) ?? 0);
      final code = parts[1];
      countryIds.add(countryLookup.putIfAbsent(code, () {
        countryCodes.add(code);
        return countryCodes.length - 1;
      }));
      final province = parts[2];
      provinceIds.add(provinceLookup.putIfAbsent(province, () {
        provinces.add(province);
        return provinces.length - 1;
      }));
    }
    starts.add(offset);

    return CityIndex._(
      names: names.toString(),
      keys: keys.toString(),
      starts: Int32List.fromList(starts),
      latitudes: Float32List.fromList(latitudes),
      longitudes: Float32List.fromList(longitudes),
      populations: Int32List.fromList(populations),
      countryIds: Uint16List.fromList(countryIds),
      provinceIds: Uint16List.fromList(provinceIds),
      countryCodes: countryCodes,
      countryNames: countryNames,
      provinces: provinces,
    );
  }

  GeoCity cityAt(int index) {
    final code = _countryCodes[_countryIds[index]];
    return GeoCity(
      name: _names.substring(_starts[index], _starts[index + 1] - 1),
      countryCode: code,
      countryName: countryName(code),
      province: _provinces[_provinceIds[index]],
      latitude: _roundCoordinate(_latitudes[index]),
      longitude: _roundCoordinate(_longitudes[index]),
      population: _populations[index],
    );
  }

  /// Float32 keeps ~7 digits; the list was written with 3 decimals, so round
  /// back to them instead of showing 33.72100067138672.
  static double _roundCoordinate(double value) => (value * 1000).roundToDouble() / 1000;

  /// What a typed query is compared with: lower case, Latin letters, digits,
  /// spaces, apostrophes and hyphens only.
  static String normaliseQuery(String query) {
    final lower = query.trim().toLowerCase();
    final buffer = StringBuffer();
    for (final unit in lower.codeUnits) {
      final isLetter = unit >= 0x61 && unit <= 0x7A;
      final isDigit = unit >= 0x30 && unit <= 0x39;
      if (isLetter || isDigit || unit == 0x20 || unit == 0x27 || unit == 0x2D) {
        buffer.writeCharCode(unit);
      }
    }
    return buffer.toString().replaceAll(RegExp(' +'), ' ').trim();
  }

  /// Places whose name contains [query]: exact names first, then names that
  /// start with it, then a later word that starts with it, then anything else
  /// — each group biggest-first (the list is stored by population), with the
  /// places of [preferCountry] (the reader's own country) ahead in each group.
  List<GeoCity> search(String query, {int limit = 40, String? preferCountry}) {
    final needle = normaliseQuery(query);
    if (needle.length < 2) return const <GeoCity>[];
    final exact = <int>[];
    final prefix = <int>[];
    final word = <int>[];
    final inside = <int>[];
    var from = 0;
    var found = 0;
    while (from < _keys.length) {
      final at = _keys.indexOf(needle, from);
      if (at < 0) break;
      final entry = _entryAt(at);
      final start = _starts[entry];
      final end = _starts[entry + 1] - 1;
      if (at == start) {
        (end - start == needle.length ? exact : prefix).add(entry);
      } else {
        final before = _keys.codeUnitAt(at - 1);
        (before == 0x20 || before == 0x2D || before == 0x27 ? word : inside).add(entry);
      }
      from = end + 1;
      // Enough to fill any page: a two-letter query matches thousands.
      if (++found >= 4000) break;
    }
    List<int> homeFirst(List<int> group) {
      if (preferCountry == null) return group;
      final home = <int>[];
      final away = <int>[];
      for (final entry in group) {
        (_countryCodes[_countryIds[entry]] == preferCountry ? home : away).add(entry);
      }
      return <int>[...home, ...away];
    }

    final ordered = <int>[
      ...homeFirst(exact),
      ...homeFirst(prefix),
      ...homeFirst(word),
      ...homeFirst(inside),
    ];
    return <GeoCity>[for (final index in ordered.take(limit)) cityAt(index)];
  }

  /// The entry whose name contains the character at [offset].
  int _entryAt(int offset) {
    var low = 0;
    var high = _starts.length - 2;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (_starts[mid] <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  /// The town a fix most plausibly belongs to.
  ///
  /// Pure nearest-point is wrong in cities: a fix in Islamabad's G-11 is
  /// closer to a small neighbourhood centre than to "Islamabad". Each place is
  /// therefore scored by distance minus a bonus that grows with the log of
  /// its population, so a big city wins over a nearby hamlet while a fix in
  /// a separate town still names that town.
  CityMatch? nearest(double latitude, double longitude, {double maxKm = 75}) {
    final cosLatitude = math.cos(latitude * math.pi / 180).abs().clamp(0.05, 1.0);
    final latitudeSpan = maxKm / 111.0;
    final longitudeSpan = maxKm / (111.0 * cosLatitude);
    var best = -1;
    var bestScore = double.infinity;
    var bestKm = 0.0;
    for (var index = 0; index < _latitudes.length; index++) {
      final placeLatitude = _latitudes[index];
      if ((placeLatitude - latitude).abs() > latitudeSpan) continue;
      var longitudeGap = (_longitudes[index] - longitude).abs();
      if (longitudeGap > 180) longitudeGap = 360 - longitudeGap;
      if (longitudeGap > longitudeSpan) continue;
      final km = distanceKm(latitude, longitude, placeLatitude, _longitudes[index]);
      if (km > maxKm) continue;
      final score = km - 2.5 * (math.log(_populations[index] + 10) / math.ln10);
      if (score < bestScore) {
        bestScore = score;
        best = index;
        bestKm = km;
      }
    }
    return best < 0 ? null : CityMatch(cityAt(best), bestKm);
  }

  /// Great-circle distance in kilometres.
  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371.0;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = phi2 - phi1;
    final dLambda = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2);
    return 2 * radius * math.asin(math.min(1.0, math.sqrt(a)));
  }
}

/// Loads the bundled list once per session, off the UI thread.
class CityIndexLoader {
  const CityIndexLoader._();

  static const String asset = 'assets/geo/cities.tsv.gz';

  static CityIndex? _cached;
  static Future<CityIndex?>? _pending;

  /// The index, or null when the asset cannot be read (never throws).
  static Future<CityIndex?> load() {
    final cached = _cached;
    if (cached != null) return Future<CityIndex?>.value(cached);
    return _pending ??= _load();
  }

  static Future<CityIndex?> _load() async {
    try {
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final index = await compute(CityIndex.fromGzip, bytes);
      _cached = index;
      return index;
    } catch (_) {
      _pending = null;
      return null;
    }
  }
}
