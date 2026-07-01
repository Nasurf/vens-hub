import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart'; // For FlutterErrorDetails
import 'package:vens_hub/core/utils/app_logger.dart';

// Define a generic exception for Crashlytics service errors
class CrashlyticsServiceException implements Exception {
  final String message;
  final dynamic underlyingException;
  final StackTrace? stackTrace;

  CrashlyticsServiceException(
    this.message, {
    this.underlyingException,
    this.stackTrace,
  });

  @override
  String toString() {
    String result = 'CrashlyticsServiceException: $message';
    if (underlyingException != null) {
      result += '\nUnderlying exception: $underlyingException';
    }
    if (stackTrace != null) {
      result += '\nStack trace: $stackTrace';
    }
    return result;
  }
}

abstract class CrashlyticsService {
  Future<void> initialize();

  Future<void> recordFlutterError(FlutterErrorDetails flutterErrorDetails);

  Future<void> recordError(
    dynamic exception,
    StackTrace stack, {
    String? reason,
    Iterable<Object> information = const [],
    bool fatal = false,
  });

  Future<void> log(String message);

  Future<void> setUserIdentifier(String? userId);

  Future<void> setCrashlyticsCollectionEnabled(bool enabled);
}

class FirebaseCrashlyticsServiceImpl implements CrashlyticsService {
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.d('CrashlyticsService is already initialized.');
      return;
    }
    try {
      // Native Firebase Crashlytics initialization happens with Firebase.initializeApp()
      // This method is for service readiness and potential future configurations.
      // Example: await _crashlytics.setCrashlyticsCollectionEnabled(true);
      _isInitialized = true;
    } catch (e, s) {
      _isInitialized = false;
      throw CrashlyticsServiceException(
        'Failed to complete CrashlyticsService initialization',
        underlyingException: e,
        stackTrace: s,
      );
    }
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails flutterErrorDetails,
  ) async {
    if (!_isInitialized) return;
    try {
      await _crashlytics.recordFlutterError(flutterErrorDetails);
    } catch (e) {
      // Avoid infinite loop if Crashlytics itself fails
      AppLogger.w('Failed to record Flutter error to Crashlytics', error: e);
    }
  }

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace stack, {
    String? reason,
    Iterable<Object> information = const [],
    bool fatal = false,
  }) async {
    if (!_isInitialized) return;
    try {
      await _crashlytics.recordError(
        exception,
        stack,
        reason: reason,
        information: information,
        fatal: fatal,
      );
    } catch (e) {
      AppLogger.w('Failed to record generic error to Crashlytics', error: e);
    }
  }

  @override
  Future<void> log(String message) async {
    if (!_isInitialized) return;
    try {
      await _crashlytics.log(message);
    } catch (e) {
      AppLogger.w('Failed to log message to Crashlytics', error: e);
    }
  }

  @override
  Future<void> setUserIdentifier(String? userId) async {
    if (!_isInitialized) return;
    try {
      await _crashlytics.setUserIdentifier(userId ?? '');
    } catch (e) {
      AppLogger.w('Failed to set user identifier in Crashlytics', error: e);
    }
  }

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    // No direct _isInitialized check here as this might be called before/during init
    // by a consent manager, for example.
    try {
      await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
      if (enabled && !_isInitialized) {
        // If collection is enabled and service wasn't marked initialized,
        // consider it initialized for the purpose of its methods.
        // This might be relevant if initialize() itself doesn't enable collection.
        AppLogger.d(
          'Crashlytics collection enabled. Marking service as ready if not already.',
        );
        _isInitialized = true;
      }
    } catch (e, s) {
      throw CrashlyticsServiceException(
        'Failed to set Crashlytics collection status',
        underlyingException: e,
        stackTrace: s,
      );
    }
  }
}
