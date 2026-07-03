import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service to handle notification permissions
class NotificationPermissionService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Check if notification permissions are granted
  static Future<bool> areNotificationsEnabled() async {
    try {
      // Prefer permission_handler as it handles Android 13+/iOS properly
      final status = await Permission.notification.status;
      if (status.isGranted || status.isLimited) return true;

      // Fallback to plugin API when status is undetermined or platform-specific
      final androidImpl =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (androidImpl != null) {
        final enabled = await androidImpl.areNotificationsEnabled();
        return enabled ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Request notification permissions directly
  static Future<bool> requestNotificationPermissions() async {
    try {
      // Prefer OS-level permission request
      final result = await Permission.notification.request();
      if (result.isGranted || result.isLimited) return true;

      // Fallback to plugin API
      final androidImpl =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        return granted ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Show permission dialog if needed
  static Future<bool> ensureNotificationPermissions() async {
    final enabled = await areNotificationsEnabled();

    if (!enabled) {
      return await requestNotificationPermissions();
    }

    return true;
  }

  /// Open app settings for notification permissions
  static Future<void> openNotificationSettings() async {
    // Open the app's OS settings page. This is the most reliable cross-platform
    // way to let users adjust notification permissions and channels.
    await openAppSettings();
  }
}
