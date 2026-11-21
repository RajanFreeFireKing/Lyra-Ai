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
        currentStyle = raw;
        cleanText = cleanText.replaceFirst(m.group(0)!, "");
      }
    }
    return {
      "style": currentStyle,
      "text": cleanText.replaceAll(RegExp(r'\s+'), ' ').trim(),
    };
  }

  /// Synthesizes speech and streams 24kHz PCM chunks to native AudioTrack, with automatic Android native TTS fallback
  Future<void> speakLine(String rawLine) async {
    if (rawLine.trim().isEmpty) return;

    final parsed = parsePerformance(rawLine);
    final text = parsed["text"] ?? "";
    final style = parsed["style"] ?? "";
    if (text.isEmpty) return;

    // Plain text for native TTS fallback (remove SSML tags like <sigh>, <laugh>)
    final plainText = text.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    if (apiKey.trim().isEmpty) {
      // Fallback directly to native TTS
      await NativeChannel.speakTextNative(plainText);
      return;
    }

    final url = Uri.parse(
        '${ApiConfig.googleGenAiBaseUrl}/models/$model:generateContent?key=$apiKey');

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
        "responseModalities": ["AUDIO"],
        "speechConfig": {
          "voiceConfig": {
            "prebuiltVoiceConfig": {
              "voiceName": voice
            }
          }
        }
      }
    });

    bool playedCloudAudio = false;

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']?['parts'] as List<dynamic>?;
          if (parts != null) {
            for (final part in parts) {
              final inlineData = part['inlineData'] ?? part['inline_data'];
              if (inlineData != null && inlineData['data'] != null) {
                final base64Audio = inlineData['data'] as String;
                final pcmBytes = base64Decode(base64Audio);
                if (pcmBytes.isNotEmpty) {
                  await NativeChannel.feedAudioChunk(pcmBytes);
                  playedCloudAudio = true;
                }
              }
            }
          }
        }
      }
    } catch (_) {
      playedCloudAudio = false;
    }

    // If cloud TTS failed to produce audio, speak aloud via native Android TTS engine!
    if (!playedCloudAudio && plainText.isNotEmpty) {
      await NativeChannel.speakTextNative(plainText);
    }
  }
}
