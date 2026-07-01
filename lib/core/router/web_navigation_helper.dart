import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'routes.dart';

/// Web-specific navigation helper with URL management and SEO optimization
class WebNavigationHelper {
  /// Navigate with proper web URL handling
  static void navigateToPage(
    String route, {
    Map<String, String>? parameters,
    Object? arguments,
    bool replace = false,
  }) {
    if (kIsWeb) {
      // Build URL with parameters for web
      String finalRoute = route;
      if (parameters != null && parameters.isNotEmpty) {
        final queryParams = parameters.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
        finalRoute = '$route?$queryParams';
      }

      if (replace) {
        Get.offNamed(finalRoute, arguments: arguments);
      } else {
        Get.toNamed(finalRoute, arguments: arguments);
      }
    } else {
      // Mobile navigation
      if (replace) {
        Get.offNamed(route, arguments: arguments, parameters: parameters);
      } else {
        Get.toNamed(route, arguments: arguments, parameters: parameters);
      }
    }
  }

  /// Navigate to course with SEO-friendly URL
  static void navigateToCourse(String courseId, String courseName) {
    if (kIsWeb) {
      // Create SEO-friendly URL: /course/course-id?name=course-name
      final cleanName = courseName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .replaceAll(' ', '-');
      navigateToPage('/course/$courseId', parameters: {'name': cleanName});
    } else {
      Get.toNamed(AppRoutes.coursePage, arguments: courseId);
    }
  }

  /// Navigate to quiz with context
  static void navigateToQuiz(
    String quizType, {
    String? courseId,
    String? difficulty,
  }) {
    final parameters = <String, String>{};
    if (courseId != null) parameters['course'] = courseId;
    if (difficulty != null) parameters['difficulty'] = difficulty;

    String route;
    switch (quizType.toLowerCase()) {
      case 'theory':
        route = AppRoutes.theoryQuiz;
        break;
      case 'gap-fill':
        route = AppRoutes.gapFillQuiz;
        break;
      default:
        route = AppRoutes.quiz;
    }

    navigateToPage(route, parameters: parameters);
  }

  /// Get current page title for web
  static String getPageTitle(String route) {
    switch (route) {
      case AppRoutes.home:
        return 'Engineering Hub - Home';
      case AppRoutes.courses:
        return 'Engineering Courses - Engineering Hub';
      case AppRoutes.study:
        return 'Study Materials - Engineering Hub';
      case AppRoutes.schedule:
        return 'Class Schedule - Engineering Hub';
      case AppRoutes.profile:
        return 'Profile - Engineering Hub';
      case AppRoutes.signIn:
        return 'Sign In - Engineering Hub';
      case AppRoutes.signUp:
        return 'Register - Engineering Hub';
      case AppRoutes.quiz:
        return 'Quiz - Engineering Hub';
      case AppRoutes.theoryQuiz:
        return 'Theory Quiz - Engineering Hub';
      case AppRoutes.gapFillQuiz:
        return 'Gap Fill Quiz - Engineering Hub';
      default:
        return 'Engineering Hub - Educational Platform';
    }
  }

  /// Get breadcrumb navigation for current route
  static List<BreadcrumbItem> getBreadcrumbs(String route) {
    final breadcrumbs = <BreadcrumbItem>[
      BreadcrumbItem('Home', AppRoutes.home),
    ];

    switch (route) {
      case AppRoutes.courses:
        breadcrumbs.add(BreadcrumbItem('Courses', AppRoutes.courses));
        break;
      case AppRoutes.study:
        breadcrumbs.add(BreadcrumbItem('Study', AppRoutes.study));
        break;
      case AppRoutes.schedule:
        breadcrumbs.add(BreadcrumbItem('Schedule', AppRoutes.schedule));
        break;
      case AppRoutes.quiz:
        breadcrumbs.addAll([
          BreadcrumbItem('Study', AppRoutes.study),
          BreadcrumbItem('Quiz', AppRoutes.quiz),
        ]);
        break;
      case AppRoutes.theoryQuiz:
        breadcrumbs.addAll([
          BreadcrumbItem('Study', AppRoutes.study),
          BreadcrumbItem('Quiz', AppRoutes.quiz),
          BreadcrumbItem('Theory', AppRoutes.theoryQuiz),
        ]);
        break;
    }

    return breadcrumbs;
  }

  /// Check if route requires authentication
  static bool requiresAuth(String route) {
    const publicRoutes = [
      AppRoutes.splash,
      AppRoutes.onBoarding,
      AppRoutes.signIn,
      AppRoutes.signUp,
      AppRoutes.forgotPassword,
      AppRoutes.notFound,
    ];
    return !publicRoutes.contains(route);
  }

  /// Get meta description for SEO
  static String getMetaDescription(String route) {
    switch (route) {
      case AppRoutes.home:
        return 'Engineering Hub - Your comprehensive platform for engineering education, courses, quizzes, and study materials.';
      case AppRoutes.courses:
        return 'Explore engineering courses across multiple disciplines. Interactive learning with quizzes and study materials.';
      case AppRoutes.study:
        return 'Access study materials, upload PDFs, and get AI-powered assistance for your engineering studies.';
      case AppRoutes.quiz:
        return 'Test your knowledge with interactive quizzes designed for engineering students.';
      default:
        return 'Engineering Hub - Educational platform for engineering students with courses, quizzes, and study tools.';
    }
  }
}

/// Breadcrumb item for navigation
class BreadcrumbItem {
  final String title;
  final String route;

  BreadcrumbItem(this.title, this.route);
}
