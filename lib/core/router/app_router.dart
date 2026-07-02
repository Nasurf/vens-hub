import 'package:vens_hub/presentation/screens/hub/hub_binding.dart';
import 'package:vens_hub/presentation/screens/hub/hub_page.mobile.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'app_transitions.dart';
import 'package:vens_hub/data/models/course_info.dart';
import 'package:vens_hub/presentation/screens/quiz/Review/review_page.dart';
import 'package:vens_hub/presentation/screens/quiz/DailyCongrats/daily_congrats_page.dart';
import 'package:vens_hub/presentation/screens/auth/forgot_password/forgot_password.dart';
import '../../presentation/screens/home/main_screen/main_screen.dart';
import 'routes.dart';
import 'package:vens_hub/presentation/screens/auth/signin/sign_in.dart';
import 'package:vens_hub/presentation/screens/auth/signup/signup.dart';
import 'package:vens_hub/presentation/screens/home/view_more.dart';
import 'package:vens_hub/presentation/screens/onboarding/onboarding_page.dart';
import 'package:vens_hub/presentation/screens/course/course_page.dart';
import 'package:vens_hub/presentation/screens/home/home_page/home_page.dart';
import 'package:vens_hub/presentation/screens/quiz/quiz_customization_page.dart';
import 'package:vens_hub/presentation/screens/quiz/MutipleChoice/multiple_choice_quiz_screen.dart';

import 'package:vens_hub/presentation/screens/common/search_page.dart';
import 'package:vens_hub/presentation/screens/splash/splash.dart';
import 'package:vens_hub/presentation/screens/profile/complete_profile_screen.dart';

import 'package:vens_hub/presentation/screens/quiz/TheoryQuiz/theory_quiz_screen.dart';
import 'package:vens_hub/presentation/screens/quiz/FillTheGap/gap_fill_quiz_screen.dart';
import 'package:vens_hub/presentation/screens/streaks/streaks_page.dart';
import 'package:vens_hub/presentation/screens/quiz/TheoryQuiz/theory_timer_setup.dart';

import 'package:vens_hub/presentation/screens/schedule/schedule_test_page.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navKey = Get.key;

  /// Web-optimized routes with SEO-friendly URLs and proper transitions
  static final List<GetPage<dynamic>> routes = [
    // Auth Routes - Clean URLs for web
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashScreen(),
      transition: kIsWeb ? Transition.fadeIn : Transition.native,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.main,
      page: () => const MainScreen(),
      transition: kIsWeb ? Transition.fadeIn : Transition.native,
    ),
    GetPage(
      name: AppRoutes.onBoarding,
      page: () => const OnboardingPage(),
      transition: kIsWeb ? Transition.rightToLeft : Transition.native,
    ),
    GetPage(
      name: AppRoutes.signUp,
      page: () => const SignupScreen(),
      transition: kIsWeb ? Transition.rightToLeft : Transition.native,
    ),
    GetPage(
      name: AppRoutes.signIn,
      page: () => SignIn(),
      transition: kIsWeb ? Transition.rightToLeft : Transition.native,
    ),
    GetPage(
      name: AppRoutes.forgotPassword,
      page: () => ForgotPasswordScreen(),
      transition: kIsWeb ? Transition.rightToLeft : Transition.native,
    ),
    GetPage(
      name: AppRoutes.resetPassword,
      page: () => ForgotPasswordScreen(),
      transition: kIsWeb ? Transition.rightToLeft : Transition.native,
    ),
    GetPage(
      name: AppRoutes.completeProfile,
      page: () => const CompleteProfileScreen(),
      transition: kIsWeb ? Transition.fadeIn : Transition.native,
    ),

    // Main Navigation Routes - SEO optimized
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
      transition: kIsWeb ? Transition.fadeIn : Transition.native,
    ),
    GetPage(
      name: AppRoutes.courses,
      page: () => const ViewMoreCoursesPage(),
      transition: kIsWeb ? Transition.fadeIn : Transition.native,
    ),
    GetPage(
      name: AppRoutes.search,
      page: () => const SearchPage(),
      transition: kIsWeb ? Transition.fadeIn : Transition.native,
    ),
    GetPage(
      name: AppRoutes.schedule,
      page: () {
        final homeController = Get.find<HomeController>();
        homeController.currentPage.value = 1;
        return const MainScreen();
      },
      transition: kIsWeb ? Transition.fadeIn : Transition.native,
    ),
    GetPage(
      name: AppRoutes.study,
      page: () {
        final homeController = Get.find<HomeController>();
        homeController.currentPage.value = 3;
        return const MainScreen();
      },
      transition: kIsWeb ? Transition.fadeIn : Transition.native,
    ),
    GetPage(
      name: AppRoutes.profile,
      page: () {
        final homeController = Get.find<HomeController>();
        homeController.currentPage.value = 4;
        return const MainScreen();
      },
      transition: kIsWeb ? Transition.fadeIn : Transition.native,
    ),
    GetPage(
      name: AppRoutes.streaks,
      page: () => const StreaksPage(),
      transition: kIsWeb ? Transition.fadeIn : Transition.native,
    ),
    GetPage(
      name: AppRoutes.hub,
      page: () => const MobileHubPage(),
      binding: HubBinding(),
      transition: kIsWeb ? Transition.fadeIn : Transition.native,
    ),

    // Dynamic Routes with Parameters
    GetPage(
      name: AppRoutes.coursePage,
      page: () => CoursePage(course: Get.arguments as CourseInfo),
      transition: kIsWeb ? Transition.rightToLeft : null,
      customTransition: kIsWeb ? null : SharedAxisVerticalTransition(),
      transitionDuration:
          kIsWeb
              ? const Duration(milliseconds: 300)
              : const Duration(milliseconds: 420),
    ),
    GetPage(
      name: AppRoutes.courseById,
      page: () => _buildCoursePageById(),
      transition: kIsWeb ? Transition.rightToLeft : null,
      customTransition: kIsWeb ? null : SharedAxisVerticalTransition(),
      transitionDuration:
          kIsWeb
              ? const Duration(milliseconds: 300)
              : const Duration(milliseconds: 420),
    ),

    // Quiz Routes - Organized hierarchy
    GetPage(
      name: AppRoutes.quizCustomization,
      page: () => const CustomizeQuizPage(),
      transition: kIsWeb ? Transition.rightToLeft : null,
      customTransition: kIsWeb ? null : SharedAxisVerticalTransition(),
      transitionDuration:
          kIsWeb
              ? const Duration(milliseconds: 300)
              : const Duration(milliseconds: 420),
    ),
    GetPage(
      name: AppRoutes.quiz,
      page: () => const MultipleChoiceQuizScreen(),
      transition: kIsWeb ? Transition.rightToLeft : Transition.native,
    ),
    GetPage(
      name: AppRoutes.theoryQuiz,
      page: () => const TheoryQuizScreen(),
      transition: kIsWeb ? Transition.rightToLeft : Transition.native,
    ),
    GetPage(
      name: AppRoutes.theoryTimerSetup,
      page: () => const TheoryTimerSetupScreen(),
      transition: kIsWeb ? Transition.rightToLeft : null,
      customTransition: kIsWeb ? null : SharedAxisVerticalTransition(),
      transitionDuration:
          kIsWeb
              ? const Duration(milliseconds: 300)
              : const Duration(milliseconds: 420),
    ),
    GetPage(
      name: AppRoutes.gapFillQuiz,
      page: () => const GapFillQuizScreen(),
      transition: kIsWeb ? Transition.rightToLeft : Transition.native,
    ),
    GetPage(
      name: AppRoutes.review,
      page: () => ReviewPage(data: Get.arguments as ReviewData),
      transition: kIsWeb ? Transition.rightToLeft : Transition.native,
    ),
    GetPage(
      name: AppRoutes.dailyCongrats,
      page: () {
        final args = Get.arguments as DailyCongratsArgs;
        return FirstDailyCongratsPage(
          previousStreakCount: args.previousStreakCount,
          currentStreakCount: args.currentStreakCount,
          courseTitle: args.courseTitle,
        );
      },
      transition: kIsWeb ? Transition.rightToLeft : Transition.native,
    ),

    // Debug Routes (only in debug mode)
    if (kDebugMode)
      GetPage(
        name: AppRoutes.scheduleTest,
        page: () => const ScheduleTestPage(),
        transition: Transition.fadeIn,
      ),

    // 404 Page for web
    GetPage(
      name: AppRoutes.notFound,
      page: () => const NotFoundPage(),
      transition: kIsWeb ? Transition.fadeIn : Transition.native,
    ),
  ];

  /// Build course page from URL parameters
  static Widget _buildCoursePageById() {
    final courseId = Get.parameters['id'];
    if (courseId == null) {
      return const NotFoundPage();
    }

    // You can fetch course data here or pass a placeholder
    final course = CourseInfo(
      id: courseId,
      title: 'Course $courseId',
      code: 'CS101',
      semester: const ['1'], // Updated to List
      description: 'Loading course details...',
      imageUrl: '',
      tags: const [],
      topics: const [],
      departmentCodes: const [],
    );

    return CoursePage(course: course);
  }

  /// Enhanced navigation with web support
  static Future<dynamic>? navigateTo(String name, [Object? arguments]) {
    if (kIsWeb) {
      // For web, use offNamed to replace current route in history
      return Get.offNamed(name, arguments: arguments);
    } else {
      return Get.toNamed(name, arguments: arguments);
    }
  }

  /// Navigate and replace current route
  static void navigateReplace(String name, [Object? arguments]) {
    Get.offNamed(name, arguments: arguments);
  }

  /// Navigate and clear all previous routes
  static void navigateAndClearAll(String name, [Object? arguments]) {
    Get.offAllNamed(name, arguments: arguments);
  }

  /// Go back with web support
  static void pop([Object? result]) {
    if (navKey.currentState?.canPop() ?? false) {
      Get.back(result: result);
    } else if (kIsWeb) {
      // On web, if can't pop, go to home
      navigateReplace(AppRoutes.main);
    }
  }

  /// Check if current route matches
  static bool isCurrentRoute(String route) {
    return Get.currentRoute == route;
  }

  /// Get current route name
  static String get currentRoute => Get.currentRoute;

  /// Web-specific: Update URL without navigation
  static void updateUrl(String url) {
    if (kIsWeb) {
      // This would require additional web routing package for full URL control
      // For now, use standard GetX navigation
    }
  }
}

/// 404 Not Found page for web
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          // Don't change the routing to home in this file ever
          onPressed: () => AppRouter.navigateReplace(AppRoutes.main),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '404 - Page Not Found',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'The page you are looking for does not exist.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => AppRouter.navigateReplace(AppRoutes.main),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
