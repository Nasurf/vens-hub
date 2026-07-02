import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:vens_hub/core/services/data/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:vens_hub/presentation/widgets/common/themed_hub_icon.dart';
import 'package:vens_hub/data/models/user_model.dart';
import 'package:vens_hub/adaptive/lib/src/adaptive_service.dart';
import 'package:vens_hub/core/services/adaptive/adaptive_storage_service.dart';

class QuizAttemptSummary {
  QuizAttemptSummary({
    required this.startedAt,
    required this.questionsCount,
    required this.correctCount,
    required this.elapsedMs,
    required this.subject,
    required this.topic,
  });

  final DateTime startedAt;
  final int questionsCount;
  final int correctCount;
  final int? elapsedMs;
  final String subject;
  final String? topic;

  double get scorePercent {
    if (questionsCount <= 0) return 0;
    final percent = (correctCount / questionsCount) * 100;
    return percent.clamp(0, 100).toDouble();
  }

  double? get elapsedMinutes => elapsedMs == null ? null : elapsedMs! / 60000.0;
}

class SubjectPerformance {
  const SubjectPerformance({
    required this.subject,
    required this.averageScore,
    required this.attempts,
  });

  final String subject;
  final double averageScore;
  final int attempts;
}

class HubController extends GetxController {
  final RxInt currentTabIndex = 0.obs; // 0=Day, 1=Week, 2=Month
  final RxList<int> hourlyCounts = List<int>.filled(24, 0).obs;
  final RxList<int> weekDailyCounts = List<int>.filled(7, 0).obs;
  final RxList<int> monthWeeklyCounts = List<int>.filled(4, 0).obs;
  final RxBool loading = false.obs;
  final RxnString error = RxnString();

  final RxBool analyticsLoading = false.obs;
  final RxnString analyticsError = RxnString();
  final RxList<QuizAttemptSummary> recentAttempts = <QuizAttemptSummary>[].obs;
  final RxList<SubjectPerformance> subjectPerformance =
      <SubjectPerformance>[].obs;
  final RxList<String> insightMessages = <String>[].obs;

  static const int performanceUnlockThreshold = 3;
  static const int subjectUnlockThreshold = 4;
  static const int efficiencyUnlockThreshold = 3;

  // Cache/ready flags to avoid refetch + spinner when switching tabs
  final RxBool _dayReady = false.obs;
  final RxBool _weekReady = false.obs;
  final RxBool _monthReady = false.obs;

  // Selections
  final Rx<DateTime> selectedDay = DateTime.now().obs;
  final RxInt selectedYear = DateTime.now().year.obs;
  final RxInt selectedMonth = DateTime.now().month.obs; // 1..12
  final RxInt selectedWeekOfMonth = 1.obs; // 1..4 (5th folded into 4th)

  final HomeController _homeController = Get.find<HomeController>();

  @override
  void onInit() {
    super.onInit();
    selectedWeekOfMonth.value = _weekOfMonth(DateTime.now()).clamp(1, 4);
    insightMessages.assignAll(['Complete a quiz to unlock insights']);
    // Load the default (day) view with spinner, and prewarm others silently.
    _loadDay(showSpinner: true).whenComplete(() {
      // Prewarm other series in background so tab switches are instant.
      prewarm();
    });

    ever<UserModel?>(_homeController.currentUser, (user) {
      final userId = user?.id;
      if (userId != null && userId.isNotEmpty) {
        _loadAnalytics();
        // Also reload the main charts since we might have started with empty user
        reload(showSpinnerForActiveTab: false);
      } else {
        resetForLogout();
      }
    });

    final initialUserId = _homeController.currentUser.value?.id;
    if (initialUserId != null && initialUserId.isNotEmpty) {
      _loadAnalytics();
      _seedAdaptiveMastery(initialUserId);
    }
  }

  /// Sync local KC states from get_storage to the D1 server.
  void _seedAdaptiveMastery(String userId) {
    final storage = AdaptiveStorageService();
    final kcStates = storage.getKcStates();
    if (kcStates.isNotEmpty) {
      AdaptiveService().seedMastery(userId, kcStates);
    }
  }

  void onTabChanged(int index) {
    // Avoid redundant work if same tab tapped
    if (currentTabIndex.value == index) return;
    // Ensure spinner isn't shown while switching tabs
    loading.value = false;
    currentTabIndex.value = index;
    // Always refresh silently when switching tabs to keep UI snappy.
    if (index == 0) {
      _loadDay(showSpinner: false);
    } else if (index == 1) {
      _loadWeek(showSpinner: false);
    } else {
      _loadMonth(showSpinner: false);
    }
  }

  Future<void> setDay(DateTime day) async {
    selectedDay.value = day;
    selectedYear.value = day.year;
    selectedMonth.value = day.month;
    selectedWeekOfMonth.value = _weekOfMonth(day).clamp(1, 4);
    _dayReady.value = false; // invalidate cache for new day
    await _loadDay(day: day, showSpinner: currentTabIndex.value == 0);
    // Background prewarm for other tabs based on new selection
    prewarm();
  }

  Future<void> setWeekOfMonth(int week) async {
    selectedWeekOfMonth.value = week.clamp(1, 4);
    _weekReady.value = false;
    await _loadWeek(showSpinner: currentTabIndex.value == 1);
    prewarm();
  }

  Future<void> setMonth(int month) async {
    selectedMonth.value = month.clamp(1, 12);
    _monthReady.value = false;
    await _loadMonth(showSpinner: currentTabIndex.value == 2);
    prewarm();
  }

  Future<void> _loadDay({DateTime? day, bool showSpinner = true}) async {
    final userId = _homeController.currentUser.value?.id;
    if (userId == null || userId.isEmpty) {
      hourlyCounts.value = List<int>.filled(24, 0);
      _dayReady.value = true;
      return;
    }
    if (showSpinner) loading.value = true;
    error.value = null;
    try {
      final counts = await FireStoreServices.find.getHourlyQuizAttempts(
        uid: userId,
        day: day ?? selectedDay.value,
      );
      hourlyCounts.value = counts;
      _dayReady.value = true;
    } catch (e) {
      error.value = 'Failed to load activity';
      hourlyCounts.value = List<int>.filled(24, 0);
    } finally {
      if (showSpinner) loading.value = false;
    }
  }

  Future<void> _loadWeek({bool showSpinner = true}) async {
    final userId = _homeController.currentUser.value?.id;
    if (userId == null || userId.isEmpty) {
      weekDailyCounts.value = List<int>.filled(7, 0);
      _weekReady.value = true;
      return;
    }
    if (showSpinner) loading.value = true;
    error.value = null;
    try {
      final dateInWeek = _dateForWeek(
        year: selectedYear.value,
        month: selectedMonth.value,
        weekOfMonth: selectedWeekOfMonth.value,
      );
      final counts = await FireStoreServices.find.getDailyCountsForWeek(
        uid: userId,
        anyDayInWeek: dateInWeek,
      );
      // Always ensure length 7
      weekDailyCounts.value = List<int>.generate(
        7,
        (i) => i < counts.length ? counts[i] : 0,
      );
      _weekReady.value = true;
    } catch (e) {
      error.value = 'Failed to load weekly activity';
      weekDailyCounts.value = List<int>.filled(7, 0);
    } finally {
      if (showSpinner) loading.value = false;
    }
  }

  Future<void> _loadMonth({bool showSpinner = true}) async {
    final userId = _homeController.currentUser.value?.id;
    if (userId == null || userId.isEmpty) {
      monthWeeklyCounts.value = List<int>.filled(4, 0);
      _monthReady.value = true;
      return;
    }
    if (showSpinner) loading.value = true;
    error.value = null;
    try {
      final counts = await FireStoreServices.find.getWeeklyCountsForMonth(
        uid: userId,
        year: selectedYear.value,
        month: selectedMonth.value,
      );
      monthWeeklyCounts.value = List<int>.generate(
        4,
        (i) => i < counts.length ? counts[i] : 0,
      );
      _monthReady.value = true;
    } catch (e) {
      error.value = 'Failed to load monthly activity';
      monthWeeklyCounts.value = List<int>.filled(4, 0);
    } finally {
      if (showSpinner) loading.value = false;
    }
  }

  int _weekOfMonth(DateTime date) {
    final firstOfMonth = DateTime(date.year, date.month, 1);
    final offset = firstOfMonth.weekday % 7;
    return ((date.day + offset - 1) ~/ 7) + 1;
  }

  DateTime _dateForWeek({
    required int year,
    required int month,
    required int weekOfMonth,
  }) {
    final firstOfMonth = DateTime(year, month, 1);
    final offset = firstOfMonth.weekday % 7;
    final startDay = 1 + (weekOfMonth - 1) * 7 - offset;
    final clampedDay = startDay.clamp(1, DateTime(year, month + 1, 0).day);
    return DateTime(year, month, clampedDay);
  }

  /// Preload all series in the background without toggling the loading spinner.
  Future<void> prewarm() async {
    final userId = _homeController.currentUser.value?.id;
    if (userId == null || userId.isEmpty) return;
    final fs = FireStoreServices.find;
    final DateTime day = selectedDay.value;
    final DateTime anyDayInWeek = _dateForWeek(
      year: selectedYear.value,
      month: selectedMonth.value,
      weekOfMonth: selectedWeekOfMonth.value,
    );

    try {
      final List<List<int>> results = await Future.wait<List<int>>([
        fs.getHourlyQuizAttempts(uid: userId, day: day),
        fs.getDailyCountsForWeek(uid: userId, anyDayInWeek: anyDayInWeek),
        fs.getWeeklyCountsForMonth(
          uid: userId,
          year: selectedYear.value,
          month: selectedMonth.value,
        ),
      ]);
      hourlyCounts.value = results[0];
      final weekData = results[1];
      weekDailyCounts.value = List<int>.generate(
        7,
        (i) => i < weekData.length ? weekData[i] : 0,
      );
      final monthData = results[2];
      monthWeeklyCounts.value = List<int>.generate(
        4,
        (i) => i < monthData.length ? monthData[i] : 0,
      );
      _dayReady.value = true;
      _weekReady.value = true;
      _monthReady.value = true;
    } catch (_) {
      // Silent fail on prewarm
    }
  }

  Future<void> reload({bool showSpinnerForActiveTab = false}) async {
    final int tab = currentTabIndex.value;
    // Load only the active tab with spinner, plus analytics.
    if (tab == 0) {
      await _loadDay(showSpinner: showSpinnerForActiveTab);
    } else if (tab == 1) {
      await _loadWeek(showSpinner: showSpinnerForActiveTab);
    } else {
      await _loadMonth(showSpinner: showSpinnerForActiveTab);
    }
    await _loadAnalytics();
    // Kick off background prewarm without blocking the refresh indicator.
    Future.microtask(() => prewarm());
  }

  Future<void> refreshAll() async {
    await reload(showSpinnerForActiveTab: true);
  }

  Future<void> _loadAnalytics() async {
    final userId = _homeController.currentUser.value?.id;
    if (userId == null || userId.isEmpty) {
      _clearAnalytics();
      return;
    }

    analyticsLoading.value = true;
    analyticsError.value = null;
    try {
      final rawAttempts = await FireStoreServices.find.getRecentQuizAttempts(
        uid: userId,
        limit: 25,
      );

      final summaries =
          rawAttempts.where((data) => data['startedAt'] is DateTime).map((
            data,
          ) {
            final DateTime startedAt = data['startedAt'] as DateTime;
            final int questionsCount = (data['questionsCount'] as int?) ?? 0;
            final int correctCount = (data['correctCount'] as int?) ?? 0;
            final int? elapsedMs = data['elapsedMs'] as int?;
            final String subject =
                (data['subject'] as String?) ?? 'Unknown course';
            final String? topic = data['topic'] as String?;
            return QuizAttemptSummary(
              startedAt: startedAt,
              questionsCount: questionsCount,
              correctCount: correctCount,
              elapsedMs: elapsedMs,
              subject: subject,
              topic: topic,
            );
          }).toList();

      recentAttempts.assignAll(summaries);
      _recomputeAnalyticsDerived();
    } catch (e) {
      analyticsError.value = 'Failed to load performance data';
      recentAttempts.clear();
      subjectPerformance.clear();
      insightMessages.assignAll(['Unable to load insights right now.']);
    } finally {
      analyticsLoading.value = false;
    }
  }

  void _clearAnalytics({bool keepMessage = true}) {
    analyticsLoading.value = false;
    analyticsError.value = null;
    recentAttempts.clear();
    subjectPerformance.clear();
    if (keepMessage) {
      insightMessages.assignAll(['Complete a quiz to unlock insights']);
    } else {
      insightMessages.clear();
    }
  }

  void resetForLogout() {
    currentTabIndex.value = 0;
    loading.value = false;
    analyticsLoading.value = false;
    error.value = null;
    analyticsError.value = null;
    hourlyCounts.value = List<int>.filled(24, 0);
    weekDailyCounts.value = List<int>.filled(7, 0);
    monthWeeklyCounts.value = List<int>.filled(4, 0);
    recentAttempts.clear();
    subjectPerformance.clear();
    insightMessages.assignAll(['Complete a quiz to unlock insights']);
    _dayReady.value = false;
    _weekReady.value = false;
    _monthReady.value = false;
    final now = DateTime.now();
    selectedDay.value = now;
    selectedYear.value = now.year;
    selectedMonth.value = now.month;
    selectedWeekOfMonth.value = _weekOfMonth(now).clamp(1, 4);
  }

  void _recomputeAnalyticsDerived() {
    final attempts = recentAttempts.toList();
    if (attempts.isEmpty) {
      subjectPerformance.clear();
      insightMessages.assignAll(['Complete a quiz to unlock insights']);
      return;
    }

    subjectPerformance.assignAll(_computeSubjectPerformance(attempts));
    insightMessages.assignAll(
      _buildInsights(attempts: attempts, subjects: subjectPerformance.toList()),
    );
  }

  int get totalAttemptCount => recentAttempts.length;

  int get timedAttemptCount =>
      recentAttempts.where((attempt) => attempt.elapsedMinutes != null).length;

  double _progress(int current, int required) {
    if (required <= 0) return 1;
    return (current / required).clamp(0, 1).toDouble();
  }

  double get performanceProgress =>
      _progress(totalAttemptCount, performanceUnlockThreshold);

  bool get performanceUnlocked =>
      totalAttemptCount >= performanceUnlockThreshold;

  double get subjectProgress =>
      _progress(totalAttemptCount, subjectUnlockThreshold);

  bool get subjectUnlocked =>
      totalAttemptCount >= subjectUnlockThreshold &&
      subjectPerformance.isNotEmpty;

  double get efficiencyProgress =>
      _progress(timedAttemptCount, efficiencyUnlockThreshold);

  bool get efficiencyUnlocked => timedAttemptCount >= efficiencyUnlockThreshold;

  int get missingPerformanceAttempts =>
      math.max(0, performanceUnlockThreshold - totalAttemptCount);

  int get missingSubjectAttempts =>
      math.max(0, subjectUnlockThreshold - totalAttemptCount);

  int get missingEfficiencyAttempts =>
      math.max(0, efficiencyUnlockThreshold - timedAttemptCount);

  List<SubjectPerformance> _computeSubjectPerformance(
    List<QuizAttemptSummary> attempts,
  ) {
    final Map<String, _SubjectAccumulator> buckets = {};
    for (final attempt in attempts) {
      final key = attempt.subject.isEmpty ? 'Unknown course' : attempt.subject;
      final bucket = buckets.putIfAbsent(key, () => _SubjectAccumulator());
      bucket.totalScore += attempt.scorePercent;
      bucket.count += 1;
    }

    final results =
        buckets.entries.map((entry) {
            final bucket = entry.value;
            final average =
                bucket.count == 0 ? 0.0 : bucket.totalScore / bucket.count;
            return SubjectPerformance(
              subject: entry.key,
              averageScore: average,
              attempts: bucket.count,
            );
          }).toList()
          ..sort((a, b) => b.averageScore.compareTo(a.averageScore));

    return results;
  }

  List<String> _buildInsights({
    required List<QuizAttemptSummary> attempts,
    required List<SubjectPerformance> subjects,
  }) {
    final List<String> messages = [];

    if (!performanceUnlocked) {
      if (missingPerformanceAttempts > 0) {
        messages.add(
          'Log $missingPerformanceAttempts more quiz${missingPerformanceAttempts == 1 ? '' : 'zes'} to unlock your performance trend.',
        );
      }
    } else {
      final firstScore = attempts.first.scorePercent;
      final lastScore = attempts.last.scorePercent;
      final delta = lastScore - firstScore;
      final startLabel = DateFormat('MMM d').format(attempts.first.startedAt);
      if (delta > 4) {
        messages.add(
          'Momentum building: +${delta.toStringAsFixed(1)} pts since $startLabel.',
        );
      } else if (delta < -4) {
        messages.add(
          'Scores dipped ${delta.abs().toStringAsFixed(1)} pts since $startLabel — revisit recent quizzes.',
        );
      } else {
        messages.add(
          'Consistent performance: last ${attempts.length} quizzes are holding steady.',
        );
      }
    }

    if (!subjectUnlocked) {
      if (missingSubjectAttempts > 0) {
        messages.add(
          'Complete $missingSubjectAttempts more quiz${missingSubjectAttempts == 1 ? '' : 'zes'} to compare subjects side-by-side.',
        );
      }
    } else if (subjects.isNotEmpty) {
      final best = subjects.first;
      final descriptor = _scoreDescriptor(best.averageScore);
      messages.add(
        'You’re $descriptor in ${best.subject} (${best.averageScore.toStringAsFixed(0)}% avg).',
      );

      if (subjects.length > 1) {
        final weakest = subjects.last;
        final gap = (best.averageScore - weakest.averageScore).abs();
        final recommendation =
            gap > 4
                ? 'Recommendation: review ${weakest.subject} next (${weakest.averageScore.toStringAsFixed(0)}% avg).'
                : 'Keep reinforcing ${weakest.subject} (${weakest.averageScore.toStringAsFixed(0)}% avg) to lock it in.';
        messages.add(recommendation);
      }
    }

    final timedAttempts =
        attempts.where((a) => a.elapsedMinutes != null).toList();
    if (!efficiencyUnlocked) {
      if (missingEfficiencyAttempts > 0) {
        messages.add(
          'Log $missingEfficiencyAttempts more timed quiz${missingEfficiencyAttempts == 1 ? '' : 'zes'} to unlock speed insights.',
        );
      }
      return messages;
    }

    final highScores =
        timedAttempts.where((a) => a.scorePercent >= 80).toList();
    final lowerScores =
        timedAttempts.where((a) => a.scorePercent < 80).toList();
    final medianTime = _median(
      timedAttempts.map((a) => a.elapsedMinutes!).toList(),
    );

    if (highScores.isNotEmpty && lowerScores.isNotEmpty) {
      final avgHighTime = _average(
        highScores.map((a) => a.elapsedMinutes!).toList(),
      );
      final avgLowTime = _average(
        lowerScores.map((a) => a.elapsedMinutes!).toList(),
      );
      final timeDiff = (avgHighTime - avgLowTime).abs();

      if (avgHighTime > avgLowTime && timeDiff > 0.3) {
        messages.add(
          'Best scores arrive when you slow down to about ${_formatMinutes(avgHighTime)} (rushed attempts average ${_formatMinutes(avgLowTime)}).',
        );
      } else if (avgHighTime < avgLowTime && timeDiff > 0.3) {
        messages.add(
          'Speed is your ally — top scores land in ~${_formatMinutes(avgHighTime)}, slower sessions averaged ${_formatMinutes(avgLowTime)}.',
        );
      } else {
        messages.add(
          'Median quiz time is ${_formatMinutes(medianTime)} — pacing is consistent with your accuracy.',
        );
      }
    } else {
      messages.add(
        'Median quiz time is ${_formatMinutes(medianTime)} — keep logging more attempts to deepen the speed insights.',
      );
    }

    return messages;
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0;
    final total = values.reduce((a, b) => a + b);
    return total / values.length;
  }

  double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  String _formatMinutes(double minutes) {
    if (minutes < 1) {
      final seconds = (minutes * 60).round();
      return '$seconds sec';
    }
    if ((minutes - minutes.round()).abs() < 0.05) {
      return '${minutes.round()} min';
    }
    return '${minutes.toStringAsFixed(1)} min';
  }

  String _scoreDescriptor(double score) {
    if (score >= 90) return 'crushing it';
    if (score >= 80) return 'performing strongly';
    if (score >= 70) return 'building solid mastery';
    if (score >= 60) return 'making steady progress';
    return 'just getting started';
  }
}

class _SubjectAccumulator {
  double totalScore = 0;
  int count = 0;
}

class MobileHubPage extends StatefulWidget {
  const MobileHubPage({super.key});

  @override
  State<MobileHubPage> createState() => _MobileHubPageState();
}

class _MobileHubPageState extends State<MobileHubPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _activityKey = GlobalKey();
  final GlobalKey _performanceKey = GlobalKey();
  final GlobalKey _subjectsKey = GlobalKey();
  final GlobalKey _efficiencyKey = GlobalKey();
  final GlobalKey _insightsKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final controller =
        Get.isRegistered<HubController>()
            ? Get.find<HubController>()
            : Get.put(HubController());

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ThemedHubIcon(selected: true, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Hub',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Obx(() {
                  final int selected = controller.currentTabIndex.value;
                  const titles = ['Day', 'Week', 'Month'];
                  return SizedBox(
                    height: 40,
                    child: Stack(
                      children: [
                        AnimatedAlign(
                          alignment: Alignment(-1.0 + (selected * 1.0), 0.0),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOutCubic,
                          child: FractionallySizedBox(
                            widthFactor: 1 / 3,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colorScheme.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(3, (index) {
                            final bool isActive = selected == index;
                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => controller.onTabChanged(index),
                                child: Container(
                                  alignment: Alignment.center,
                                  color: Colors.transparent,
                                  child: Text(
                                    titles[index],
                                    textAlign: TextAlign.center,
                                    style: textTheme.labelLarge?.copyWith(
                                      color: isActive
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              _SectionNavigator(
                onActivityTap: () => _scrollToSection(_activityKey),
                onPerformanceTap: () => _scrollToSection(_performanceKey),
                onSubjectsTap: () => _scrollToSection(_subjectsKey),
                onEfficiencyTap: () => _scrollToSection(_efficiencyKey),
                onInsightsTap: () => _scrollToSection(_insightsKey),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.refreshAll,
                  triggerMode: RefreshIndicatorTriggerMode.anywhere,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          key: _activityKey,
                          height: math.min(
                            MediaQuery.of(context).size.height * 0.45,
                            360.0,
                          ),
                          child: Obx(() {
                            final bool isLoading = controller.loading.value;
                            if (isLoading) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            return HubActivityChart(controller: controller);
                          }),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          key: _performanceKey,
                          child: PerformanceOverTimeCard(
                            controller: controller,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          key: _subjectsKey,
                          child: SubjectBreakdownCard(controller: controller),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          key: _efficiencyKey,
                          child: EfficiencyScatterCard(controller: controller),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          key: _insightsKey,
                          child: InsightsCard(controller: controller),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionNavigator extends StatelessWidget {
  const _SectionNavigator({
    required this.onActivityTap,
    required this.onPerformanceTap,
    required this.onSubjectsTap,
    required this.onEfficiencyTap,
    required this.onInsightsTap,
  });

  final VoidCallback onActivityTap;
  final VoidCallback onPerformanceTap;
  final VoidCallback onSubjectsTap;
  final VoidCallback onEfficiencyTap;
  final VoidCallback onInsightsTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onHorizontalDragStart: (_) {},
      onHorizontalDragUpdate: (_) {},
      onHorizontalDragEnd: (_) {},
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _NavChip(
              label: 'Activity',
              icon: Icons.bar_chart_rounded,
              onTap: onActivityTap,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(width: 8),
            _NavChip(
              label: 'Performance',
              icon: Icons.trending_up,
              onTap: onPerformanceTap,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(width: 8),
            _NavChip(
              label: 'Subjects',
              icon: Icons.library_books_outlined,
              onTap: onSubjectsTap,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(width: 8),
            _NavChip(
              label: 'Efficiency',
              icon: Icons.speed_outlined,
              onTap: onEfficiencyTap,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(width: 8),
            _NavChip(
              label: 'Insights',
              icon: Icons.lightbulb_outline,
              onTap: onInsightsTap,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HubActivityChart extends StatelessWidget {
  const HubActivityChart({super.key, required this.controller});

  final HubController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _PeriodSelectorMobile(controller: controller),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Quiz activity',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Quizzes done',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Obx(() {
              final int tab = controller.currentTabIndex.value;
              List<int> series;
              double minX = 0, maxX = 23, intervalX = 6;
              Widget Function(double, TitleMeta) labelBuilder;
              if (tab == 0) {
                series = controller.hourlyCounts.toList();
                minX = 0;
                maxX = 23;
                intervalX = 6;
                labelBuilder = (value, meta) {
                  final int h = value.toInt();
                  if (h < 0 || h > 23) return const SizedBox.shrink();
                  if (h % 6 != 0) return const SizedBox.shrink();
                  final label = _hourLabel(h);
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      label,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                };
              } else if (tab == 1) {
                series = controller.weekDailyCounts.toList();
                minX = 0;
                maxX = 6;
                intervalX = 1;
                const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                labelBuilder = (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i > 6) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      letters[i],
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                };
              } else {
                series = controller.monthWeeklyCounts.toList();
                minX = 1;
                maxX = 4.3;
                intervalX = 1;
                labelBuilder = (value, meta) {
                  final i = value.toInt();
                  if (i < 1 || i > 4) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      i.toString(),
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                };
              }

              final spots = <FlSpot>[];
              if (tab == 0) {
                for (int i = 0; i < 24; i++) {
                  spots.add(FlSpot(i.toDouble(), series[i].toDouble()));
                }
              } else if (tab == 1) {
                for (int i = 0; i < 7; i++) {
                  spots.add(
                    FlSpot(
                      i.toDouble(),
                      (i < series.length ? series[i] : 0).toDouble(),
                    ),
                  );
                }
              } else {
                for (int i = 1; i <= 4; i++) {
                  final v =
                      (i - 1 < series.length ? series[i - 1] : 0).toDouble();
                  spots.add(FlSpot(i.toDouble(), v));
                }
              }

              return LineChart(
                LineChartData(
                  minY: 0,
                  minX: minX,
                  maxX: maxX,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine:
                        (value) => FlLine(
                          color: colorScheme.outline.withValues(alpha: 0.15),
                          strokeWidth: 1,
                        ),
                    getDrawingVerticalLine:
                        (value) => FlLine(
                          color: colorScheme.outline.withValues(alpha: 0.12),
                          strokeWidth: 1,
                        ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: _suggestLeftInterval(series),
                        getTitlesWidget:
                            (value, meta) => Text(
                              value.toInt().toString(),
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: intervalX,
                        getTitlesWidget: labelBuilder,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      left: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      right: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      bottom: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: colorScheme.primary,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colorScheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Obx(() {
              final int tab = controller.currentTabIndex.value;
              final label =
                  tab == 0 ? 'Time of day' : (tab == 1 ? 'Weekday' : 'Weeks');
              return Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class PerformanceOverTimeCard extends StatelessWidget {
  const PerformanceOverTimeCard({super.key, required this.controller});

  final HubController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Obx(() {
      final attempts = controller.recentAttempts.toList();
      final bool isLoading =
          controller.analyticsLoading.value && attempts.isEmpty;
      final bool unlocked = controller.performanceUnlocked;
      final int missing = controller.missingPerformanceAttempts;
      final bool hasData = attempts.isNotEmpty;
      final String? error = controller.analyticsError.value;

      List<QuizAttemptSummary> displayAttempts = <QuizAttemptSummary>[];
      Widget content;
      if (isLoading) {
        content = const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        );
      } else if (!unlocked) {
        final message =
            missing == 1
                ? 'One more quiz attempt unlocks your performance trend.'
                : 'Complete $missing more quizzes to unlock your performance trend.';
        content = AnalyticsUnlockTube(
          title: 'Track progress over time',
          message: message,
          current: controller.totalAttemptCount,
          required: HubController.performanceUnlockThreshold,
          progress: controller.performanceProgress,
        );
      } else if (!hasData) {
        final message =
            error ?? 'Complete a quiz to start tracking your performance.';
        content = Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        );
      } else {
        displayAttempts =
            attempts.length > 10
                ? attempts.sublist(attempts.length - 10)
                : attempts;
        final spots = <FlSpot>[];
        for (int i = 0; i < displayAttempts.length; i++) {
          spots.add(FlSpot(i.toDouble(), displayAttempts[i].scorePercent));
        }
        final maxIndex = math.max(displayAttempts.length - 1, 0);
        final lineChart = SizedBox(
          height: 220,
          child: Stack(
            children: [
              Positioned(
                bottom: 4,
                right: 4,
                child: Text(
                  'Day',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ),
              LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  minX: 0,
                  maxX: maxIndex.toDouble(),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 20,
                    verticalInterval: 1,
                    getDrawingHorizontalLine:
                        (value) => FlLine(
                          color: colorScheme.outline.withValues(alpha: 0.15),
                          strokeWidth: 1,
                        ),
                    getDrawingVerticalLine:
                        (value) => FlLine(
                          color: colorScheme.outline.withValues(alpha: 0.1),
                          strokeWidth: 1,
                        ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 20,
                        getTitlesWidget:
                            (value, meta) => Text(
                              '${value.toInt()}%'.trim(),
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= displayAttempts.length) {
                            return const SizedBox.shrink();
                          }
                          final attempt = displayAttempts[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              DateFormat('d').format(attempt.startedAt),
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      left: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      right: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      bottom: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: colorScheme.primary,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter:
                            (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                                  radius: 4,
                                  color: colorScheme.primary,
                                  strokeWidth: 2,
                                  strokeColor: colorScheme.surface,
                                ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor:
                          (_) => colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.95,
                          ),
                      getTooltipItems: (touchedSpots) {
                        final baseStyle = (textTheme.bodySmall ??
                                const TextStyle(fontSize: 12))
                            .copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            );
                        return touchedSpots.map((item) {
                          final idx = item.x.toInt();
                          if (idx < 0 || idx >= displayAttempts.length) {
                            return null;
                          }
                          final attempt = displayAttempts[idx];
                          final timeLabel = _formatAttemptTime(attempt);
                          return LineTooltipItem(
                            '${attempt.subject}\n${attempt.scorePercent.toStringAsFixed(0)}% · $timeLabel',
                            baseStyle,
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
              if (controller.analyticsLoading.value)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: colorScheme.surface.withValues(alpha: 0.08),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

        final detailRows =
            displayAttempts.reversed.take(5).map((attempt) {
              final primaryText =
                  '${DateFormat('MMM d').format(attempt.startedAt)} • ${attempt.subject}';
              final topicText =
                  attempt.topic == null || attempt.topic!.isEmpty
                      ? null
                      : attempt.topic;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            primaryText,
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (topicText != null)
                            Text(
                              topicText,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${attempt.scorePercent.toStringAsFixed(0)}%',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                        Text(
                          _formatAttemptTime(attempt),
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList();

        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [lineChart, const SizedBox(height: 12), ...detailRows],
        );
      }

      final String subtitleText =
          unlocked && hasData
              ? 'Last ${displayAttempts.length} quiz${displayAttempts.length == 1 ? '' : 'zes'}'
              : unlocked
              ? 'Trend updates every time you finish a quiz.'
              : 'Unlocks after ${HubController.performanceUnlockThreshold} quizzes.';

      return AnalyticsCard(
        title: 'My Recent Performance',
        subtitle: subtitleText,
        child: content,
      );
    });
  }

  static String _formatAttemptTime(QuizAttemptSummary attempt) {
    final minutes = attempt.elapsedMinutes;
    if (minutes == null) return '—';
    if (minutes < 1) {
      final seconds = (minutes * 60).round();
      return '${seconds}s';
    }
    final precision = minutes >= 10 ? 0 : 1;
    final str = minutes.toStringAsFixed(precision);
    return '${str}m';
  }
}

class SubjectBreakdownCard extends StatelessWidget {
  const SubjectBreakdownCard({super.key, required this.controller});

  final HubController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Obx(() {
      final subjects = controller.subjectPerformance.toList();
      final attempts = controller.recentAttempts.toList();
      final bool isLoading =
          controller.analyticsLoading.value && attempts.isEmpty;
      final bool unlocked = controller.subjectUnlocked;
      final int missing = controller.missingSubjectAttempts;

      Widget content;
      if (isLoading) {
        content = const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        );
      } else if (!unlocked) {
        final message =
            missing == 1
                ? 'One more quiz unlocks your subject breakdown.'
                : 'Complete $missing more quizzes to compare subjects side-by-side.';
        content = AnalyticsUnlockTube(
          title: 'Unlock subject insights',
          message: message,
          current: controller.totalAttemptCount,
          required: HubController.subjectUnlockThreshold,
          progress: controller.subjectProgress,
          accentColor: colorScheme.secondary,
        );
      } else {
        final display = subjects.length > 6 ? subjects.sublist(0, 6) : subjects;
        final groups = List.generate(display.length, (index) {
          final subject = display[index];
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: subject.averageScore.clamp(0, 100),
                width: 18,
                borderRadius: BorderRadius.circular(6),
                color: colorScheme.primary,
              ),
            ],
          );
        });

        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine:
                        (value) => FlLine(
                          color: colorScheme.outline.withValues(alpha: 0.15),
                          strokeWidth: 1,
                        ),
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      left: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      bottom: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      top: BorderSide.none,
                      right: BorderSide.none,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 20,
                        getTitlesWidget:
                            (value, meta) => Text(
                              '${value.toInt()}%',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= display.length) {
                            return const SizedBox.shrink();
                          }
                          final subject = display[index];
                          final shortName =
                              subject.subject.length > 3
                                  ? subject.subject.substring(0, 3)
                                  : subject.subject;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              shortName,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: groups,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...display.map((subject) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        subject.subject,
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${subject.averageScore.toStringAsFixed(0)}%',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${subject.attempts} quiz${subject.attempts == 1 ? '' : 'zes'}',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (subjects.length > display.length)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${subjects.length - display.length} more subjects',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        );
      }

      final String subtitleText =
          unlocked
              ? 'Average score per course'
              : 'Unlocks after ${HubController.subjectUnlockThreshold} quizzes.';

      return AnalyticsCard(
        title: 'Performance by Subject',
        subtitle: subtitleText,
        child: content,
      );
    });
  }
}

class EfficiencyScatterCard extends StatelessWidget {
  const EfficiencyScatterCard({super.key, required this.controller});

  final HubController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Obx(() {
      final attempts =
          controller.recentAttempts
              .where((attempt) => attempt.elapsedMinutes != null)
              .toList();
      final bool isLoading =
          controller.analyticsLoading.value &&
          controller.recentAttempts.isEmpty;
      final bool unlocked = controller.efficiencyUnlocked;
      final int missing = controller.missingEfficiencyAttempts;

      Widget content;
      if (isLoading) {
        content = const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        );
      } else if (!unlocked) {
        final message =
            missing == 1
                ? 'One more timed quiz unlocks your speed vs score chart.'
                : 'Finish $missing more timed quizzes to reveal your speed vs score pattern.';
        content = AnalyticsUnlockTube(
          title: 'Unlock speed insights',
          message: message,
          current: controller.timedAttemptCount,
          required: HubController.efficiencyUnlockThreshold,
          progress: controller.efficiencyProgress,
          accentColor: colorScheme.tertiary,
        );
      } else if (attempts.isEmpty) {
        content = Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Complete a timed quiz to see your efficiency trends.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        );
      } else {
        final displayAttempts =
            attempts.length > 20
                ? attempts.sublist(attempts.length - 20)
                : List<QuizAttemptSummary>.from(attempts);
        displayAttempts.sort((a, b) => a.startedAt.compareTo(b.startedAt));
        final avgTime =
            displayAttempts
                .map((a) => a.elapsedMinutes!)
                .reduce((a, b) => a + b) /
            displayAttempts.length;

        final spots = <FlSpot>[];
        for (int i = 0; i < displayAttempts.length; i++) {
          spots.add(FlSpot(i.toDouble(), displayAttempts[i].scorePercent));
        }
        final maxIndex = math.max(displayAttempts.length - 1, 0);
        final int desiredLabels = math.min(displayAttempts.length, 8);
        final int labelInterval =
            desiredLabels <= 1 || maxIndex == 0
                ? 1
                : math.max(1, (maxIndex / (desiredLabels - 1)).ceil());

        final seenSubjects = <String>{};
        final legendSubjects = <String>[];
        for (final attempt in displayAttempts) {
          if (seenSubjects.add(attempt.subject)) {
            legendSubjects.add(attempt.subject);
          }
          if (legendSubjects.length >= 6) break;
        }

        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  minX: 0,
                  maxX: maxIndex.toDouble(),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 20,
                    verticalInterval: 1,
                    getDrawingHorizontalLine:
                        (value) => FlLine(
                          color: colorScheme.outline.withValues(alpha: 0.12),
                          strokeWidth: 1,
                        ),
                    getDrawingVerticalLine:
                        (value) => FlLine(
                          color: colorScheme.outline.withValues(alpha: 0.1),
                          strokeWidth: 1,
                        ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 20,
                        getTitlesWidget:
                            (value, meta) => Text(
                              '${value.toInt()}%',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: labelInterval.toDouble(),
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= displayAttempts.length) {
                            return const SizedBox.shrink();
                          }
                          if (index % labelInterval != 0 &&
                              index != 0 &&
                              index != maxIndex) {
                            return const SizedBox.shrink();
                          }
                          final attempt = displayAttempts[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              DateFormat('d').format(attempt.startedAt),
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      left: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      right: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      bottom: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      barWidth: 3,
                      color: colorScheme.tertiary,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter:
                            (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                                  radius: 4,
                                  color: colorScheme.tertiary,
                                  strokeWidth: 2,
                                  strokeColor: colorScheme.surface,
                                ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colorScheme.tertiary.withValues(alpha: 0.25),
                            colorScheme.tertiary.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor:
                          (_) => colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.95,
                          ),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((barSpot) {
                          final index = barSpot.x.toInt();
                          if (index < 0 || index >= displayAttempts.length) {
                            return null;
                          }
                          final attempt = displayAttempts[index];
                          final score = attempt.scorePercent.toStringAsFixed(0);
                          final time = attempt.elapsedMinutes!.toStringAsFixed(
                            1,
                          );
                          return LineTooltipItem(
                            '${attempt.subject}\n$score% · ${time}m',
                            textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ) ??
                                const TextStyle(),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Avg time: ${avgTime.toStringAsFixed(1)}m',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Last ${displayAttempts.length} timed quiz${displayAttempts.length == 1 ? '' : 'zes'}',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (legendSubjects.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    legendSubjects.map((subject) {
                      final Color chipColor = _colorForSubject(
                        subject,
                        colorScheme,
                      );
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: chipColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: chipColor.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          subject,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ],
          ],
        );
      }

      final String subtitleText =
          unlocked
              ? 'Track your speed and efficiency over time'
              : 'Unlocks after ${HubController.efficiencyUnlockThreshold} timed quizzes.';

      return AnalyticsCard(
        title: 'Efficiency Trend',
        subtitle: subtitleText,
        child: content,
      );
    });
  }

  Color _colorForSubject(String subject, ColorScheme scheme) {
    final palette = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      Colors.blueAccent,
      Colors.orangeAccent,
      Colors.teal,
      Colors.purpleAccent,
      Colors.pinkAccent,
    ];
    final index = subject.hashCode.abs() % palette.length;
    return palette[index];
  }
}

class InsightsCard extends StatelessWidget {
  const InsightsCard({super.key, required this.controller});

  final HubController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Obx(() {
      final insights = controller.insightMessages.toList();
      final bool isLoading =
          controller.analyticsLoading.value &&
          controller.recentAttempts.isEmpty;
      final String? error = controller.analyticsError.value;

      Widget content;
      if (isLoading) {
        content = const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        );
      } else if (insights.isEmpty) {
        final message =
            error ??
            'Insights will appear here after you have a few quiz attempts logged.';
        content = Text(
          message,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        );
      } else {
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              insights.map((line) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.insights_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          line,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        );
      }

      return AnalyticsCard(
        title: 'Personalized Insights',
        subtitle: 'Highlights generated from your recent activity',
        child: content,
      );
    });
  }
}

class AnalyticsCard extends StatelessWidget {
  const AnalyticsCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.03),
            offset: const Offset(0, 1),
            blurRadius: 0,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.02),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            offset: const Offset(0, 12),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class AnalyticsUnlockTube extends StatelessWidget {
  const AnalyticsUnlockTube({
    super.key,
    required this.title,
    required this.message,
    required this.current,
    required this.required,
    required this.progress,
    this.accentColor,
  });

  final String title;
  final String message;
  final int current;
  final int required;
  final double progress;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final Color accent = accentColor ?? colorScheme.primary;
    final double clampedProgress = progress.clamp(0, 1);
    final String progressLabel = '$current / $required';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          height: 128,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  color: accent.withValues(alpha: 0.08),
                ),
              ),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                heightFactor: clampedProgress,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [accent, accent.withValues(alpha: 0.45)],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Text(
                    progressLabel,
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

double _suggestLeftInterval(List<int> counts) {
  final int maxVal =
      counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);
  if (maxVal <= 4) return 1;
  if (maxVal <= 10) return 2;
  if (maxVal <= 20) return 5;
  return (maxVal / 4).ceilToDouble();
}

String _hourLabel(int h) {
  if (h == 0) return '00:00';
  if (h == 12) return '12:00';
  if (h < 12) return '${h.toString().padLeft(2, '0')}:00';
  return '${h.toString().padLeft(2, '0')}:00';
}

class _PeriodSelectorMobile extends StatelessWidget {
  final HubController controller;
  const _PeriodSelectorMobile({required this.controller});

  String _ordinal(int n) {
    if (n == 1) return '1st';
    if (n == 2) return '2nd';
    if (n == 3) return '3rd';
    return '${n}th';
  }

  String _dayLabel(DateTime d) {
    return DateFormat('E, d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Obx(() {
      final int tab = controller.currentTabIndex.value;
      late String label;
      if (tab == 0) {
        label = _dayLabel(controller.selectedDay.value);
      } else if (tab == 1) {
        label = '${_ordinal(controller.selectedWeekOfMonth.value)} week';
      } else {
        final monthName = DateFormat('MMMM').format(
          DateTime(
            controller.selectedYear.value,
            controller.selectedMonth.value,
          ),
        );
        label = monthName;
      }

      return PopupMenuButton<int>(
        onSelected: (value) async {
          if (tab == 0) {
            // Not used; we'll open date picker instead below
          } else if (tab == 1) {
            await controller.setWeekOfMonth(value);
          } else {
            await controller.setMonth(value);
          }
        },
        itemBuilder: (ctx) {
          if (tab == 1) {
            return List.generate(4, (i) {
              final w = i + 1;
              return PopupMenuItem<int>(
                value: w,
                child: Text('${_ordinal(w)} week'),
              );
            });
          }
          if (tab == 2) {
            return List.generate(12, (i) {
              final m = i + 1;
              final name = DateFormat(
                'MMMM',
              ).format(DateTime(controller.selectedYear.value, m));
              return PopupMenuItem<int>(value: m, child: Text(name));
            });
          }
          // Day tab: we won’t show menu items; we'll intercept onOpened to show date picker
          return <PopupMenuEntry<int>>[
            const PopupMenuItem<int>(
              enabled: false,
              height: 0,
              child: SizedBox.shrink(),
            ),
          ];
        },
        onOpened: () async {
          if (controller.currentTabIndex.value == 0) {
            final now = controller.selectedDay.value;
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(now.year - 1, 1, 1),
              lastDate: DateTime(now.year + 1, 12, 31),
              helpText: 'Select day',
            );
            if (picked != null) {
              await controller.setDay(picked);
            }
          }
        },
        position: PopupMenuPosition.under,
        tooltip: '',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      );
    });
  }
}
