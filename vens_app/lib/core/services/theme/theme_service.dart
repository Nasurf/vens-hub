import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/core/services/analytics/analytics_service.dart';
import 'package:vens_hub/core/theme/app_theme.dart';
import 'package:vens_hub/core/theme/theme_enums.dart';
import 'package:vens_hub/core/utils/app_logger.dart';

class ThemeService extends GetxController {
  final _box = GetStorage();
  final _themeModeKey = 'themeMode';
  final _colorSchemeKey = 'colorScheme';

  // Reactive variables to track theme state
  final _currentThemeMode = AppThemeMode.light.obs;
  final _currentColorScheme = AppColorScheme.teal.obs;

  @override
  void onInit() {
    super.onInit();
    _currentThemeMode.value = getAppThemeModeInternal();
    _currentColorScheme.value = getColorScheme();
  }

  Future<ThemeService> init() async {
    await GetStorage.init();
    return this;
  }

  Rx<AppThemeMode> get themeModeObs => _currentThemeMode;
  Rx<AppColorScheme> get colorSchemeObs => _currentColorScheme;

  AppThemeMode getAppThemeModeInternal() {
    final String? themeModeString = _box.read(_themeModeKey);
    if (themeModeString != null) {
      return AppThemeMode.values.firstWhere(
        (e) => e.toString() == themeModeString,
        orElse: () => AppThemeMode.system,
      );
    }
    return AppThemeMode.light;
  }

  ThemeMode getAppThemeMode() {
    final AppThemeMode mode = _currentThemeMode.value;
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _box.write(_themeModeKey, mode.toString());
    _currentThemeMode.value = mode;
  }

  AppColorScheme getColorScheme() {
    final String? colorSchemeString = _box.read(_colorSchemeKey);
    if (colorSchemeString != null) {
      return AppColorScheme.values.firstWhere(
        (e) => e.toString() == colorSchemeString,
        orElse: () => AppColorScheme.green,
      );
    }
    return AppColorScheme.green;
  }

  Future<void> setColorScheme(AppColorScheme scheme) async {
    await _box.write(_colorSchemeKey, scheme.toString());
    _currentColorScheme.value = scheme;

    try {
      di.sl<AnalyticsService>().logEvent(
        name: 'color_scheme_selected',
        parameters: {'color_scheme': scheme.toString().split('.').last},
      );
    } catch (e) {
      AppLogger.e('Error logging color_scheme_selected event', error: e);
    }
  }

  List<AppColorScheme> getAvailableColorSchemes() {
    return AppColorScheme.values.toList();
  }

  ThemeData getLightThemeData() {
    return AppThemes.getThemeData(_currentColorScheme.value, Brightness.light);
  }

  ThemeData getDarkThemeData() {
    return AppThemes.getThemeData(_currentColorScheme.value, Brightness.dark);
  }

  ThemeData getResolvedThemeData() {
    final AppThemeMode currentMode = _currentThemeMode.value;
    final AppColorScheme currentScheme = _currentColorScheme.value;
    Brightness effectiveBrightness;

    switch (currentMode) {
      case AppThemeMode.light:
        effectiveBrightness = Brightness.light;
        break;
      case AppThemeMode.dark:
        effectiveBrightness = Brightness.dark;
        break;
      case AppThemeMode.system:
        effectiveBrightness =
            Get.isPlatformDarkMode ? Brightness.dark : Brightness.light;
        break;
    }
    return AppThemes.getThemeData(currentScheme, effectiveBrightness);
  }
}
