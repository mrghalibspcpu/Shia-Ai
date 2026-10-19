import 'package:flutter_test/flutter_test.dart';
import 'package:shiaverse/services/place_names.dart';

/// The online geocoders' payloads, as they arrive (trimmed): OpenStreetMap's
/// reverse and search, BigDataCloud's reverse, and Open-Meteo's search.
void main() {
  group('reverse geocoding', () {
    test('OpenStreetMap: neighbourhood and city, province and country', () {
      final name = OnlinePlaces.parseNominatimReverse(<String, dynamic>{
        'display_name': 'G-11/2, G-11, اسلام آباد, پاکستان',
        'address': <String, dynamic>{
          'neighbourhood': 'G-11/2',
          'suburb': 'G-11',
          'city': 'اسلام آباد',
          'state': 'وفاقی دارالحکومت',
          'country': 'پاکستان',
          'country_code': 'pk',
        },
      })!;
      expect(name.label, 'G-11، اسلام آباد');
      expect(name.detail, 'وفاقی دارالحکومت، پاکستان');
    });

    test('OpenStreetMap: a village is its own label', () {
      final name = OnlinePlaces.parseNominatimReverse(<String, dynamic>{
        'address': <String, dynamic>{
          'village': 'Khaplu',
          'state': 'Gilgit-Baltistan',
          'country': 'Pakistan',
        },
      })!;
      expect(name.label, 'Khaplu');
      expect(name.detail, 'Gilgit-Baltistan، Pakistan');
    });

    test('OpenStreetMap: errors and empty answers are null', () {
      expect(OnlinePlaces.parseNominatimReverse(<String, dynamic>{'error': 'Unable to geocode'}), isNull);
      expect(OnlinePlaces.parseNominatimReverse(<String, dynamic>{'address': <String, dynamic>{}}), isNull);
    });

    test('BigDataCloud: locality and city', () {
      final name = OnlinePlaces.parseBigDataCloud(<String, dynamic>{
        'city': 'Rawalpindi',
        'locality': 'Saddar',
        'principalSubdivision': 'Punjab',
        'countryName': 'Pakistan',
      })!;
      expect(name.label, 'Saddar، Rawalpindi');
      expect(name.detail, 'Punjab، Pakistan');
      final cityOnly = OnlinePlaces.parseBigDataCloud(<String, dynamic>{
        'city': 'Karbala',
        'locality': 'Karbala',
        'countryName': 'Iraq',
      })!;
      expect(cityOnly.label, 'Karbala');
      expect(cityOnly.detail, 'Iraq');
      expect(OnlinePlaces.parseBigDataCloud(<String, dynamic>{}), isNull);
    });
  });

  group('online search', () {
    test('Open-Meteo rows become picker rows', () {
      final rows = OnlinePlaces.parseOpenMeteo(<String, dynamic>{
        'results': <Object>[
          <String, dynamic>{
            'name': 'Kharmang',
            'latitude': 34.94,
            'longitude': 76.22,
            'country': 'Pakistan',
            'admin1': 'Gilgit-Baltistan',
            'population': 1200,
          },
          <String, dynamic>{'name': 'No coordinates'},
          'junk',
        ],
      });
      expect(rows.length, 1);
      expect(rows.single.title, 'Kharmang');
      expect(rows.single.subtitle, 'Gilgit-Baltistan، Pakistan');
      expect(rows.single.origin, PlaceOrigin.online);
      expect(rows.single.population, 1200);
      expect(OnlinePlaces.parseOpenMeteo(<String, dynamic>{'generationtime_ms': 0.4}), isEmpty);
    });

    test('OpenStreetMap search rows, with string coordinates', () {
      final rows = OnlinePlaces.parseNominatimSearch(<Object>[
        <String, dynamic>{
          'lat': '33.7034',
          'lon': '70.3241',
          'name': 'Sadda',
          'display_name': 'Sadda, Kurram, Khyber Pakhtunkhwa, Pakistan',
          'address': <String, dynamic>{
            'county': 'Kurram',
            'state': 'Khyber Pakhtunkhwa',
            'country': 'Pakistan',
          },
        },
        <String, dynamic>{
          'lat': '91',
          'lon': '0',
          'name': 'Impossible',
        },
        <String, dynamic>{
          'lat': '32.1',
          'lon': '74.2',
          'display_name': 'Unnamed hamlet, Punjab, Pakistan',
        },
      ]);
      expect(rows.length, 2);
      expect(rows.first.title, 'Sadda');
      expect(rows.first.latitude, closeTo(33.7034, 1e-9));
      expect(rows.first.subtitle, 'Kurram، Khyber Pakhtunkhwa، Pakistan');
      expect(rows.last.title, 'Unnamed hamlet');
    });

    test('two rows at one spot are recognised as the same place', () {
      const a = PlaceResult(
        title: 'کراچی',
        subtitle: 'Karachi',
        latitude: 24.8607,
        longitude: 67.0011,
        origin: PlaceOrigin.curated,
      );
      const b = PlaceResult(
        title: 'Karachi',
        subtitle: 'سندھ، پاکستان',
        latitude: 24.861,
        longitude: 67.010,
        origin: PlaceOrigin.offline,
      );
      const far = PlaceResult(
        title: 'Lahore',
        subtitle: '',
        latitude: 31.558,
        longitude: 74.351,
        origin: PlaceOrigin.offline,
      );
      expect(a.sameSpotAs(b), isTrue);
      expect(a.sameSpotAs(far), isFalse);
    });
  });
}
