import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:vens_hub/core/utils/app_logger.dart';

// Define a generic exception for Analytics service errors
class AnalyticsServiceException implements Exception {
  final String message;
  final dynamic underlyingException;
  final StackTrace? stackTrace;

  AnalyticsServiceException(
    this.message, {
    this.underlyingException,
    this.stackTrace,
  });

  @override
  String toString() {
    String result = 'AnalyticsServiceException: $message';
    if (underlyingException != null) {
      result += '\nUnderlying exception: $underlyingException';
    }
    if (stackTrace != null) {
      result += '\nStack trace: $stackTrace';
    }
    return result;
  }
}

abstract class AnalyticsService {
  Future<void> initialize();

  Future<void> logScreenView(String screenName, {String? screenClassOverride});

  Future<void> logError(
    String errorDescription, {
    Object? error,
    StackTrace? stackTrace,
    bool fatal = false,
  });

  Future<void> logQuizCreated({
    required String quizId,
    required String quizName,
    String? subject,
    int? questionCount,
  });

  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  });

  // New enhanced analytics methods
  Future<void> logUserEngagement({
    required String feature,
    required Duration timeSpent,
    Map<String, Object>? additionalData,
  });

  Future<void> logUserJourney({
    required String fromScreen,
    required String toScreen,
    String? action,
    Map<String, Object>? context,
  });

  Future<void> logFeatureUsage({
    required String featureName,
    String? outcome,
    Map<String, Object>? metadata,
  });

  Future<void> logPerformanceMetric({
    required String metricName,
    required num value,
    String? unit,
    Map<String, Object>? tags,
  });

  Future<void> logSearchQuery({
    required String query,
    String? category,
    int? resultCount,
    bool? hasResults,
  });

  Future<void> logContentInteraction({
    required String contentType,
    required String contentId,
    required String action,
    Map<String, Object>? properties,
  });

  Future<void> logQuizPerformance({
    required String quizId,
    required int score,
    required int totalQuestions,
    required Duration completionTime,
    String? difficulty,
    String? subject,
  });

  Future<void> logAuthEvent({
    required String authAction,
    required String method,
    bool? success,
    String? errorCode,
  });

  Future<void> logAppLifecycle({
    required String event,
    Map<String, Object>? sessionData,
  });

  Future<void> setUserId({String? id});

  Future<void> setUserProperty({required String name, required String? value});

  Future<void> setAnalyticsCollectionEnabled(bool enabled);
}

class FirebaseAnalyticsService implements AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  bool _isInitialized = false;
  DateTime? _sessionStart;
  final Map<String, DateTime> _screenStartTimes = {};

  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.d('AnalyticsService is already initialized.');
      return;
    }
    try {
      // Native Firebase Analytics initialization happens with Firebase.initializeApp()
      // This method is for service readiness and potential future configurations.
      _isInitialized = true;
      _sessionStart = DateTime.now();

      // Log app initialization
      await logAppLifecycle(
        event: 'app_initialized',
        sessionData: {
          'timestamp': DateTime.now().toIso8601String(),
          'platform': defaultTargetPlatform.name,
        },
      );
    } catch (e, s) {
      _isInitialized = false;
      throw AnalyticsServiceException(
        'Failed to complete AnalyticsService initialization',
        underlyingException: e,
        stackTrace: s,
      );
    }
  }

  @override
  Future<void> logScreenView(
    String screenName, {
    String? screenClassOverride,
  }) async {
    if (!_isInitialized) return;

    try {
      // Track screen timing for previous screen
      final now = DateTime.now();
      _screenStartTimes.forEach((screen, startTime) {
        final timeSpent = now.difference(startTime);
        if (timeSpent.inSeconds > 1) {
          // Only log if spent more than 1 second
          logUserEngagement(
            feature: screen,
            timeSpent: timeSpent,
            additionalData: {'screen_type': 'view'},
          );
        }
      });

      // Clear previous screen times and set current
      _screenStartTimes.clear();
      _screenStartTimes[screenName] = now;

      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClassOverride ?? screenName,
      );

      // Enhanced screen view logging
      await _analytics.logEvent(
        name: 'screen_view_enhanced',
        parameters: {
          'screen_name': screenName,
          'screen_class': screenClassOverride ?? screenName,
          'timestamp': now.toIso8601String(),
          'session_duration':
              _sessionStart != null
                  ? now.difference(_sessionStart!).inSeconds
                  : 0,
        },
      );
    } catch (e) {
      AppLogger.w('Failed to log screen view to Analytics', error: e);
    }
  }

  @override
  Future<void> logError(
    String errorDescription, {
    Object? error,
    StackTrace? stackTrace,
    bool fatal = false,
  }) async {
    if (!_isInitialized) return;

    try {
      await _analytics.logEvent(
        name: 'app_error_enhanced',
        parameters: {
          'error_description': errorDescription,
          'error_type': error?.runtimeType.toString() ?? 'unknown',
          'is_fatal': fatal ? 'true' : 'false',
          'timestamp': DateTime.now().toIso8601String(),
          'stack_trace_hash': stackTrace?.toString().hashCode.toString() ?? '',
          if (error != null)
            'error_message': error.toString().substring(
              0,
              error.toString().length > 100 ? 100 : error.toString().length,
            ),
        },
      );
    } catch (e) {
      AppLogger.w('Failed to log error to Analytics', error: e);
    }
  }

  @override
  Future<void> logQuizCreated({
    required String quizId,
    required String quizName,
    String? subject,
    int? questionCount,
  }) async {
    if (!_isInitialized) return;

    try {
      await _analytics.logEvent(
        name: 'quiz_created',
        parameters: {
          'quiz_id': quizId,
          'quiz_name': quizName,
          'timestamp': DateTime.now().toIso8601String(),
          if (subject != null) 'quiz_subject': subject,
          if (questionCount != null) 'quiz_question_count': questionCount,
        },
      );
    } catch (e) {
      AppLogger.w('Failed to log quiz creation to Analytics', error: e);
    }
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!_isInitialized) return;
    try {
      // Add common parameters to all events
      final enhancedParams = <String, Object>{
        'timestamp': DateTime.now().toIso8601String(),
        'session_id':
            _sessionStart?.millisecondsSinceEpoch.toString() ?? 'unknown',
      };

      // Filter out null values from parameters to prevent Firebase errors
      if (parameters != null) {
        parameters.forEach((key, value) {
          enhancedParams[key] = value;
        });
      }

      await _analytics.logEvent(name: name, parameters: enhancedParams);
    } catch (e) {
      AppLogger.w('Failed to log event to Analytics', error: e);
    }
  }

  // Helper method to filter out null values from parameters
  Map<String, Object> _filterNullValues(Map<String, Object?> parameters) {
    final filtered = <String, Object>{};
    parameters.forEach((key, value) {
      if (value != null) {
        filtered[key] = value;
      }
    });
    return filtered;
  }

  @override
  Future<void> logUserEngagement({
    required String feature,
    required Duration timeSpent,
    Map<String, Object>? additionalData,
  }) async {
    if (!_isInitialized) return;

    try {
      final parameters = _filterNullValues({
        'feature_name': feature,
        'engagement_time_msec': timeSpent.inMilliseconds,
        'engagement_time_sec': timeSpent.inSeconds,
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalData,
      });

      await _analytics.logEvent(
        name: 'feature_engagement',
        parameters: parameters,
      );
    } catch (e) {
      AppLogger.w('Failed to log feature engagement to Analytics', error: e);
    }
  }

  @override
  Future<void> logUserJourney({
    required String fromScreen,
    required String toScreen,
    String? action,
    Map<String, Object>? context,
  }) async {
    if (!_isInitialized) return;

    try {
      await _analytics.logEvent(
        name: 'user_journey',
        parameters: {
          'from_screen': fromScreen,
          'to_screen': toScreen,
          'timestamp': DateTime.now().toIso8601String(),
          if (action != null) 'action': action,
          ...?context,
        },
      );
    } catch (e) {
      AppLogger.w('Failed to log user journey to Analytics', error: e);
    }
  }

  @override
  Future<void> logFeatureUsage({
    required String featureName,
    String? outcome,
    Map<String, Object>? metadata,
  }) async {
    if (!_isInitialized) return;

    try {
      await _analytics.logEvent(
        name: 'feature_usage',
        parameters: {
          'feature_name': featureName,
          'timestamp': DateTime.now().toIso8601String(),
          if (outcome != null) 'outcome': outcome,
          ...?metadata,
        },
      );
    } catch (e) {
      AppLogger.w('Failed to log feature usage to Analytics', error: e);
    }
  }

  @override
  Future<void> logPerformanceMetric({
    required String metricName,
    required num value,
    String? unit,
    Map<String, Object>? tags,
  }) async {
    if (!_isInitialized) return;

    try {
      final parameters = _filterNullValues({
        'metric_name': metricName,
        'metric_value': value,
        'timestamp': DateTime.now().toIso8601String(),
        'unit': unit,
        ...?tags,
      });

      await _analytics.logEvent(
        name: 'performance_metric',
        parameters: parameters,
      );
    } catch (e) {
      AppLogger.w('Failed to log performance metric to Analytics', error: e);
    }
  }

  @override
  Future<void> logSearchQuery({
    required String query,
    String? category,
    int? resultCount,
    bool? hasResults,
  }) async {
    if (!_isInitialized) return;

    try {
      await _analytics.logEvent(
        name: 'search_query',
        parameters: {
          'search_term': query.length > 100 ? query.substring(0, 100) : query,
          'query_length': query.length,
          'timestamp': DateTime.now().toIso8601String(),
          if (category != null) 'search_category': category,
          if (resultCount != null) 'result_count': resultCount,
          if (hasResults != null) 'has_results': hasResults,
        },
      );
    } catch (e) {
      AppLogger.w('Failed to log search query to Analytics', error: e);
    }
  }

  @override
  Future<void> logContentInteraction({
    required String contentType,
    required String contentId,
    required String action,
    Map<String, Object>? properties,
  }) async {
    if (!_isInitialized) return;

    try {
      await _analytics.logEvent(
        name: 'content_interaction',
        parameters: {
          'content_type': contentType,
          'content_id': contentId,
          'action': action,
          'timestamp': DateTime.now().toIso8601String(),
          ...?properties,
        },
      );
    } catch (e) {
      AppLogger.w('Failed to log content interaction to Analytics', error: e);
    }
  }

  @override
  Future<void> logQuizPerformance({
    required String quizId,
    required int score,
    required int totalQuestions,
    required Duration completionTime,
    String? difficulty,
    String? subject,
  }) async {
    if (!_isInitialized) return;

    try {
      final scorePercentage = (score / totalQuestions * 100).round();

      await _analytics.logEvent(
        name: 'quiz_completed',
        parameters: {
          'quiz_id': quizId,
          'score': score,
          'total_questions': totalQuestions,
          'score_percentage': scorePercentage,
          'completion_time_sec': completionTime.inSeconds,
          'completion_time_min': (completionTime.inSeconds / 60).round(),
          'timestamp': DateTime.now().toIso8601String(),
          if (difficulty != null) 'difficulty': difficulty,
          if (subject != null) 'subject': subject,
        },
      );
    } catch (e) {
      AppLogger.w('Failed to log quiz performance to Analytics', error: e);
    }
  }

  @override
  Future<void> logAuthEvent({
    required String authAction,
    required String method,
    bool? success,
    String? errorCode,
  }) async {
    if (!_isInitialized) return;

    try {
      await _analytics.logEvent(
        name: 'auth_event',
        parameters: {
          'auth_action': authAction,
          'auth_method': method,
          'timestamp': DateTime.now().toIso8601String(),
          if (success != null) 'success': success ? 'true' : 'false',
          if (errorCode != null) 'error_code': errorCode,
        },
      );
    } catch (e) {
      AppLogger.w('Failed to log auth event to Analytics', error: e);
    }
  }

  @override
  Future<void> logAppLifecycle({
    required String event,
    Map<String, Object>? sessionData,
  }) async {
    if (!_isInitialized) return;

    try {
      await _analytics.logEvent(
        name: 'app_lifecycle',
        parameters: {
          'lifecycle_event': event,
          'timestamp': DateTime.now().toIso8601String(),
          if (_sessionStart != null)
            'session_duration_sec':
                DateTime.now().difference(_sessionStart!).inSeconds,
          ...?sessionData,
        },
      );
    } catch (e) {
      AppLogger.w('Failed to log app lifecycle to Analytics', error: e);
    }
  }

  @override
  Future<void> setUserId({String? id}) async {
    if (!_isInitialized) return;
    try {
      await _analytics.setUserId(id: id);

      // Log user identification event
      if (id != null) {
        await logEvent(
          name: 'user_identified',
          parameters: {'user_id_set': 'true'},
        );
      }
    } catch (e) {
      AppLogger.w('Failed to set user ID in Analytics', error: e);
    }
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (!_isInitialized) return;
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      AppLogger.w('Failed to set user property in Analytics', error: e);
    }
  }

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
      if (enabled && !_isInitialized) {
        AppLogger.d(
          'Analytics collection enabled. Marking service as ready if not already.',
        );
        _isInitialized = true;
      }
    } catch (e, s) {
      throw AnalyticsServiceException(
        'Failed to set Analytics collection status',
        underlyingException: e,
        stackTrace: s,
      );
    }
  }
}
