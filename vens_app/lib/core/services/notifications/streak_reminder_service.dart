import 'dart:async';
import 'dart:developer' as dev;
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';

/// Service to handle streak reminder notifications at 10 PM and 11 PM
class StreakReminderService {
  static const String _streakReminder10PMId = 'streak_reminder_10pm';
  static const String _streakReminder11PMId = 'streak_reminder_11pm';

  static const String _streakReminderChannelId = 'enghub_streak_reminders';
  static const String _streakReminderChannelName = 'Streak Reminders';
  static const String _streakReminderChannelDesc =
      'Urgent reminders to maintain your daily practice streak';

  bool _tzInitialized = false;
  bool _initialized = false;
  Future<void>? _initializing;
  Timer? _countdownTimer;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  HomeController? get _homeControllerOrNull =>
      Get.isRegistered<HomeController>() ? Get.find<HomeController>() : null;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    return _initializing ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    try {
      if (!kIsWeb) {
        await _ensureTimezone();
      }

      // Initialize notification channels
      if (!kIsWeb) {
        const AndroidInitializationSettings androidSettings =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const InitializationSettings initSettings = InitializationSettings(
          android: androidSettings,
        );
        await _local.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (
            NotificationResponse response,
          ) async {
            // Handle notification taps - navigate to quiz or streaks page
            if (response.payload == 'streak_10pm' ||
                response.payload == 'streak_11pm' ||
                response.payload == 'streak_10pm_recurring' ||
                response.payload == 'streak_11pm_recurring') {
              // Navigate to streaks page to show current streak status
              final controller = _homeControllerOrNull;
              controller?.navigateToPage(2); // Assuming streaks is page 2
            }
          },
        );
      }

      // Create Android channel
      final androidImpl =
          _local
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _streakReminderChannelId,
          _streakReminderChannelName,
          description: _streakReminderChannelDesc,
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('streak_reminder'),
        ),
      );

      _initialized = true;
    } catch (e) {
      dev.log('StreakReminderService initialization failed: $e');
    } finally {
      _initializing = null;
    }
  }

  Future<void> _ensureTimezone() async {
    if (_tzInitialized) return;
    try {
      tz.initializeTimeZones();
      try {
        final String localName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localName));
        dev.log('StreakReminderService timezone set to: $localName');
      } catch (e) {
        dev.log(
          'Failed to get local timezone for streak reminders, using UTC offset: $e',
        );
        final int offsetHours = DateTime.now().timeZoneOffset.inHours;
        final String approx =
            offsetHours >= 0
                ? 'Etc/GMT-$offsetHours'
                : 'Etc/GMT+${-offsetHours}';
        tz.setLocalLocation(tz.getLocation(approx));
        dev.log('StreakReminderService timezone set to approximation: $approx');
      }
    } catch (e) {
      dev.log('StreakReminderService timezone initialization failed: $e');
    } finally {
      _tzInitialized = true;
    }
  }

  /// Schedule both 10 PM and 11 PM streak reminder notifications for today
  Future<void> scheduleTodayStreakReminders() async {
    if (kIsWeb) return; // Not supported on web
    await initialize();

    // Cancel any existing reminders first
    await cancelTodayStreakReminders();

    // Only schedule if user hasn't completed today
    final homeController = _homeControllerOrNull;
    if (homeController == null) {
      dev.log('HomeController not ready; skipping streak reminders scheduling');
      return;
    }
    final bool hasCompleted = homeController.hasCompletedToday.value;
    if (hasCompleted) {
      dev.log(
        'User has already completed daily practice today, skipping streak reminders',
      );
      return;
    }

    await _ensureTimezone();

    // Schedule 10 PM reminder
    await _schedule10PMReminder();

    // Schedule 11 PM reminder
    await _schedule11PMReminder();
  }

  /// Schedule recurring daily streak reminder notifications (10 PM and 11 PM)
  /// These will repeat every day regardless of app usage
  Future<void> scheduleRecurringStreakReminders() async {
    if (kIsWeb) return; // Not supported on web
    await initialize();

    await _ensureTimezone();

    // Cancel existing recurring reminders first
    await cancelRecurringStreakReminders();

    // Schedule recurring 10 PM reminder
    await _scheduleRecurring10PMReminder();

    // Schedule recurring 11 PM reminder
    await _scheduleRecurring11PMReminder();

    dev.log('Scheduled recurring streak reminders for 10 PM and 11 PM daily');
  }

  /// Schedule the 10 PM urgent reminder notification
  Future<void> _schedule10PMReminder() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled10PM = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      22, // 10 PM
      0,
    );

    // If it's already past 10 PM, schedule for tomorrow
    if (scheduled10PM.isBefore(now)) {
      scheduled10PM = scheduled10PM.add(const Duration(days: 1));
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _streakReminderChannelId,
        _streakReminderChannelName,
        channelDescription: _streakReminderChannelDesc,
        styleInformation: const BigTextStyleInformation(
          '⚠️ URGENT: Do your daily quiz now to keep your streak alive!',
          contentTitle: 'Daily Practice Reminder',
        ),
        importance: Importance.high,
        priority: Priority.high,
        color: const Color(0xFFFF4444), // Red color
        icon: '@mipmap/ic_launcher',
        playSound: true,
      ),
    );

    await _local.zonedSchedule(
      _stableIdFrom(_streakReminder10PMId),
      'Daily Practice Reminder',
      '⚠️ URGENT: Do your daily quiz now to keep your streak alive!',
      scheduled10PM,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'streak_10pm',
    );

    dev.log('Scheduled 10 PM streak reminder for: $scheduled10PM');
  }

  /// Schedule the 11 PM countdown reminder notification
  Future<void> _schedule11PMReminder() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled11PM = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      23, // 11 PM
      0,
    );

    // If it's already past 11 PM, schedule for tomorrow
    if (scheduled11PM.isBefore(now)) {
      scheduled11PM = scheduled11PM.add(const Duration(days: 1));
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _streakReminderChannelId,
        _streakReminderChannelName,
        channelDescription: _streakReminderChannelDesc,
        styleInformation: const BigTextStyleInformation(
          '⏰ COUNTDOWN: Do a daily practice before midnight!',
          contentTitle: 'Do a daily practice',
        ),
        importance: Importance.high,
        priority: Priority.high,
        color: const Color(0xFFFF6B35), // Orange color for urgency
        icon: '@mipmap/ic_launcher',
        playSound: true,
      ),
    );

    await _local.zonedSchedule(
      _stableIdFrom(_streakReminder11PMId),
      'Do a daily practice',
      '⏰ COUNTDOWN: Do a daily practice before midnight!',
      scheduled11PM,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'streak_11pm',
    );

    dev.log('Scheduled 11 PM streak reminder for: $scheduled11PM');
  }

  /// Schedule recurring 10 PM reminder notification (repeats daily)
  Future<void> _scheduleRecurring10PMReminder() async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _streakReminderChannelId,
        _streakReminderChannelName,
        channelDescription: _streakReminderChannelDesc,
        styleInformation: const BigTextStyleInformation(
          '⚠️ URGENT: Do your daily quiz now to keep your streak alive!',
          contentTitle: 'Daily Practice Reminder',
        ),
        importance: Importance.high,
        priority: Priority.high,
        color: const Color(0xFFFF4444), // Red color
        icon: '@mipmap/ic_launcher',
        playSound: true,
      ),
    );

    await _local.zonedSchedule(
      _stableIdFrom('${_streakReminder10PMId}_recurring'),
      'Daily Practice Reminder',
      '⚠️ URGENT: Do your daily quiz now to keep your streak alive!',
      _getNext10PM(),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'streak_10pm_recurring',
    );

    dev.log('Scheduled recurring 10 PM streak reminder');
  }

  /// Schedule recurring 11 PM reminder notification (repeats daily)
  Future<void> _scheduleRecurring11PMReminder() async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _streakReminderChannelId,
        _streakReminderChannelName,
        channelDescription: _streakReminderChannelDesc,
        styleInformation: const BigTextStyleInformation(
          '⏰ COUNTDOWN: Do a daily practice before midnight!',
          contentTitle: 'Do a daily practice',
        ),
        importance: Importance.high,
        priority: Priority.high,
        color: const Color(0xFFFF6B35), // Orange color for urgency
        icon: '@mipmap/ic_launcher',
        playSound: true,
      ),
    );

    await _local.zonedSchedule(
      _stableIdFrom('${_streakReminder11PMId}_recurring'),
      'Do a daily practice',
      '⏰ COUNTDOWN: Do a daily practice before midnight!',
      _getNext11PM(),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'streak_11pm_recurring',
    );

    dev.log('Scheduled recurring 11 PM streak reminder');
  }

  /// Get the next 10 PM time (today if in the past, otherwise today)
  tz.TZDateTime _getNext10PM() {
    final now = tz.TZDateTime.now(tz.local);
    var next10PM = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      22, // 10 PM
      0,
    );

    // If it's already past 10 PM, schedule for tomorrow
    if (next10PM.isBefore(now)) {
      next10PM = next10PM.add(const Duration(days: 1));
    }

    return next10PM;
  }

  /// Get the next 11 PM time (today if in the past, otherwise today)
  tz.TZDateTime _getNext11PM() {
    final now = tz.TZDateTime.now(tz.local);
    var next11PM = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      23, // 11 PM
      0,
    );

    // If it's already past 11 PM, schedule for tomorrow
    if (next11PM.isBefore(now)) {
      next11PM = next11PM.add(const Duration(days: 1));
    }

    return next11PM;
  }

  /// Cancel today's streak reminders
  Future<void> cancelTodayStreakReminders() async {
    if (kIsWeb || !_initialized) return;

    try {
      await _local.cancel(_stableIdFrom(_streakReminder10PMId));
      await _local.cancel(_stableIdFrom(_streakReminder11PMId));
      _stopCountdownTimer();
      dev.log('Cancelled today\'s streak reminders');
    } catch (e) {
      dev.log('Failed to cancel streak reminders: $e');
    }
  }

  /// Cancel recurring streak reminders (all future daily notifications)
  Future<void> cancelRecurringStreakReminders() async {
    if (kIsWeb || !_initialized) return;

    try {
      await _local.cancel(_stableIdFrom('${_streakReminder10PMId}_recurring'));
      await _local.cancel(_stableIdFrom('${_streakReminder11PMId}_recurring'));
      dev.log('Cancelled recurring streak reminders');
    } catch (e) {
      dev.log('Failed to cancel recurring streak reminders: $e');
    }
  }

  /// Cancel only today's recurring streak reminders (keeps future days scheduled)
  Future<void> cancelTodaysRecurringStreakReminders() async {
    if (kIsWeb || !_initialized) return;

    try {
      // Get today's specific notification IDs and cancel only those
      final today = DateTime.now();
      final today10PMId = _stableIdFrom(
        '${_streakReminder10PMId}_${today.year}_${today.month}_${today.day}',
      );
      final today11PMId = _stableIdFrom(
        '${_streakReminder11PMId}_${today.year}_${today.month}_${today.day}',
      );

      await _local.cancel(today10PMId);
      await _local.cancel(today11PMId);
      _stopCountdownTimer();
      dev.log('Cancelled today\'s recurring streak reminders only');
    } catch (e) {
      dev.log('Failed to cancel today\'s recurring streak reminders: $e');
    }
  }

  /// Start a countdown timer for the 11 PM notification that updates every minute
  Future<void> startCountdownNotifications() async {
    if (kIsWeb) return;

    _stopCountdownTimer();

    // Start a timer that updates the 11 PM notification every minute with countdown
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await _updateCountdownNotification();
    });

    dev.log('Started countdown timer for streak reminders');
  }

  /// Stop the countdown timer
  void _stopCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    dev.log('Stopped countdown timer for streak reminders');
  }

  /// Update the 11 PM notification with current countdown
  Future<void> _updateCountdownNotification() async {
    if (kIsWeb || !_initialized) return;

    final now = DateTime.now();
    final midnight = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ); // Next midnight
    final timeUntilMidnight = midnight.difference(now);

    // Calculate hours and minutes
    final hours = timeUntilMidnight.inHours;
    final minutes = (timeUntilMidnight.inMinutes % 60);

    String countdownText;
    if (hours > 0) {
      countdownText =
          '$hours hour${hours > 1 ? 's' : ''} and $minutes minute${minutes > 1 ? 's' : ''}';
    } else {
      countdownText = '$minutes minute${minutes > 1 ? 's' : ''}';
    }

    final title = 'Do a daily practice';
    final body =
        '⏰ COUNTDOWN: Only $countdownText left to maintain your streak!';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _streakReminderChannelId,
        _streakReminderChannelName,
        channelDescription: _streakReminderChannelDesc,
        styleInformation: BigTextStyleInformation(body, contentTitle: title),
        importance: Importance.high,
        priority: Priority.high,
        color: const Color(0xFFFF6B35), // Orange color for urgency
        icon: '@mipmap/ic_launcher',
        playSound: true,
      ),
    );

    // Update the existing 11 PM notification
    await _local.zonedSchedule(
      _stableIdFrom(_streakReminder11PMId),
      title,
      body,
      tz.TZDateTime.from(
        DateTime.now().add(const Duration(seconds: 30)),
        tz.local,
      ), // Update in 30 seconds
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'streak_11pm_countdown',
    );

    dev.log('Updated countdown notification: $body');
  }

  /// Check if we should show streak reminders based on current time and completion status
  Future<bool> shouldShowStreakReminders() async {
    final now = DateTime.now();
    final hour = now.hour;

    // Only show between 7 PM and midnight
    if (hour < 19 || hour >= 24) {
      return false;
    }

    // Check if user has completed today
    final homeController = _homeControllerOrNull;
    if (homeController == null) {
      return false;
    }
    final hasCompleted = homeController.hasCompletedToday.value;
    return !hasCompleted;
  }

  /// Clean up resources
  void dispose() {
    _stopCountdownTimer();
  }

  int _stableIdFrom(String input) {
    // Simple deterministic hash into a 31-bit positive int
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = (hash * 31 + input.codeUnitAt(i)) & 0x7fffffff;
    }
    return hash;
  }

  /// Show immediate streak reminder notification (for testing)
  Future<void> showImmediateStreakReminder({bool isUrgent = false}) async {
    if (kIsWeb) return;
    await initialize();

    final title = isUrgent ? 'Daily Practice Reminder' : 'Do a daily practice';
    final body =
        isUrgent
            ? '⚠️ URGENT: Do your daily quiz now to keep your streak alive!'
            : '⏰ COUNTDOWN: Do a daily practice before midnight!';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _streakReminderChannelId,
        _streakReminderChannelName,
        channelDescription: _streakReminderChannelDesc,
        styleInformation: BigTextStyleInformation(body, contentTitle: title),
        importance: Importance.high,
        priority: Priority.high,
        color: isUrgent ? const Color(0xFFFF4444) : const Color(0xFFFF6B35),
        icon: '@mipmap/ic_launcher',
        playSound: true,
      ),
    );

    final int id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
    await _local.show(
      id,
      title,
      body,
      details,
      payload: isUrgent ? 'streak_urgent' : 'streak_countdown',
    );
    dev.log('Showed immediate streak reminder: $title - $body');
  }

  /// Test method to show both types of notifications immediately
  Future<void> testStreakReminders() async {
    dev.log('Testing streak reminder notifications...');

    // Show urgent notification
    await showImmediateStreakReminder(isUrgent: true);

    // Wait 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    // Show countdown notification
    await showImmediateStreakReminder(isUrgent: false);

    dev.log('Streak reminder test completed');
  }
}
