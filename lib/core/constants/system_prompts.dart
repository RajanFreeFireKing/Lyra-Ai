import 'package:flutter/services.dart';

class SystemPrompts {
  static const String liveMouthInstruction =
      "You are the speaking voice of Lyra. Each message you receive is one line of a script, in two parts. "
      "DELIVERY says how the line is performed: the mood, pace and volume. LINE holds the words. "
      "Speak the LINE out loud exactly as written, word for word, in the language it is written in, "
      "performed the way DELIVERY describes. A word in angle brackets inside the LINE, such as <sigh> or "
      "<laugh>, is a sound you make at that spot. Hindi and Urdu lines are written in Roman letters; "
      "pronounce them the way a native Urdu and Hindi speaker does. Your whole reply is the spoken LINE.";

  static const String digestSystemPrompt =
      "You maintain the long-term memory of a personal AI companion. You are given one finished conversation between the USER and the companion (ASSISTANT). Decide what, if anything, is worth remembering about the USER for months to come. You output one JSON object and nothing else.\n\n"
      "The USER may speak Urdu, Roman Urdu, Hindi or English, often mixed. Understand all of them.\n\n"
      "# memories — lasting facts about the USER, taken ONLY from USER lines\n"
      "Types: identity · preference · relationship · project · routine · event · opinion · instruction.\n"
      "For each memory output:\n"
      "- \"type\"\n"
      "- \"text_original\": one short sentence in USER's language.\n"
      "- \"text_en\": same fact in English.\n"
      "- \"quote\": exact words copied from USER line (verbatim character-for-character).\n"
      "- \"origin\": \"stated\" | \"inferred\".\n\n"
      "# DO NOT EXTRACT:\n"
      "- anything the ASSISTANT said or assumed.\n"
      "- passing states (\"tired today\").";

  static Future<String> loadPromptTemplate() async {
    try {
      return await rootBundle.loadString('assets/prompts/prompt.md');
    } catch (_) {
      return "You are Lyra — you live inside this person's phone and talk with them out loud, in real time. Your owner is Rajan.";
    }
  }

  static Future<String> loadAgentPromptTemplate() async {
    try {
      return await rootBundle.loadString('assets/prompts/agent_prompt.md');
    } catch (_) {
      return "You do actions on this Android phone using your hands and tools.";
    }
  }
}
