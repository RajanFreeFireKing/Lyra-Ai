import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/theme_notifier.dart';
import '../../services/native_channel.dart';
import '../widgets/glass_container.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _geminiKeyController = TextEditingController();
  final TextEditingController _openRouterKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  void _loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _geminiKeyController.text = prefs.getString('lyra_gemini_api_key') ?? '';
      _openRouterKeyController.text = prefs.getString('lyra_openrouter_api_key') ?? '';
    });
  }

  void _saveKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lyra_gemini_api_key', _geminiKeyController.text.trim());
    await prefs.setString('lyra_openrouter_api_key', _openRouterKeyController.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("API Keys saved successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeNotifier>(context);
    final neon = theme.neonColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text("SETTINGS"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Theme Palette Switcher
          GlassContainer(
            borderColor: neon.withOpacity(0.3),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "NEON COLOR PALETTE",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: NeonPalette.values.map((p) {
                    final isSel = theme.palette == p;
                    return GestureDetector(
                      onTap: () => theme.setPalette(p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: p.primary.withOpacity(isSel ? 0.25 : 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel ? p.primary : Colors.white24,
                            width: isSel ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 6, backgroundColor: p.primary),
                            const SizedBox(width: 8),
                            Text(
                              p.label,
                              style: TextStyle(
                                color: isSel ? Colors.white : Colors.white70,
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // API Keys (BYOK)
          GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "CLOUD AI KEYS (BYOK)",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _geminiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Google AI Studio API Key (STT & TTS)",
                    hintText: "AIzaSy...",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _openRouterKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "OpenRouter API Key (Brain & Agent S3)",
                    hintText: "sk-or-...",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _saveKeys,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: neon.withOpacity(0.3),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Save API Keys"),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Android Permissions & Services
          GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "ANDROID OS PERMISSIONS",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.accessibility_new_rounded, color: neon),
                  title: const Text("Accessibility Automation", style: TextStyle(fontSize: 14)),
                  subtitle: const Text("Required for clicks and scrolls", style: TextStyle(fontSize: 11)),
                  trailing: TextButton(
                    onPressed: () => NativeChannel.openAccessibilitySettings(),
                    child: const Text("Configure"),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.layers_rounded, color: neon),
                  title: const Text("Floating HUD Overlay", style: TextStyle(fontSize: 14)),
                  subtitle: const Text("Display spinning ring and status pill", style: TextStyle(fontSize: 11)),
                  trailing: TextButton(
                    onPressed: () => NativeChannel.requestOverlayPermission(),
                    child: const Text("Grant"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
