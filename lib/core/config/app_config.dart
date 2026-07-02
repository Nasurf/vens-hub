// lib/core/config/app_config.dart
import 'package:vens_hub/core/config/environment_config.dart';

class AppConfig {
  // R2 Configuration - using environment config
  static String get r2AccessKey => EnvironmentConfig.r2AccessKey;
  static String get r2SecretKey => EnvironmentConfig.r2SecretKey;
  static String get r2AccountId => EnvironmentConfig.r2AccountId;
  static String get r2BucketName => EnvironmentConfig.r2BucketName;
  static String get r2PublicDomain => EnvironmentConfig.r2PublicDomain;

  // Firebase Functions base URL
  static String get functionsBaseUrl => EnvironmentConfig.functionsBaseUrl;

  // Gemini AI
  String get geminiApiKey => EnvironmentConfig.geminiApiKey;

  final String defaultLanguage = 'en';
  final int maxQuizQuestions = 10;

  AppConfig();
}
