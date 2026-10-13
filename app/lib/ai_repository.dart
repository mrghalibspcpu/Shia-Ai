import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const String _compiledApiBaseUrl = String.fromEnvironment('SHIA_AI_API_BASE_URL');
class AiRepository {
  AiRepository({http.Client? client, FlutterSecureStorage? secureStorage})
      : _client = client ?? http.Client(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  String? _sessionId;

  Future<String> configuredBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('shia_ai_api_url') ?? _compiledApiBaseUrl).trim();
  }

  Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shia_ai_api_url', url.trim().replaceAll(RegExp(r'/+$'), ''));
  }

  Future<String> configuredApiToken() async =>
      (await _secureStorage.read(key: 'shia_ai_api_token')) ?? '';

  Future<void> saveApiToken(String token) async {
    final value = token.trim();
    if (value.isEmpty) {
      await _secureStorage.delete(key: 'shia_ai_api_token');
    } else {
      await _secureStorage.write(key: 'shia_ai_api_token', value: value);
    }
  }

  Future<ChatMessage> ask(
    String question,
    List<ChatMessage> previous, {
    String? readerContext,
    ReaderTarget? readerTarget,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _sessionId ??= prefs.getString('shia_ai_session_id');
    final baseUrl = await configuredBaseUrl();
    if (baseUrl.isEmpty) {
      throw const AiServiceException(
        'Shia AI backend URL is not configured. Open settings and add the HTTPS service URL.',
      );
    }
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const AiServiceException('Enter a valid HTTPS backend URL without embedded credentials.');
    }

    final history = previous
        .where((message) => message.text.trim().isNotEmpty)
        .toList()
        .reversed
        .take(6)
        .toList()
        .reversed
        .map((message) => {
              'role': message.isUser ? 'user' : 'assistant',
              'text': message.text.length > 1500 ? message.text.substring(0, 1500) : message.text,
            })
        .toList();
    final safeQuestion = question.trim();
    final safeReaderContext = readerContext?.trim() ?? '';
    final headers = <String, String>{'Content-Type': 'application/json; charset=utf-8'};
    final apiToken = await configuredApiToken();
    if (apiToken.isNotEmpty) headers['Authorization'] = 'Bearer $apiToken';
    late final http.Response response;
    try {
      response = await _client
          .post(
            uri.resolve('/api/chat'),
            headers: headers,
            body: jsonEncode({
              'question': safeQuestion.length > 4000 ? safeQuestion.substring(0, 4000) : safeQuestion,
              'session_id': _sessionId,
              'history': history,
              'reader_context': safeReaderContext.length > 3000 ? safeReaderContext.substring(0, 3000) : safeReaderContext,
              if (readerTarget != null)
                'reader_target': {
                  'book': readerTarget.book,
                  'record_id': readerTarget.recordId,
                },
              'limit': 6,
            }),
          )
          .timeout(const Duration(seconds: 120));
    } catch (error) {
      throw AiServiceException('Could not reach the Shia AI service: $error');
    }

    Map<String, dynamic> body;
    try {
      body = Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)) as Map);
    } catch (_) {
      throw AiServiceException('The Shia AI service returned an invalid response (${response.statusCode}).');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServiceException((body['message'] ?? body['error'] ?? 'AI service unavailable').toString());
    }
    _sessionId = (body['session_id'] ?? _sessionId)?.toString();
    if (_sessionId != null) await prefs.setString('shia_ai_session_id', _sessionId!);
    final sources = (body['sources'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((source) => AiSource.fromJson(Map<String, dynamic>.from(source)))
        .where((source) => source.target.book.isNotEmpty && source.target.recordId > 0)
        .toList();
    final answer = (body['answer'] ?? '').toString().trim();
    if (answer.isEmpty) throw const AiServiceException('The AI returned an empty response.');
    return ChatMessage(isUser: false, text: answer, sources: sources, createdAt: DateTime.now());
  }

  Future<void> resetSession() async {
    _sessionId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('shia_ai_session_id');
  }

  void dispose() => _client.close();
}

class AiServiceException implements Exception {
  const AiServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
