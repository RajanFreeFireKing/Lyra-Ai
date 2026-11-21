import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';

class GeminiSttRest {
  final String apiKey;
  final String model;

  GeminiSttRest({
    required this.apiKey,
    this.model = ApiConfig.sttModel,
  });

  /// Wrap raw 16kHz 16-bit mono PCM into standard WAV container
  static Uint8List pcmToWav(Uint8List pcmData, {int sampleRate = 16000, int channels = 1, int bitDepth = 16}) {
    final byteRate = sampleRate * channels * (bitDepth ~/ 8);
    final blockAlign = channels * (bitDepth ~/ 8);
    final totalDataLen = pcmData.length;
    final totalFileLen = totalDataLen + 36;

    final header = ByteData(44);
    // RIFF chunk descriptor
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, totalFileLen, Endian.little);
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // "fmt " sub-chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1Size
    header.setUint16(20, 1, Endian.little);  // AudioFormat (1 = PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitDepth, Endian.little);

    // "data" sub-chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, totalDataLen, Endian.little);

    final wav = Uint8List(44 + totalDataLen);
    wav.setRange(0, 44, header.buffer.asUint8List());
    wav.setRange(44, 44 + totalDataLen, pcmData);
    return wav;
  }

  /// Transcribe audio buffer using Gemini multimodal audio REST endpoint
  Future<String> transcribePcm(Uint8List pcmData) async {
    if (pcmData.length < 1600) return ""; // Less than 50ms of audio, ignore
    if (apiKey.trim().isEmpty) return "";

    try {
      final wavData = pcmToWav(pcmData);
      final base64Audio = base64Encode(wavData);

      final url = Uri.parse(
        '${ApiConfig.googleGenAiBaseUrl}/models/$model:generateContent?key=$apiKey',
      );

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "inlineData": {
                  "mimeType": "audio/wav",
                  "data": base64Audio,
                }
              },
              {
                "text": "Transcribe the spoken words in this audio exactly. Do not describe sounds, do not add introductory text or commentary. Return ONLY the verbatim transcribed words in whatever language was spoken (Hindi, Urdu, English, Hinglish). If there is no speech, return an empty string."
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.0,
          "maxOutputTokens": 500,
        }
      });

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String? ?? "";
            return text.trim();
          }
        }
      }
      return "";
    } catch (_) {
      return "";
    }
  }
}
