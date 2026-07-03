import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:vens_hub/core/services/local_storage/streak_service.dart';
import 'package:vens_hub/core/di/injection_container.dart' as di;

/// Background service to handle notification filtering based on completion status
/// This ensures notifications are only shown when user hasn't completed daily practice
class NotificationBackgroundService {
  static const String _channelId = 'enghub_background_check';
  static const String _channelName = 'Background Check';
  static const String _channelDesc = 'Background completion status checks';

  bool _initialized = false;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _local.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      // Create Android channel for background checks
      final androidImpl =
          _local
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.low,
          playSound: false,
        ),
      );

      _initialized = true;
      dev.log('NotificationBackgroundService initialized');
    } catch (e) {
      dev.log('NotificationBackgroundService initialization failed: $e');
    }
  }

  /// Handle background notification responses to check completion status
  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    final payload = response.payload;

    // Check if this is a streak reminder that needs verification
    if (payload != null &&
        (payload.contains('streak_10pm') || payload.contains('streak_11pm'))) {
      // Check completion status before allowing notification to show
      final shouldShow = await _shouldShowStreakNotification();

      if (!shouldShow) {
        dev.log(
          'Background check: User has completed today, suppressing notification',
        );
        // Cancel the notification
        if (response.id != null) {
          await _local.cancel(response.id!);
        }
        return;
      }
    }
  }

  /// Check if user has completed today's practice
  Future<bool> _shouldShowStreakNotification() async {
    try {
      // Try to get HomeController if available
      if (Get.isRegistered<HomeController>()) {
        final controller = Get.find<HomeController>();
        return !controller.hasCompletedToday.value;
      }

      // Fallback: Check directly with StreakService
      if (di.sl.isRegistered<StreakService>()) {
        final streakService = di.sl<StreakService>();
        final hasCompleted = await streakService.hasCompletedToday();
        return !hasCompleted;
      }

      // Default to showing notification if we can't determine status
      dev.log(
        'Background check: Could not determine completion status, defaulting to show',
      );
      return true;
    } catch (e) {
      dev.log('Background check error: $e, defaulting to show notification');
      return true;
    }
  }

  /// Schedule a background check before streak reminders
  Future<void> scheduleBackgroundCheck({
    required DateTime notificationTime,
    required String notificationId,
  }) async {
    if (kIsWeb || !_initialized) return;

    // Schedule a silent notification 1 minute before the actual notification
    final checkTime = notificationTime.subtract(const Duration(minutes: 1));

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.low,
        priority: Priority.low,
        silent: true,
        playSound: false,
        enableVibration: false,
      ),
    );

    await _local.zonedSchedule(
      notificationId.hashCode + 1000, // Different ID to avoid conflicts
      'Background Check',
      'Checking completion status...',
      tz.TZDateTime.from(checkTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'background_check_$notificationId',
    );

    dev.log('Scheduled background check for $notificationId at $checkTime');
  }

  /// Clean up background checks
  Future<void> cancelBackgroundCheck(String notificationId) async {
    if (kIsWeb || !_initialized) return;

    try {
      await _local.cancel(notificationId.hashCode + 1000);
      dev.log('Cancelled background check for $notificationId');
    } catch (e) {
      dev.log('Failed to cancel background check: $e');
    }
  }

  /// Cancel all background checks
  Future<void> cancelAllBackgroundChecks() async {
    if (kIsWeb || !_initialized) return;

    try {
      await _local.cancelAll();
      dev.log('Cancelled all background checks');
    } catch (e) {
      dev.log('Failed to cancel all background checks: $e');
    }
  }
}
