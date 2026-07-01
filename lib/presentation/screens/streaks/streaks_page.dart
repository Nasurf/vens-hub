import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/core/services/local_storage/recent_quiz_service.dart';
import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/data/models/course_info.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vens_hub/core/services/data/firestore_service.dart';
import 'dart:async';

const Map<int, String> _weekdayLabels = {
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
};

class StreaksPage extends StatelessWidget {
  const StreaksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController home = Get.find<HomeController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: colorScheme.onSurface,
          iconTheme: IconThemeData(color: colorScheme.onSurface),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Streaks',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(width: 3, color: colorScheme.primary),
                  insets: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
                ),
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                labelStyle: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
                tabs: const [Tab(text: 'PERSONAL'), Tab(text: 'FRIENDS')],
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              // PERSONAL TAB
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Obx(() {
                  final int streak = home.streakCount.value;
                  final bool completedToday = home.hasCompletedToday.value;

                  final Color active = colorScheme.primary;
                  final Color inactive = colorScheme.outline;

                  // Helpers to lighten/darken a color
                  Color lighten(Color color, [double amount = 0.2]) {
                    final hsl = HSLColor.fromColor(color);
                    final hslLight = hsl.withLightness(
                      (hsl.lightness + amount).clamp(0.0, 1.0),
                    );
                    return hslLight.toColor();
                  }

                  // Color darken(Color color, [double amount = 0.2]) {
                  //   final hsl = HSLColor.fromColor(color);
                  //   final hslDark = hsl.withLightness(
                  //     (hsl.lightness - amount).clamp(0.0, 1.0),
                  //   );
                  //   return hslDark.toColor();
                  // }

                  final width = MediaQuery.of(context).size.width;
                  final double bigNumberSize = (width * 0.32).clamp(
                    96.0,
                    180.0,
                  );
                  final double bigIconSize = bigNumberSize * 1.2;
                  final bool isLight = theme.brightness == Brightness.light;

                  // CTA text should be a light version of the primary color (slightly darker than before)
                  final Color ctaTextColor = lighten(
                    colorScheme.primary,
                    isLight ? 0.22 : 0.18,
                  );
                  // Clock should be dark version in dark mode, and light version in light mode
                  // final Color clockTint = isLight
                  //     ? lighten(colorScheme.primary, 0.3)
                  //     : darken(colorScheme.primary, 0.3);

                  return StreamBuilder<DateTime>(
                    stream: Stream<DateTime>.periodic(
                      const Duration(minutes: 1),
                      (_) => DateTime.now(),
                    ),
                    initialData: DateTime.now(),
                    builder: (context, snapshot) {
                      final DateTime now = snapshot.data ?? DateTime.now();
                      final bool isAfterTenPm = now.hour >= 22;
                      final bool showDanger = !completedToday && isAfterTenPm;

                      final Color headerColor =
                          showDanger
                              ? Colors.red
                              : (completedToday ? active : inactive);
                      final Color textColor =
                          showDanger
                              ? Colors.red
                              : (completedToday
                                  ? active
                                  : theme.colorScheme.onSurfaceVariant);

                      int toEpoch(DateTime date) =>
                          DateUtils.dateOnly(date).millisecondsSinceEpoch;
                      final List<DateTime> completionHistory =
                          home.completionHistory.toList();
                      final Set<int> completionKeys =
                          completionHistory
                              .map((date) => toEpoch(date))
                              .toSet();
                      // Ensure today's completion reflects immediately, even if
                      // history is still loading or hasn't synced yet.
                      if (home.hasCompletedToday.value) {
                        completionKeys.add(toEpoch(now));
                      }
                      final DateTime today = DateUtils.dateOnly(now);
                      final bool isHistoryLoading = home.isHistoryLoading.value;
                      const int totalCalendarDays =
                          HomeController.streakCalendarDays;
                      final int halfSpan = (totalCalendarDays - 1) ~/ 2;
                      final DateTime firstCalendarDay = today.subtract(
                        Duration(days: halfSpan),
                      );
                      final List<DateTime> calendarDays = List.generate(
                        totalCalendarDays,
                        (index) => firstCalendarDay.add(Duration(days: index)),
                      );
                      final int completedInWindow =
                          calendarDays
                              .where(
                                (date) =>
                                    completionKeys.contains(toEpoch(date)),
                              )
                              .length;

                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Massive number + massive fire icon (centered)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // STREAKS HUB pill directly above the number
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: headerColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: headerColor.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'STREAKS HUB',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.8,
                                              color: headerColor,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '$streak',
                                        softWrap: false,
                                        style: TextStyle(
                                          fontSize: bigNumberSize,
                                          fontWeight: FontWeight.w900,
                                          height: 0.9,
                                          color: headerColor,
                                          letterSpacing: -1.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'day streak!',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            color: textColor,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 28),
                                Transform.translate(
                                  offset: Offset(0, -bigNumberSize * 0.21),
                                  child: Icon(
                                    Icons.local_fire_department_rounded,
                                    size: bigIconSize,
                                    color: headerColor,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 28),

                            // Call-to-action card with depth
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    theme.colorScheme.surfaceContainerHighest,
                                    theme.colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.92),
                                  ],
                                ),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.shadow.withValues(
                                      alpha: 0.06,
                                    ),
                                    blurRadius: 20,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.05,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: headerColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: SvgPicture.asset(
                                      'assets/svg/clock.svg',
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Keep your streak alive, jump back in the Hub for a quick quiz!',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.onSurface,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                        ),
                                        const SizedBox(height: 10),
                                        InkWell(
                                          onTap: () async {
                                            try {
                                              CourseInfo? targetCourse;

                                              // Fast path: use local recent title if available
                                              try {
                                                final recent =
                                                    di.sl<RecentQuizService>();
                                                final String? recentTitle =
                                                    await recent
                                                        .getMostRecentCourseTitle();
                                                if (recentTitle != null &&
                                                    recentTitle.isNotEmpty) {
                                                  targetCourse =
                                                      const CourseInfo(
                                                        id: '',
                                                        title: '',
                                                        code: '',
                                                        semester: [],
                                                        tags: [],
                                                        topics: [],
                                                        departmentCodes: [],
                                                      ).copyWith(
                                                        title: recentTitle,
                                                      );
                                                }
                                              } catch (_) {}

                                              // If no local cache, get only the title from remote attempts
                                              if (targetCourse == null) {
                                                final String? uid =
                                                    home.currentUser.value?.id;
                                                if (uid != null &&
                                                    uid.isNotEmpty) {
                                                  final String?
                                                  title = await FireStoreServices
                                                      .find
                                                      .getMostRecentQuizCourseTitle(
                                                        uid,
                                                      );
                                                  if (title != null &&
                                                      title.isNotEmpty) {
                                                    targetCourse =
                                                        const CourseInfo(
                                                          id: '',
                                                          title: '',
                                                          code: '',
                                                          semester: [],
                                                          tags: [],
                                                          topics: [],
                                                          departmentCodes: [],
                                                        ).copyWith(
                                                          title: title,
                                                        );
                                                  }
                                                }
                                              }

                                              // Final fallback: fetch all courses and use the first one
                                              if (targetCourse == null) {
                                                final List<CourseInfo> courses =
                                                    await FireStoreServices.find
                                                        .getAllCourseData();
                                                if (!context.mounted) return;
                                                if (courses.isEmpty) {
                                                  AppNotifier.warning(
                                                    context: context,
                                                    title: 'No Courses',
                                                    message:
                                                        'No courses are available at the moment.',
                                                  );
                                                  return;
                                                }
                                                targetCourse = courses.first;
                                              }

                                              // Navigate immediately. CoursePage hydrates topics after navigation.
                                              Get.toNamed(
                                                AppRoutes.coursePage,
                                                arguments: targetCourse,
                                              );
                                            } catch (e) {
                                              if (!context.mounted) return;
                                              AppNotifier.error(
                                                context: context,
                                                title: 'Error',
                                                message:
                                                    'Unable to navigate to quiz. Please try again.',
                                              );
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4.0,
                                            ),
                                            child: Text(
                                              'DO YOUR QUIZ',
                                              style: theme.textTheme.titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    color: ctaTextColor,
                                                    letterSpacing: 0.8,
                                                    fontSize: 18,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 22),

                            _StreakCalendar(
                              days: calendarDays,
                              completedDayKeys: completionKeys,
                              completedCount: completedInWindow,
                              theme: theme,
                              colorScheme: colorScheme,
                              today: today,
                              isLoading: isHistoryLoading,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ),
              // FRIENDS TAB (placeholder)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 64,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Friends streaks coming soon',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _StreakCalendar extends StatelessWidget {
  const _StreakCalendar({
    required this.days,
    required this.completedDayKeys,
    required this.completedCount,
    required this.theme,
    required this.colorScheme,
    required this.today,
    required this.isLoading,
  });

  final List<DateTime> days;
  final Set<int> completedDayKeys;
  final int completedCount;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final DateTime today;
  final bool isLoading;

  int _toKey(DateTime date) => DateUtils.dateOnly(date).millisecondsSinceEpoch;

  @override
  Widget build(BuildContext context) {
    final bool isLight = theme.brightness == Brightness.light;
    final int todayKey = _toKey(today);
    final List<List<DateTime>> rows = [];
    for (int index = 0; index < days.length; index += 7) {
      final int end = (index + 7) > days.length ? days.length : index + 7;
      rows.add(days.sublist(index, end));
    }
    final size = MediaQuery.of(context).size;
    final bool isCompact = size.width < 430;
    final double ringSize = isCompact ? 36 : 54;
    final double cellHeight = ringSize + (isCompact ? 56 : 78);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHighest.withValues(
              alpha: isLight ? 0.85 : 0.65,
            ),
            colorScheme.surfaceContainerHigh.withValues(alpha: 0.95),
          ],
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCompact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'STUDY CALENDAR',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$completedCount/${days.length} days completed',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'STUDY CALENDAR',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '$completedCount/${days.length} days completed',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child:
                isLoading && completedDayKeys.isEmpty
                    ? SizedBox(
                      key: const ValueKey('calendar-loading'),
                      height: cellHeight,
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    )
                    : Column(
                      key: const ValueKey('calendar-grid'),
                      children: [
                        for (
                          int rowIndex = 0;
                          rowIndex < rows.length;
                          rowIndex++
                        )
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: rowIndex == rows.length - 1 ? 0 : 18,
                            ),
                            child: SizedBox(
                              height: cellHeight,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final date in rows[rowIndex])
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Builder(
                                          builder: (_) {
                                            final int dayKey = _toKey(date);
                                            return _CalendarDay(
                                              date: date,
                                              studied: completedDayKeys
                                                  .contains(dayKey),
                                              isToday: dayKey == todayKey,
                                              isPast: dayKey < todayKey,
                                              theme: theme,
                                              colorScheme: colorScheme,
                                              ringSize: ringSize,
                                              height: cellHeight,
                                              compact: isCompact,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  for (
                                    int filler = rows[rowIndex].length;
                                    filler < 7;
                                    filler++
                                  )
                                    const Expanded(child: SizedBox.shrink()),
                                ],
                              ),
                            ),
                          ),
                        if (isLoading)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface.withValues(
                                      alpha: isLight ? 0.4 : 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          valueColor: AlwaysStoppedAnimation(
                                            colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Syncing streaks',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.studied,
    required this.isToday,
    required this.isPast,
    required this.theme,
    required this.colorScheme,
    required this.ringSize,
    required this.height,
    required this.compact,
  });

  final DateTime date;
  final bool studied;
  final bool isToday;
  final bool isPast;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final double ringSize;
  final double height;
  final bool compact;

  bool get _isFuture => !isToday && !isPast;

  @override
  Widget build(BuildContext context) {
    final String dayLabel = _weekdayLabels[date.weekday] ?? '';
    final Color labelColor =
        studied
            ? colorScheme.primary
            : isToday
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant.withValues(
              alpha: isPast ? 0.75 : 0.55,
            );

    return SizedBox(
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            dayLabel,
            style: (compact
                    ? theme.textTheme.labelSmall
                    : theme.textTheme.labelMedium)
                ?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
          ),
          SizedBox(height: compact ? 4 : 6),
          _buildDayNumber(),
          SizedBox(height: compact ? 8 : 14),
          _buildCompletionRing(),
        ],
      ),
    );
  }

  Widget _buildDayNumber() {
    final String text = '${date.day}';

    final base =
        compact ? theme.textTheme.labelLarge : theme.textTheme.bodyMedium;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color defaultColor =
        studied
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant.withValues(
              alpha: _isFuture ? 0.5 : 0.72,
            );
    final Color todayColor = isDark ? Colors.white : Colors.black;

    return Text(
      text,
      style: base?.copyWith(
        fontSize: compact ? 14 : base.fontSize,
        color: isToday ? todayColor : defaultColor,
        fontWeight:
            isToday
                ? FontWeight.w800
                : (studied ? FontWeight.w700 : FontWeight.w500),
      ),
    );
  }

  Widget _buildCompletionRing() {
    final double size = ringSize;
    final Color outer = colorScheme.primary;
    final Color middle = colorScheme.secondary;
    final Color inner =
        theme.brightness == Brightness.light
            ? colorScheme.tertiary
            : colorScheme.tertiaryContainer;
    final double inactiveAlpha = isPast ? 0.18 : 0.1;

    Widget ring(double dimension, Color color, double strokeWidth) {
      return Container(
        width: dimension,
        height: dimension,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: strokeWidth),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring(
            size,
            outer.withValues(alpha: studied ? 0.9 : inactiveAlpha),
            3.2,
          ),
          ring(
            size * 0.78,
            middle.withValues(alpha: studied ? 0.85 : inactiveAlpha * 0.8),
            3,
          ),
          ring(
            size * 0.56,
            inner.withValues(alpha: studied ? 0.75 : inactiveAlpha * 0.7),
            2.8,
          ),
          if (studied)
            Container(
              width: size * 0.42,
              height: size * 0.42,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.check_rounded,
                size: size * 0.3,
                color: colorScheme.primary,
              ),
            )
          else
            Container(
              width: size * 0.24,
              height: size * 0.24,
              decoration: BoxDecoration(
                color:
                    isToday
                        ? colorScheme.primary.withValues(alpha: 0.25)
                        : colorScheme.onSurfaceVariant.withValues(
                          alpha: _isFuture ? 0.12 : 0.18,
                        ),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
