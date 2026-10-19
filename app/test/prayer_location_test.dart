import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiaverse/services/prayer_locations.dart';

/// The location chain's parsing and storage: the IP payloads (both providers),
/// typed coordinates, the city list, and the round trip through preferences.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IP geolocation payloads', () {
    test('reads ipapi.co', () {
      final payload = jsonDecode('''
        {"ip":"39.51.1.2","city":"Islamabad","region":"Islamabad",
         "country_name":"Pakistan","latitude":33.6844,"longitude":73.0479}
      ''');
      final location = PrayerLocations.fromIpPayload((payload as Map).cast<String, dynamic>())!;
      expect(location.latitude, 33.6844);
      expect(location.longitude, 73.0479);
      expect(location.label, 'Islamabad, Pakistan');
      expect(location.source, LocationSource.ip);
    });

    test('reads ipwho.is, where the numbers arrive as strings', () {
      final payload = jsonDecode('''
        {"success":true,"city":"Karachi","region":"Sindh","country":"Pakistan",
         "latitude":"24.8607","longitude":"67.0011"}
      ''');
      final location = PrayerLocations.fromIpPayload((payload as Map).cast<String, dynamic>())!;
      expect(location.latitude, closeTo(24.8607, 1e-9));
      expect(location.longitude, closeTo(67.0011, 1e-9));
      expect(location.label, 'Karachi, Pakistan');
    });

    test('falls back to the region when no city is given', () {
      final payload = jsonDecode('{"latitude":51.5,"longitude":-0.12,"region":"England"}');
      final location = PrayerLocations.fromIpPayload((payload as Map).cast<String, dynamic>())!;
      expect(location.label, 'England');
    });

    test('rejects failures, junk, and impossible coordinates', () {
      expect(PrayerLocations.fromIpPayload(<String, dynamic>{'error': true}), isNull);
      expect(PrayerLocations.fromIpPayload(<String, dynamic>{'success': false}), isNull);
      expect(PrayerLocations.fromIpPayload(<String, dynamic>{'latitude': 'nope'}), isNull);
      expect(PrayerLocations.fromIpPayload(<String, dynamic>{'latitude': 120.0, 'longitude': 0}), isNull);
      expect(PrayerLocations.fromIpPayload(<String, dynamic>{'latitude': 30.0, 'longitude': 200}), isNull);
    });
  });

  group('typed coordinates', () {
    test('accepts a comma- or space-separated pair', () {
      final comma = PrayerLocations.fromQuery('33.68, 73.04')!;
      expect(comma.latitude, closeTo(33.68, 1e-9));
      expect(comma.longitude, closeTo(73.04, 1e-9));
      expect(comma.source, LocationSource.manual);
      final space = PrayerLocations.fromQuery('-33.8688 151.2093')!;
      expect(space.latitude, closeTo(-33.8688, 1e-9));
    });

    test('refuses anything else', () {
      expect(PrayerLocations.fromQuery('Karachi'), isNull);
      expect(PrayerLocations.fromQuery('33.68'), isNull);
      expect(PrayerLocations.fromQuery('91, 10'), isNull);
      expect(PrayerLocations.fromQuery('10, 181'), isNull);
      expect(PrayerLocations.fromQuery(''), isNull);
    });
  });

  group('city list', () {
    test('is long enough to be useful and free of duplicates', () {
      expect(PrayerLocations.cities.length, greaterThan(50));
      final names = PrayerLocations.cities.map((city) => city.label).toSet();
      expect(names.length, PrayerLocations.cities.length);
    });

    test('every city is a real coordinate', () {
      for (final city in PrayerLocations.cities) {
        expect(city.latitude.abs(), lessThanOrEqualTo(90), reason: city.label);
        expect(city.longitude.abs(), lessThanOrEqualTo(180), reason: city.label);
      }
    });

    test('search finds a city by its Latin name, its Urdu name, or a typo-ish spelling', () {
      expect(PrayerLocations.searchCities('karachi').first.nameLatin, 'Karachi');
      expect(PrayerLocations.searchCities('کراچی').first.nameLatin, 'Karachi');
      expect(PrayerLocations.searchCities('lahor').first.nameLatin, 'Lahore');
      expect(PrayerLocations.searchCities('mashhad').first.nameLatin, 'Mashhad');
      expect(PrayerLocations.searchCities('').length, PrayerLocations.cities.length);
    });

    test('the sacred cities are present with their published coordinates', () {
      final makkah = PrayerLocations.cities.firstWhere((city) => city.nameLatin == 'Makkah');
      expect(makkah.latitude, closeTo(21.4225, 0.001));
      expect(makkah.longitude, closeTo(39.8262, 0.001));
      final najaf = PrayerLocations.cities.firstWhere((city) => city.nameLatin == 'Najaf');
      expect(najaf.latitude, closeTo(32.0, 0.01));
    });
  });

  group('storage', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('a location survives a round trip', () async {
      const stored = PrayerLocation(
        latitude: 24.8607,
        longitude: 67.0011,
        label: 'کراچی',
        source: LocationSource.manual,
      );
      await PrayerLocations.store(stored);
      final loaded = await PrayerLocations.loadStored();
      expect(loaded, isNotNull);
      expect(loaded!.latitude, closeTo(24.8607, 1e-9));
      expect(loaded.longitude, closeTo(67.0011, 1e-9));
      expect(loaded.label, 'کراچی');
      expect(loaded.source, LocationSource.manual);
    });

    test('a corrupt or impossible stored value is ignored, not thrown', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PrayerLocations.storageKey: 'not json at all',
      });
      expect(await PrayerLocations.loadStored(), isNull);

      SharedPreferences.setMockInitialValues(<String, Object>{
        PrayerLocations.storageKey: jsonEncode(<String, dynamic>{
          'lat': 300.0,
          'lon': 0.0,
          'label': 'impossible',
        }),
      });
      expect(await PrayerLocations.loadStored(), isNull);
    });

    test('nothing stored yet is not an error', () async {
      expect(await PrayerLocations.loadStored(), isNull);
    });

    test('the fallback is Islamabad and is marked as the fallback', () {
      expect(PrayerLocation.fallback.latitude, closeTo(33.6844, 1e-9));
      expect(PrayerLocation.fallback.isFallback, isTrue);
      expect(PrayerLocation.fallback.source, LocationSource.fallback);
      expect(PrayerLocation.fallback.source.labelUrdu, 'ڈیفالٹ');
    });
  });

  group('1.9: names, provinces and the bigger list', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('the province line and the refined flag survive a round trip', () async {
      const stored = PrayerLocation(
        latitude: 33.6686,
        longitude: 72.9973,
        label: 'G-11، اسلام آباد',
        detail: 'اسلام آباد، پاکستان',
        source: LocationSource.gps,
        refined: true,
      );
      await PrayerLocations.store(stored);
      final loaded = (await PrayerLocations.loadStored())!;
      expect(loaded.label, 'G-11، اسلام آباد');
      expect(loaded.detail, 'اسلام آباد، پاکستان');
      expect(loaded.refined, isTrue);
      expect(loaded.source, LocationSource.gps);
    });

    test('a location stored by 1.8 (no province, no flag) still loads', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PrayerLocations.storageKey: jsonEncode(<String, dynamic>{
          'lat': 33.6,
          'lon': 73.0,
          'label': 'میرا موجودہ مقام',
          'source': 'gps',
        }),
      });
      final loaded = (await PrayerLocations.loadStored())!;
      expect(loaded.detail, '');
      expect(loaded.refined, isFalse);
      expect(loaded.label, 'میرا موجودہ مقام');
    });

    test('an IP city that is a curated one is named in Urdu', () {
      final ip = PrayerLocations.fromIpPayload(<String, dynamic>{
        'city': 'Islamabad',
        'country_name': 'Pakistan',
        'latitude': 33.6844,
        'longitude': 73.0479,
      })!;
      final named = PrayerLocations.localiseIp(ip);
      expect(named.label, 'اسلام آباد');
      expect(named.detail, 'Islamabad, Pakistan');
      expect(named.source, LocationSource.ip);
      final unknown = PrayerLocations.fromIpPayload(<String, dynamic>{
        'city': 'Reykjavik',
        'country_name': 'Iceland',
        'latitude': 64.1,
        'longitude': -21.9,
      })!;
      expect(PrayerLocations.localiseIp(unknown).label, 'Reykjavik, Iceland');
    });

    test('the curated list now covers the towns of Pakistan', () {
      final latin = PrayerLocations.cities.map((city) => city.nameLatin).toSet();
      for (final town in <String>[
        'Parachinar',
        'Chakwal',
        'Jhang',
        'Hangu',
        'Khaplu',
        'Sargodha',
        'Bahawalpur',
        'Gilgit',
        'Skardu',
      ]) {
        expect(latin, contains(town));
      }
      expect(PrayerLocations.cities.length, greaterThan(150));
      expect(PrayerLocations.searchCities('chakwal').first.nameUrdu, 'چکوال');
      expect(PrayerLocations.searchCities('پاراچنار').first.nameLatin, 'Parachinar');
    });

    test('every location problem has a message and an action', () {
      for (final problem in LocationProblem.values) {
        expect(problem.messageUrdu, isNotEmpty);
        expect(problem.actionUrdu, isNotEmpty);
      }
      const failed = DeviceFix.failed(LocationProblem.servicesOff);
      expect(failed.location, isNull);
      expect(failed.problem, LocationProblem.servicesOff);
    });

    test('country labels are Urdu where known', () {
      expect(PrayerLocations.countryLabel('PK'), 'پاکستان');
      expect(PrayerLocations.countryLabel('IQ'), 'عراق');
      expect(PrayerLocations.countryLabel('IS', 'Iceland'), 'Iceland');
      expect(PrayerLocations.countryLabel('ZZ'), 'ZZ');
    });

    test('distance between two locations', () {
      expect(
        PrayerLocations.distanceKm(
          PrayerLocation.fallback,
          const PrayerLocation(
            latitude: 24.8607,
            longitude: 67.0011,
            label: 'کراچی',
            source: LocationSource.manual,
          ),
        ),
        closeTo(1142.5, 1),
      );
    });
  });
}
