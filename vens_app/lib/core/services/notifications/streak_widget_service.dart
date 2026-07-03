import 'dart:async';
import 'dart:developer' as developer;

import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/core/services/local_storage/streak_service.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:home_widget/home_widget.dart';

/// Service to manage the Android Streak widget
class StreakWidgetService {
  static const String _androidProvider = 'EngineeringHubStreakWidgetProvider';

  // If you name your iOS Widget extension target differently, update this:
  static const String _iosWidgetName = 'EngineeringHubStreakWidgets';
  Timer? _timer;
  bool _started = false;

  /// Update the streak widget with current streak data
  Future<void> updateStreakWidget() async {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      developer.log(
        'StreakWidgetService: Skipping update - unsupported platform',
      );
      return;
    }

    try {
      developer.log('StreakWidgetService: Starting widget update');
      final streakService = di.sl<StreakService>();
      final int streakCount = await streakService.getStreakCount();
      final bool completedToday = await streakService.hasCompletedToday();

      String motivationText;
      if (streakCount == 0) {
        motivationText = "Start your journey!";
      } else if (completedToday) {
        motivationText = "Keep it going!";
      } else {
        motivationText = "Don't break the chain!";
      }

      await _updateWidgetData(streakCount, motivationText);
      developer.log(
        'StreakWidgetService: Updated widget with streak count: $streakCount',
      );
    } catch (e, stackTrace) {
      developer.log(
        'StreakWidgetService: Error updating widget',
        error: e,
        stackTrace: stackTrace,
      );
      // Handle errors silently - widget will show default values
    }
  }

  Future<void> _updateWidgetData(int streakCount, String motivationText) async {
    try {
      developer.log(
        'StreakWidgetService: Saving widget data - count: $streakCount, motivation: $motivationText',
      );

      // Get weekly completion status
      final streakService = di.sl<StreakService>();
      final weeklyStatus = await streakService.getWeeklyCompletionStatus();

      // Persist streak data for the widget
      await HomeWidget.saveWidgetData<String>(
        'streak_count',
        streakCount.toString(),
      );
      await HomeWidget.saveWidgetData<String>(
        'streak_motivation',
        motivationText,
      );
      await HomeWidget.saveWidgetData<String>(
        'streak_longest',
        "Personal best: 7 days",
      );

      // Save weekly completion data
      await HomeWidget.saveWidgetData<bool>(
        'day_saturday',
        weeklyStatus['saturday'] ?? false,
      );
      await HomeWidget.saveWidgetData<bool>(
        'day_sunday',
        weeklyStatus['sunday'] ?? false,
      );
      await HomeWidget.saveWidgetData<bool>(
        'day_monday',
        weeklyStatus['monday'] ?? false,
      );
      await HomeWidget.saveWidgetData<bool>(
        'day_tuesday',
        weeklyStatus['tuesday'] ?? false,
      );
      await HomeWidget.saveWidgetData<bool>(
        'day_wednesday',
        weeklyStatus['wednesday'] ?? false,
      );
      await HomeWidget.saveWidgetData<bool>(
        'day_thursday',
        weeklyStatus['thursday'] ?? false,
      );
      await HomeWidget.saveWidgetData<bool>(
        'day_friday',
        weeklyStatus['friday'] ?? false,
      );

      developer.log(
        'StreakWidgetService: Data saved, triggering widget update for provider: $_androidProvider',
      );

      // Trigger a refresh
      await HomeWidget.updateWidget(
        name: _androidProvider,
        iOSName: _iosWidgetName,
      );

      developer.log(
        'StreakWidgetService: Widget update triggered successfully',
      );
    } catch (e, stackTrace) {
      developer.log(
        'StreakWidgetService: Error updating widget data',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  void startAutoUpdateIfPossible() {
    if (_started) {
      developer.log('StreakWidgetService: Auto-update already started');
      return;
    }

    try {
      _started = true;
      _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
        developer.log('StreakWidgetService: Periodic update triggered');
        updateStreakWidget();
      });
      developer.log('StreakWidgetService: Auto-update started successfully');
    } catch (e, stackTrace) {
      developer.log(
        'StreakWidgetService: Error starting auto-update',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Stop auto-update by cancelling timer
  void stopAutoUpdate() {
    if (!_started) {
      developer.log(
        'StreakWidgetService: Auto-update not started, nothing to stop',
      );
      return;
    }

    try {
      _timer?.cancel();
      _timer = null;
      _started = false;
      developer.log('StreakWidgetService: Auto-update stopped successfully');
    } catch (e, stackTrace) {
      developer.log(
        'StreakWidgetService: Error stopping auto-update',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Dispose of all resources
  void dispose() {
    developer.log('StreakWidgetService: Disposing service');
    stopAutoUpdate();
  }
}

// Optional background callback for Android (periodic widget updates)
@pragma('vm:entry-point')
Future<void> streakWidgetBackgroundCallback(Uri? data) async {
  // For now, do nothing heavy. Your app can fetch from cache/API if needed.
}
