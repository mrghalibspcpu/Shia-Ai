import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_ai/services/city_index.dart';
import 'package:shia_ai/services/place_names.dart';
import 'package:shia_ai/services/prayer_locations.dart';

/// The offline place list behind the location picker and the naming of a GPS
/// fix: parsing, search ranking, the "which town is this" scoring, and the
/// Urdu labels built from a match.
void main() {
  const sample = '#shiaverse-cities\t1\t8\n'
      '#c\tPK\tPakistan\n'
      '#c\tIQ\tIraq\n'
      'Rawalpindi\tPK\tPunjab\t33.597\t73.048\t3400000\n'
      'Islamabad\tPK\tIslamabad\t33.721\t73.043\t600000\n'
      'Saidpur\tPK\tIslamabad\t33.740\t73.068\t15000\n'
      'Chakwal\tPK\tPunjab\t32.933\t72.854\t100000\n'
      'Najaf\tIQ\tAn Najaf\t31.996\t44.315\t480000\n'
      'Kufa\tIQ\tAn Najaf\t32.051\t44.440\t110000\n'
      'Alizai\tPK\tKhyber Pakhtunkhwa\t33.539\t70.346\t3300\n'
      'New Mirpur City\tPK\tAzad Kashmir\t33.148\t73.752\t120000\n'
      'a line without enough fields\n'
      'Broken\tPK\tPunjab\tnot-a-number\t73\t5\n';

  final index = CityIndex.parse(sample);

  group('parsing', () {
    test('reads every good line and skips the broken ones', () {
      expect(index.length, 8);
      expect(index.countryName('PK'), 'Pakistan');
      expect(index.countryName('XX'), 'XX');
      final islamabad = index.cityAt(1);
      expect(islamabad.name, 'Islamabad');
      expect(islamabad.province, 'Islamabad');
      expect(islamabad.countryCode, 'PK');
      expect(islamabad.countryName, 'Pakistan');
      expect(islamabad.latitude, 33.721);
      expect(islamabad.longitude, 73.043);
      expect(islamabad.population, 600000);
    });

    test('the bundled list is in the app and holds Pakistan in depth', () {
      final file = File('assets/geo/cities.tsv.gz');
      expect(file.existsSync(), isTrue, reason: 'run scripts/build_city_index.py');
      final bundled = CityIndex.fromGzip(file.readAsBytesSync());
      expect(bundled.length, greaterThan(50000));
      expect(bundled.search('chakwal').first.name, 'Chakwal');
      expect(bundled.search('parachinar').first.countryCode, 'PK');
      expect(bundled.search('skardu').first.province, 'Gilgit-Baltistan');
      // A fix in Islamabad's G-11 sector belongs to Islamabad, not Rawalpindi.
      expect(bundled.nearest(33.6686, 72.9973)!.city.name, 'Islamabad');
      expect(bundled.nearest(31.4697, 74.4093)!.city.name, 'Lahore');
    });
  });

  group('search', () {
    test('queries are normalised to what the list stores', () {
      expect(CityIndex.normaliseQuery('  Chak WAL!! '), 'chak wal');
      expect(CityIndex.normaliseQuery('Dera   Ismail-Khan'), 'dera ismail-khan');
      expect(CityIndex.normaliseQuery('کراچی'), '');
    });

    test('exact names, then prefixes, then later words, then anything inside', () {
      expect(index.search('islamabad').first.name, 'Islamabad');
      expect(index.search('isl').first.name, 'Islamabad');
      expect(index.search('mirpur').single.name, 'New Mirpur City');
      expect(index.search('pur').map((city) => city.name), <String>['Saidpur', 'New Mirpur City']);
      expect(index.search('CHAKWAL').single.name, 'Chakwal');
    });

    test('one letter, or nothing that matches, is an empty list', () {
      expect(index.search('a'), isEmpty);
      expect(index.search(''), isEmpty);
      expect(index.search('zzzz'), isEmpty);
    });

    test('the home country of the reader comes first within each group', () {
      final mixed = CityIndex.parse(
        'Al Hillah\tIQ\tBabil\t32.464\t44.420\t460000\n'
        'Alizai\tPK\tKhyber Pakhtunkhwa\t33.539\t70.346\t3300\n'
        'Al\tNO\tViken\t60.630\t8.564\t2000\n',
      );
      expect(mixed.search('al').map((city) => city.name), <String>['Al', 'Al Hillah', 'Alizai']);
      expect(
        mixed.search('al', preferCountry: 'PK').map((city) => city.name),
        <String>['Al', 'Alizai', 'Al Hillah'],
        reason: 'an exact name still beats a prefix from home',
      );
    });

    test('the limit is respected', () {
      expect(index.search('a', limit: 2), isEmpty);
      expect(index.search('al', limit: 1).length, 1);
    });
  });

  group('nearest town', () {
    test('a big city wins over a closer small place, a separate town keeps its name', () {
      expect(index.nearest(33.6686, 72.9973)!.city.name, 'Islamabad');
      expect(index.nearest(33.523, 73.095)!.city.name, 'Rawalpindi');
      expect(index.nearest(32.93, 72.85)!.city.name, 'Chakwal');
      expect(index.nearest(32.03, 44.40)!.city.name, 'Kufa');
    });

    test('reports the distance, and nothing in the middle of the ocean', () {
      final match = index.nearest(33.7034, 70.3241)!;
      expect(match.city.name, 'Alizai');
      expect(match.distanceKm, closeTo(18.4, 0.5));
      expect(index.nearest(0, 0), isNull);
    });

    test('great-circle distance', () {
      expect(CityIndex.distanceKm(33.6844, 73.0479, 24.8607, 67.0011), closeTo(1142.5, 1));
      expect(CityIndex.distanceKm(10, 10, 10, 10), 0);
    });
  });

  group('labels', () {
    test('a curated town is named in Urdu, without saying the city twice', () {
      final name = PrayerLocations.describeMatch(CityMatch(index.cityAt(1), 7.2))!;
      expect(name.label, 'اسلام آباد');
      expect(name.detail, 'پاکستان');
    });

    test('a Pakistani province is in Urdu, a distant fix is "near" its town', () {
      final name = PrayerLocations.describeMatch(CityMatch(index.cityAt(6), 18.4))!;
      expect(name.label, 'Alizai کے قریب');
      expect(name.detail, 'خیبر پختونخوا، پاکستان');
    });

    test('abroad: the curated Urdu name, the English province, the Urdu country', () {
      final name = PrayerLocations.describeMatch(CityMatch(index.cityAt(4), 1.8))!;
      expect(name.label, 'نجف اشرف');
      expect(name.detail, 'An Najaf، عراق');
      expect(PrayerLocations.describeMatch(null), isNull);
    });

    test('curated and GeoNames spellings of one town are recognised', () {
      expect(PrayerLocations.namesAgree('Hyderabad, Sindh', 'Hyderabad'), isTrue);
      expect(PrayerLocations.namesAgree('Mirpur (AJK)', 'New Mirpur City'), isTrue);
      expect(PrayerLocations.namesAgree('Jhang', 'Jhang Sadr'), isTrue);
      expect(PrayerLocations.namesAgree('Karachi', 'Lahore'), isFalse);
      expect(PrayerLocations.curatedTwin(index.cityAt(7))?.nameUrdu, 'میرپور، آزاد کشمیر');
    });

    test('the picker lists a curated city once, before the bundled list', () {
      final results = PrayerLocations.searchOffline('chakwal', index);
      expect(results.first.title, 'چکوال');
      expect(results.first.origin, PlaceOrigin.curated);
      expect(results.where((row) => row.title == 'Chakwal'), isEmpty);

      final mirpur = PrayerLocations.searchOffline('mirpur', index);
      expect(mirpur.map((row) => row.title), contains('میرپور، آزاد کشمیر'));
      expect(mirpur.where((row) => row.title == 'New Mirpur City'), isEmpty);

      final saidpur = PrayerLocations.searchOffline('saidpur', index);
      expect(saidpur.single.title, 'Saidpur');
      expect(saidpur.single.origin, PlaceOrigin.offline);
      expect(saidpur.single.subtitle, 'اسلام آباد، پاکستان');

      // Without the list (still loading) the curated cities still answer.
      expect(PrayerLocations.searchOffline('karachi', null).first.title, 'کراچی');
      expect(PrayerLocations.searchOffline('', index).length, PrayerLocations.cities.length);
    });
  });
}
