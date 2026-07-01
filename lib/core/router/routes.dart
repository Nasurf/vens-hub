class AppRoutes {
  // Auth Routes - Clean URLs
  static const String splash = "/";
  static const String main = "/app";
  static const String onBoarding = "/welcome";
  static const String signIn = "/login";
  static const String signUp = "/register";
  static const String forgotPassword = "/forgot-password";
  static const String resetPassword = "/reset-password";
  static const String completeProfile = "/complete-profile";
  static const String emailVerification = "/verify-email";
  // Public landing URL for verification links
  static const String verify = "/verify";

  // Main Navigation - SEO Friendly
  static const String home = "/home";
  static const String courses = "/courses";
  static const String search = "/search";
  static const String schedule = "/schedule";
  static const String study = "/study";
  static const String profile = "/profile";
  static const String streaks = "/streaks";

  // Dynamic Routes with Parameters
  static const String coursePage = "/course";
  static const String courseById = "/course/:id";

  // Quiz Routes - Hierarchical
  static const String quizCustomization = "/quiz/customize";
  static const String quiz = "/quiz/start";
  static const String theoryQuiz = "/quiz/theory";
  static const String theoryTimerSetup = "/quiz/theory/setup";
  static const String gapFillQuiz = "/quiz/gap-fill";
  static const String review = "/quiz/review";
  static const String dailyCongrats = "/quiz/congrats";

  // Study Routes
  static const String theoryQuestions = "/study/theory";
  static const String problemScreen = "/study/problems";

  // Other Pages
  static const String notFound = "/404";
  static const String hub = "/hub";

  // Debug Routes (only available in debug mode)
  static const String scheduleTest = "/debug/schedule-test";

  // Legacy routes (keep for backward compatibility)
  @Deprecated('Use AppRoutes.courses instead')
  static const String viewMoreCourses = "/courses";
  @Deprecated('Use AppRoutes.forgotPassword instead - typo fixed')
  static const String forgotPassowrd = "/forgot-password";
}
