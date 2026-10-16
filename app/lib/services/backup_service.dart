import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Version stamped into every backup file this build writes.
const String kBackupAppVersion = '1.13.2';

/// Export and import of the app's on-device user state.
///
/// Everything the reader created lives in `SharedPreferences`: bookmarks,
/// notes, last-read positions, the tasbeeh counters and saved wirds, the
/// prayer settings and chosen location, theme and reader preferences. The
/// downloaded databases are deliberately *not* part of a backup — they are
/// ~230 MB of re-downloadable books — so a backup is a small JSON file that
/// is easy to keep on WhatsApp, Drive or a computer.
///
/// The format is self-describing and typed:
///
/// ```json
/// {
///   "format": "shiaverse-backup",
///   "formatVersion": 1,
///   "app": "shia_ai",
///   "appVersion": "1.13.2",
///   "createdAt": "2026-10-16T12:00:00.000Z",
///   "preferences": { "bookmarks": {"type": "stringList", "value": ["..."]} },
///   "installedDatabases": ["quran.db"]
/// }
/// ```
///
/// `installedDatabases` is informational: after restoring, the download
/// screen can offer exactly the books that were installed before. Nothing
/// here is sent anywhere — the file only leaves the device when the reader
/// chooses where to save it.
class BackupService {
  BackupService(this._prefs);

  final SharedPreferences _prefs;

  static const String format = 'shiaverse-backup';
  static const int formatVersion = 1;

  /// File bytes ⇄ JSON text helpers, so screens never touch `dart:convert`
  /// themselves (see tests/test_check_dart.py).
  static Uint8List encodeFileBytes(String json) => Uint8List.fromList(utf8.encode(json));

  static String decodeFileBytes(Uint8List bytes) => utf8.decode(bytes, allowMalformed: true);

  /// Every preference the app can hold, typed and sorted for stable files.
  Map<String, Object> export({
    String appVersion = kBackupAppVersion,
    DateTime? createdAt,
    List<String> installedDatabases = const [],
  }) {
    final preferences = <String, Object>{};
    final keys = _prefs.getKeys().toList()..sort();
    for (final key in keys) {
      final encoded = encodeValue(_prefs.get(key));
      if (encoded != null) preferences[key] = encoded;
    }
    return {
      'format': format,
      'formatVersion': formatVersion,
      'app': 'shia_ai',
      'appVersion': appVersion,
      'createdAt': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      'preferences': preferences,
      if (installedDatabases.isNotEmpty) 'installedDatabases': installedDatabases,
    };
  }

  String exportJson({
    String appVersion = kBackupAppVersion,
    DateTime? createdAt,
    List<String> installedDatabases = const [],
  }) {
    final json = const JsonEncoder.withIndent('  ').convert(export(
      appVersion: appVersion,
      createdAt: createdAt,
      installedDatabases: installedDatabases,
    ));
    return '$json\n';
  }

  /// One preference value as `{type, value}`; unsupported types are skipped
  /// instead of breaking the whole file.
  static Map<String, Object>? encodeValue(Object? value) {
    if (value is String) return {'type': 'string', 'value': value};
    if (value is bool) return {'type': 'bool', 'value': value};
    if (value is int) return {'type': 'int', 'value': value};
    if (value is double) return {'type': 'double', 'value': value};
    if (value is List<String>) return {'type': 'stringList', 'value': value};
    return null;
  }

  static Object? decodeValue(Map<String, Object?> entry) {
    final type = entry['type'];
    final value = entry['value'];
    if (value == null) return null;
    if (type == 'string' && value is String) return value;
    if (type == 'bool' && value is bool) return value;
    if (type == 'int' && value is num) return value.toInt();
    if (type == 'double' && value is num) return value.toDouble();
    if (type == 'stringList' && value is List) {
      return value.map((item) => item?.toString() ?? '').toList();
    }
    return null;
  }

  /// Parses and validates a backup without touching stored data.
  static BackupFile parse(String jsonText) {
    Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      throw const BackupFormatException('فائل JSON میں نہیں ہے — یہ ShiaVerse بیک اپ فائل نہیں لگتی۔');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BackupFormatException('یہ ShiaVerse بیک اپ فائل نہیں لگتی۔');
    }
    if (decoded['format'] != format) {
      throw const BackupFormatException('یہ ShiaVerse بیک اپ فائل نہیں لگتی۔');
    }
    final version = decoded['formatVersion'];
    if (version is! num || version.toInt() < 1) {
      throw const BackupFormatException('بیک اپ فائل کا نسخہ درست نہیں۔');
    }
    if (version.toInt() > formatVersion) {
      throw const BackupFormatException('یہ بیک اپ نئی ورژن سے بنایا گیا ہے — پہلے ایپ اپ ڈیٹ کریں۔');
    }
    final rawPreferences = decoded['preferences'];
    if (rawPreferences is! Map) {
      throw const BackupFormatException('بیک اپ فائل میں ترتیبات نہیں ملیں۔');
    }
    final preferences = <String, Object>{};
    for (final entry in rawPreferences.entries) {
      if (entry.value is! Map) continue;
      final typed = decodeValue((entry.value as Map).cast<String, Object?>());
      if (typed != null) preferences[entry.key] = typed;
    }
    final installed = <String>[
      if (decoded['installedDatabases'] is List)
        for (final item in decoded['installedDatabases'] as List)
          if (item != null) item.toString(),
    ];
    return BackupFile(
      preferences: preferences,
      appVersion: decoded['appVersion']?.toString() ?? '',
      createdAt: decoded['createdAt']?.toString() ?? '',
      installedDatabases: installed,
    );
  }

  /// Applies a backup on this device.
  ///
  /// With `replace: true` (the normal restore) any preference the backup does
  /// not mention is removed first, so the device ends up exactly like the
  /// source. Without it, the backup is merged over whatever is stored.
  Future<BackupRestoreSummary> restore(BackupFile file, {bool replace = true}) async {
    var removed = 0;
    if (replace) {
      for (final key in _prefs.getKeys()) {
        if (file.preferences.containsKey(key)) continue;
        await _prefs.remove(key);
        removed += 1;
      }
    }
    var restored = 0;
    for (final entry in file.preferences.entries) {
      final value = entry.value;
      if (value is String) {
        await _prefs.setString(entry.key, value);
      } else if (value is bool) {
        await _prefs.setBool(entry.key, value);
      } else if (value is int) {
        await _prefs.setInt(entry.key, value);
      } else if (value is double) {
        await _prefs.setDouble(entry.key, value);
      } else if (value is List<String>) {
        await _prefs.setStringList(entry.key, value);
      } else {
        continue;
      }
      restored += 1;
    }
    return BackupRestoreSummary(
      restored: restored,
      removed: removed,
      installedDatabases: file.installedDatabases,
    );
  }
}

/// One validated backup file.
class BackupFile {
  const BackupFile({
    required this.preferences,
    required this.appVersion,
    required this.createdAt,
    required this.installedDatabases,
  });

  final Map<String, Object> preferences;
  final String appVersion;
  final String createdAt;
  final List<String> installedDatabases;

  int get bookmarkCount {
    final value = preferences['bookmarks'];
    return value is List ? value.length : 0;
  }

  int get noteCount => preferences.keys.where((key) => key.startsWith('note:')).length;
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupRestoreSummary {
  const BackupRestoreSummary({
    required this.restored,
    required this.removed,
    required this.installedDatabases,
  });

  final int restored;
  final int removed;
  final List<String> installedDatabases;
}
