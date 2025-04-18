import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

class ThemeManager {
  static const String _themeKey = 'theme';

  // Lädt das Theme aus SharedPreferences
  static Future<String> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'Dark'; // Standardwert: 'Dark'
  }

  // Speichert das ausgewählte Theme in SharedPreferences
  static Future<void> saveTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_themeKey, theme); // Speichert das ausgewählte Theme
  }

  // Gibt den entsprechenden ThemeMode zurück
  static ThemeMode getThemeMode(String theme) {
    switch (theme) {
      case 'Light':
        return ThemeMode.light;
      case 'Dark':
        return ThemeMode.dark;
      case 'System':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }
}