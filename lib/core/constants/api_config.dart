class ApiConfig {
  // STT Models (Google AI Studio public endpoint)
  static const String sttModel = "gemini-2.0-flash";
  static const String sttLiveModel = "gemini-2.0-flash-exp";
  static const String sttClipModel = "gemini-2.0-flash";

  // TTS Models (Google AI Studio public endpoint)
  static const String ttsExpressiveModel = "gemini-2.0-flash";
  static const String ttsExpressiveLiteModel = "gemini-2.0-flash-lite";
  static const String ttsLiveModel = "gemini-2.0-flash-exp";

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
