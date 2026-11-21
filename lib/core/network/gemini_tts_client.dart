import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';
import '../../services/native_channel.dart';

class GeminiTtsClient {
  final String apiKey;
  final String model;
  final String voice;

  GeminiTtsClient({
    required this.apiKey,
    this.model = ApiConfig.ttsExpressiveModel,
    this.voice = "Aoede", // Aoede (female) or Charon (male)
  });

  static final RegExp _bracketRegex = RegExp(r'\[([^\[\]]*)\]');

  /// Splits directions: "[soft and slow] Sir... [sigh] afsos hai." -> (style: "soft and slow", text: "Sir... <sigh> afsos hai.")
  static Map<String, String> parsePerformance(String line, {String baseStyle = ""}) {
    String currentStyle = baseStyle;
    String cleanText = line;

    final matches = _bracketRegex.allMatches(line);
    for (final m in matches) {
      final raw = m.group(1)?.trim() ?? "";
      final lower = raw.toLowerCase();
      if (lower.contains("laugh") || lower.contains("chuckle")) {
        cleanText = cleanText.replaceFirst(m.group(0)!, "<laugh>");
      } else if (lower.contains("sigh")) {
        cleanText = cleanText.replaceFirst(m.group(0)!, "<sigh>");
      } else if (lower.contains("gasp")) {
        cleanText = cleanText.replaceFirst(m.group(0)!, "<gasp>");
      } else {
        // Mood / Delivery direction
        currentStyle = raw;
        cleanText = cleanText.replaceFirst(m.group(0)!, "");
      }
    }
    return {
      "style": currentStyle,
      "text": cleanText.replaceAll(RegExp(r'\s+'), ' ').trim(),
    };
  }

  /// Synthesizes speech and streams 24kHz PCM chunks to native AudioTrack
  Future<void> speakLine(String rawLine) async {
    if (rawLine.trim().isEmpty) return;

    final parsed = parsePerformance(rawLine);
    final text = parsed["text"] ?? "";
    final style = parsed["style"] ?? "";
    if (text.isEmpty) return;

    final url = Uri.parse(
        '${ApiConfig.googleGenAiBaseUrl}/models/$model:generateContentStream?key=$apiKey');

    final payloadPart = <String, dynamic>{"text": text};
    if (style.isNotEmpty) {
      payloadPart["speech_metadata"] = {"style": style};
    }

    final body = jsonEncode({
      "contents": [
        {
          "role": "user",
          "parts": [payloadPart]
        }
      ],
      "generationConfig": {
        "response_modalities": ["AUDIO"],
        "speech_config": {
          "voice_config": {
            "voice": voice
          }
        }
      }
    });

    try {
      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = body;

      final response = await request.send();
      if (response.statusCode != 200) {
        return;
      }

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        _processChunkJson(chunk);
      }
    } catch (_) {}
  }

  void _processChunkJson(String jsonChunk) {
    try {
      final cleaned = jsonChunk.trim().replaceAll(RegExp(r'^,|\[|\]$'), '');
      if (cleaned.isEmpty) return;
      final data = jsonDecode(cleaned);
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final parts = candidates[0]['content']?['parts'] as List<dynamic>?;
        if (parts != null) {
          for (final part in parts) {
            final inlineData = part['inlineData'] ?? part['inline_data'];
            if (inlineData != null && inlineData['data'] != null) {
              final base64Audio = inlineData['data'] as String;
              final pcmBytes = base64Decode(base64Audio);
              NativeChannel.feedAudioChunk(pcmBytes);
            }
          }
        }
      }
    } catch (_) {}
  }
}
