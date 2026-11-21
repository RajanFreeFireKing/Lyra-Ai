import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_config.dart';
import '../../core/constants/system_prompts.dart';
import '../../services/native_channel.dart';

class MemoryRepository {
  final String apiKey;
  final String baseUrl;

  MemoryRepository({
    required this.apiKey,
    this.baseUrl = ApiConfig.openRouterBaseUrl,
  });

  /// Loads the deterministic State Card compiled directly by native SQLite
  Future<String> loadStateCard() async {
    return await NativeChannel.compileStateCard();
  }

  /// Records a turn into SQLite turns table
  Future<void> recordTurn(String role, String text) async {
    await NativeChannel.insertTurn(role, text);
  }

  /// Post-conversation digest with strict quote-verification gate (port of digest.js)
  Future<int> digestConversation(List<Map<String, String>> conversationTurns) async {
    if (conversationTurns.isEmpty) return 0;

    final turnsText = conversationTurns
        .map((t) => "${t['role']?.toUpperCase()}: ${t['text']}")
        .join("\n\n");

    final body = jsonEncode({
      "model": ApiConfig.defaultBrainModel,
      "messages": [
        {"role": "system", "content": SystemPrompts.digestSystemPrompt},
        {"role": "user", "content": turnsText}
      ],
      "temperature": 0.0,
      "response_format": {"type": "json_object"}
    });

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: body,
      );

      if (res.statusCode != 200) return 0;

      final data = jsonDecode(res.body);
      final rawJson = data['choices']?[0]?['message']?['content'] as String? ?? "{}";
      final parsed = jsonDecode(rawJson);
      final memories = parsed['memories'] as List<dynamic>? ?? [];

      int storedCount = 0;
      for (final m in memories) {
        final quote = m['quote'] as String? ?? '';
        final type = m['type'] as String? ?? 'identity';
        final original = m['text_original'] as String? ?? '';
        final en = m['text_en'] as String? ?? '';
        final origin = m['origin'] as String? ?? 'stated';

        // STRICT GATE: Verify quote exists verbatim in user lines
        final isVerified = await NativeChannel.verifyQuote(quote);
        if (isVerified && original.isNotEmpty) {
          await NativeChannel.insertMemory(type, original, en, quote, origin, false);
          storedCount++;
        }
      }
      return storedCount;
    } catch (_) {
      return 0;
    }
  }
}
