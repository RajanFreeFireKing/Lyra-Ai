import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_config.dart';

class GeminiLiveStt {
  final String apiKey;
  final String model;
  WebSocketChannel? _channel;
  final StreamController<String> _transcriptController = StreamController<String>.broadcast();
  bool _isConnected = false;

  GeminiLiveStt({
    required this.apiKey,
    this.model = ApiConfig.sttLiveModel,
  });

  Stream<String> get transcriptStream => _transcriptController.stream;
  bool get isConnected => _isConnected;

  Future<bool> connect({String? customGatewayUrl}) async {
    final wsUrl = customGatewayUrl ??
        "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=$apiKey";

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      // Send setup payload
      final setupPayload = jsonEncode({
        "setup": {
          "model": "models/$model",
          "generationConfig": {
            "responseModalities": ["TEXT"],
          }
        }
      });
      _channel?.sink.add(setupPayload);

      _channel?.stream.listen((message) {
        _handleMessage(message);
      }, onError: (err) {
        _isConnected = false;
      }, onDone: () {
        _isConnected = false;
      });

      return true;
    } catch (_) {
      _isConnected = false;
      return false;
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final json = jsonDecode(message.toString());
      final serverContent = json['serverContent'];
      if (serverContent != null) {
        final modelTurn = serverContent['modelTurn'];
        if (modelTurn != null) {
          final parts = modelTurn['parts'] as List<dynamic>?;
          if (parts != null) {
            for (final p in parts) {
              final text = p['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                _transcriptController.add(text);
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  void sendAudioChunk(Uint8List pcmChunk) {
    if (!_isConnected || _channel == null) return;
    try {
      final base64Audio = base64Encode(pcmChunk);
      final payload = jsonEncode({
        "realtimeInput": {
          "mediaChunks": [
            {
              "mimeType": "audio/pcm;rate=16000",
              "data": base64Audio
            }
          ]
        }
      });
      _channel?.sink.add(payload);
    } catch (_) {}
  }

  void endSpeechTurn() {
    if (!_isConnected || _channel == null) return;
    try {
      final payload = jsonEncode({
        "realtimeInput": {
          "audioStreamEnd": true
        }
      });
      _channel?.sink.add(payload);
    } catch (_) {}
  }

  void disconnect() {
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;
  }
}
