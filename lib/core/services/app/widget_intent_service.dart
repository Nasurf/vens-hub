import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';

/// Service to handle widget click intents and navigate to appropriate sections
class WidgetIntentService {
  static const MethodChannel _channel = MethodChannel(
    'vens_hub/widget_intent',
  );

  /// Check if the app was launched from a widget click and handle navigation
  static Future<void> handleWidgetIntent() async {
    try {
      developer.log('WidgetIntentService: Checking for widget intent data');
      final Map<String, dynamic>? intentData = await _channel.invokeMapMethod(
        'getWidgetIntentData',
      );

      if (intentData != null && intentData['widget_click'] == true) {
        developer.log(
          'WidgetIntentService: Widget click detected, handling navigation',
        );
        await _handleWidgetNavigation(intentData);
      } else {
        developer.log('WidgetIntentService: No widget click intent found');
      }
    } on PlatformException catch (e, stackTrace) {
      developer.log(
        'WidgetIntentService: Platform error getting widget intent data',
        error: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      developer.log(
        'WidgetIntentService: Unexpected error getting widget intent data',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Handle navigation based on widget intent data
  static Future<void> _handleWidgetNavigation(
    Map<String, dynamic> intentData,
  ) async {
    try {
      // Wait a bit to ensure the app is fully loaded
      await Future.delayed(const Duration(milliseconds: 500));

      final String? targetPage = intentData['target_page'];
      final String? targetRoute = intentData['target_route'];
      final int? pageIndex = intentData['page_index'];

      developer.log(
        'WidgetIntentService: Navigating to target_page: $targetPage, target_route: $targetRoute, page_index: $pageIndex',
      );

      if (targetPage == 'schedule' || targetRoute == AppRoutes.schedule) {
        await _navigateToSchedulePage(pageIndex);
        return;
      }

      if (targetPage == 'streaks' || targetRoute == AppRoutes.streaks) {
        await _navigateToStreaksPage();
        return;
      }

      if (targetRoute != null && targetRoute.isNotEmpty) {
        await _navigateToNamedRoute(targetRoute);
      } else {
        developer.log(
          'WidgetIntentService: No valid navigation target found, navigating to home',
        );
        await _ensureMainShell();
      }
    } catch (e, stackTrace) {
      developer.log(
        'WidgetIntentService: Error handling widget navigation',
        error: e,
        stackTrace: stackTrace,
      );
      // Fallback to home screen on error
      try {
        await _ensureMainShell();
      } catch (fallbackError) {
        developer.log(
          'WidgetIntentService: Fallback navigation also failed',
          error: fallbackError,
        );
      }
    }
  }

  /// Navigate to the schedule/calendar page
  static Future<void> _navigateToSchedulePage(int? pageIndex) async {
    try {
      developer.log(
        'WidgetIntentService: Navigating to schedule page at index ${pageIndex ?? 1}',
      );
      await _ensureMainShell();

      // Try to get the HomeController and navigate to schedule page
      if (Get.isRegistered<HomeController>()) {
        final homeController = Get.find<HomeController>();
        // Schedule page is at index 1 in the PageView
        homeController.navigateToPage(pageIndex ?? 1);
        developer.log(
          'WidgetIntentService: Successfully navigated to schedule page',
        );
      } else {
        developer.log(
          'WidgetIntentService: HomeController not registered, waiting and retrying',
        );
        // If controller is not registered yet, wait and try again
        await Future.delayed(const Duration(milliseconds: 800));
        if (Get.isRegistered<HomeController>()) {
          final homeController = Get.find<HomeController>();
          homeController.navigateToPage(pageIndex ?? 1);
          developer.log(
            'WidgetIntentService: Successfully navigated to schedule page after retry',
          );
        } else {
          developer.log(
            'WidgetIntentService: HomeController still not registered after retry',
          );
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'WidgetIntentService: Error navigating to schedule page',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> _navigateToStreaksPage() async {
    try {
      developer.log('WidgetIntentService: Navigating to streaks page');
      await _ensureMainShell();
      if (Get.currentRoute == AppRoutes.streaks) {
        developer.log('WidgetIntentService: Already on streaks page');
        return;
      }
      await Get.toNamed(AppRoutes.streaks);
      developer.log(
        'WidgetIntentService: Successfully navigated to streaks page',
      );
    } catch (e, stackTrace) {
      developer.log(
        'WidgetIntentService: Error navigating to streaks page',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> _navigateToNamedRoute(String route) async {
    try {
      developer.log('WidgetIntentService: Navigating to route: $route');
      if (route == AppRoutes.main) {
        await _ensureMainShell();
        return;
      }
      if (Get.currentRoute == route) {
        developer.log('WidgetIntentService: Already on route: $route');
        return;
      }
      await Get.toNamed(route);
      developer.log(
        'WidgetIntentService: Successfully navigated to route: $route',
      );
    } catch (e, stackTrace) {
      developer.log(
        'WidgetIntentService: Error navigating to route: $route',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> _ensureMainShell() async {
    if (Get.currentRoute == AppRoutes.main) {
      developer.log('WidgetIntentService: Already on main shell');
      return;
    }
    try {
      developer.log('WidgetIntentService: Navigating to main shell');
      await Get.offAllNamed(AppRoutes.main);
      developer.log(
        'WidgetIntentService: Successfully navigated to main shell',
      );
    } catch (e, stackTrace) {
      developer.log(
        'WidgetIntentService: Error ensuring main shell',
        error: e,
        stackTrace: stackTrace,
      );
    }
    await Future.delayed(const Duration(milliseconds: 300));
  }

  /// Check for widget intent on app resume (when app comes to foreground)
  static Future<void> handleAppResume() async {
    try {
      developer.log(
        'WidgetIntentService: Checking for widget intent on app resume',
      );
      final Map<String, dynamic>? intentData = await _channel.invokeMapMethod(
        'getWidgetIntentData',
      );

      if (intentData != null && intentData['widget_click'] == true) {
        developer.log(
          'WidgetIntentService: Widget click detected on resume, handling navigation',
        );
        // Clear the intent data so it doesn't trigger again
        await _channel.invokeMethod('clearWidgetIntentData');
        await _handleWidgetNavigation(intentData);
      } else {
        developer.log('WidgetIntentService: No widget click intent on resume');
      }
    } on PlatformException catch (e, stackTrace) {
      developer.log(
        'WidgetIntentService: Platform error handling app resume widget intent',
        error: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      developer.log(
        'WidgetIntentService: Unexpected error handling app resume widget intent',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
