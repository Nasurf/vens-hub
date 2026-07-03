import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/core/services/notifications/notification_permission_service.dart';
import 'package:vens_hub/core/services/notifications/notification_prefs_service.dart';
import 'package:vens_hub/core/services/notifications/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';

/// Service to test notification functionality
class NotificationTestService {
  NotificationService get _notificationService => di.sl<NotificationService>();

  NotificationPrefsService get _prefsService =>
      Get.find<NotificationPrefsService>();

  /// Test immediate notification
  Future<void> testImmediateNotification() async {
    final hasPermission =
        await NotificationPermissionService.ensureNotificationPermissions();
    if (!hasPermission) {
      AppNotifier.warning(
        context: Get.context,
        title: 'Permission Required',
        message: 'Notification permissions are required to test notifications',
      );
      return;
    }

    await _notificationService.showTestNotification(
      title: 'Test Notification',
      body: 'This is a test notification from Engineering Hub',
    );
  }

  /// Test scheduled notification (5 seconds from now)
  Future<void> testScheduledNotification() async {
    await _notificationService.scheduleTestNotificationIn(
      const Duration(seconds: 5),
      title: 'Scheduled Test',
      body: 'This notification was scheduled 5 seconds ago',
    );
  }

  /// Test event reminder notification
  Future<void> testEventReminder() async {
    final eventStart = DateTime.now().add(const Duration(minutes: 1));
    await _notificationService.scheduleEventReminder(
      eventId: 'test-event-${DateTime.now().millisecondsSinceEpoch}',
      eventStart: eventStart,
      minutesBefore: 1,
      title: 'Test Event Reminder',
      description: 'Your test event starts in 1 minute',
    );
  }

  /// Check if notifications are enabled
  bool get notificationsEnabled => _prefsService.notificationsEnabled.value;

  /// Get notification permission status
  Future<bool> checkNotificationPermissions() async {
    return await NotificationPermissionService.areNotificationsEnabled();
  }

  /// Show notification settings dialog
  Future<void> showNotificationSettings() async {
    Get.dialog(
      AlertDialog(
        title: const Text('Notification Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => SwitchListTile(
                title: const Text('Enable Notifications'),
                subtitle: const Text('Receive reminders for your events'),
                value: _prefsService.notificationsEnabled.value,
                onChanged: (value) {
                  _prefsService.setNotificationsEnabled(value);
                },
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Test Immediate'),
              subtitle: const Text('Show a test notification now'),
              trailing: const Icon(Icons.play_arrow),
              onTap: () async {
                await testImmediateNotification();
                Get.back();
                AppNotifier.success(
                  context: Get.context,
                  title: 'Test Sent',
                  message: 'Check your notification panel',
                );
              },
            ),
            ListTile(
              title: const Text('Test Scheduled'),
              subtitle: const Text('Schedule a test notification in 5 seconds'),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                await testScheduledNotification();
                Get.back();
                AppNotifier.info(
                  context: Get.context,
                  title: 'Test Scheduled',
                  message: 'You should receive a notification in 5 seconds',
                );
              },
            ),
            ListTile(
              title: const Text('Check Permissions'),
              subtitle: const Text('Verify notification permissions'),
              trailing: const Icon(Icons.security),
              onTap: () async {
                final hasPermission = await checkNotificationPermissions();
                Get.back();
                AppNotifier.info(
                  context: Get.context,
                  title: 'Permission Status',
                  message:
                      hasPermission
                          ? 'Notifications are enabled'
                          : 'Notifications are disabled',
                );

                if (!hasPermission) {
                  await Future.delayed(const Duration(seconds: 2));
                  final shouldEnable =
                      await Get.dialog<bool>(
                        AlertDialog(
                          title: const Text('Enable Notifications?'),
                          content: const Text(
                            'Would you like to enable notifications now?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(result: false),
                              child: const Text('Not Now'),
                            ),
                            TextButton(
                              onPressed: () => Get.back(result: true),
                              child: const Text('Enable'),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (shouldEnable) {
                    await NotificationPermissionService.openNotificationSettings();
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Close')),
        ],
      ),
    );
  }
}
