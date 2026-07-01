import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// A centralized logger for the application.
///
/// Usage:
/// ```dart
/// AppLogger.d('Debug message');
/// AppLogger.i('Info message');
/// AppLogger.w('Warning message');
/// AppLogger.e('Error message', error: exception, stackTrace: stack);
/// ```
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: kDebugMode ? Level.trace : Level.warning,
  );

  // Private constructor to prevent instantiation
  AppLogger._();

  /// Log a trace message (most verbose)
  static void t(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  /// Log a debug message
  static void d(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log an info message
  static void i(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log a warning message
  static void w(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log an error message
  static void e(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log a fatal/what-the-heck message
  static void f(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}
