import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_notifier.dart';
import '../../services/voice_conversation_controller.dart';
import '../../services/screen_agent_controller.dart';
import '../../services/native_channel.dart';
import '../widgets/cyber_ai_core.dart';
import '../widgets/glass_container.dart';
import '../widgets/cyber_button.dart';
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
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: neon.withOpacity(0.18),
                border: Border.all(color: neon.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(color: neon.withOpacity(0.4), blurRadius: 10),
                ],
              ),
              child: Icon(Icons.bolt_rounded, size: 16, color: neon),
            ),
            const SizedBox(width: 10),
            Text(
              "LYRA AI",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
                fontSize: 19,
                color: Colors.white,
                shadows: [
                  Shadow(color: neon.withOpacity(0.6), blurRadius: 16),
                ],
              ),
            ),
          ],
        ),
        actions: [
          _buildAppBarIconButton(
            icon: Icons.history_rounded,
            tooltip: "Chat History",
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
            },
          ),
          _buildAppBarIconButton(
            icon: Icons.psychology_rounded,
            tooltip: "Memory Digest",
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryScreen()));
            },
          ),
          _buildAppBarIconButton(
            icon: Icons.tune_rounded,
            tooltip: "Settings",
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Cyberpunk Dynamic Neon Backlight Blobs (No static images)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: neon.withOpacity(0.14),
                boxShadow: [
                  BoxShadow(color: neon.withOpacity(0.24), blurRadius: 120, spreadRadius: 60),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.secondaryColor.withOpacity(0.12),
                boxShadow: [
                  BoxShadow(color: theme.secondaryColor.withOpacity(0.2), blurRadius: 110, spreadRadius: 50),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // 1. Interactive Character / Persona Pill
                  CyberButton(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CharacterScreen()));
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    borderRadius: 30,
                    borderColor: neon.withOpacity(0.35),
                    color: const Color(0xFF10141E).withOpacity(0.65),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: neon.withOpacity(0.2),
                          child: Icon(
                            voice.character.gender == "female"
                                ? Icons.favorite_rounded
                                : Icons.security_rounded,
                            size: 14,
                            color: neon,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "${voice.character.name} (${voice.character.gender.toUpperCase()})",
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white54),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // 2. Central 3D Cyber AI Core & Audio Waves
                  CyberAiCore(
                    status: voice.status,
                    neonColor: neon,
                    onTap: () {
                      voice.toggleListening();
                    },
                    size: 260,
                  ),

                  const SizedBox(height: 28),

                  // 3. Status Badge Pill
                  StatusBadge(status: voice.status, neonColor: neon),

                  const SizedBox(height: 14),

                  // 4. Live Status Text or Live Transcript
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: voice.lastUserTranscript.isNotEmpty && voice.status == AssistantStatus.listening
                        ? Container(
                            key: const ValueKey("live_transcript"),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: neon.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: neon.withOpacity(0.3)),
                            ),
                            child: Text(
                              "“${voice.lastUserTranscript}”",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontStyle: FontStyle.italic,
                                color: neon,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : Text(
                            voice.currentStatusText,
                            key: ValueKey(voice.currentStatusText),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15.5,
                              color: Colors.white.withOpacity(0.88),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),

                  const Spacer(),

                  // 5. Cyberpunk Floating Action Dock
                  GlassContainer(
                    borderRadius: 24,
                    borderColor: neon.withOpacity(0.25),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavDockItem(
                          context: context,
                          icon: Icons.screen_search_desktop_rounded,
                          label: "Screen Agent",
                          accentColor: neon,
                          onTap: () async {
                            final active = await NativeChannel.isAccessibilityServiceActive();
                            if (!active) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Enable Lyra Accessibility Service in Android Settings.")),
                              );
                              NativeChannel.openAccessibilitySettings();
                              return;
                            }
                            await NativeChannel.requestScreenCapturePermission();
                            screenAgent.executeScreenTask("Open settings and check storage");
                          },
                        ),
                        _buildNavDockItem(
                          context: context,
                          icon: Icons.layers_outlined,
                          label: "HUD Overlay",
                          accentColor: Colors.white70,
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
                        _buildNavDockItem(
                          context: context,
                          icon: Icons.chat_bubble_outline_rounded,
                          label: "Chat History",
                          accentColor: Colors.white70,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return CyberButton(
      onTap: onTap,
      padding: const EdgeInsets.all(8),
      borderRadius: 12,
      child: Icon(icon, size: 20, color: Colors.white70),
    );
  }

  Widget _buildNavDockItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return CyberButton(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      borderRadius: 14,
      color: Colors.transparent,
      borderColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: accentColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: accentColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
