import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/theme_notifier.dart';
import '../../services/native_channel.dart';
import '../../services/voice_conversation_controller.dart';
import '../widgets/glass_container.dart';
import '../widgets/cyber_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _geminiKeyController = TextEditingController();
  final TextEditingController _openRouterKeyController = TextEditingController();
  bool _hasMicPerm = false;
  bool _hasOverlayPerm = false;
  bool _hasAccessibilityPerm = false;

  @override
  void initState() {
    super.initState();
    _loadKeys();
    _checkPermissions();
  }

  void _loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _geminiKeyController.text = prefs.getString('lyra_gemini_api_key') ?? '';
      _openRouterKeyController.text = prefs.getString('lyra_openrouter_api_key') ?? '';
    });
  }

  void _checkPermissions() async {
    final mic = await NativeChannel.checkMicrophonePermission();
    final overlay = await NativeChannel.checkOverlayPermission();
    final access = await NativeChannel.isAccessibilityServiceActive();
    if (mounted) {
      setState(() {
        _hasMicPerm = mic;
        _hasOverlayPerm = overlay;
        _hasAccessibilityPerm = access;
      });
    }
  }

  void _saveKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final gemini = _geminiKeyController.text.trim();
    final openRouter = _openRouterKeyController.text.trim();
    await prefs.setString('lyra_gemini_api_key', gemini);
    await prefs.setString('lyra_openrouter_api_key', openRouter);

    if (mounted) {
      Provider.of<VoiceConversationController>(context, listen: false)
          .updateApiKeys(geminiKey: gemini, openRouterKey: openRouter);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("API Keys saved successfully")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeNotifier>(context);
    final neon = theme.neonColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text("SETTINGS"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 1. Cyberpunk Theme Palette Switcher
          GlassContainer(
            borderColor: neon.withOpacity(0.35),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_rounded, size: 18, color: neon),
                    const SizedBox(width: 8),
                    const Text(
                      "NEON COLOR PALETTE",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: NeonPalette.values.map((p) {
                    final isSel = theme.palette == p;
                    return CyberButton(
                      onTap: () => theme.setPalette(p),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      borderRadius: 14,
                      borderColor: isSel ? p.primary : Colors.white12,
                      color: isSel ? p.primary.withOpacity(0.25) : const Color(0xFF131722),
                      isGlow: isSel,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 6,
                            backgroundColor: p.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            p.label,
                            style: TextStyle(
                              color: isSel ? Colors.white : Colors.white70,
                              fontSize: 12.5,
                              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 2. Cloud AI Keys (BYOK)
          GlassContainer(
            padding: const EdgeInsets.all(20),
            borderColor: Colors.white12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.vpn_key_rounded, size: 18, color: neon),
                    const SizedBox(width: 8),
                    const Text(
                      "CLOUD AI KEYS (BYOK)",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _geminiKeyController,
                  obscureText: true,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    labelText: "Google AI Studio API Key (Gemini 2.0 Audio)",
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13),
                    hintText: "AIzaSy...",
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: Icon(Icons.mic_none_rounded, color: neon, size: 20),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.25),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: neon, width: 1.8),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _openRouterKeyController,
                  obscureText: true,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    labelText: "OpenRouter API Key (Optional Brain)",
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13),
                    hintText: "sk-or-...",
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: Icon(Icons.memory_rounded, color: neon, size: 20),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.25),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: neon, width: 1.8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: CyberButton(
                    onTap: _saveKeys,
                    borderColor: neon,
                    isGlow: true,
                    color: neon.withOpacity(0.28),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        "SAVE CONFIGURATION",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(color: neon, blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 3. Android Permissions
          GlassContainer(
            padding: const EdgeInsets.all(20),
            borderColor: Colors.white12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security_rounded, size: 18, color: neon),
                    const SizedBox(width: 8),
                    const Text(
                      "ANDROID OS PERMISSIONS",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _buildPermissionRow(
                  icon: Icons.mic_rounded,
                  title: "Microphone Access",
                  subtitle: "Required for voice conversation & VAD",
                  isGranted: _hasMicPerm,
                  neon: neon,
                  onAction: () async {
                    final granted = await NativeChannel.requestMicrophonePermission();
                    setState(() => _hasMicPerm = granted);
                  },
                ),
                const Divider(height: 20, color: Colors.white10),

                _buildPermissionRow(
                  icon: Icons.accessibility_new_rounded,
                  title: "Accessibility Automation",
                  subtitle: "Required for Agent S3 clicks & scrolls",
                  isGranted: _hasAccessibilityPerm,
                  neon: neon,
                  onAction: () async {
                    await NativeChannel.openAccessibilitySettings();
                    _checkPermissions();
                  },
                ),
                const Divider(height: 20, color: Colors.white10),

                _buildPermissionRow(
                  icon: Icons.layers_rounded,
                  title: "Floating HUD Overlay",
                  subtitle: "Display spinning status ring & pill",
                  isGranted: _hasOverlayPerm,
                  neon: neon,
                  onAction: () async {
                    await NativeChannel.requestOverlayPermission();
                    _checkPermissions();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPermissionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required Color neon,
    required VoidCallback onAction,
  }) {
    return Row(
      children: [
        Icon(icon, size: 22, color: isGranted ? const Color(0xFF00FF9D) : neon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
        ),
        if (isGranted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF9D).withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00FF9D).withOpacity(0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, size: 12, color: Color(0xFF00FF9D)),
                SizedBox(width: 4),
                Text(
                  "ACTIVE",
                  style: TextStyle(color: Color(0xFF00FF9D), fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          )
        else
          CyberButton(
            onTap: onAction,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            borderRadius: 12,
            borderColor: neon,
            color: neon.withOpacity(0.18),
            child: Text(
              "GRANT",
              style: TextStyle(color: neon, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}
