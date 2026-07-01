import 'dart:developer' as dev;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:vens_hub/domain/repositories/schedule_repository.dart';
import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/core/services/local_storage/user_cache_service.dart';
import 'package:vens_hub/core/services/notifications/streak_reminder_service.dart';
import 'package:vens_hub/firebase_options.dart';

/// Centralized notifications manager for FCM and local notifications.
class NotificationService {
  NotificationService();

  static const String _generalChannelId = 'enghub_general';
  static const String _generalChannelName = 'General Reminders';
  static const String _generalChannelDesc =
      'Daily streak and engagement reminders';

  static const String _classChannelId = 'enghub_classes';
  static const String _classChannelName = 'Class Reminders';
  static const String _classChannelDesc = 'Reminders for upcoming classes';

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _tzInitialized = false;
  bool _initialized = false;
  Future<void>? _initializing;

  // Streak reminder service instance
  StreakReminderService? get _streakReminderService =>
      di.sl.isRegistered<StreakReminderService>()
          ? di.sl<StreakReminderService>()
          : null;

  Future<void> initialize() {
    if (_initialized) {
      return Future.value();
    }
    return _initializing ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    try {
      if (!kIsWeb) {
        await _ensureTimezone();
      }

      // On web, skip local notifications setup (plugin is not supported)
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
            // Handle notification taps if needed
          },
        );
      }

      // Create Android channels (skip on web)
      final androidImpl =
          _local
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _generalChannelId,
          _generalChannelName,
          description: _generalChannelDesc,
          importance: Importance.high,
        ),
      );
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _classChannelId,
          _classChannelName,
          description: _classChannelDesc,
          importance: Importance.high,
        ),
      );

      // Skip requesting exact alarm permission; use inexact scheduling instead.
      // On web, do NOT request push permission on startup; must be triggered by a user gesture.
      if (!kIsWeb) {
        dev.log('Requesting FCM notification permission (non-web platform)');
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      } else {
        dev.log(
          'Web detected: deferring push permission request to a user gesture.',
        );
      }

      // Obtain FCM token (required for push delivery)
      // On web, this should be done after explicit user consent, with a VAPID key.
      if (!kIsWeb) {
        try {
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            dev.log('Obtained FCM token on non-web platform');
          }
        } catch (e) {
          dev.log('Failed to obtain FCM token (non-web): $e');
        }
      }

      // Foreground message handler → show local notification (skip on web)
      if (!kIsWeb) {
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      }

      // Subscribe to department topic based on cached user profile
      await _subscribeToDepartmentTopicFromCache();

      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  /// Web-only helper to request browser push permissions and fetch an FCM token.
  /// Must be called from a user gesture (e.g., a button tap) on the web.
  /// Provide your Web Push certificate VAPID key via the `vapidKey` parameter.
  Future<bool> requestWebPushPermission({String? vapidKey}) async {
    if (!kIsWeb) {
      dev.log('requestWebPushPermission called on non-web platform; ignoring.');
      return false;
    }

    try {
      dev.log('Requesting browser notification permission (web)');
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // If permission is granted, attempt to get a token.
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        try {
          final token = await FirebaseMessaging.instance.getToken(
            vapidKey: vapidKey,
          );
          if (token != null) {
            dev.log('Obtained FCM token on web');
          }
          return true;
        } catch (e) {
          dev.log('Failed to obtain FCM token on web: $e');
          return false;
        }
      } else {
        dev.log(
          'Browser notification permission not granted on web: ${settings.authorizationStatus}',
        );
        return false;
      }
    } catch (e) {
      dev.log('Error requesting web push permission: $e');
      return false;
    }
  }

  Future<void> _ensureTimezone() async {
    if (_tzInitialized) return;
    try {
      tz.initializeTimeZones();
      try {
        final String localName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localName));
        dev.log('Timezone set to: $localName');
      } catch (e) {
        dev.log('Failed to get local timezone, using UTC offset: $e');
        // Fallback: approximate via UTC offset using Etc/GMT±X (note reversed signs in IANA)
        final int offsetHours = DateTime.now().timeZoneOffset.inHours;
        final String approx =
            offsetHours >= 0
                ? 'Etc/GMT-$offsetHours'
                : 'Etc/GMT+${-offsetHours}';
        tz.setLocalLocation(tz.getLocation(approx));
        dev.log('Timezone set to approximation: $approx');
      }
    } catch (e) {
      dev.log('Timezone initialization failed: $e');
      // If everything fails, continue; tz.local will default to UTC
    } finally {
      _tzInitialized = true;
    }
  }

  // Show a simple local notification for an incoming FCM message while app is in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    // final AndroidNotification? android = notification?.android; // Unused
    final int id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);

    final String title = notification?.title ?? 'Engineering Hub';
    final String body = notification?.body ?? (message.data['body'] ?? '');

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        (message.data['channel_id'] as String?) ?? _generalChannelId,
        (message.data['channel_name'] as String?) ?? _generalChannelName,
        channelDescription:
            (message.data['channel_desc'] as String?) ?? _generalChannelDesc,
        styleInformation: BigTextStyleInformation(
          body.isEmpty ? title : body,
          contentTitle: title,
        ),
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _local.show(
      id,
      title,
      body,
      details,
      payload: message.data['payload'] as String?,
    );
  }

  /// Schedule daily general reminders at 07:30, 15:00, 19:00 local time.
  Future<void> scheduleDailyGeneralReminders() async {
    if (kIsWeb) return; // Not supported on web
    await initialize();
    await _ensureTimezone();

    // Note: You can customize these messages to match the brand tone.
    // Sample general notifications (edit messages below to your liking):
    // - Morning (07:30): "Good morning! Ready for your daily lesson?"
    // - Afternoon (15:00): "Afternoon check-in: Have you practiced today?"
    // - Evening (19:00): "The Hub misses you! Come back and continue learning."

    await _scheduleDaily(
      id: 73001,
      hour: 7,
      minute: 30,
      title: 'Time to learn',
      body: 'Good morning! Ready for your daily lesson?',
      channelId: _generalChannelId,
      channelName: _generalChannelName,
      channelDesc: _generalChannelDesc,
    );

    await _scheduleDaily(
      id: 150001,
      hour: 15,
      minute: 0,
      title: 'Keep your streak alive',
      body: 'Afternoon check-in: Have you practiced today?',
      channelId: _generalChannelId,
      channelName: _generalChannelName,
      channelDesc: _generalChannelDesc,
    );

    await _scheduleDaily(
      id: 190001,
      hour: 19,
      minute: 0,
      title: 'Evening nudge',
      body: 'The Hub misses you! Come back and continue learning.',
      channelId: _generalChannelId,
      channelName: _generalChannelName,
      channelDesc: _generalChannelDesc,
    );
  }

  /// Optional: schedule department-specific sample nudges locally.
  ///
  /// By default, department-targeted pushes should be sent from the server via
  /// FCM topics (see _subscribeToDepartmentTopicFromCache()). If you also want
  /// on-device scheduled nudges per department, add your examples below.
  ///
  /// Example messages to customize:
  /// - EEE: "Explore the latest Electrical modules available now!"
  /// - COE: "New Computer Engineering practice sets are live!"
  ///
  /// Not called automatically to avoid duplicate nudges; call from your setup
  /// if you want these local samples.
  Future<void> scheduleDepartmentLocalSamples() async {
    if (kIsWeb) return; // Not supported on web
    await initialize();
    await _ensureTimezone();
    final cached = await di.sl<UserCacheService>().getCachedUserData();
    final dept = cached?.department;
    if (dept == null || dept.isEmpty) return;

    // Choose one consistent time for a department nudge (e.g., 12:00)
    String title = 'Department spotlight';
    String body = 'Check out new modules for your department.';
    switch (dept.toUpperCase()) {
      case 'EEE':
        body =
            'Explore the latest Electrical Engineering modules available now!';
        break;
      case 'COE':
        body = 'New Computer Engineering practice sets are live!';
        break;
      // Add more department-specific samples here
    }

    await _scheduleDaily(
      id: _stableIdFrom('dept-$dept-1200'),
      hour: 12,
      minute: 0,
      title: title,
      body: body,
      channelId: _generalChannelId,
      channelName: _generalChannelName,
      channelDesc: _generalChannelDesc,
    );
  }

  /// Schedule reminders for today’s classes, 30 minutes before each start time.
  Future<void> scheduleTodayClassReminders() async {
    if (kIsWeb) return; // Not supported on web
    await initialize();
    await _ensureTimezone();
    if (!Get.isRegistered<ScheduleRepository>()) return;
    final repo = Get.find<ScheduleRepository>();
    await repo.ensureInitialized();
    final now = DateTime.now();
    final classes = repo.getCombinedEventsForDay(now);

    for (final c in classes) {
      final DateTime eventStart = DateTime(
        now.year,
        now.month,
        now.day,
        c.startTime.hour,
        c.startTime.minute,
      );
      final DateTime remindAt = eventStart.subtract(
        const Duration(minutes: 30),
      );
      if (remindAt.isBefore(now)) {
        continue; // Skip past times
      }

      final String courseName =
          (c.course == null || c.course!.isEmpty) ? 'your class' : c.course!;
      final String venueName =
          (c.venue == null || c.venue!.isEmpty) ? '' : ' in ${c.venue}';
      final String title = 'Upcoming Class Reminder';
      final String body = '$courseName$venueName starts in 30 minutes.';

      final int id = _stableIdFrom(
        '${c.title}-${c.course}-${c.startTime.hour}:${c.startTime.minute}',
      );

      await _zonedOneShot(
        id: id,
        dateTime: remindAt,
        title: title,
        body: body,
        channelId: _classChannelId,
        channelName: _classChannelName,
        channelDesc: _classChannelDesc,
      );
    }
  }

  Future<void> cancelTodayClassReminders() async {
    if (kIsWeb) return;
    if (!_initialized) {
      // Nothing scheduled if initialization never finished
      return;
    }
    if (!Get.isRegistered<ScheduleRepository>()) return;
    final repo = Get.find<ScheduleRepository>();
    final now = DateTime.now();
    final classes = repo.getCombinedEventsForDay(now);
    for (final c in classes) {
      final int id = _stableIdFrom(
        '${c.title}-${c.course}-${c.startTime.hour}:${c.startTime.minute}',
      );
      await _local.cancel(id);
    }
  }

  /// Cancel all scheduled and active notifications (non-web only)
  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    if (!_initialized) {
      return;
    }
    try {
      await _local.cancelAll();
    } catch (_) {}
  }

  Future<void> cancelDailyGeneralReminders() async {
    if (kIsWeb) return;
    if (!_initialized) {
      return;
    }
    await _local.cancel(73001);
    await _local.cancel(150001);
    await _local.cancel(190001);
  }

  Future<void> _subscribeToDepartmentTopicFromCache() async {
    if (kIsWeb) {
      // Topic subscriptions are typically managed server-side for web; skip here.
      return;
    }
    try {
      final cached = await di.sl<UserCacheService>().getCachedUserData();
      final String? dept = cached?.department;
      if (dept != null && dept.isNotEmpty) {
        // Topic naming convention: dept_<code> (e.g., dept_eee)
        final topic = 'dept_${dept.toLowerCase()}';
        await FirebaseMessaging.instance.subscribeToTopic(topic);

        // Department-specific sample notifications can be sent via this topic.
        // Add your department-specific message examples in the server-side senders.
        // Example topic: dept_eee → "Explore the latest EEE modules available now!"
      }
    } catch (_) {
      // Ignore failures silently; will retry next launch
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDesc,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        styleInformation: BigTextStyleInformation(body, contentTitle: title),
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _local.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'general',
    );
  }

  Future<void> _zonedOneShot({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDesc,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var target = tz.TZDateTime(
      tz.local,
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
    );
    if (target.isBefore(now)) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        styleInformation: BigTextStyleInformation(body, contentTitle: title),
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _local.zonedSchedule(
      id,
      title,
      body,
      target,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'class',
    );
  }

  int _stableIdFrom(String input) {
    // Simple deterministic hash into a 31-bit positive int
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = (hash * 31 + input.codeUnitAt(i)) & 0x7fffffff;
    }
    return hash;
  }

  /// Public helper to schedule a one-shot local notification at a specific time.
  Future<void> scheduleOneShotLocal({
    required DateTime dateTime,
    required String title,
    required String body,
    String channelId = _generalChannelId,
    String channelName = _generalChannelName,
    String channelDesc = _generalChannelDesc,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await _ensureTimezone();
    final int id = _stableIdFrom(
      '$title-$body-${dateTime.millisecondsSinceEpoch}',
    );
    await _zonedOneShot(
      id: id,
      dateTime: dateTime,
      title: title,
      body: body,
      channelId: channelId,
      channelName: channelName,
      channelDesc: channelDesc,
    );
  }

  /// Show an immediate local notification to verify delivery on device.
  Future<void> showTestNotification({
    String title = 'Test Notification',
    String body = 'This is a test from Engineering Hub.',
  }) async {
    if (kIsWeb) return;
    dev.log('NotificationService ensure init before test notification');
    await initialize();

    dev.log('Showing test notification: $title - $body');

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _generalChannelId,
        _generalChannelName,
        channelDescription: _generalChannelDesc,
        styleInformation: BigTextStyleInformation(body, contentTitle: title),
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final int id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);

    try {
      await _local.show(id, title, body, details, payload: 'test');
      dev.log('Test notification shown successfully with ID: $id');
    } catch (e) {
      dev.log('Failed to show test notification: $e');
    }
  }

  /// Schedule a one-shot test notification after a delay.
  Future<void> scheduleTestNotificationIn(
    Duration delay, {
    String? title,
    String? body,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await _ensureTimezone();

    final DateTime when = DateTime.now().add(delay);
    final int id = _stableIdFrom('test-${when.millisecondsSinceEpoch}');

    dev.log(
      'Scheduling test notification for: $when (in ${delay.inSeconds} seconds)',
    );

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _generalChannelId,
        _generalChannelName,
        channelDescription: _generalChannelDesc,
        styleInformation: BigTextStyleInformation(
          body ??
              'This test notification was scheduled ${delay.inSeconds} seconds ago.',
          contentTitle: title ?? 'Scheduled Test',
        ),
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    try {
      final scheduledDate = tz.TZDateTime.from(when, tz.local);

      await _local.zonedSchedule(
        id,
        title ?? 'Scheduled Test',
        body ??
            'This test notification was scheduled ${delay.inSeconds} seconds ago.',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'test',
      );
      dev.log('Test notification scheduled successfully (local timezone)');
    } catch (e) {
      dev.log('Failed to schedule test notification: $e');
    }
  }

  // ===== User Event Reminder helpers =====
  int eventReminderId(String eventId, DateTime eventStart) {
    return _stableIdFrom('uev-$eventId-${eventStart.millisecondsSinceEpoch}');
  }

  int eventStartId(String eventId, DateTime eventStart) {
    return _stableIdFrom(
      'uevstart-$eventId-${eventStart.millisecondsSinceEpoch}',
    );
  }

  Future<void> scheduleEventReminder({
    required String eventId,
    required DateTime eventStart,
    required int minutesBefore,
    String? title,
    String? description,
  }) async {
    if (kIsWeb) return;
    await initialize();

    if (minutesBefore <= 0) return;
    DateTime remindAt = eventStart.subtract(Duration(minutes: minutesBefore));
    final now = DateTime.now();

    dev.log(
      'Scheduling reminder: eventId=$eventId, eventStart=$eventStart, minutesBefore=$minutesBefore',
    );

    if (remindAt.isBefore(now) && eventStart.isAfter(now)) {
      final seconds = eventStart.difference(now).inSeconds > 5 ? 5 : 1;
      remindAt = now.add(Duration(seconds: seconds));
      dev.log('Adjusted reminder time to: $remindAt');
    }
    if (remindAt.isBefore(now)) {
      dev.log('Event already passed, skipping notification');
      return;
    }

    final int id = eventReminderId(eventId, eventStart);

    final String notifTitle = title ?? 'Event Reminder';
    final String notifBody = description ?? 'Your event starts soon.';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _classChannelId,
        _classChannelName,
        channelDescription: _classChannelDesc,
        styleInformation: BigTextStyleInformation(
          notifBody,
          contentTitle: notifTitle,
        ),
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    try {
      await _local.zonedSchedule(
        id,
        notifTitle,
        notifBody,
        tz.TZDateTime.from(remindAt, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'event',
      );
      dev.log('Event reminder scheduled successfully');
    } catch (e) {
      dev.log('Failed to schedule event reminder: $e');
    }
  }

  Future<void> cancelEventReminder({
    required String eventId,
    required DateTime eventStart,
  }) async {
    if (kIsWeb || !_initialized) return;
    final int id = eventReminderId(eventId, eventStart);
    await _local.cancel(id);
  }

  Future<void> scheduleEventStartNotification({
    required String eventId,
    required DateTime eventStart,
    String? title,
    String? description,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await _ensureTimezone();
    final now = DateTime.now();
    var when =
        eventStart.isAfter(now)
            ? eventStart
            : now.add(const Duration(seconds: 1));
    final int id = eventStartId(eventId, eventStart);
    final String notifTitle = title ?? 'Event Started';
    final String notifBody = description ?? 'Your event is starting now.';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _classChannelId,
        _classChannelName,
        channelDescription: _classChannelDesc,
        styleInformation: BigTextStyleInformation(
          notifBody,
          contentTitle: notifTitle,
        ),
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _local.zonedSchedule(
      id,
      notifTitle,
      notifBody,
      tz.TZDateTime.from(when, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'event',
    );
  }

  Future<void> cancelEventStartNotification({
    required String eventId,
    required DateTime eventStart,
  }) async {
    if (kIsWeb || !_initialized) return;
    final int id = eventStartId(eventId, eventStart);
    await _local.cancel(id);
  }

  // ===== Streak Reminder Methods =====

  /// Schedule streak reminder notifications for today (10 PM and 11 PM)
  Future<void> scheduleStreakReminders() async {
    if (kIsWeb) return;
    await _streakReminderService?.scheduleTodayStreakReminders();
  }

  /// Schedule recurring daily streak reminder notifications
  Future<void> scheduleRecurringStreakReminders() async {
    if (kIsWeb) return;
    await _streakReminderService?.scheduleRecurringStreakReminders();
  }

  /// Cancel today's streak reminder notifications
  Future<void> cancelStreakReminders() async {
    if (kIsWeb) return;
    await _streakReminderService?.cancelTodayStreakReminders();
  }

  /// Cancel recurring streak reminder notifications
  Future<void> cancelRecurringStreakReminders() async {
    if (kIsWeb) return;
    await _streakReminderService?.cancelRecurringStreakReminders();
  }

  /// Cancel only today's recurring streak reminders (keeps future days scheduled)
  Future<void> cancelTodaysRecurringStreakReminders() async {
    if (kIsWeb) return;
    await _streakReminderService?.cancelTodaysRecurringStreakReminders();
  }

  /// Show immediate streak reminder notification (for testing)
  Future<void> showImmediateStreakReminder({bool isUrgent = false}) async {
    if (kIsWeb) return;
    await _streakReminderService?.showImmediateStreakReminder(
      isUrgent: isUrgent,
    );
  }

  /// Test streak reminder notifications (for debugging)
  Future<void> testStreakReminders() async {
    if (kIsWeb) return;

    try {
      if (_streakReminderService == null) {
        dev.log('StreakReminderService not available for testing');
        return;
      }

      await _streakReminderService!.testStreakReminders();
      dev.log('Streak reminder test completed successfully');
    } catch (e) {
      dev.log('Error testing streak reminders: $e');
      rethrow;
    }
  }
}

/// Background handler for FCM messages.
/// Ensures Firebase is initialized and shows a basic local notification.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final FlutterLocalNotificationsPlugin local =
      FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  await local.initialize(
    const InitializationSettings(android: androidSettings),
  );

  final String title = message.notification?.title ?? 'Engineering Hub';
  final String body =
      message.notification?.body ?? (message.data['body'] ?? '');

  final NotificationDetails details = NotificationDetails(
    android: AndroidNotificationDetails(
      NotificationService._generalChannelId,
      NotificationService._generalChannelName,
      channelDescription: NotificationService._generalChannelDesc,
      styleInformation: BigTextStyleInformation(body, contentTitle: title),
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  final int id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
  await local.show(id, title, body, details);
}
