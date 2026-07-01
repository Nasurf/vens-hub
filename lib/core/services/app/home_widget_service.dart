import 'package:vens_hub/data/models/timetable_model.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:vens_hub/domain/repositories/schedule_repository.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:get/get.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

/// Simple facade to manage Home Screen Widgets (Android AppWidget + iOS WidgetKit)
class HomeScreenWidgetService {
  static const String _androidProvider = 'EngineeringHubWidgetProvider';

  // If you name your iOS Widget extension target differently, update this:
  static const String _iosWidgetName = 'EngineeringHubWidgets';
  bool _started = false;
  Worker? _w1;
  Worker? _w2;

  /// Update the widget with today's schedule (multiple events) and highlight next class.
  /// On Android, the widget shows a scrollable list. On iOS, we maintain
  /// backwards compatibility by still setting the single-event fields the
  /// existing WidgetKit may use.
  Future<void> updateWithNextClass() async {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      developer.log(
        'HomeScreenWidgetService: Skipping update - unsupported platform',
      );
      return;
    }

    if (!Get.isRegistered<ScheduleRepository>()) {
      developer.log(
        'HomeScreenWidgetService: ScheduleRepository not registered, skipping update',
      );
      return;
    }

    try {
      developer.log('HomeScreenWidgetService: Starting widget update');
      final repo = Get.find<ScheduleRepository>();
      await repo.ensureInitialized();
      final now = DateTime.now();

      TimeTableModel? pickNext(List<TimeTableModel> list, DateTime now) {
        for (final e in list) {
          if (e.endTime.isAfter(now)) return e;
        }
        return null;
      }

      TimeTableModel? next;
      TimeTableModel? ongoing;
      final List<TimeTableModel> today = repo.getCombinedEventsForDay(now)
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      final academic =
          today
              .where((e) => (e.eventType == null || e.eventType == 'academic'))
              .toList();
      next = pickNext(academic, now) ?? pickNext(today, now);
      // Ongoing = first class that already started and not yet ended
      for (final e in academic.isNotEmpty ? academic : today) {
        if (now.isAfter(e.startTime) && now.isBefore(e.endTime)) {
          ongoing = e;
          break;
        }
      }

      if (next == null) {
        for (int i = 1; i <= 6 && next == null; i++) {
          final d = now.add(Duration(days: i));
          final list = repo.getCombinedEventsForDay(d)
            ..sort((a, b) => a.startTime.compareTo(b.startTime));
          final acad =
              list
                  .where(
                    (e) => (e.eventType == null || e.eventType == 'academic'),
                  )
                  .toList();
          next = pickNext(acad, d) ?? pickNext(list, d);
        }
      }

      String title;
      String time;
      String venue;

      if (next == null) {
        title = 'No upcoming class';
        time = 'Enjoy your day!';
        venue = '';
      } else {
        final isToday =
            next.startTime.year == now.year &&
            next.startTime.month == now.month &&
            next.startTime.day == now.day;
        final dayPrefix =
            isToday ? '' : '${DateFormat.E().format(next.startTime)} ';
        final isOngoing =
            now.isAfter(next.startTime) && now.isBefore(next.endTime);
        title =
            next.course?.isNotEmpty == true ? next.course! : 'Upcoming Class';
        time =
            isOngoing
                ? '${dayPrefix}Now • until ${DateFormat.jm().format(next.endTime)}'
                : '$dayPrefix${DateFormat.jm().format(next.startTime)} - ${DateFormat.jm().format(next.endTime)}';
        venue = next.venue ?? '';
      }

      // Persist single-event data (backward compatible / iOS)
      await HomeWidget.saveWidgetData<String>('eh_title', title);
      await HomeWidget.saveWidgetData<String>('eh_time', time);
      await HomeWidget.saveWidgetData<String>('eh_venue', venue);

      // Persist today's events as JSON for Android collection widget
      final eventsJson =
          today.map((e) {
            final bool isToday =
                e.startTime.year == now.year &&
                e.startTime.month == now.month &&
                e.startTime.day == now.day;
            final bool isOngoing =
                now.isAfter(e.startTime) && now.isBefore(e.endTime);
            String timeLabel;
            if (e.allDay == true) {
              timeLabel =
                  isToday
                      ? 'All day'
                      : '${DateFormat.E().format(e.startTime)} • All day';
            } else {
              final start = DateFormat.jm().format(e.startTime);
              final end = DateFormat.jm().format(e.endTime);
              final dayPrefix =
                  isToday ? '' : '${DateFormat.E().format(e.startTime)} ';
              timeLabel =
                  isOngoing
                      ? '${dayPrefix}Now • until $end'
                      : '$dayPrefix$start - $end';
            }
            final displayTitle =
                e.course?.isNotEmpty == true
                    ? e.course!
                    : (e.participants?.isNotEmpty == true
                        ? e.participants!
                        : 'Event');
            return {
              'title': displayTitle,
              'time': timeLabel,
              if (e.venue?.isNotEmpty == true) 'venue': e.venue,
            };
          }).toList();
      await HomeWidget.saveWidgetData<String>(
        'eh_events',
        jsonEncode(eventsJson),
      );

      // Persist compact pill widget fields (fixed-size widget)
      String prettyTimeRange(TimeTableModel e) {
        if (e.allDay == true) return 'All day';
        final s = DateFormat.jm().format(e.startTime);
        final en = DateFormat.jm().format(e.endTime);
        return '$s - $en';
      }

      final String pillNowTitle =
          ongoing?.course?.isNotEmpty == true
              ? ongoing!.course!
              : (ongoing?.participants?.isNotEmpty == true
                  ? ongoing!.participants!
                  : (ongoing != null ? 'Ongoing class' : 'No ongoing class'));
      final String pillNowTime =
          ongoing == null ? '' : prettyTimeRange(ongoing);

      final String pillNextTitle =
          next?.course?.isNotEmpty == true
              ? next!.course!
              : (next?.participants?.isNotEmpty == true
                  ? next!.participants!
                  : (next != null ? 'Upcoming class' : 'No upcoming class'));
      final String pillNextTime = next == null ? '' : prettyTimeRange(next);

      await HomeWidget.saveWidgetData<String>('pill_now_title', pillNowTitle);
      await HomeWidget.saveWidgetData<String>('pill_now_time', pillNowTime);
      await HomeWidget.saveWidgetData<String>('pill_next_title', pillNextTitle);
      await HomeWidget.saveWidgetData<String>('pill_next_time', pillNextTime);

      // Trigger a refresh
      await HomeWidget.updateWidget(
        name: _androidProvider,
        iOSName: _iosWidgetName,
      );
      // Also update the new pill widget provider
      await HomeWidget.updateWidget(
        name: 'EngineeringHubPillWidgetProvider',
        iOSName: _iosWidgetName,
      );

      developer.log(
        'HomeScreenWidgetService: Widget update completed with ${today.length} events',
      );
      developer.log('HomeScreenWidgetService: Title: $title, Time: $time');
    } catch (e, stackTrace) {
      developer.log(
        'HomeScreenWidgetService: Error updating widget',
        error: e,
        stackTrace: stackTrace,
      );
      // Even on error, try to set default data so widget shows something
      try {
        await HomeWidget.saveWidgetData<String>('eh_title', 'Engineering Hub');
        await HomeWidget.saveWidgetData<String>('eh_time', 'Tap to open app');
        await HomeWidget.saveWidgetData<String>('eh_venue', '');
        await HomeWidget.saveWidgetData<String>('eh_events', '[]');
        await HomeWidget.updateWidget(
          name: _androidProvider,
          iOSName: _iosWidgetName,
        );
        developer.log('HomeScreenWidgetService: Set fallback widget data');
      } catch (fallbackError) {
        developer.log(
          'HomeScreenWidgetService: Failed to set fallback data',
          error: fallbackError,
        );
      }
    }
  }

  void startAutoUpdateIfPossible() {
    if (_started) {
      developer.log('HomeScreenWidgetService: Auto-update already started');
      return;
    }

    if (!Get.isRegistered<ScheduleRepository>()) {
      developer.log(
        'HomeScreenWidgetService: ScheduleRepository not registered, cannot start auto-update',
      );
      return;
    }

    try {
      final repo = Get.find<ScheduleRepository>();
      _w1 = ever(repo.timeTableData, (_) {
        developer.log(
          'HomeScreenWidgetService: Timetable data changed, updating widget',
        );
        updateWithNextClass();
      });
      _w2 = ever(repo.userEvents, (_) {
        developer.log(
          'HomeScreenWidgetService: User events changed, updating widget',
        );
        updateWithNextClass();
      });
      _started = true;
      developer.log(
        'HomeScreenWidgetService: Auto-update started successfully',
      );
    } catch (e, stackTrace) {
      developer.log(
        'HomeScreenWidgetService: Error starting auto-update',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Stop auto-update by disposing workers
  void stopAutoUpdate() {
    if (!_started) {
      developer.log(
        'HomeScreenWidgetService: Auto-update not started, nothing to stop',
      );
      return;
    }

    try {
      _w1?.dispose();
      _w2?.dispose();
      _w1 = null;
      _w2 = null;
      _started = false;
      developer.log(
        'HomeScreenWidgetService: Auto-update stopped successfully',
      );
    } catch (e, stackTrace) {
      developer.log(
        'HomeScreenWidgetService: Error stopping auto-update',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Dispose of all resources
  void dispose() {
    developer.log('HomeScreenWidgetService: Disposing service');
    stopAutoUpdate();
  }
}

// Optional background callback for Android (periodic widget updates)
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? data) async {
  // For now, do nothing heavy. Your app can fetch from cache/API if needed.
}
