import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_config.dart';
import '../core/constants/system_prompts.dart';
import '../core/network/gemini_live_stt.dart';
import '../core/network/gemini_tts_client.dart';
import '../data/models/character_model.dart';
import '../data/repositories/memory_repository.dart';
import 'native_channel.dart';
import 'screen_agent_controller.dart';

enum AssistantStatus { idle, listening, thinking, speaking, working }

class VoiceConversationController extends ChangeNotifier {
  final String geminiApiKey;
  final String openRouterApiKey;
  final ScreenAgentController screenAgent;

  CharacterModel character = CharacterModel.soulmate();
  AssistantStatus status = AssistantStatus.idle;
  String currentStatusText = "Tap to speak with Lyra";
  String lastUserTranscript = "";
  String lastAssistantReply = "";

  final List<Map<String, String>> chatHistory = [];
  GeminiLiveStt? _sttClient;
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
  }

  void switchCharacter(CharacterModel newChar) {
    character = newChar;
    _ttsClient = GeminiTtsClient(apiKey: geminiApiKey, voice: character.voice);
    notifyListeners();
  }

  Future<void> startListening() async {
    if (status == AssistantStatus.listening) {
      await stopListening();
      return;
    }

    // Stop ongoing speech on user interrupt
    await NativeChannel.stopPlayback();
    status = AssistantStatus.listening;
    currentStatusText = "Listening...";
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
      currentStatusText = "Microphone error";
      notifyListeners();
      return;
    }

    _audioSubscription = NativeChannel.audioStream.listen((event) {
      final pcm = event['data'] as Uint8List?;
      final isSpeech = event['isSpeech'] as bool? ?? false;

      if (pcm != null && pcm.isNotEmpty) {
        _sttClient?.sendAudioChunk(pcm);
      }

      if (!isSpeech && lastUserTranscript.trim().isNotEmpty && status == AssistantStatus.listening) {
        // Speech paused: finalize turn
        _sttClient?.endSpeechTurn();
        _onUserSpeechFinished(lastUserTranscript.trim());
      }
    });
  }

  Future<void> stopListening() async {
    status = AssistantStatus.idle;
    currentStatusText = "Idle";
    notifyListeners();
    NativeChannel.updateOverlay("Idle", "");

    await NativeChannel.stopRecording();
    _audioSubscription?.cancel();
    _transcriptSubscription?.cancel();
    _sttClient?.disconnect();
  }

  Future<void> _onUserSpeechFinished(String userText) async {
    await stopListening();
    if (userText.isEmpty) return;

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

    // Background memory digest
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
        return data['choices']?[0]?['message']?['content'] as String? ?? "Ji, sun rahi hoon.";
      }
    } catch (_) {}
    return "Main yahin hoon, bataiye.";
  }
}

extension on List<Map<String, String>> {
  List<Map<String, String>> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}
