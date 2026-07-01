// lib/core/config/app_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vens_hub/core/config/environment_config.dart';

class AppConfig {
  // R2 Configuration - using environment config
  static const String r2AccessKey = EnvironmentConfig.r2AccessKey;
  static const String r2SecretKey = EnvironmentConfig.r2SecretKey;
  static const String r2AccountId = EnvironmentConfig.r2AccountId;
  static const String r2BucketName = EnvironmentConfig.r2BucketName;
  static const String r2PublicDomain = EnvironmentConfig.r2PublicDomain;
  // Optional: Firebase Functions base URL. Can be provided via .env (FUNCTIONS_BASE_URL) or EnvironmentConfig fallback.
  static String get functionsBaseUrl => EnvironmentConfig.functionsBaseUrl;

  final String geminiApiKey =
      dotenv.env['GEMINI_API_KEY'] ?? EnvironmentConfig.geminiApiKey;
  final String defaultLanguage = 'en';
  final int maxQuizQuestions = 10; // Example from restructure_plan

  AppConfig();
}
