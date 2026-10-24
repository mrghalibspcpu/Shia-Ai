/// Persists the ShiaAi conversation on the device (SharedPreferences).
///
/// Pushing a reader route already keeps the chat widget and its scroll
/// position in memory; this store additionally restores the conversation
/// after an app restart. Only the user's questions, the app-generated
/// answers and verified citation descriptors are stored — never API keys.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'shia_ai_models.dart';

class ShiaAiConversationStore {
  const ShiaAiConversationStore();

  static const String _messagesKey = 'shia_ai_messages_v1';
  static const int _maxStoredMessages = 60;

  Future<List<ShiaAiMessage>> loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_messagesKey);
    if (raw == null || raw.isEmpty) return const <ShiaAiMessage>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <ShiaAiMessage>[];
      return decoded
          .whereType<Map>()
          .map((row) => ShiaAiMessage.fromJson(row.cast<String, Object?>()))
          .toList();
    } on FormatException {
      return const <ShiaAiMessage>[];
    }
  }

  Future<void> saveMessages(List<ShiaAiMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = messages.length > _maxStoredMessages
        ? messages.sublist(messages.length - _maxStoredMessages)
        : messages;
    await prefs.setString(
      _messagesKey,
      jsonEncode(trimmed.map((message) => message.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_messagesKey);
  }
}
