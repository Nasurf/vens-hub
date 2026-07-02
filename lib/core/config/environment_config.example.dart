// Copy this file to environment_config.dart and fill in your actual values.
// NEVER commit environment_config.dart to version control.
class EnvironmentConfig {
  // Cloudflare R2 Configuration
  static const String r2AccessKey = "YOUR_R2_ACCESS_KEY";
  static const String r2SecretKey = "YOUR_R2_SECRET_KEY";
  static const String r2AccountId = "YOUR_R2_ACCOUNT_ID";
  static const String r2BucketName = "YOUR_R2_BUCKET_NAME";
  static const String r2PublicDomain = "https://YOUR_R2_PUBLIC_DOMAIN";

  // Firebase Functions base URL
  static const String functionsBaseUrl = "https://us-central1-YOUR_PROJECT.cloudfunctions.net";

  // API Keys
  static const String geminiApiKey = "YOUR_GEMINI_API_KEY";

  // Web Push (Firebase Cloud Messaging VAPID key for Web)
  static const String webPushVapidKey = "YOUR_VAPID_KEY";

  // Environment
  static const bool isProduction = false;

  // App Info
  static const String appName = "Vens Hub";
  static const String appVersion = "1.0.0";
  static const String buildNumber = "1";

  // Legal & Privacy URLs
  static const String privacyPolicyUrl = "https://venshub.example.com/privacy-policy";
  static const String termsOfServiceUrl = "https://venshub.example.com/terms-of-service";
  static const String supportEmail = 'support@venshub.example.com';
  static const String developedBy = "Nasurf";
  static const String developerWebsite = "https://venshub.example.com/";

  // Feature flags
  static const bool enableAnalytics = true;
  static const bool enableCrashlytics = true;
  static const bool enablePerformanceMonitoring = true;
}
