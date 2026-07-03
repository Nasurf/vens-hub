// lib/core/config/environment_config.dart
// Loads secrets from assets/.env via flutter_dotenv.
// Never hardcode secrets here — they belong in .env.

import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentConfig {
  // Cloudflare R2 Configuration
  static String get r2AccessKey => dotenv.env['R2_ACCESS_KEY'] ?? '';
  static String get r2SecretKey => dotenv.env['R2_SECRET_KEY'] ?? '';
  static String get r2AccountId => dotenv.env['R2_ACCOUNT_ID'] ?? '';
  static String get r2BucketName => dotenv.env['R2_BUCKET_NAME'] ?? '';
  static String get r2PublicDomain => dotenv.env['R2_PUBLIC_DOMAIN'] ?? '';

  // Firebase Functions base URL
  static String get functionsBaseUrl =>
      dotenv.env['FUNCTIONS_BASE_URL'] ?? '';

  // API Keys
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // Vens Hub API (Cloudflare Worker)
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://vens-hub-api.nasurf25.workers.dev';

  // Web Push (Firebase Cloud Messaging VAPID key for Web)
  static String get webPushVapidKey => dotenv.env['WEB_PUSH_VAPID_KEY'] ?? '';

  // Environment
  static const bool isProduction = false;

  // App Info
  static const String appName = "Vens Hub";
  static const String appVersion = "1.0.0";
  static const String buildNumber = "1";

  // Legal & Privacy URLs
  static const String privacyPolicyUrl =
      "https://venshub.nuesaabuad.ng/privacy-policy";
  static const String termsOfServiceUrl =
      "https://nuesaabuad.ng/terms-of-service";
  static const String supportEmail = 'nuesatechteam@nuesaabuad.ng';
  static const String developedBy = "Nasurf";
  static const String developerWebsite = "https://venshub.nuesaabuad.ng/";

  // Feature flags
  static const bool enableAnalytics = true;
  static const bool enableCrashlytics = true;
  static const bool enablePerformanceMonitoring = true;
}
