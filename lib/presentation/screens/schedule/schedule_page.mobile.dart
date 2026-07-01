import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:vens_hub/domain/repositories/schedule_repository.dart';
import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/data/models/timetable_model.dart';
import 'package:vens_hub/core/services/notifications/notification_service.dart';
import 'package:vens_hub/core/services/notifications/notification_prefs_service.dart';
import 'package:vens_hub/core/services/app/home_widget_service.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';
import 'package:vens_hub/presentation/screens/schedule/widgets/event_form_dialog.dart';
import 'package:vens_hub/presentation/screens/schedule/widgets/modern_event_card.dart';

import '../../../core/services/analytics/analytics_service.dart';
import 'package:vens_hub/core/services/data/firestore_service.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:vens_hub/core/router/routes.dart';

class MobileScheduleScreen extends StatefulWidget {
  const MobileScheduleScreen({super.key});

  @override
  State<MobileScheduleScreen> createState() => _MobileScheduleScreenState();
}

class _MobileScheduleScreenState extends State<MobileScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final _scheduleRepo = Get.find<ScheduleRepository>();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    log("ScheduleScreen initState: Initial selectedDay = $_selectedDay");

    // Log schedule_viewed event
    try {
      di.sl<AnalyticsService>().logEvent(name: 'schedule_viewed');
    } catch (e) {
      log("Error logging schedule_viewed event: $e");
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleRepo.ensureInitialized();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use app theme instead of forced dark theme
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    log("ScheduleScreen build: Current selectedDay = $_selectedDay");

    return Obx(() {
      // Force Obx to track dependencies on these lists for reactive updates
      _scheduleRepo.userEvents.length;
      _scheduleRepo.timeTableData.length;
      _scheduleRepo.academicEvents.length;

      final isLoading = _scheduleRepo.isLoading.value;
      final error = _scheduleRepo.loadError.value;
      final hasLoaded = _scheduleRepo.hasLoadedOnce.value;

      final fab = FloatingActionButton.extended(
        onPressed: _onAddEventPressed,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Event'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
      );

      if (!hasLoaded && isLoading) {
        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: const Center(child: CircularProgressIndicator()),
          floatingActionButton: fab,
        );
      }

      if (!hasLoaded && error != null && error.isNotEmpty) {
        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: _buildInitialErrorState(theme, colorScheme, textTheme, error),
          floatingActionButton: fab,
        );
      }

      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Stack(
          children: [
            SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _scheduleRepo.refreshFromServer();
                  if (!mounted) return;
                  setState(() {});
                },
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildMissingDepartmentBanner(context),
                    ),

                    // Date Navigation Pill
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.chevron_left,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedDay = _selectedDay?.subtract(
                                        const Duration(days: 1),
                                      );
                                      _focusedDay = _selectedDay!;
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                  ),
                                  child: Text(
                                    DateFormat(
                                      'MMM d',
                                    ).format(_selectedDay ?? DateTime.now()),
                                    style: textTheme.titleMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.chevron_right,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedDay = _selectedDay?.add(
                                        const Duration(days: 1),
                                      );
                                      _focusedDay = _selectedDay!;
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Calendar Card
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.1,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildCalendar(
                            context,
                            colorScheme,
                            textTheme,
                          ),
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Events',
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildEventCount(colorScheme, textTheme),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildEventsTimeline(colorScheme, textTheme),
                    ),
                    // Add extra padding at bottom for FAB
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              ),
            ),
            if (isLoading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kDebugMode)
              FloatingActionButton.small(
                heroTag: 'debug_schedule',
                onPressed: () => Get.toNamed(AppRoutes.scheduleTest),
                backgroundColor: Colors.orange,
                child: const Icon(Icons.science, size: 20),
              ),
            if (kDebugMode) const SizedBox(height: 8),
            fab,
          ],
        ),
      );
    });
  }

  Widget _buildInitialErrorState(
    ThemeData theme,
    ColorScheme colorScheme,
    TextTheme textTheme,
    String message,
  ) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                'Unable to load schedule',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed:
                    () => _scheduleRepo.ensureInitialized(forceRefresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissingDepartmentBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (!Get.isRegistered<HomeController>()) return const SizedBox.shrink();
    return Obx(() {
      final user = Get.find<HomeController>().currentUser.value;
      final missing =
          (user?.department.isEmpty ?? true) || (user?.level.isEmpty ?? true);
      if (!missing) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Card(
          color: colorScheme.secondaryContainer,
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text(
              'Set your department to load your course calendar',
            ),
            subtitle: const Text(
              'Choose your department and level to see timetable events',
            ),
            trailing: TextButton(
              onPressed: () => _showSetDepartmentSheet(context),
              child: const Text('Set'),
            ),
          ),
        ),
      );
    });
  }

  Future<void> _showSetDepartmentSheet(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final hc = Get.find<HomeController>();
    final user = hc.currentUser.value;
    if (user == null || (user.id == null || user.id!.isEmpty)) {
      AppNotifier.warning(
        context: context,
        title: 'Not signed in',
        message: 'Please sign in to update your department',
      );
      return;
    }

    String? department;
    String? level;
    const Map<String, String> departments = {
      'EEE': 'Electrical Engineering',
      'MEE': 'Mechanical Engineering',
      'MCT': 'Mechatronics Engineering',
      'COE': 'Computer Engineering',
      'CHE': 'Chemical Engineering',
      'BME': 'Biomedical Engineering',
      'AAE': 'Aeronautics Engineering',
      'CVE': 'Civil Engineering',
      'PTE': 'Petroleum Engineering',
    };
    const levels = ['100', '200', '300', '400', '500'];

    final Widget content = StatefulBuilder(
      builder: (ctx, setState) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Department and Level',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: department,
                decoration: const InputDecoration(labelText: 'Department'),
                items:
                    departments.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text('${e.value} (${e.key})'),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => department = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: level,
                decoration: const InputDecoration(labelText: 'Level'),
                items:
                    levels
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (v) => setState(() => level = v),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if ((department == null || department!.isEmpty) ||
                        (level == null || level!.isEmpty)) {
                      AppNotifier.warning(
                        context: ctx,
                        title: 'Missing info',
                        message: 'Please choose both department and level',
                      );
                      return;
                    }
                    try {
                      await Get.find<FireStoreServices>().updateUserData(
                        user.id!,
                        {'department': department, 'level': level},
                      );
                      await hc.refreshUserDetails(forceRefresh: true);
                      await _scheduleRepo.refreshFromServer();
                      if (mounted) setState(() {});
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        AppNotifier.success(
                          context: ctx,
                          title: 'Updated',
                          message: 'Department and level saved',
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        AppNotifier.error(
                          context: ctx,
                          title: 'Error',
                          message: 'Failed to save: $e',
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (kIsWeb) {
      await showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Set Department and Level'),
              content: SingleChildScrollView(child: content),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder:
            (ctx) =>
                Padding(padding: const EdgeInsets.all(16.0), child: content),
      );
    }
  }

  Widget _buildEventCount(ColorScheme colorScheme, TextTheme textTheme) {
    return Obx(() {
      final events =
          _selectedDay != null
              ? _scheduleRepo.getCombinedEventsForDay(_selectedDay!)
              : <dynamic>[];

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${events.length} events',
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    });
  }

  Future<void> _onAddEventPressed() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: EventFormDialog(
            selectedDate: _selectedDay,
            onSave: (newEvent) async {
              try {
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder:
                      (c) => const Center(child: CircularProgressIndicator()),
                );

                final saved = await _scheduleRepo.addUserEvent(newEvent);

                // Update home widget
                try {
                  final svc = Get.put(
                    HomeScreenWidgetService(),
                    permanent: true,
                  );
                  await svc.updateWithNextClass();
                } catch (_) {}

                // Handle notifications
                final prefsSvc = Get.find<NotificationPrefsService>();
                if (prefsSvc.notificationsEnabled.value && saved.id != null) {
                  final notificationService = di.sl<NotificationService>();
                  await notificationService.scheduleEventStartNotification(
                    eventId: saved.id!,
                    eventStart: saved.startTime,
                    title: 'Event Started',
                    description: '${saved.title} is starting now',
                  );
                }

                if (context.mounted) {
                  Navigator.pop(context); // Pop loading
                }
                if (mounted) {
                  setState(() {});
                }
                if (context.mounted) {
                  AppNotifier.success(
                    context: context,
                    message: 'Event created successfully!',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Pop loading
                  AppNotifier.error(
                    context: context,
                    message: 'Failed to create event: $e',
                  );
                }
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildCalendar(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      availableCalendarFormats: const {
        CalendarFormat.month: 'Month',
        CalendarFormat.week: 'Week',
      },
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      eventLoader: (day) => _scheduleRepo.getCombinedEventsForDay(day),
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(_selectedDay, selectedDay)) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        }
      },
      headerStyle: HeaderStyle(
        titleCentered: true,
        formatButtonVisible: true,
        formatButtonShowsNext: false,
        formatButtonDecoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        formatButtonTextStyle: textTheme.labelMedium!.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
        titleTextFormatter: (date, locale) {
          return DateFormat('MMMM yyyy', locale?.toString()).format(date);
        },
        titleTextStyle: textTheme.titleLarge!.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        leftChevronIcon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.chevron_left_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        rightChevronIcon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.chevron_right_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: textTheme.labelMedium!.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        weekendStyle: textTheme.labelMedium!.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      calendarStyle: CalendarStyle(
        defaultTextStyle: textTheme.bodyMedium!.copyWith(
          color: colorScheme.onSurface,
        ),
        weekendTextStyle: textTheme.bodyMedium!.copyWith(
          color: colorScheme.primary.withValues(alpha: 0.8),
        ),
        outsideTextStyle: textTheme.bodyMedium!.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        todayDecoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.primary, width: 2),
        ),
        todayTextStyle: textTheme.bodyMedium!.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
        selectedDecoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        selectedTextStyle: textTheme.bodyMedium!.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
        markerDecoration: BoxDecoration(
          color: colorScheme.tertiary,
          shape: BoxShape.circle,
        ),
        markersMaxCount: 3,
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          if (events.isEmpty) return const SizedBox();

          final hasAcademic = events.any(
            (e) =>
                e is TimeTableModel &&
                e.eventType == 'academic' &&
                !e.isPersonal,
          );
          final hasClasses = events.any(
            (e) =>
                e is TimeTableModel &&
                e.eventType != 'academic' &&
                !e.isPersonal &&
                e.id != 'break_time',
          );
          final hasPersonal = events.any(
            (e) => e is TimeTableModel && e.isPersonal,
          );

          return Positioned(
            bottom: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasClasses)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (hasAcademic)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.yellow.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (hasPersonal)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      startingDayOfWeek: StartingDayOfWeek.sunday,
    );
  }

  Widget _buildEventsTimeline(ColorScheme colorScheme, TextTheme textTheme) {
    if (_selectedDay == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              "Select a day to see events",
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Obx(() {
      final events = _scheduleRepo.getCombinedEventsForDay(_selectedDay!);

      if (events.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_busy_rounded,
                  size: 48,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No events scheduled',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat.yMMMMd().format(_selectedDay!),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return _buildEventListTile(context, event, colorScheme, textTheme);
          },
        ),
      );
    });
  }

  Widget _buildEventListTile(
    BuildContext context,
    dynamic event,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (event is! TimeTableModel) return const SizedBox.shrink();
    return ModernEventCard(
      event: event,
      onEdit: () => _onEditEventPressed(event),
      onDelete: () => _onDeleteEventPressed(event),
    );
  }

  Future<void> _onEditEventPressed(TimeTableModel original) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: EventFormDialog(
            event: original,
            selectedDate: original.startTime,
            onSave: (updatedEvent) async {
              try {
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder:
                      (c) => const Center(child: CircularProgressIndicator()),
                );

                await _scheduleRepo.updateUserEvent(updatedEvent);

                // Update home widget
                try {
                  final svc = Get.put(
                    HomeScreenWidgetService(),
                    permanent: true,
                  );
                  await svc.updateWithNextClass();
                } catch (_) {}

                // Handle notifications
                final prefsSvc = Get.find<NotificationPrefsService>();
                if (prefsSvc.notificationsEnabled.value &&
                    updatedEvent.id != null) {
                  final notificationService = di.sl<NotificationService>();
                  // Cancel old notification first
                  await notificationService.cancelEventStartNotification(
                    eventId: original.id!,
                    eventStart: original.startTime,
                  );
                  await notificationService.cancelEventReminder(
                    eventId: original.id!,
                    eventStart: original.startTime,
                  );

                  await notificationService.scheduleEventStartNotification(
                    eventId: updatedEvent.id!,
                    eventStart: updatedEvent.startTime,
                    title: 'Event Started',
                    description: '${updatedEvent.title} is starting now',
                  );
                }

                if (context.mounted) {
                  Navigator.pop(context); // Pop loading
                  if (mounted) setState(() {});
                  AppNotifier.success(
                    context: context,
                    message: 'Event updated successfully!',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Pop loading
                  AppNotifier.error(
                    context: context,
                    message: 'Failed to update event: $e',
                  );
                }
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _onDeleteEventPressed(TimeTableModel event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Event?'),
            content: const Text('Are you sure you want to delete this event?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true && event.id != null) {
      try {
        await _scheduleRepo.deleteUserEvent(event.id!);
        if (mounted) {
          setState(() {});
          AppNotifier.success(context: context, message: 'Event deleted');
        }

        // Cancel notifications
        final notificationService = di.sl<NotificationService>();
        await notificationService.cancelEventStartNotification(
          eventId: event.id!,
          eventStart: event.startTime,
        );
        await notificationService.cancelEventReminder(
          eventId: event.id!,
          eventStart: event.startTime,
        );

        // Update home widget
        try {
          final svc = Get.put(HomeScreenWidgetService(), permanent: true);
          await svc.updateWithNextClass();
        } catch (_) {}
      } catch (e) {
        if (mounted) {
          AppNotifier.error(
            context: context,
            message: 'Failed to delete event',
          );
        }
      }
    }
  }
}
