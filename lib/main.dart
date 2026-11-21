import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/theme_notifier.dart';
import 'core/theme/app_theme.dart';
import 'services/screen_agent_controller.dart';
import 'services/voice_conversation_controller.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final geminiKey = prefs.getString('lyra_gemini_api_key') ?? '';
  final openRouterKey = prefs.getString('lyra_openrouter_api_key') ?? '';

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(
          create: (_) => ScreenAgentController(openRouterApiKey: openRouterKey),
        ),
        ChangeNotifierProxyProvider<ScreenAgentController, VoiceConversationController>(
          create: (ctx) => VoiceConversationController(
            geminiApiKey: geminiKey,
            openRouterApiKey: openRouterKey,
            screenAgent: ctx.read<ScreenAgentController>(),
          ),
          update: (ctx, screenAgent, prev) => VoiceConversationController(
            geminiApiKey: geminiKey,
            openRouterApiKey: openRouterKey,
            screenAgent: screenAgent,
          ),
        ),
      ],
      child: const LyraApp(),
    ),
  );
}

class LyraApp extends StatelessWidget {
  const LyraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      title: 'Lyra AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getDarkTheme(themeNotifier.neonColor),
      home: const HomeScreen(),
    );
  }
}
