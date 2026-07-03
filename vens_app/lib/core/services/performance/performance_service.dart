import 'package:firebase_performance/firebase_performance.dart';
import 'package:vens_hub/core/utils/app_logger.dart';

// Define a generic exception for Performance service errors
class PerformanceServiceException implements Exception {
  final String message;
  final dynamic underlyingException;
  final StackTrace? stackTrace;

  PerformanceServiceException(
    this.message, {
    this.underlyingException,
    this.stackTrace,
  });

  @override
  String toString() {
    String result = 'PerformanceServiceException: $message';
    if (underlyingException != null) {
      result += '\nUnderlying exception: $underlyingException';
    }
    if (stackTrace != null) {
      result += '\nStack trace: $stackTrace';
    }
    return result;
  }
}

abstract class PerformanceService {
  Future<void> initialize();

  Trace newTrace(String name);

  HttpMetric newHttpMetric(String url, HttpMethod httpMethod);

  Future<void> setPerformanceCollectionEnabled(bool enabled);
}

class FirebasePerformanceServiceImpl implements PerformanceService {
  final FirebasePerformance _performance = FirebasePerformance.instance;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.d('PerformanceService is already initialized.');
      return;
    }
    try {
      // Native Firebase Performance initialization happens with Firebase.initializeApp()
      // This method is for service readiness and potential future configurations.
      // Example: await _performance.setPerformanceCollectionEnabled(true);
      _isInitialized = true;
    } catch (e, s) {
      _isInitialized = false;
      throw PerformanceServiceException(
        'Failed to complete PerformanceService initialization',
        underlyingException: e,
        stackTrace: s,
      );
    }
  }

  @override
  Trace newTrace(String name) {
    if (!_isInitialized) {
      final disabledTrace = _performance.newTrace(name);
      // disabledTrace.start(); // Ensure it's "started" before stopping if API requires
      disabledTrace.stop();
      AppLogger.w(
        'PerformanceService not initialized when newTrace called for "$name". Returning a no-op trace.',
      );
      return disabledTrace;
    }
    return _performance.newTrace(name);
  }

  @override
  HttpMetric newHttpMetric(String url, HttpMethod httpMethod) {
    if (!_isInitialized) {
      final disabledHttpMetric = _performance.newHttpMetric(url, httpMethod);
      // disabledHttpMetric.start(); // Ensure it's "started" before stopping
      disabledHttpMetric.stop();
      AppLogger.w(
        'PerformanceService not initialized when newHttpMetric called for "$url". Returning a no-op HttpMetric.',
      );
      return disabledHttpMetric;
    }
    return _performance.newHttpMetric(url, httpMethod);
  }

  @override
  Future<void> setPerformanceCollectionEnabled(bool enabled) async {
    try {
      await _performance.setPerformanceCollectionEnabled(enabled);
      if (enabled && !_isInitialized) {
        AppLogger.d(
          'Performance collection enabled. Marking service as ready if not already.',
        );
        _isInitialized = true;
      }
    } catch (e, s) {
      throw PerformanceServiceException(
        'Failed to set Performance collection status',
        underlyingException: e,
        stackTrace: s,
      );
    }
  }
}
