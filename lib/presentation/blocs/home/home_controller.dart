import 'dart:developer';
import 'package:get/get.dart';
import 'package:vens_hub/data/models/user_model.dart';
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart';
import 'package:vens_hub/core/services/local_storage/user_cache_service.dart';
import 'package:vens_hub/core/services/local_storage/course_cache_service.dart';
import 'package:vens_hub/core/services/local_storage/streak_service.dart';
import 'package:vens_hub/core/services/local_storage/daily_cache_service.dart';
import 'package:vens_hub/core/services/local_storage/cache_clearing_service.dart';
import 'package:vens_hub/core/services/notifications/notification_service.dart';
import 'package:vens_hub/core/services/notifications/streak_widget_service.dart';
import '../../../core/di/injection_container.dart' as di;

class HomeController extends GetxController {
  // Instance of AuthenticationRepository to fetch user data
  final _authRepo = di.sl<AuthRepository>();
  final _userCacheService = di.sl<UserCacheService>();
  final _streakService = di.sl<StreakService>();
  final _dailyCacheService = di.sl<DailyCacheService>();
  final _cacheClearingService = di.sl<CacheClearingService>();
  final _notificationService = di.sl<NotificationService>();
  final _streakWidgetService = StreakWidgetService();

  static const String _dailyUserCacheKey = 'home_user_profile';

  static const int streakCalendarDays = 31;
  static const int streakHistoryWindowDays = 120;

  // Navigation state
  final RxInt currentPage = 0.obs;

  // Callback for external page navigation (e.g., from PageController)
  Function(int)? _pageNavigationCallback;

  // User state
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoading = true.obs;
  // Streak state
  final RxInt streakCount = 0.obs;
  final RxBool hasCompletedToday = false.obs;
  final RxList<DateTime> completionHistory = <DateTime>[].obs;
  final RxBool isHistoryLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _fetchCurrentUserDetails();
  }

  void changePage(int page) {
    currentPage.value = page;
    log("HomeController: Page changed to $page");
  }

  /// Set the page navigation callback (usually from MobileMainScreen)
  void setPageNavigationCallback(Function(int)? callback) {
    _pageNavigationCallback = callback;
    log("HomeController: Page navigation callback set");
  }

  /// Navigate to a specific page using both state update and callback
  void navigateToPage(int page) {
    currentPage.value = page;
    _pageNavigationCallback?.call(page);
    log("HomeController: Navigated to page $page");
  }

  Future<void> _fetchCurrentUserDetails({bool forceRefresh = false}) async {
    try {
      log("HomeController: Fetching current user details...");
      final shouldRefresh =
          forceRefresh ||
          await _dailyCacheService.shouldRefresh(_dailyUserCacheKey);

      final cachedUser = await _userCacheService.getCachedUserData();
      final hasCached = cachedUser != null;

      if (hasCached) {
        currentUser.value = cachedUser;
        log(
          "HomeController: Using cached user data for ${cachedUser.firstName} ${cachedUser.lastName}",
        );
        await _initializeStreaks();
      }

      if (!hasCached || forceRefresh) {
        isLoading.value = true;
      }

      if (!shouldRefresh && hasCached && !forceRefresh) {
        isLoading.value = false;
        return;
      }

      final data = await _authRepo.getCurrentUser();
      await data.fold(
        (failure) async {
          log(
            "HomeController: Error fetching user details: ${failure.message}",
          );
        },
        (user) async {
          if (user != null) {
            currentUser.value = user;
            await _userCacheService.cacheUserData(user);
            await _dailyCacheService.markRefreshed(_dailyUserCacheKey);

            log(
              "HomeController: User details loaded from Firebase: ${user.firstName} ${user.lastName}",
            );
            await _initializeStreaks();
          } else {
            log(
              "HomeController: No current user found or error fetching details.",
            );
            await _initializeStreaks();
          }
        },
      );
    } catch (e) {
      log("HomeController: Error fetching user details: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshUserDetails({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await _userCacheService.clearCachedUserData();
      await _dailyCacheService.invalidate(_dailyUserCacheKey);
    }
    await _fetchCurrentUserDetails(forceRefresh: forceRefresh);
  }

  Future<void> _initializeStreaks() async {
    // Ensure the streak is synced for today (may reset if missed days)
    await _streakService.syncForToday();
    streakCount.value = await _streakService.getStreakCount();
    hasCompletedToday.value = await _streakService.hasCompletedToday();

    // Update streak widget with current data
    await _streakWidgetService.updateStreakWidget();

    // Load recent completion history for the study calendar
    await _loadCompletionHistory();

    // Schedule recurring streak reminders (will work every day regardless of app usage)
    await _notificationService.scheduleRecurringStreakReminders();
  }

  /// Call when a quiz is completed successfully to update streak.
  Future<bool> markQuizCompletedToday() async {
    final bool alreadyCompleted = await _streakService.hasCompletedToday();
    final updated = await _streakService.markCompletedToday();
    streakCount.value = updated;
    hasCompletedToday.value = true;

    // Cancel only today's recurring streak reminders (keeps future days scheduled)
    await _notificationService.cancelTodaysRecurringStreakReminders();

    // Update streak widget with new data
    await _streakWidgetService.updateStreakWidget();

    // Refresh completion history so the calendar reflects today's completion
    await _loadCompletionHistory();
    return !alreadyCompleted;
  }

  /// Load recent completion history into the reactive state used by the
  /// Streaks page calendar. Uses a small loading flag for the calendar only.
  Future<void> _loadCompletionHistory() async {
    try {
      isHistoryLoading.value = true;
      final list = await _streakService.getCompletionHistory(
        days: streakCalendarDays,
      );
      completionHistory.assignAll(list);
    } catch (_) {
      completionHistory.clear();
    } finally {
      isHistoryLoading.value = false;
    }
  }

  /// Get cache age in hours for debugging
  Future<double?> getCacheAge() async {
    return await _userCacheService.getCacheAge();
  }

  /// Check if there's valid cached data
  Future<bool> hasValidCachedData() async {
    return await _userCacheService.hasValidCachedData();
  }

  /// Force clear cache (useful for testing or manual refresh)
  Future<void> clearCache() async {
    await _userCacheService.clearCachedUserData();
    await _dailyCacheService.invalidate(_dailyUserCacheKey);
    log("HomeController: Cache cleared manually");
  }

  /// Update streak widget with current streak data
  Future<void> updateStreakWidget() async {
    await _streakWidgetService.updateStreakWidget();
    log("HomeController: Streak widget updated");
  }

  Future<void> signOut() async {
    try {
      isLoading.value = true;
      log("HomeController: Signing out user...");
      final result = await _authRepo.signOut();
      await result.fold(
        (failure) async {
          log("HomeController: Error signing out: ${failure.message}");
        },
        (_) async {
          await _handlePostSignOutCleanup();
          log("HomeController: User signed out successfully.");
        },
      );
    } catch (e) {
      log("HomeController: Error signing out: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _handlePostSignOutCleanup() async {
    currentUser.value = null;
    currentPage.value = 0;
    streakCount.value = 0;
    hasCompletedToday.value = false;
    completionHistory.clear();
    isHistoryLoading.value = false;

    await _userCacheService.clearCachedUserData();

    try {
      await _streakService.clearLocalCache();
    } catch (_) {}

    if (di.sl.isRegistered<CourseCacheService>()) {
      try {
        await di.sl<CourseCacheService>().clearCache();
      } catch (_) {}
    }
  }
}
