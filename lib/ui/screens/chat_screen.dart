import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_notifier.dart';
import '../../services/voice_conversation_controller.dart';
import '../widgets/glass_container.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeNotifier>(context);
    final voice = Provider.of<VoiceConversationController>(context);
    final neon = theme.neonColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text("CONVERSATION"),
      ),
      body: voice.chatHistory.isEmpty
          ? Center(
              child: Text(
                "No conversation turns yet.\nSpeak with Lyra on the home screen.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: voice.chatHistory.length,
              itemBuilder: (context, index) {
                final item = voice.chatHistory[index];
                final isUser = item['role'] == 'user';
                final text = item['text'] ?? '';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: GlassContainer(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    borderRadius: 16,
                    borderColor: isUser ? neon.withOpacity(0.4) : Colors.white12,
                    child: Column(
                      crossAxisAlignment:
                          isUser ? CrossAlignment.end : CrossAlignment.start,
                      children: [
                        Text(
                          isUser ? "YOU" : "LYRA",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isUser ? neon : Colors.white54,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          text,
                          style: const TextStyle(fontSize: 14.5, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
