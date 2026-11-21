import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_notifier.dart';
import '../../services/native_channel.dart';
import '../widgets/glass_container.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  String _stateCardText = "Loading memory core...";

  @override
  void initState() {
    super.initState();
    _refreshStateCard();
  }

  void _refreshStateCard() async {
    final card = await NativeChannel.compileStateCard();
    setState(() {
      _stateCardText = card.isEmpty ? "No stored memories yet. As you talk with Lyra, key facts, preferences, and promises will be remembered here." : card;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeNotifier>(context);
    final neon = theme.neonColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text("MEMORY CORE"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshStateCard,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassContainer(
            borderColor: neon.withOpacity(0.3),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.memory_rounded, color: neon, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      "Deterministic State Card",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _stateCardText,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAlignment.start,
              children: [
                const Text(
                  "Verification Gate (digest.js)",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  "All memories must pass strict quote verification against raw conversation turns in SQLite. Hallucinated or assistant-suggested facts are automatically rejected.",
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
