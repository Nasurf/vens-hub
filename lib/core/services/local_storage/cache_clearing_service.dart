import 'dart:developer';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/core/services/notifications/notification_prefs_service.dart';
import 'package:vens_hub/core/services/notifications/notification_service.dart';
import 'package:vens_hub/core/services/theme/theme_service.dart';
import 'package:vens_hub/core/theme/theme_enums.dart';
import 'package:vens_hub/domain/study/repositories/study_repository.dart';

class CacheClearingService {
  /// Clear all user-related caches on logout
  Future<void> clearAllUserCaches() async {
    try {
      await _cancelNotifications();
      await _clearSharedPreferences();
      await _clearGetStorage();
      await _clearFileCache();
      await _clearStudyCache();
      await _resetNotificationPrefs();
      await _resetThemePrefs();
      log("CacheClearingService: All user caches cleared successfully");
    } catch (e) {
      log("CacheClearingService: Error clearing caches: $e");
    }
  }

  /// Clear SharedPreferences (user cache, streak data, etc.)
  Future<void> _clearSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    const prefixMatches = <String>[
      'cached_',
      'user_cache_',
      'streak_',
      'daily_cache_key_',
      'recent_quiz_',
      'notif',
      'notification_',
      'onboarding_',
      'schedule_',
      'app_theme_',
    ];

    const exactMatches = <String>{'app_theme_mode'};

    for (final key in prefs.getKeys()) {
      final shouldRemove =
          exactMatches.contains(key) ||
          prefixMatches.any((prefix) => key.startsWith(prefix));
      if (shouldRemove) {
        await prefs.remove(key);
      }
    }
  }

  /// Clear GetStorage while preserving device-level privacy toggles.
  Future<void> _clearGetStorage() async {
    final box = GetStorage();

    const keysToPreserve = <String>{
      'analytics_enabled',
      'crashlytics_enabled',
      'performance_enabled',
    };

    for (final key in box.getKeys().toList()) {
      if (!keysToPreserve.contains(key)) {
        await box.remove(key);
      }
    }
  }

  Future<void> _clearFileCache() async {
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}
  }

  Future<void> _clearStudyCache() async {
    try {
      if (di.sl.isRegistered<StudyRepository>()) {
        di.sl<StudyRepository>().clearCache();
      }
    } catch (_) {}
  }

  Future<void> _cancelNotifications() async {
    try {
      if (di.sl.isRegistered<NotificationService>()) {
        final ns = di.sl<NotificationService>();
        await ns.cancelDailyGeneralReminders();
        await ns.cancelTodayClassReminders();
        await ns.cancelAllNotifications();
      }
    } catch (_) {}
  }

  Future<void> _resetNotificationPrefs() async {
    try {
      if (Get.isRegistered<NotificationPrefsService>()) {
        final prefs = Get.find<NotificationPrefsService>();
        prefs.notificationsEnabled.value = true;
        prefs.dailyGeneralEnabled.value = true;
        prefs.classRemindersEnabled.value = true;
      }
    } catch (_) {}
  }

  Future<void> _resetThemePrefs() async {
    try {
      if (Get.isRegistered<ThemeService>()) {
        final theme = Get.find<ThemeService>();
        theme.themeModeObs.value = AppThemeMode.system;
        theme.colorSchemeObs.value = AppColorScheme.green;
        Get.changeThemeMode(theme.getAppThemeMode());
        Get.changeTheme(theme.getResolvedThemeData());
      }
    } catch (_) {}
  }
}
