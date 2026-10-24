/// On-device ShiaAi configuration.
///
/// The Gemini API key never exists in the client — only the URL of the
/// user-maintained gateway that holds the key server-side. The URL itself is
/// not a secret: it authorizes nothing by itself, and online synthesis is
/// additionally gated behind an explicit consent flag (default off).
library;

import 'package:shared_preferences/shared_preferences.dart';

class ShiaAiPreferences {
  const ShiaAiPreferences({
    this.gatewayUrl = '',
    this.onlineEnabled = false,
  });

  /// Empty by default: until the maintainer/user deploys the gateway from
  /// `backend/shia-ai-gateway/` and pastes its HTTPS URL here, ShiaAi stays a
  /// fully offline, citations-only feature.
  final String gatewayUrl;

  /// Explicit opt-in to send short retrieved excerpts (never the database)
  /// to the configured gateway, which forwards them to Gemini.
  final bool onlineEnabled;

  bool get isConfigured =>
      onlineEnabled && gatewayUrl.trim().isNotEmpty && _validUrl(gatewayUrl);

  static const String urlStorageKey = 'shia_ai_gateway_url_v1';
  static const String consentStorageKey = 'shia_ai_online_enabled_v1';

  static bool _validUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    // Android emulator/dev loopback is the only plain-http case allowed.
    if (uri.scheme == 'http' && !uri.host.startsWith('10.') &&
        uri.host != 'localhost' && uri.host != '127.0.0.1') {
      return false;
    }
    return true;
  }

  ShiaAiPreferences copyWith({String? gatewayUrl, bool? onlineEnabled}) =>
      ShiaAiPreferences(
        gatewayUrl: gatewayUrl ?? this.gatewayUrl,
        onlineEnabled: onlineEnabled ?? this.onlineEnabled,
      );

  static Future<ShiaAiPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ShiaAiPreferences(
      gatewayUrl: prefs.getString(urlStorageKey) ?? '',
      onlineEnabled: prefs.getBool(consentStorageKey) ?? false,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(urlStorageKey, gatewayUrl.trim());
    await prefs.setBool(consentStorageKey, onlineEnabled);
  }
}
