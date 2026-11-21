import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_notifier.dart';
import '../../data/models/character_model.dart';
import '../../services/voice_conversation_controller.dart';
import '../widgets/glass_container.dart';
import '../widgets/cyber_button.dart';

class CharacterScreen extends StatelessWidget {
  const CharacterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeNotifier>(context);
    final voice = Provider.of<VoiceConversationController>(context);
    final neon = theme.neonColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text("PERSONAS"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _buildCharacterCard(
            context,
            character: CharacterModel.soulmate(),
            isSelected: voice.character.id == "female_soulmate",
            neon: neon,
            onTap: () {
              voice.switchCharacter(CharacterModel.soulmate());
            },
          ),
          const SizedBox(height: 18),
          _buildCharacterCard(
            context,
            character: CharacterModel.jarvis(),
            isSelected: voice.character.id == "male_jarvis",
            neon: neon,
            onTap: () {
              voice.switchCharacter(CharacterModel.jarvis());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterCard(
    BuildContext context, {
    required CharacterModel character,
    required bool isSelected,
    required Color neon,
    required VoidCallback onTap,
  }) {
    final isFemale = character.gender == "female";

    return CyberButton(
      onTap: onTap,
      padding: EdgeInsets.zero,
      borderRadius: 24,
      borderColor: isSelected ? neon : Colors.white12,
      isGlow: isSelected,
      child: GlassContainer(
        borderColor: isSelected ? neon : Colors.white10,
        borderRadius: 24,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        isSelected ? neon.withOpacity(0.4) : Colors.white10,
                        const Color(0xFF131722),
                      ],
                    ),
                    border: Border.all(
                      color: isSelected ? neon : Colors.white24,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(color: neon.withOpacity(0.4), blurRadius: 14),
                          ]
                        : null,
                  ),
                  child: Icon(
                    isFemale ? Icons.favorite_rounded : Icons.security_rounded,
                    color: isSelected ? neon : Colors.white70,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            character.name,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? neon : Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? neon.withOpacity(0.2) : Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              character.gender.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? neon : Colors.white60,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "Voice: ${character.voice} (Gemini 2.0 Audio)",
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: neon,
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.black, size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              character.prompt,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.white.withOpacity(0.85),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Icon(Icons.format_quote_rounded, size: 14, color: isSelected ? neon : Colors.white38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      character.naturalVoice,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
