class ApiConfig {
  // STT Models
  static const String sttLiveModel = "gemini-3.5-transcribe-live";
  static const String sttClipModel = "gemini-3.5-transcribe";

  // TTS Models
  static const String ttsExpressiveModel = "gemini-3.8-flash-tts";
  static const String ttsExpressiveLiteModel = "gemini-3.8-flash-lite-tts";
  static const String ttsLiveModel = "gemini-3.8-live";

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
