import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shia_ai/gemini_client.dart';

class _ScriptedClient extends http.BaseClient {
  _ScriptedClient(this._handler);
  final Future<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  test('retries the next Gemini model after HTTP 404', () async {
    final seen = <String>[];
    final client = GeminiClient(
      client: _ScriptedClient((request) async {
        seen.add(request.url.path);
        if (request.url.path.contains('gemini-2.5-flash')) {
          return http.Response('{"error":{"status":"NOT_FOUND"}}', 404);
        }
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'جواب [R1]'},
                  ],
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final answer = await client.generateGroundedAnswer(
      apiKey: 'AIzaSyDummyTestKeyValueForUnitTests12345',
      preferredModel: 'gemini-2.5-flash',
      question: 'سوال',
      passages: const [
        {'book': 'الکافی', 'arabic': 'قال', 'urdu': 'فرمایا', 'record': '1'},
      ],
    );

    expect(answer, contains('[R1]'));
    expect(answer, isNot(contains('حوالہ جات')));
    expect(seen.first, contains('gemini-2.5-flash'));
    expect(seen, hasLength(greaterThan(1)));
  });

  test('parses keyword JSON even when wrapped in extra text', () {
    expect(
      GeminiClient.parseKeywordQueries('here {"queries":["جمع بین الصلاتین", "ظہر عصر"]}'),
      ['جمع بین الصلاتین', 'ظہر عصر'],
    );
  });

  test('maps an invalid API key to a Urdu error without retrying forever', () async {
    final client = GeminiClient(
      client: _ScriptedClient((request) async => http.Response('denied', 403)),
    );
    expect(
      () => client.generateGroundedAnswer(
        apiKey: 'AIzaSyDummyTestKeyValueForUnitTests12345',
        question: 'سوال',
        passages: const [
          {'book': 'الکافی', 'arabic': 'قال', 'urdu': 'فرمایا', 'record': '1'},
        ],
      ),
      throwsA(isA<GeminiClientException>().having((error) => error.message, 'message', contains('کلید'))),
    );
  });
}
