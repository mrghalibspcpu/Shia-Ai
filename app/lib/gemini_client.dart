import 'dart:convert';

import 'package:http/http.dart' as http;

const List<String> kGeminiModelFallbacks = [
  'gemini-2.0-flash',
  'gemini-2.5-flash',
  'gemini-flash-latest',
  'gemini-1.5-flash',
  'gemini-1.5-flash-latest',
];

class GeminiClientException implements Exception {
  const GeminiClientException(this.message, {this.retryWithNextModel = false});

  final String message;
  final bool retryWithNextModel;

  @override
  String toString() => message;
}

class GeminiClient {
  GeminiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  List<String> modelsToTry(String? preferred) {
    final chosen = (preferred ?? '').trim().replaceFirst(RegExp(r'^models/'), '');
    final models = <String>[];
    if (chosen.isNotEmpty) models.add(chosen);
    for (final model in kGeminiModelFallbacks) {
      if (!models.contains(model)) models.add(model);
    }
    return models;
  }

  Future<String> draftSilentUnderstanding({
    required String apiKey,
    required String question,
    String? preferredModel,
  }) async {
    return _generateWithRetry(
      apiKey: apiKey,
      preferredModel: preferredModel,
      system: _draftInstruction,
      userText: 'User question:\n${question.trim()}\n\nInternal briefing:',
      temperature: 0.2,
      maxOutputTokens: 500,
    );
  }

  Future<List<String>> extractSearchKeywords({
    required String apiKey,
    required String question,
    String? preferredModel,
    String? internalDraft,
  }) async {
    final draft = (internalDraft ?? '').trim();
    final userText = draft.isEmpty
        ? 'Question:\n${question.trim()}\n\nJSON:'
        : 'Question:\n${question.trim()}\n\nInternal briefing (never shown to the user):\n$draft\n\nJSON:';
    final raw = await _generateWithRetry(
      apiKey: apiKey,
      preferredModel: preferredModel,
      system: _keywordInstruction,
      userText: userText,
      temperature: 0,
      maxOutputTokens: 400,
    );
    return parseKeywordQueries(raw);
  }

  Future<String> generateGroundedAnswer({
    required String apiKey,
    required String question,
    required List<Map<String, String>> passages,
    List<Map<String, String>> history = const [],
    String? readerContext,
    String? preferredModel,
  }) async {
    final answer = await _generateWithRetry(
      apiKey: apiKey,
      preferredModel: preferredModel,
      system: _systemInstruction,
      userText: _userPrompt(question, passages, readerContext),
      history: history,
      temperature: 0.4,
      maxOutputTokens: 2800,
    );
    return _retainKnownMarkers(answer.trim(), passages.length);
  }

  Future<String> verifyApiKey(String apiKey, {String? preferredModel}) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const GeminiClientException('API کلید خالی ہے۔');
    }
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models',
      {'key': key},
    );
    late final http.Response response;
    try {
      response = await _client.get(uri, headers: const {'Accept': 'application/json'}).timeout(
        const Duration(seconds: 20),
      );
    } catch (_) {
      throw const GeminiClientException('Google AI Studio تک رسائی نہیں ہو سکی۔ انٹرنیٹ چیک کریں۔');
    }
    if (response.statusCode == 200) {
      return 'Google AI Studio کی کلید درست ہے۔';
    }
    throw GeminiClientException(_statusMessage(response.statusCode, preferredModel: preferredModel));
  }

  Future<String> _generateWithRetry({
    required String apiKey,
    required String system,
    required String userText,
    List<Map<String, String>> history = const [],
    String? preferredModel,
    double temperature = 0.2,
    int maxOutputTokens = 2048,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const GeminiClientException('Google AI Studio کی API کلید موجود نہیں۔');
    }
    Object? lastError;
    for (final model in modelsToTry(preferredModel)) {
      try {
        return await _complete(
          apiKey: key,
          model: model,
          system: system,
          userText: userText,
          history: history,
          temperature: temperature,
          maxOutputTokens: maxOutputTokens,
        );
      } on GeminiClientException catch (error) {
        lastError = error;
        if (!error.retryWithNextModel) rethrow;
      }
    }
    throw lastError as GeminiClientException? ??
        const GeminiClientException('Gemini سے جواب نہیں مل سکا۔');
  }

  Future<String> _complete({
    required String apiKey,
    required String model,
    required String system,
    required String userText,
    required List<Map<String, String>> history,
    required double temperature,
    required int maxOutputTokens,
  }) async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$model:generateContent',
      {'key': apiKey},
    );
    final contents = <Map<String, Object?>>[];
    for (final item in history.take(8)) {
      final role = item['role'] == 'assistant' || item['role'] == 'model' ? 'model' : 'user';
      final text = (item['text'] ?? '').trim();
      if (text.isEmpty) continue;
      contents.add({
        'role': role,
        'parts': [
          {'text': text.length > 2000 ? text.substring(0, 2000) : text},
        ],
      });
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userText},
      ],
    });

    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': system},
                ],
              },
              'contents': contents,
              'generationConfig': {
                'temperature': temperature,
                'maxOutputTokens': maxOutputTokens,
              },
            }),
          )
          .timeout(const Duration(seconds: 90));
    } catch (_) {
      throw const GeminiClientException('Gemini تک درخواست نہیں پہنچ سکی۔ انٹرنیٹ چیک کریں۔');
    }

    if (response.statusCode == 404 || response.statusCode == 400) {
      throw GeminiClientException(
        _statusMessage(response.statusCode, preferredModel: model),
        retryWithNextModel: true,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GeminiClientException(_statusMessage(response.statusCode, preferredModel: model));
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const GeminiClientException('Gemini نے ناقابلِ فہم جواب بھیجا۔');
    }

    final answer = _extractAnswer(body);
    if (answer.trim().isEmpty) {
      throw GeminiClientException(
        'Gemini نے خالی جواب دیا۔',
        retryWithNextModel: true,
      );
    }
    return answer;
  }

  static String _extractAnswer(Map<String, dynamic> body) {
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';
    final first = candidates.first;
    if (first is! Map) return '';
    final content = first['content'];
    if (content is! Map) return '';
    final parts = content['parts'];
    if (parts is! List) return '';
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is! Map) continue;
      if (part['thought'] == true) continue;
      final text = part['text'];
      if (text is String) buffer.write(text);
    }
    return buffer.toString();
  }

  static List<String> parseKeywordQueries(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return const [];
    try {
      final decoded = jsonDecode(raw.substring(start, end + 1));
      if (decoded is! Map) return const [];
      final queries = decoded['queries'];
      if (queries is! List) return const [];
      return [
        for (final item in queries)
          if (item is String && item.trim().isNotEmpty) item.trim(),
      ].take(12).toList();
    } catch (_) {
      return const [];
    }
  }

  static String _retainKnownMarkers(String answer, int passageCount) {
    if (passageCount <= 0) return answer;
    final allowed = {for (var i = 1; i <= passageCount; i++) '[R$i]'};
    return answer.replaceAllMapped(RegExp(r'\[R\d+\]'), (match) {
      return allowed.contains(match.group(0)) ? match.group(0)! : '';
    });
  }

  static String _userPrompt(
    String question,
    List<Map<String, String>> passages,
    String? readerContext,
  ) {
    final chunks = <String>[];
    for (var i = 0; i < passages.length; i++) {
      final passage = passages[i];
      chunks.add(
        [
          '[R${i + 1}] کتاب: ${passage['book'] ?? ''}',
          'باب: ${passage['chapter'] ?? ''}',
          'فصل: ${passage['section'] ?? ''}',
          'حدیث نمبر: ${passage['record'] ?? ''}',
          'عربی: ${passage['arabic'] ?? ''}',
          'اردو: ${passage['urdu'] ?? ''}',
        ].join('\n'),
      );
    }
    final context = (readerContext ?? '').trim();
    final contextNote = context.isEmpty ? '' : '\n\nReader position:\n${context.length > 3000 ? context.substring(0, 3000) : context}';
    final safeQuestion = question.trim();
    final corpus = chunks.isEmpty
        ? 'No on-device excerpts were retrieved for this wording. Still answer the question from well-known Jaʿfari teaching, and say that a direct local hit was limited.'
        : chunks.join('\n\n');
    return 'Local Shia corpus excerpts follow. Read them ALL together before answering.\n\n'
        '$corpus'
        '$contextNote\n\nQuestion: ${safeQuestion.length > 4000 ? safeQuestion.substring(0, 4000) : safeQuestion}';
  }

  static String _statusMessage(int status, {String? preferredModel}) {
    switch (status) {
      case 400:
      case 404:
        return 'ماڈل دستیاب نہیں ${preferredModel == null ? '' : '($preferredModel)'}۔ دوسرا ماڈل آزمایا جا رہا ہے۔';
      case 401:
      case 403:
        return 'Google AI Studio کی API کلید غلط ہے یا اس ماڈل کی اجازت نہیں۔ کلید چیک کریں۔';
      case 429:
        return 'Gemini کی حد پوری ہو گئی ہے۔ کچھ دیر بعد کوشش کریں۔';
      default:
        return 'Gemini سروس دستیاب نہیں (HTTP $status)۔';
    }
  }
}

const String _draftInstruction =
    'You are an internal Shia hadith librarian. The user will never see this text. '
    'Write 4 to 8 short lines: (1) what they are asking, (2) the Arabic and Urdu '
    'fiqh/hadith terms that should be searched in al-Kafi, Tahdhib, Wasa\'il, '
    'Man la yahduruhu al-faqih and similar books. Do not answer the question. '
    'Do not cite books. Plain text only.';

const String _keywordInstruction =
    'You prepare search phrases for a bilingual Shia hadith library '
    '(al-Kafi, Tahdhib, Wasa\'il, Man la yahduruhu al-faqih, and similar). '
    'Use the question and any internal briefing. '
    'Return ONLY JSON of the form {"queries":["..."]} with 8 to 12 short '
    'Arabic and Urdu phrases that would actually appear in those books. '
    'Include classical fiqh terms (for example جمع بین الصلاتین). No markdown.';

const String _systemInstruction =
    'You are Shia AI, a warm, clear teacher of the Ahl al-Bayt narrations. '
    'Always answer the user\'s question. Never say that no information exists. '
    'Read every supplied excerpt together: a ruling is often proven by several '
    'riwayat, not by one complete recipe in a single report. Synthesize, compare, '
    'and summarize them into a practical answer. Cite [R#] when a claim comes from '
    'an excerpt. Ignore off-topic excerpts. '
    'Priority: (1) combined corpus evidence; (2) well-known Jaʿfari/Shia teaching '
    'that does not contradict the corpus, clearly marked as مشہور شیعہ فتویٰ/آموزش; '
    '(3) never invent a specific hadith text, narrator chain, book+number, or grading. '
    'Use your reasoning to explain, but do not outrank the books. '
    'Respond in the same language as the question, usually simple, interesting Urdu. '
    'Structure: (1) سیدھا جواب in 2–5 lines; (2) روایات سے وضاحت with [R#]; '
    '(3) آسان خلاصہ. Do not dump a raw list of [R1], [R2] as the answer.';
