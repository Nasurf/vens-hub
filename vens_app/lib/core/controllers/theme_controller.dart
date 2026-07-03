import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeController extends GetxController {
  static const String _themeKey = 'app_theme_mode';

  // Observable theme mode
  final Rx<ThemeMode> _themeMode = ThemeMode.dark.obs;
  ThemeMode get themeMode => _themeMode.value;
  Rx<ThemeMode> get themeModeObs => _themeMode;

  // Observable for current theme data
  final Rx<ThemeData> _currentLightTheme = AppThemes.greenLightTheme.obs;
  final Rx<ThemeData> _currentDarkTheme = AppThemes.greenDarkTheme.obs;

  ThemeData get currentLightTheme => _currentLightTheme.value;
  ThemeData get currentDarkTheme => _currentDarkTheme.value;

  // Check if current theme is dark
  bool get isDarkMode => _themeMode.value == ThemeMode.dark;

  @override
  void onInit() {
    super.onInit();
    _loadThemeFromPrefs();
  }

  // Load theme preference from SharedPreferences
  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeIndex = prefs.getInt(_themeKey);

      if (savedThemeIndex != null) {
        _themeMode.value = ThemeMode.values[savedThemeIndex];
      }
    } catch (e) {
      // If there's an error, default to dark mode
      _themeMode.value = ThemeMode.dark;
    }
  }

  // Save theme preference to SharedPreferences
  Future<void> _saveThemeToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, _themeMode.value.index);
    } catch (e) {
      // Handle error silently
    }
  }

  // Toggle between light and dark mode
  Future<void> toggleTheme() async {
    _themeMode.value =
        _themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;

    await _saveThemeToPrefs();

    // Force update the app theme
    Get.changeThemeMode(_themeMode.value);

    // Additional update to ensure all widgets rebuild
    update();
  }

  // Set specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode.value = mode;
    await _saveThemeToPrefs();
    Get.changeThemeMode(_themeMode.value);
  }

  // Get theme icon based on current mode
  IconData get themeIcon {
    return _themeMode.value == ThemeMode.dark
        ? Icons.light_mode
        : Icons.dark_mode;
  }

  // Get theme description
  String get themeDescription {
    return _themeMode.value == ThemeMode.dark
        ? 'Switch to Light Mode'
        : 'Switch to Dark Mode';
  }
}
