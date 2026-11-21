import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_notifier.dart';
import '../../data/models/character_model.dart';
import '../../services/voice_conversation_controller.dart';
import '../widgets/glass_container.dart';

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
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 16),
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
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderColor: isSelected ? neon : Colors.white10,
        borderRadius: 20,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isSelected ? neon.withOpacity(0.2) : Colors.white10,
                  child: Icon(
                    character.gender == "female"
                        ? Icons.favorite_rounded
                        : Icons.security_rounded,
                    color: isSelected ? neon : Colors.white54,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAlignment.start,
                    children: [
                      Text(
                        character.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? neon : Colors.white,
                        ),
                      ),
                      Text(
                        "Voice: ${character.voice} (${character.gender.toUpperCase()})",
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: neon, size: 24),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              character.prompt,
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8), height: 1.4),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Tone: ${character.naturalVoice}",
                style: const TextStyle(fontSize: 11, color: Colors.white54, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
