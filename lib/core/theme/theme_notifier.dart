import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NeonPalette {
  cyan("Neon Cyan", Color(0xFF00F0FF), Color(0xFF007799)),
  violet("Cyber Violet", Color(0xFFB026FF), Color(0xFF660099)),
  emerald("Matrix Emerald", Color(0xFF00FF88), Color(0xFF007744)),
  amber("Solar Amber", Color(0xFFFF9900), Color(0xFF995500));

  final String label;
  final Color primary;
  final Color secondary;

  const NeonPalette(this.label, this.primary, this.secondary);
}

class ThemeNotifier extends ChangeNotifier {
  NeonPalette _palette = NeonPalette.cyan;

  NeonPalette get palette => _palette;
  Color get neonColor => _palette.primary;
  Color get secondaryColor => _palette.secondary;

  ThemeNotifier() {
    _loadFromPrefs();
  }

  void setPalette(NeonPalette newPalette) async {
    _palette = newPalette;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lyra_theme_palette', newPalette.name);
  }

  void _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('lyra_theme_palette');
    if (saved != null) {
      _palette = NeonPalette.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => NeonPalette.cyan,
      );
      notifyListeners();
    }
  }
}
