import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_ai/services/backup_service.dart';

/// The backup format that makes the signing-key migration safe: everything the
/// reader created must survive an export → uninstall → install → restore round
/// trip byte for byte, and a damaged file must never half-apply.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{
        'bookmarks': <String>['quran:1', 'alkafi:42'],
        'note:quran:1': 'یہ نوٹ محفوظ رہنا چاہیے',
        'last_read_v2': 'quran|5|12',
        'last_read_book_quran': 'quran|5|12',
        'tasbeeh_v2': '{"preset":"zahra","count":12}',
        'prayer_preset_v1': 'jafari',
        'prayer_alert_v1': 'on',
        'hijri_adjust_v1': '-1',
        'prayer_location_v1': '{"lat":33.68,"lon":73.05,"source":"manual"}',
        'theme_mode': 'light',
        'light_default_applied': true,
        'search_history': <String>['امام حسین', 'غدیر'],
        'quran_mushaf_mode_v1': true,
        'reader_font_scale': 1.15,
        'reader_script': 'urdu',
        'reader_palette': 'paper',
      }));

  group('export', () {
    test('carries every stored value with its type intact', () async {
      final prefs = await SharedPreferences.getInstance();
      final json = BackupService(prefs).exportJson(
        appVersion: '1.13.2',
        createdAt: DateTime.utc(2026, 10, 16),
        installedDatabases: ['quran.db'],
      );

      expect(json, contains('"format": "shiaverse-backup"'));
      expect(json, contains('"formatVersion": 1'));
      expect(json, contains('"appVersion": "1.13.2"'));
      expect(json, contains('"installedDatabases"'));
      final file = BackupService.parse(json);
      expect(file.preferences['theme_mode'], 'light');
      expect(file.preferences['light_default_applied'], true);
      expect(file.preferences['reader_font_scale'], 1.15);
      expect(file.preferences['bookmarks'], <String>['quran:1', 'alkafi:42']);
      expect(file.installedDatabases, <String>['quran.db']);
      expect(file.bookmarkCount, 2);
      expect(file.noteCount, 1);
    });

    test('survives a full round trip on a wiped device', () async {
      final source = await SharedPreferences.getInstance();
      final json = BackupService(source).exportJson();

      // The "new phone": nothing is stored.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final target = await SharedPreferences.getInstance();
      expect(target.getKeys(), isEmpty);

      final summary = await BackupService(target).restore(BackupService.parse(json));
      expect(summary.restored, 16);
      expect(summary.removed, 0);
      expect(target.getStringList('bookmarks'), <String>['quran:1', 'alkafi:42']);
      expect(target.getString('note:quran:1'), 'یہ نوٹ محفوظ رہنا چاہیے');
      expect(target.getString('tasbeeh_v2'), '{"preset":"zahra","count":12}');
      expect(target.getDouble('reader_font_scale'), 1.15);
      expect(target.getBool('quran_mushaf_mode_v1'), true);
      expect(target.getStringList('search_history'), <String>['امام حسین', 'غدیر']);
    });

    test('a restore replaces stale values instead of merging with them', () async {
      final source = await SharedPreferences.getInstance();
      final json = BackupService(source).exportJson();

      SharedPreferences.setMockInitialValues(<String, Object>{
        'theme_mode': 'dark',
        'stale_key_from_older_install': 'x',
      });
      final target = await SharedPreferences.getInstance();
      final summary = await BackupService(target).restore(BackupService.parse(json));

      expect(summary.removed, 1);
      expect(target.getString('theme_mode'), 'light');
      expect(target.containsKey('stale_key_from_older_install'), isFalse);
    });
  });

  group('import safety', () {
    test('rejects text that is not a ShiaVerse backup', () {
      expect(() => BackupService.parse('not json at all'), throwsA(isA<BackupFormatException>()));
      expect(() => BackupService.parse('{"format":"other"}'), throwsA(isA<BackupFormatException>()));
      expect(
        () => BackupService.parse('{"format":"shiaverse-backup","formatVersion":0}'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects a backup from a newer format instead of guessing', () {
      expect(
        () => BackupService.parse(
          '{"format":"shiaverse-backup","formatVersion":99,"preferences":{}}',
        ),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('skips unreadable values but keeps the rest', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final file = BackupService.parse('''
      {
        "format": "shiaverse-backup",
        "formatVersion": 1,
        "preferences": {
          "theme_mode": {"type": "string", "value": "dark"},
          "broken": {"type": "nonsense", "value": 3},
          "not_a_map": 7
        }
      }
      ''');
      await BackupService(prefs).restore(file);
      expect(prefs.getString('theme_mode'), 'dark');
      expect(prefs.containsKey('broken'), isFalse);
      expect(prefs.containsKey('not_a_map'), isFalse);
    });

    test('typed values keep their exact type', () {
      expect(BackupService.encodeValue('a'), {'type': 'string', 'value': 'a'});
      expect(BackupService.encodeValue(true), {'type': 'bool', 'value': true});
      expect(BackupService.encodeValue(7), {'type': 'int', 'value': 7});
      expect(BackupService.encodeValue(7.5), {'type': 'double', 'value': 7.5});
      expect(BackupService.encodeValue(<String>['x']), {
        'type': 'stringList',
        'value': ['x']
      });
      expect(BackupService.encodeValue(<int>[1]), isNull);
      expect(BackupService.decodeValue({'type': 'int', 'value': 7.0}), 7);
      expect(BackupService.decodeValue({'type': 'double', 'value': 7}), 7.0);
    });
  });
}
