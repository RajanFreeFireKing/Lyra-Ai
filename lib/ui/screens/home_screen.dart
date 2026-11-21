import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_notifier.dart';
import '../../services/voice_conversation_controller.dart';
import '../../services/screen_agent_controller.dart';
import '../../services/native_channel.dart';
import '../widgets/neon_visualizer.dart';
import '../widgets/glass_container.dart';
import '../widgets/status_badge.dart';
import 'chat_screen.dart';
import 'character_screen.dart';
import 'memory_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeNotifier>(context);
    final voice = Provider.of<VoiceConversationController>(context);
    final screenAgent = Provider.of<ScreenAgentController>(context);

    final neon = theme.neonColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("LYRA AI"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.psychology_rounded),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background ambient neon glows (No static images)
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: neon.withOpacity(0.12),
                boxShadow: [
                  BoxShadow(color: neon.withOpacity(0.2), blurRadius: 100, spreadRadius: 40),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.secondaryColor.withOpacity(0.12),
                boxShadow: [
                  BoxShadow(color: theme.secondaryColor.withOpacity(0.2), blurRadius: 90, spreadRadius: 30),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Character Selector Chip Bar
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CharacterScreen()));
                    },
                    child: GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      borderRadius: 30,
                      borderColor: neon.withOpacity(0.3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.face_retouching_natural_rounded, size: 18, color: neon),
                          const SizedBox(width: 8),
                          Text(
                            "Persona: ${voice.character.name} (${voice.character.gender.toUpperCase()})",
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white54),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Neon Visualizer Ring (Aura / Comet)
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        NeonVisualizer(
                          neonColor: neon,
                          isPulsing: voice.status == AssistantStatus.listening ||
                              voice.status == AssistantStatus.speaking ||
                              screenAgent.isExecuting,
                          size: 240,
                        ),
                        // Inner mic interaction trigger
                        GestureDetector(
                          onTap: () {
                            voice.startListening();
                          },
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  neon.withOpacity(0.35),
                                  const Color(0xFF131722),
                                ],
                              ),
                              border: Border.all(color: neon.withOpacity(0.6), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: neon.withOpacity(voice.status == AssistantStatus.listening ? 0.6 : 0.2),
                                  blurRadius: 25,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              voice.status == AssistantStatus.listening
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                              size: 42,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 35),
                  StatusBadge(status: voice.status, neonColor: neon),

                  const SizedBox(height: 16),
                  Text(
                    voice.currentStatusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const Spacer(),

                  // Bottom Quick Actions Card
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(
                          icon: Icons.screen_search_desktop_rounded,
                          label: "Screen Agent",
                          color: neon,
                          onTap: () async {
                            final active = await NativeChannel.isAccessibilityServiceActive();
                            if (!active) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please enable Lyra Accessibility Service in Android Settings.")),
                              );
                              NativeChannel.openAccessibilitySettings();
                              return;
                            }
                            await NativeChannel.requestScreenCapturePermission();
                            screenAgent.executeScreenTask("Open settings and check storage");
                          },
                        ),
                        _buildActionButton(
                          icon: Icons.layers_outlined,
                          label: "HUD Overlay",
                          color: Colors.white70,
                          onTap: () async {
                            final hasPerm = await NativeChannel.checkOverlayPermission();
                            if (!hasPerm) {
                              await NativeChannel.requestOverlayPermission();
                            } else {
                              NativeChannel.showOverlay();
                              NativeChannel.updateOverlay("Ready", "Overlay active");
                            }
                          },
                        ),
                        _buildActionButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: "Chat History",
                          color: Colors.white70,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
