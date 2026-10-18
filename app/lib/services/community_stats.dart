import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Privacy-safe community counters for ShiaVerse.
///
/// The app never sends a name, phone number, location or device model. On the
/// first start it creates ONE random anonymous ID (e.g. `SV-8F3K2Q`) and keeps
/// only: that ID, the install date, and the last-active date — on the device
/// itself. The public totals (total installs, active users, worldwide zikr)
/// are read from `community_stats/stats.json` in the main branch of the
/// project repository, a file the maintainers update from anonymous install
/// receipts; every user sees exactly the same public numbers in Settings.
class CommunityStats {
  const CommunityStats({
    required this.totalInstalls,
    required this.activeUsers,
    required this.globalZikrTotal,
    this.updatedAt = '',
  });

  final int totalInstalls;
  final int activeUsers;
  final int globalZikrTotal;
  final String updatedAt;

  static const empty = CommunityStats(totalInstalls: 0, activeUsers: 0, globalZikrTotal: 0);

  factory CommunityStats.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    return CommunityStats(
      totalInstalls: asInt(json['total_installs']),
      activeUsers: asInt(json['active_users']),
      globalZikrTotal: asInt(json['global_zikr_total']),
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'total_installs': totalInstalls,
        'active_users': activeUsers,
        'global_zikr_total': globalZikrTotal,
        'updated_at': updatedAt,
      };
}

/// This device's anonymous install record (kept only on this device).
class InstallRecord {
  const InstallRecord({required this.anonymousId, required this.installedOn, required this.lastActiveOn});
  final String anonymousId;
  final String installedOn;
  final String lastActiveOn;
}

class CommunityStatsService {
  CommunityStatsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Public counters maintained in the repository's main branch.
  static final Uri statsUrl = Uri.parse(
    'https://raw.githubusercontent.com/mrghalibspcpu/Shia-Ai/main/community_stats/stats.json',
  );

  static const _statsKey = 'community_stats_cache_v1';
  static const _idKey = 'community_anonymous_id_v1';
  static const _installedKey = 'community_installed_on_v1';
  static const _activeKey = 'community_last_active_v1';

  /// Creates (once) and refreshes this device's anonymous record.
  /// Returns the record; no personal data is ever collected or sent.
  Future<InstallRecord> ensureInstallRecord() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_idKey);
    if (id == null || id.isEmpty) {
      final random = math.Random.secure();
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      id = 'SV-${List.generate(6, (_) => chars[random.nextInt(chars.length)]).join()}';
      await prefs.setString(_idKey, id);
      await prefs.setString(_installedKey, _today());
    }
    await prefs.setString(_activeKey, _today());
    return InstallRecord(
      anonymousId: id,
      installedOn: prefs.getString(_installedKey) ?? _today(),
      lastActiveOn: _today(),
    );
  }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<CommunityStats> cached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_statsKey);
      if (raw == null) return CommunityStats.empty;
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? CommunityStats.fromJson(decoded.cast<String, dynamic>())
          : CommunityStats.empty;
    } catch (_) {
      return CommunityStats.empty;
    }
  }

  /// Fetches the latest public counters (needs internet, e.g. when books are
  /// being downloaded anyway); silently keeps the cache when offline.
  Future<CommunityStats> refresh() async {
    try {
      final response = await _client.get(statsUrl).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return cached();
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return cached();
      final stats = CommunityStats.fromJson(decoded.cast<String, dynamic>());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_statsKey, jsonEncode(stats.toJson()));
      return stats;
    } catch (_) {
      return cached();
    }
  }
}
