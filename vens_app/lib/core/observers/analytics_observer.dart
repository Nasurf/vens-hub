import 'package:flutter/widgets.dart';
import 'package:vens_hub/core/services/analytics/analytics_service.dart';
import 'package:vens_hub/core/di/injection_container.dart'; // For sl

class FirebaseAnalyticsObserver extends NavigatorObserver {
  String? _previousScreenName;

  void _sendScreenView(PageRoute<dynamic> route) {
    final String? screenName = route.settings.name;
    if (screenName != null && screenName.isNotEmpty) {
      sl<AnalyticsService>().logScreenView(screenName);

      // Track user journey if we have a previous screen
      if (_previousScreenName != null && _previousScreenName != screenName) {
        sl<AnalyticsService>().logUserJourney(
          fromScreen: _previousScreenName!,
          toScreen: screenName,
          action: 'navigation',
          context: {
            'route_arguments': route.settings.arguments?.toString() ?? 'none',
          },
        );
      }

      _previousScreenName = screenName;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute<dynamic>) {
      _sendScreenView(route);

      // Log navigation action
      sl<AnalyticsService>().logEvent(
        name: 'screen_navigation',
        parameters: {
          'action': 'push',
          'screen_name': route.settings.name ?? 'unknown',
          'previous_screen': previousRoute?.settings.name ?? 'none',
        },
      );
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute<dynamic>) {
      _sendScreenView(newRoute);

      // Log navigation action
      sl<AnalyticsService>().logEvent(
        name: 'screen_navigation',
        parameters: {
          'action': 'replace',
          'screen_name': newRoute.settings.name ?? 'unknown',
          'previous_screen': oldRoute?.settings.name ?? 'none',
        },
      );
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute<dynamic>) {
      _sendScreenView(previousRoute);

      // Log navigation action
      sl<AnalyticsService>().logEvent(
        name: 'screen_navigation',
        parameters: {
          'action': 'pop',
          'screen_name': previousRoute.settings.name ?? 'unknown',
          'popped_screen': route.settings.name ?? 'unknown',
        },
      );
    }
  }
}
