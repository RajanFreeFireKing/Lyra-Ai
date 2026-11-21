class ApiConfig {
  // Live Bidirectional Audio Models (Gemini Live BidiGenerateContent)
  static const String liveNativeAudioModel = "gemini-2.5-flash-native-audio-preview-12-2025";
  static const String liveFallbackModel = "gemini-3.8-live";

  // STT Models (Google AI Studio public endpoint)
  static const String sttModel = "gemini-3.8-flash";
  static const String sttLiveModel = "gemini-3.8-flash";
  static const String sttClipModel = "gemini-3.8-flash";

  // TTS Models (Google AI Studio public endpoint)
  static const String ttsExpressiveModel = "gemini-3.8-flash";
  static const String ttsExpressiveLiteModel = "gemini-3.8-flash";
  static const String ttsLiveModel = "gemini-3.8-flash";

  // Agent S3 Automation Models
  static const String defaultPlannerModel = "openai/gpt-5.6-sol";
  static const String defaultGroundingModel = "bytedance/ui-tars-1.5-7b";

  // Brain Models
  static const String defaultBrainModel = "claude-3-5-sonnet-20241022";

  // Base URLs
  static const String openRouterBaseUrl = "https://openrouter.ai/api/v1";
  static const String googleGenAiBaseUrl = "https://generativelanguage.googleapis.com/v1beta";
  static const String anthropicBaseUrl = "https://api.anthropic.com/v1";

  // Audio Rates
  static const int sttSampleRate = 16000;
  static const int ttsSampleRate = 24000;
}
