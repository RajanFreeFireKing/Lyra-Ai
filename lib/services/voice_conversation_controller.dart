import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_config.dart';
import '../core/constants/system_prompts.dart';
import '../core/network/gemini_live_stt.dart';
import '../core/network/gemini_stt_rest.dart';
import '../core/network/gemini_tts_client.dart';
import '../data/models/character_model.dart';
import '../data/repositories/memory_repository.dart';
import 'native_channel.dart';
import 'screen_agent_controller.dart';

enum AssistantStatus { idle, listening, thinking, speaking, working }

extension _ListTakeLast<T> on List<T> {
  List<T> takeLast(int n) {
    if (length <= n) return List<T>.from(this);
    return sublist(length - n);
  }
}

class VoiceConversationController extends ChangeNotifier {
  String geminiApiKey;
  String openRouterApiKey;
  final ScreenAgentController screenAgent;

  CharacterModel character = CharacterModel.soulmate();
  AssistantStatus status = AssistantStatus.idle;
  String currentStatusText = "Tap to speak with Lyra";
  String lastUserTranscript = "";
  String lastAssistantReply = "";
  double currentAudioRms = 0.0;

  final List<Map<String, String>> chatHistory = [];
  final List<int> _recordedPcmBytes = [];
  DateTime? _lastSpeechTime;
  bool _wasSpeechDetected = false;

  Timer? _silenceTimer;
  GeminiLiveStt? _sttClient;
  GeminiSttRest? _sttRest;
  GeminiTtsClient? _ttsClient;
  MemoryRepository? _memoryRepo;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _transcriptSubscription;

  VoiceConversationController({
    required this.geminiApiKey,
    required this.openRouterApiKey,
    required this.screenAgent,
  }) {
    _memoryRepo = MemoryRepository(apiKey: openRouterApiKey);
    _ttsClient = GeminiTtsClient(apiKey: geminiApiKey, voice: character.voice);
    _sttRest = GeminiSttRest(apiKey: geminiApiKey);
  }

  void updateApiKeys({required String geminiKey, required String openRouterKey}) {
    geminiApiKey = geminiKey;
    openRouterApiKey = openRouterKey;
    _memoryRepo = MemoryRepository(apiKey: openRouterApiKey);
    _ttsClient = GeminiTtsClient(apiKey: geminiApiKey, voice: character.voice);
    _sttRest = GeminiSttRest(apiKey: geminiApiKey);
    screenAgent.updateApiKey(openRouterKey);
    notifyListeners();
  }

  void switchCharacter(CharacterModel newChar) {
    character = newChar;
    _ttsClient = GeminiTtsClient(apiKey: geminiApiKey, voice: character.voice);
    notifyListeners();
  }

  /// Toggle listening: if idle -> start; if listening -> finish turn immediately
  Future<void> toggleListening() async {
    if (status == AssistantStatus.listening) {
      await finishTurnManually();
    } else if (status == AssistantStatus.idle) {
      await startListening();
    }
  }

  Future<void> startListening() async {
    if (status == AssistantStatus.listening) {
      await finishTurnManually();
      return;
    }

    // 1. Check API Key
    if (geminiApiKey.trim().isEmpty && openRouterApiKey.trim().isEmpty) {
      status = AssistantStatus.idle;
      currentStatusText = "Set Google AI Key in Settings";
      notifyListeners();
      return;
    }

    // 2. Check & Request Microphone Permission
    bool hasMic = await NativeChannel.checkMicrophonePermission();
    if (!hasMic) {
      currentStatusText = "Requesting microphone permission...";
      notifyListeners();
      hasMic = await NativeChannel.requestMicrophonePermission();
      if (!hasMic) {
        status = AssistantStatus.idle;
        currentStatusText = "Microphone permission required";
        notifyListeners();
        return;
      }
    }

    // Stop ongoing speech on user interrupt
    await NativeChannel.stopPlayback();
    status = AssistantStatus.listening;
    currentStatusText = "Listening...";
    lastUserTranscript = "";
    currentAudioRms = 0.0;
    _recordedPcmBytes.clear();
    _wasSpeechDetected = false;
    _lastSpeechTime = null;
    notifyListeners();
    NativeChannel.updateOverlay("Listening", "");

    _sttClient = GeminiLiveStt(apiKey: geminiApiKey);
    await _sttClient?.connect();

    _transcriptSubscription = _sttClient?.transcriptStream.listen((transcript) {
      lastUserTranscript = transcript;
      notifyListeners();
    });

    final ok = await NativeChannel.startRecording();
    if (!ok) {
      status = AssistantStatus.idle;
      currentStatusText = "Microphone failed to start";
      notifyListeners();
      return;
    }

    // Audio Chunk Stream from Android Native
    _audioSubscription = NativeChannel.audioStream.listen((event) {
      final pcm = event['data'] as Uint8List?;
      final isSpeech = event['isSpeech'] as bool? ?? false;
      final rms = (event['rms'] as num?)?.toDouble() ?? 0.0;

      currentAudioRms = rms;
      if (status == AssistantStatus.listening) {
        notifyListeners();
      }

      if (pcm != null && pcm.isNotEmpty) {
        _recordedPcmBytes.addAll(pcm);
        _sttClient?.sendAudioChunk(pcm);
      }

      if (isSpeech || rms > 45.0) {
        _wasSpeechDetected = true;
        _lastSpeechTime = DateTime.now();
      }
    });

    // Independent Auto-Silence Clock Timer (checks every 200ms)
    _silenceTimer?.cancel();
    _silenceTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (status != AssistantStatus.listening) {
        timer.cancel();
        return;
      }

      if (_wasSpeechDetected && _lastSpeechTime != null) {
        final silenceMs = DateTime.now().difference(_lastSpeechTime!).inMilliseconds;
        // User spoke for at least ~0.3s (9600 bytes) and has been silent for >= 800ms
        if (_recordedPcmBytes.length >= 9600 && silenceMs >= 800) {
          timer.cancel();
          finishTurnManually();
        }
      }
    });
  }

  /// Trigger turn completion when user stops speaking or taps mic STOP button
  Future<void> finishTurnManually() async {
    if (status != AssistantStatus.listening) return;

    _silenceTimer?.cancel();
    _silenceTimer = null;

    status = AssistantStatus.thinking;
    currentStatusText = "Transcribing speech...";
    currentAudioRms = 0.0;
    notifyListeners();
    NativeChannel.updateOverlay("Thinking", "");

    await NativeChannel.stopRecording();
    await _audioSubscription?.cancel();
    await _transcriptSubscription?.cancel();
    _sttClient?.endSpeechTurn();
    _sttClient?.disconnect();

    String userText = lastUserTranscript.trim();

    // If WebSocket streaming gave no transcript, run Gemini REST audio transcription
    if (userText.isEmpty && _recordedPcmBytes.length > 2000) {
      final pcmData = Uint8List.fromList(_recordedPcmBytes);
      _sttRest = GeminiSttRest(apiKey: geminiApiKey);
      final restResult = await _sttRest!.transcribePcm(pcmData);

      if (restResult.startsWith("ERROR:")) {
        // Show exact diagnostic error on screen
        status = AssistantStatus.idle;
        currentStatusText = restResult;
        notifyListeners();
        NativeChannel.updateOverlay("Error", restResult);
        _recordedPcmBytes.clear();
        return;
      }
      userText = restResult.trim();
    }

    _recordedPcmBytes.clear();
    _wasSpeechDetected = false;
    _lastSpeechTime = null;

    if (userText.isEmpty) {
      status = AssistantStatus.idle;
      currentStatusText = "Tap to speak with Lyra";
      notifyListeners();
      NativeChannel.updateOverlay("Ready", "");
      return;
    }

    await _onUserSpeechFinished(userText);
  }

  Future<void> cancelListening() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    status = AssistantStatus.idle;
    currentStatusText = "Tap to speak with Lyra";
    currentAudioRms = 0.0;
    notifyListeners();
    NativeChannel.updateOverlay("Ready", "");

    await NativeChannel.stopRecording();
    await _audioSubscription?.cancel();
    await _transcriptSubscription?.cancel();
    _sttClient?.disconnect();
    _recordedPcmBytes.clear();
  }

  Future<void> _onUserSpeechFinished(String userText) async {
    chatHistory.add({"role": "user", "text": userText});
    await _memoryRepo?.recordTurn("user", userText);
    notifyListeners();

    // Check if the user is asking to perform an on-screen automation task
    final lower = userText.toLowerCase();
    if (_isScreenAutomationRequest(lower)) {
      status = AssistantStatus.working;
      currentStatusText = "Working on your screen...";
      notifyListeners();
      NativeChannel.updateOverlay("Working", "Executing task");

      // Say brief acknowledgment aloud before tool run (Stonic Agent Rule)
      await _ttsClient?.speakLine("[warm] Checking your screen now.");
      final outcome = await screenAgent.executeScreenTask(userText);

      // Report outcome back
      await _ttsClient?.speakLine("[gentle] $outcome");
      chatHistory.add({"role": "assistant", "text": outcome});
      await _memoryRepo?.recordTurn("assistant", outcome);

      status = AssistantStatus.idle;
      currentStatusText = "Task complete";
      notifyListeners();
      NativeChannel.updateOverlay("Done", "");
      return;
    }

    // Conversational Turn
    status = AssistantStatus.thinking;
    currentStatusText = "Thinking...";
    notifyListeners();
    NativeChannel.updateOverlay("Thinking", "");

    final reply = await _generateBrainReply(userText);
    lastAssistantReply = reply;
    chatHistory.add({"role": "assistant", "text": reply});
    await _memoryRepo?.recordTurn("assistant", reply);
    notifyListeners();

    // Speak reply
    status = AssistantStatus.speaking;
    currentStatusText = "Speaking...";
    notifyListeners();
    NativeChannel.updateOverlay("Speaking", "");

    await _ttsClient?.speakLine(reply);

    status = AssistantStatus.idle;
    currentStatusText = "Tap to speak with Lyra";
    notifyListeners();
    NativeChannel.updateOverlay("Idle", "");

    // Background memory digest with quote gate verification
    _memoryRepo?.digestConversation(chatHistory);
  }

  bool _isScreenAutomationRequest(String input) {
    final triggers = [
      "open", "click", "tap", "search", "scroll", "type",
      "install", "delete", "book", "find on screen", "screen"
    ];
    return triggers.any((t) => input.contains(t));
  }

  Future<String> _generateBrainReply(String userMessage) async {
    final stateCard = await _memoryRepo?.loadStateCard() ?? "";
    final awareness = await NativeChannel.getAwarenessSnapshot();
    final template = await SystemPrompts.loadPromptTemplate();

    final systemPrompt = template
        .replaceAll("{{NAME}}", character.name)
        .replaceAll("{{CHARACTER}}", character.prompt)
        .replaceAll("{{SCRIPT_RULE}}", "- Speak in natural Hindustani (Roman Urdu/Hindi) or English.")
        .replaceAll("{{GENDER_RULE}}", "")
        .replaceAll("{{NATURAL_VOICE}}", " — ${character.naturalVoice} —")
        .replaceAll("{{PERFORM_EXAMPLES}}", character.bracketExamples.join("\n"));

    final contextBlock = StringBuffer()
      ..writeln(systemPrompt)
      ..writeln("\n## Context & Memory\n")
      ..writeln(stateCard)
      ..writeln("\nCurrent Foreground App: ${awareness['foregroundApp'] ?? 'Homescreen'}");

    final messages = [
      {"role": "system", "content": contextBlock.toString()},
      ...chatHistory.takeLast(6),
      {"role": "user", "content": userMessage}
    ];

    // 1. Try OpenRouter Brain if configured
    if (openRouterApiKey.trim().isNotEmpty) {
      try {
        final res = await http.post(
          Uri.parse('${ApiConfig.openRouterBaseUrl}/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $openRouterApiKey',
          },
          body: jsonEncode({
            "model": ApiConfig.defaultBrainModel,
            "messages": messages,
            "temperature": 0.7,
          }),
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final reply = data['choices']?[0]?['message']?['content'] as String?;
          if (reply != null && reply.trim().isNotEmpty) {
            return reply.trim();
          }
        }
      } catch (_) {}
    }

    // 2. Fallback to Gemini 2.0 Flash Brain using Gemini API Key
    if (geminiApiKey.trim().isNotEmpty) {
      try {
        final url = Uri.parse(
          '${ApiConfig.googleGenAiBaseUrl}/models/gemini-2.0-flash:generateContent?key=$geminiApiKey',
        );

        final contents = <Map<String, dynamic>>[];
        for (final m in chatHistory.takeLast(4)) {
          final role = m['role'] == 'user' ? 'user' : 'model';
          contents.add({
            "role": role,
            "parts": [{"text": m['text'] ?? ""}]
          });
        }
        contents.add({
          "role": "user",
          "parts": [{"text": userMessage}]
        });

        final body = jsonEncode({
          "systemInstruction": {
            "parts": [{"text": contextBlock.toString()}]
          },
          "contents": contents,
          "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 400,
          }
        });

        final res = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: body,
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]['content']?['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                return text.trim();
              }
            }
          }
        }
      } catch (_) {}
    }

    return "Ji, main sun rahi hoon. Kuch aur bataiye?";
  }
}
