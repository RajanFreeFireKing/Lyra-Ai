import 'dart:async';
import 'package:flutter/services.dart';

class NativeChannel {
  static const MethodChannel _audioChannel = MethodChannel('ai.lyra.mobile/audio');
  static const EventChannel _audioStreamChannel = EventChannel('ai.lyra.mobile/audio_stream');
  static const MethodChannel _liveChannel = MethodChannel('ai.lyra.mobile/live');
  static const EventChannel _liveEventChannel = EventChannel('ai.lyra.mobile/live_events');
  static const MethodChannel _automationChannel = MethodChannel('ai.lyra.mobile/automation');
  static const MethodChannel _overlayChannel = MethodChannel('ai.lyra.mobile/overlay');
  static const MethodChannel _memoryChannel = MethodChannel('ai.lyra.mobile/memory');
  static const MethodChannel _awarenessChannel = MethodChannel('ai.lyra.mobile/awareness');

  // Audio Methods
  static Future<bool> checkMicrophonePermission() async {
    try {
      final res = await _audioChannel.invokeMethod<bool>('checkMicrophonePermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestMicrophonePermission() async {
    try {
      final res = await _audioChannel.invokeMethod<bool>('requestMicrophonePermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> startRecording() async {
    try {
      final res = await _audioChannel.invokeMethod<bool>('startRecording');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopRecording() async {
    try {
      await _audioChannel.invokeMethod('stopRecording');
    } catch (_) {}
  }

  static Future<void> feedAudioChunk(Uint8List pcmChunk) async {
    try {
      await _audioChannel.invokeMethod('feedAudioChunk', {'data': pcmChunk});
    } catch (_) {}
  }

  static Future<void> stopPlayback() async {
    try {
      await _audioChannel.invokeMethod('stopPlayback');
      await _audioChannel.invokeMethod('stopNativePlayback');
    } catch (_) {}
  }

  static Future<bool> speakTextNative(String text, {String lang = "en-US"}) async {
    try {
      final res = await _audioChannel.invokeMethod<bool>('speakTextNative', {
        'text': text,
        'lang': lang,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopNativePlayback() async {
    try {
      await _audioChannel.invokeMethod('stopNativePlayback');
    } catch (_) {}
  }

  static Stream<Map<dynamic, dynamic>> get audioStream {
    return _audioStreamChannel.receiveBroadcastStream().map((event) => event as Map<dynamic, dynamic>);
  }

  // Live Audio Transport Methods (Gemini Live BidiGenerateContent)
  static Future<bool> startLiveSession({
    required String apiKey,
    String model = "gemini-2.5-flash-native-audio-preview-12-2025",
    String voice = "Aoede",
    required String systemPrompt,
    double temperature = 0.85,
  }) async {
    try {
      final res = await _liveChannel.invokeMethod<bool>('startLiveSession', {
        'apiKey': apiKey,
        'model': model,
        'voice': voice,
        'systemPrompt': systemPrompt,
        'temperature': temperature,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopLiveSession() async {
    try {
      await _liveChannel.invokeMethod('stopLiveSession');
    } catch (_) {}
  }

  static Future<void> sendLiveText(String text) async {
    try {
      await _liveChannel.invokeMethod('sendLiveText', {'text': text});
    } catch (_) {}
  }

  static Future<void> sendLiveAudioEnd() async {
    try {
      await _liveChannel.invokeMethod('sendLiveAudioEnd');
    } catch (_) {}
  }

  static Future<bool> isLiveReady() async {
    try {
      final res = await _liveChannel.invokeMethod<bool>('isLiveReady');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Stream<Map<dynamic, dynamic>> get liveEventStream {
    return _liveEventChannel.receiveBroadcastStream().map((event) => event as Map<dynamic, dynamic>);
  }

  // Automation Methods
  static Future<bool> requestScreenCapturePermission() async {
    try {
      final res = await _automationChannel.invokeMethod<bool>('requestScreenCapturePermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isAccessibilityServiceActive() async {
    try {
      final res = await _automationChannel.invokeMethod<bool>('isAccessibilityServiceActive');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _automationChannel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> captureScreen() async {
    try {
      final res = await _automationChannel.invokeMethod<Map<dynamic, dynamic>>('captureScreen');
      if (res != null) {
        return {
          'png': res['png'] as Uint8List,
          'width': res['width'] as int,
          'height': res['height'] as int,
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> performClick(int x, int y) async {
    try {
      final res = await _automationChannel.invokeMethod<bool>('click', {'x': x, 'y': y});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> performScroll(String direction, int x, int y) async {
    try {
      final res = await _automationChannel.invokeMethod<bool>('scroll', {'direction': direction, 'x': x, 'y': y});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> performTypeText(String text) async {
    try {
      final res = await _automationChannel.invokeMethod<bool>('typeText', {'text': text});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> pressBack() async {
    try {
      final res = await _automationChannel.invokeMethod<bool>('pressBack');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  // Overlay Methods
  static Future<bool> checkOverlayPermission() async {
    try {
      final res = await _overlayChannel.invokeMethod<bool>('checkOverlayPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestOverlayPermission() async {
    try {
      await _overlayChannel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  static Future<void> showOverlay() async {
    try {
      await _overlayChannel.invokeMethod('showOverlay');
    } catch (_) {}
  }

  static Future<void> updateOverlay(String status, String detail) async {
    try {
      await _overlayChannel.invokeMethod('updateOverlay', {'status': status, 'detail': detail});
    } catch (_) {}
  }

  static Future<void> hideOverlay() async {
    try {
      await _overlayChannel.invokeMethod('hideOverlay');
    } catch (_) {}
  }

  // Memory Methods
  static Future<String> compileStateCard() async {
    try {
      final res = await _memoryChannel.invokeMethod<String>('compileStateCard');
      return res ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<String> insertTurn(String role, String text) async {
    try {
      final res = await _memoryChannel.invokeMethod<String>('insertTurn', {'role': role, 'text': text});
      return res ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<String> insertMemory(String type, String original, String en, String quote, String origin, bool pinned) async {
    try {
      final res = await _memoryChannel.invokeMethod<String>('insertMemory', {
        'type': type,
        'textOriginal': original,
        'textEn': en,
        'quote': quote,
        'origin': origin,
        'pinned': pinned,
      });
      return res ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<bool> verifyQuote(String quote) async {
    try {
      final res = await _memoryChannel.invokeMethod<bool>('verifyQuote', {'quote': quote});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  // Awareness Methods
  static Future<Map<String, dynamic>> getAwarenessSnapshot() async {
    try {
      final res = await _awarenessChannel.invokeMethod<Map<dynamic, dynamic>>('getSnapshot');
      return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
    } catch (_) {
      return {};
    }
  }
}
