/// Thin HTTPS client for the self-hosted ShiaAi gateway.
///
/// The app never holds a Gemini API key. It posts the user's question and a
/// SMALL set of already-retrieved local excerpts to the gateway configured in
/// [ShiaAiPreferences]; the gateway keeps the key as a server-side secret and
/// talks to Gemini. Only the passages in this request can be used by the
/// model, and every citation id the model returns is re-checked on device.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'shia_ai_models.dart';

/// Normalized model response. [usedIds] only contains ids from the request;
/// the engine still validates them again against its retrieved set.
class ShiaAiGatewayResponse {
  const ShiaAiGatewayResponse({
    required this.answer,
    required this.sufficient,
    required this.usedIds,
  });

  final String answer;
  final bool sufficient;
  final List<String> usedIds;
}

/// Transport-level failure mapped onto the chat's delivery states, so the UI
/// can show the right Urdu message without inspecting platform exceptions.
class ShiaAiGatewayException implements Exception {
  const ShiaAiGatewayException(this.delivery, this.message);

  final ShiaAiDelivery delivery;
  final String message;

  @override
  String toString() => 'ShiaAiGatewayException(${delivery.name}): $message';
}

class ShiaAiGateway {
  ShiaAiGateway({http.Client? client, this.timeout = const Duration(seconds: 45)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// Maximum excerpt text sent per passage (also enforced in the gateway).
  static const int excerptChars = 1200;

  /// Hard cap on passages per request — a handful of excerpts, never a book.
  static const int maxPassages = 8;

  Future<ShiaAiGatewayResponse> synthesize({
    required Uri endpoint,
    required String question,
    required List<ShiaAiEvidence> evidence,
  }) async {
    if (evidence.isEmpty) {
      throw const ShiaAiGatewayException(
        ShiaAiDelivery.noEvidence,
        'no evidence was retrieved',
      );
    }
    final passages = evidence
        .take(maxPassages)
        .map((item) => item.toGatewayJson(maxChars: excerptChars))
        .toList();
    final body = jsonEncode(<String, Object?>{
      'question': question,
      'language': 'ur',
      'passages': passages,
    });

    http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: const <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const ShiaAiGatewayException(
        ShiaAiDelivery.networkError,
        'gateway timed out',
      );
    } on http.ClientException catch (error) {
      throw ShiaAiGatewayException(
        ShiaAiDelivery.networkError,
        error.message,
      );
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 401:
      case 403:
        throw const ShiaAiGatewayException(
          ShiaAiDelivery.keyUnavailable,
          'gateway rejected the request (server-side key missing or invalid)',
        );
      case 404:
      case 501:
        throw const ShiaAiGatewayException(
          ShiaAiDelivery.serviceError,
          'gateway endpoint not found',
        );
      case 429:
      case 503:
        throw const ShiaAiGatewayException(
          ShiaAiDelivery.quotaExhausted,
          'model quota exhausted or service temporarily unavailable',
        );
      default:
        throw ShiaAiGatewayException(
          ShiaAiDelivery.serviceError,
          'unexpected HTTP ${response.statusCode}',
        );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw ShiaAiGatewayException(
        ShiaAiDelivery.serviceError,
        'malformed gateway JSON: $error',
      );
    }
    if (decoded is! Map) {
      throw const ShiaAiGatewayException(
        ShiaAiDelivery.serviceError,
        'gateway returned a non-object payload',
      );
    }
    final answer = (decoded['answer'] ?? '').toString().trim();
    final sufficient = decoded['sufficient'] != false;
    final rawIds = decoded['used_citation_ids'];
    final usedIds = rawIds is List
        ? rawIds.map((value) => value.toString()).where((id) => id.contains(':')).toList()
        : const <String>[];
    if (answer.isEmpty) {
      throw const ShiaAiGatewayException(
        ShiaAiDelivery.serviceError,
        'gateway returned an empty answer',
      );
    }
    return ShiaAiGatewayResponse(
      answer: answer,
      sufficient: sufficient,
      usedIds: usedIds,
    );
  }

  void close() => _client.close();
}
