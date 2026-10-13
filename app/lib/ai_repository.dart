import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'gemini_client.dart';
import 'library_repository.dart';
import 'models.dart';
import 'text_utils.dart';

const String _compiledApiBaseUrl = String.fromEnvironment('SHIA_AI_API_BASE_URL');

class AiRepository {
  AiRepository({
    required LibraryRepository library,
    http.Client? client,
    FlutterSecureStorage? secureStorage,
    GeminiClient? gemini,
  }) : this._(
          library,
          client ?? http.Client(),
          secureStorage ?? const FlutterSecureStorage(),
          gemini,
        );

  AiRepository._(
    this._library,
    this._client,
    this._secureStorage,
    GeminiClient? gemini,
  ) : _gemini = gemini ?? GeminiClient(client: _client);

  final LibraryRepository _library;
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  final GeminiClient _gemini;
  String? _sessionId;

  Future<String> configuredBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('shia_ai_api_url') ?? _compiledApiBaseUrl).trim();
  }

  Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = url.trim();
    if (looksLikeGeminiApiKey(trimmed)) {
      await saveGeminiApiKey(trimmed);
      await prefs.remove('shia_ai_api_url');
      return;
    }
    await prefs.setString('shia_ai_api_url', trimmed.replaceAll(RegExp(r'/+$'), ''));
  }

  Future<String> configuredApiToken() async =>
      (await _secureStorage.read(key: 'shia_ai_api_token')) ?? '';

  Future<void> saveApiToken(String token) async {
    final value = token.trim();
    if (looksLikeGeminiApiKey(value)) {
      await saveGeminiApiKey(value);
      await _secureStorage.delete(key: 'shia_ai_api_token');
      return;
    }
    if (value.isEmpty) {
      await _secureStorage.delete(key: 'shia_ai_api_token');
    } else {
      await _secureStorage.write(key: 'shia_ai_api_token', value: value);
    }
  }

  Future<String> configuredGeminiApiKey() async {
    var key = ((await _secureStorage.read(key: 'shia_ai_gemini_key')) ?? '').trim();
    if (looksLikeGeminiApiKey(key)) return key;

    final url = await configuredBaseUrl();
    if (looksLikeGeminiApiKey(url)) {
      await saveGeminiApiKey(url);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('shia_ai_api_url');
      return url.trim();
    }

    final token = await configuredApiToken();
    if (looksLikeGeminiApiKey(token)) {
      await saveGeminiApiKey(token);
      await _secureStorage.delete(key: 'shia_ai_api_token');
      return token.trim();
    }
    return '';
  }

  Future<void> saveGeminiApiKey(String key) async {
    final value = key.trim();
    if (value.isEmpty) {
      await _secureStorage.delete(key: 'shia_ai_gemini_key');
    } else {
      await _secureStorage.write(key: 'shia_ai_gemini_key', value: value);
    }
  }

  Future<String> configuredGeminiModel() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('shia_ai_gemini_model') ?? kGeminiModelFallbacks.first).trim();
  }

  Future<void> saveGeminiModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shia_ai_gemini_model', model.trim());
  }

  Future<String> verifyGeminiApiKey(String key) => _gemini.verifyApiKey(key);

  Future<ChatMessage> ask(
    String question,
    List<ChatMessage> previous, {
    String? readerContext,
    ReaderTarget? readerTarget,
  }) async {
    final geminiKey = await configuredGeminiApiKey();
    final model = await configuredGeminiModel();
    final queries = List<String>.from(expandSearchQueries(question));
    if (geminiKey.isNotEmpty) {
      try {
        final extra = await _gemini.extractSearchKeywords(
          apiKey: geminiKey,
          question: question,
          preferredModel: model,
        );
        for (final item in extra) {
          if (queries.every((query) => query != item)) queries.add(item);
        }
      } catch (_) {
        // Keyword expansion is helpful, not required; local phrases still run.
      }
    }

    final hits = await _collectHits(readerTarget, queries: queries);

    if (geminiKey.isNotEmpty) {
      try {
        final answer = await _gemini.generateGroundedAnswer(
          apiKey: geminiKey,
          question: question,
          passages: [
            for (final hit in hits)
              {
                'book': hit.book.titleUrdu,
                'chapter': hit.passage.chapterTitle,
                'section': hit.passage.sectionTitle,
                'record': '${hit.passage.recordId}',
                'arabic': _excerpt(hit.passage.arabic),
                'urdu': _excerpt(hit.passage.urdu),
              },
          ],
          history: previous
              .where((message) => message.text.trim().isNotEmpty)
              .toList()
              .reversed
              .take(6)
              .toList()
              .reversed
              .map((message) => {
                    'role': message.isUser ? 'user' : 'assistant',
                    'text': message.text,
                  })
              .toList(),
          readerContext: readerContext,
          preferredModel: model,
        );
        return ChatMessage(
          isUser: false,
          text: answer,
          sources: _sourcesFromHits(hits),
          createdAt: DateTime.now(),
        );
      } on GeminiClientException catch (error) {
        throw AiServiceException(error.message);
      }
    }

    if (hits.isEmpty) {
      return ChatMessage(isUser: false, text: noMatchMessage(question), createdAt: DateTime.now());
    }

    final baseUrl = await configuredBaseUrl();
    if (baseUrl.isNotEmpty && !looksLikeGeminiApiKey(baseUrl)) {
      return _askBackend(
        question,
        previous,
        readerContext: readerContext,
        readerTarget: readerTarget,
        baseUrl: baseUrl,
      );
    }

    return ChatMessage(
      isUser: false,
      text: localGroundedAnswer(
        question,
        [
          for (var i = 0; i < hits.length; i++)
            [
              '[R${i + 1}] ${hits[i].citation}',
              if (hits[i].passage.arabic.trim().isNotEmpty) _excerpt(hits[i].passage.arabic, 280),
              if (hits[i].passage.urdu.trim().isNotEmpty) _excerpt(hits[i].passage.urdu, 280),
            ].join('\n'),
        ],
      ),
      sources: _sourcesFromHits(hits),
      createdAt: DateTime.now(),
    );
  }

  Future<List<SearchHit>> _collectHits(
    ReaderTarget? readerTarget, {
    required List<String> queries,
  }) async {
    final hits = List<SearchHit>.from(await _library.searchMany(queries, limit: 12));
    if (readerTarget != null) {
      final book = BookDefinition.byKey(readerTarget.book);
      if (book != null) {
        final passage = await _library.getPassageById(book, readerTarget.recordId);
        if (passage != null &&
            !hits.any((hit) => hit.book.key == book.key && hit.passage.recordId == passage.recordId)) {
          hits.insert(
            0,
            SearchHit(
              book: book,
              passage: passage,
              citation: formatCitation(
                bookTitle: book.titleUrdu,
                chapterTitle: passage.chapterTitle,
                sectionTitle: passage.sectionTitle,
                recordId: passage.recordId,
                page: passage.page,
              ),
            ),
          );
          if (hits.length > 12) hits.removeLast();
        }
      }
    }
    return hits;
  }

  Future<ChatMessage> _askBackend(
    String question,
    List<ChatMessage> previous, {
    String? readerContext,
    ReaderTarget? readerTarget,
    required String baseUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _sessionId ??= prefs.getString('shia_ai_session_id');
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const AiServiceException('درست HTTPS سروس کا پتہ درج کریں، یا Google AI Studio کی AIza کلید لگائیں۔');
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
      throw AiServiceException('شیعہ اے آئی سروس تک رسائی نہیں ہو سکی: $error');
    }

    Map<String, dynamic> body;
    try {
      body = Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)) as Map);
    } catch (_) {
      throw AiServiceException('شیعہ اے آئی سروس نے غلط جواب دیا (${response.statusCode})۔');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServiceException((body['message'] ?? body['error'] ?? 'AI سروس دستیاب نہیں').toString());
    }
    _sessionId = (body['session_id'] ?? _sessionId)?.toString();
    if (_sessionId != null) await prefs.setString('shia_ai_session_id', _sessionId!);
    final sources = (body['sources'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((source) => AiSource.fromJson(Map<String, dynamic>.from(source)))
        .where((source) => source.target.book.isNotEmpty && source.target.recordId > 0)
        .toList();
    final answer = (body['answer'] ?? '').toString().trim();
    if (answer.isEmpty) throw const AiServiceException('اے آئی نے خالی جواب دیا۔');
    return ChatMessage(isUser: false, text: answer, sources: sources, createdAt: DateTime.now());
  }

  List<AiSource> _sourcesFromHits(List<SearchHit> hits) {
    return [
      for (var i = 0; i < hits.length; i++)
        AiSource(
          marker: '[R${i + 1}]',
          citation: hits[i].citation,
          target: ReaderTarget(
            book: hits[i].book.key,
            recordId: hits[i].passage.recordId,
            sectionId: hits[i].passage.sectionId,
            page: hits[i].passage.page,
          ),
        ),
    ];
  }

  static String _excerpt(String text, [int limit = 1800]) {
    final compact = compactDisplayText(text);
    if (compact.length <= limit) return compact;
    return '${compact.substring(0, limit)}…';
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
