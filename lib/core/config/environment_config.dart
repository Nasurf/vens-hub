// lib/core/config/environment_config.dart
// This file contains environment-specific configuration
// In production, these values should be loaded from secure environment variables
// or a secure configuration service

class EnvironmentConfig {
  // Cloudflare R2 Configuration
  static const String r2AccessKey = "b4715ff2884eaecaf1f2f0a0b3653ec7";
  static const String r2SecretKey =
      "f4866d7c8e25c42c1415c44231cdeb86e423948504df3337dcfb5ed179b24f2b";
  static const String r2AccountId = "a06481b3ed7ddcf617cc917bf38d39d4";
  static const String r2BucketName = "users-docs";
  static const String r2PublicDomain = "https://files.nuesaabuad.ng";
  // Optional: Firebase Functions (or any HTTPS backend) base URL for presigned uploads on Web
  // Example: "https://us-central1-YOUR_PROJECT.cloudfunctions.net"
  static const String functionsBaseUrl =
      "https://us-central1-vens-hub-PLACEHOLDER.cloudfunctions.net";

  // API Keys
  static const String geminiApiKey = "AIzaSyCP6igfyX0FTLiWxN0os50nvN748gn6YiA";

  // Web Push (Firebase Cloud Messaging VAPID key for Web)
  // Replace with your actual public VAPID key from Firebase console > Cloud Messaging > Web configuration.
  // Safe to expose in client apps as it is a public key.
  static const String webPushVapidKey = ""; // TODO: set your Web Push VAPID key

  // Environment
  static const bool isProduction = false; // Set to true in production builds

  // Other configuration constants
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
  static const String developerWebsite =
      "https://venshub.nuesaabuad.ng/";

  // Feature flags
  static const bool enableAnalytics = true;
  static const bool enableCrashlytics = true;
  static const bool enablePerformanceMonitoring = true;
}
