import 'dart:developer';
import 'package:get/get.dart';
import 'package:vens_hub/core/legacy_brain/timetable.dart';
import 'package:vens_hub/data/models/timetable_model.dart';
import 'package:vens_hub/core/services/data/firestore_service.dart';
import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/core/services/local_storage/user_cache_service.dart';
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart';

class ScheduleRepository extends GetxController {
  static get find => Get.find();

  RxList<TimeTableModel> timeTableData = <TimeTableModel>[].obs;
  RxList<TimeTableModel> userEvents = <TimeTableModel>[].obs;
  RxList<TimeTableModel> academicEvents = <TimeTableModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasLoadedOnce = false.obs;
  final RxnString loadError = RxnString();
  Future<void>? _ongoingLoad;
  // Keys in the form 'tt_<id>' for timetable and 'ac_<id>' for academic
  final RxList<String> _hiddenKeys = <String>[].obs;
  final _firestore = di.sl<FireStoreServices>();
  final _userCache = di.sl<UserCacheService>();
  final _authRepo = di.sl<AuthRepository>();

  // Add this method to filter events by date
  List<TimeTableModel> getEventsForDay(DateTime date) {
    final dayName = _getDayName(date.weekday).toLowerCase();
    return timeTableData
        .where((event) => event.title.toLowerCase() == dayName)
        .toList();
  }

  @override
  void onReady() {
    ensureInitialized();
  }

  /// Force refresh timetable and user events from Firestore.
  Future<void> refreshFromServer() async {
    await ensureInitialized(forceRefresh: true);
  }

  Future<void> ensureInitialized({bool forceRefresh = false}) async {
    if (_ongoingLoad != null) {
      if (forceRefresh) {
        await _ongoingLoad;
        return ensureInitialized(forceRefresh: true);
      }
      return _ongoingLoad!;
    }

    if (!forceRefresh && hasLoadedOnce.value) {
      return;
    }

    final future = _load();
    _ongoingLoad = future;
    await future.whenComplete(() => _ongoingLoad = null);
  }

  Future<void> _load() async {
    isLoading.value = true;
    loadError.value = null;
    try {
      String? department;
      String? level;

      // Prefer cached user
      final cached = await _userCache.getCachedUserData();
      if (cached != null) {
        department = cached.department;
        level = cached.level;
      } else {
        final either = await _authRepo.getCurrentUser();
        either.fold((_) {}, (user) {
          if (user != null) {
            department = user.department;
            level = user.level;
          }
        });
      }

      if (department == null ||
          level == null ||
          department!.isEmpty ||
          level!.isEmpty) {
        // No user context: clear timetable but still proceed to load
        // academic calendar (global) and any user-specific events.
        timeTableData.clear();
      } else {
        // Normalize level e.g., 400L -> 400
        level = level!.replaceAll('L', '').trim();

        // Fetch timetable from Firestore
        final raw = await _firestore.getTimetableEntries(
          departmentCode: department!,
          level: level!,
        );

        bool needsReseed = false;
        if (raw.isEmpty) {
          needsReseed = true;
        } else {
          // Check for "bad" data: title is day name, but course is empty
          // Only relevant if we have seed data for this dept/level (EEE 400)
          if (department == 'EEE' && level == '400') {
            final isBad = raw.any((d) {
              final t = (d['title'] as String? ?? '').toLowerCase();
              final days = [
                'monday',
                'tuesday',
                'wednesday',
                'thursday',
                'friday',
                'saturday',
                'sunday',
              ];
              // If the title is EXACTLY a day name, it's the old legacy format.
              // Real events might be "Monday Class" but not just "monday".
              return days.contains(t);
            });
            if (isBad) needsReseed = true;
          }
        }

        if (needsReseed) {
          // Seed from legacy map for EEE 400 if empty or bad
          if (department == 'EEE' && level == '400') {
            final seed = _convertTimetableToFirestoreSeed(timetable);
            await _firestore.replaceTimetable(
              departmentCode: department!,
              level: level!,
              entries: seed,
            );
            final seeded = await _firestore.getTimetableEntries(
              departmentCode: department!,
              level: level!,
            );
            timeTableData.assignAll(seeded.map(TimeTableModel.fromJson));
          } else {
            timeTableData.clear();
          }
        } else {
          timeTableData.assignAll(raw.map(TimeTableModel.fromJson));
        }
      }

      // Fetch user events
      final cachedUser = cached;
      final userId = cachedUser?.id;
      if (userId != null && userId.isNotEmpty) {
        final userRaw = await _firestore.getUserEvents(uid: userId);
        userEvents.assignAll(
          userRaw.map(
            (json) => TimeTableModel.fromJson(json).copyWith(isPersonal: true),
          ),
        );
      } else {
        userEvents.clear();
      }

      // Fetch academic calendar for the active session
      // Default to 2025/2026 for now; can be made dynamic or via Remote Config
      const String sessionLabel = '2025/2026';
      final String sessionId = sessionLabel.replaceAll('/', '_');
      try {
        final calRaw = await _firestore.getAcademicCalendarEvents(
          sessionId: sessionId,
        );
        academicEvents.assignAll(
          calRaw.map((json) {
            final model = TimeTableModel.fromJson(json);
            // Normalize 'academic_calendar' to 'academic' for consistency
            if (model.eventType == 'academic_calendar') {
              return model.copyWith(eventType: 'academic');
            }
            return model;
          }),
        );
      } catch (e) {
        // If not found or permission denied, ignore silently to avoid breaking schedule
        academicEvents.clear();
      }

      // Load hidden schedule (per-user hides of non-user events)
      if (userId != null && userId.isNotEmpty) {
        try {
          final hidden = await _firestore.getHiddenScheduleEvents(uid: userId);
          final keys =
              hidden
                  .map((e) {
                    final src = (e['source'] as String?) ?? '';
                    final eid = (e['eventId'] as String?) ?? '';
                    return '${src}_$eid';
                  })
                  .where((k) => k.length > 3)
                  .toList();
          _hiddenKeys.assignAll(keys);
        } catch (e) {
          _hiddenKeys.clear();
        }
      } else {
        _hiddenKeys.clear();
      }
    } catch (e) {
      log('ScheduleRepository init error: $e');
      loadError.value = e.toString();
      // Do not fallback to legacy globally. Show nothing on failure.
      timeTableData.clear();
      userEvents.clear();
      academicEvents.clear();
      _hiddenKeys.clear();
    } finally {
      hasLoadedOnce.value = true;
      isLoading.value = false;
    }
  }

  // Removed unused legacy conversion; Firestore is the single source of truth.

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  // Combined events for a day (timetable + user events)
  List<TimeTableModel> getCombinedEventsForDay(DateTime date) {
    // Timetable events (department schedule) already keyed by weekday title
    // We must project them onto the specific 'date' so they have the correct year/month/day
    final baseRaw = getEventsForDay(date);
    final List<TimeTableModel> base =
        baseRaw.map((e) {
          final start = DateTime(
            date.year,
            date.month,
            date.day,
            e.startTime.hour,
            e.startTime.minute,
          );
          final end = DateTime(
            date.year,
            date.month,
            date.day,
            e.endTime.hour,
            e.endTime.minute,
          );

          // Since these are timetable events, 'title' is the day name (e.g. 'monday').
          // We should NEVER display the day name as the event title.
          // Always use the course name, or a generic fallback if missing.
          final String displayTitle =
              (e.course != null && e.course!.trim().isNotEmpty)
                  ? e.course!
                  : 'Class Session';

          return e.copyWith(
            startTime: start,
            endTime: end,
            title: displayTitle,
            eventType: e.eventType ?? 'class',
            isPersonal: false,
          );
        }).toList();

    // Academic calendar events: exact date match
    final List<TimeTableModel> academicForDay =
        academicEvents
            .where(
              (e) =>
                  e.startTime.year == date.year &&
                  e.startTime.month == date.month &&
                  e.startTime.day == date.day,
            )
            .map((e) {
              // Fix title for academic events too (often stored in 'course')
              final String displayTitle =
                  (e.course != null && e.course!.trim().isNotEmpty)
                      ? e.course!
                      : e.title;
              return e.copyWith(title: displayTitle, isPersonal: false);
            })
            .toList();

    // Expand personal events with simple recurrence rules without writing back to Firestore
    final List<TimeTableModel> personalExpanded = [];
    for (final e in userEvents) {
      final String repeat = (e.repeatRule ?? 'none').toLowerCase();

      // Quickly reject when repeat is none but stored weekday doesn't match selected day
      if (repeat == 'none') {
        // Include only exact date match for non-repeating personal events
        if (e.startTime.year == date.year &&
            e.startTime.month == date.month &&
            e.startTime.day == date.day) {
          personalExpanded.add(e);
        }
        continue;
      }

      bool include = false;
      switch (repeat) {
        case 'daily':
          include = true;
          break;
        case 'weekly':
          include = e.startTime.weekday == date.weekday;
          break;
        case 'monthly':
          include = e.startTime.day == date.day;
          break;
        default:
          include = false;
      }

      if (!include) continue;

      // Compute instance occurrence at target date preserving time-of-day and duration
      final Duration dur = e.endTime.difference(e.startTime);
      final int startHour = e.allDay == true ? 0 : e.startTime.hour;
      final int startMin = e.allDay == true ? 0 : e.startTime.minute;
      final DateTime startAt = DateTime(
        date.year,
        date.month,
        date.day,
        startHour,
        startMin,
      );
      final DateTime endAt =
          e.allDay == true
              ? DateTime(date.year, date.month, date.day, 23, 59)
              : startAt.add(dur);

      personalExpanded.add(
        e.copyWith(startTime: startAt, endTime: endAt, isPersonal: true),
      );
    }

    // Apply per-user hides
    final hiddenTt =
        _hiddenKeys
            .where((k) => k.startsWith('tt_'))
            .map((k) => k.substring(3))
            .toSet();
    final hiddenAc =
        _hiddenKeys
            .where((k) => k.startsWith('ac_'))
            .map((k) => k.substring(3))
            .toSet();

    base.removeWhere((e) => e.id != null && hiddenTt.contains(e.id));
    academicForDay.removeWhere((e) => e.id != null && hiddenAc.contains(e.id));

    final List<TimeTableModel> combined = [
      ...base,
      ...academicForDay,
      ...personalExpanded,
    ];

    // Add universal break time for weekdays (Monday-Friday)
    // IMPORTANT: Use year 2000 to match timetable events from Firestore
    if (date.weekday >= 1 && date.weekday <= 5) {
      final breakStart = DateTime(2000, 1, 1, 12, 30);
      final breakEnd = DateTime(2000, 1, 1, 13, 30);

      final breakEvent = TimeTableModel(
        id: 'break_time',
        title: 'LUNCH BREAK',
        course: 'BREAK',
        venue: 'Cafeteria / Outdoors',
        participants: '',
        startTime: breakStart,
        endTime: breakEnd,
        isPersonal: false,
      );

      combined.add(breakEvent);
    }

    combined.sort((a, b) => a.startTime.compareTo(b.startTime));

    return combined;
  }

  Future<void> hideNonUserEvent({
    required String source, // 'tt' | 'ac'
    required String eventId,
  }) async {
    final cachedUser = await _userCache.getCachedUserData();
    final uid = cachedUser?.id;
    final key = '${source}_$eventId';
    if (_hiddenKeys.contains(key)) return;
    _hiddenKeys.add(key);
    if (uid == null || uid.isEmpty) {
      return; // session-only hide for guests
    }
    try {
      await _firestore.hideScheduleEvent(
        uid: uid,
        source: source,
        eventId: eventId,
      );
    } catch (_) {
      // On failure, revert local add
      _hiddenKeys.remove(key);
      rethrow;
    }
  }

  Future<void> unhideNonUserEvent({
    required String source, // 'tt' | 'ac'
    required String eventId,
  }) async {
    final cachedUser = await _userCache.getCachedUserData();
    final uid = cachedUser?.id;
    final key = '${source}_$eventId';
    _hiddenKeys.remove(key);
    if (uid == null || uid.isEmpty) {
      return;
    }
    try {
      await _firestore.unhideScheduleEvent(
        uid: uid,
        source: source,
        eventId: eventId,
      );
    } catch (_) {
      // On failure, restore locally
      if (!_hiddenKeys.contains(key)) {
        _hiddenKeys.add(key);
      }
      rethrow;
    }
  }

  Future<TimeTableModel> addUserEvent(TimeTableModel event) async {
    final cachedUser = await _userCache.getCachedUserData();
    final uid = cachedUser?.id;
    if (uid == null || uid.isEmpty) {
      userEvents.add(event);
      return event;
    }
    final id = await _firestore.addUserEvent(uid: uid, event: event.toJson());
    final saved = event.copyWith(id: id);
    userEvents.add(saved);
    return saved;
  }

  Future<void> updateUserEvent(TimeTableModel event) async {
    final cachedUser = await _userCache.getCachedUserData();
    final uid = cachedUser?.id;
    if (uid == null || uid.isEmpty || event.id == null) {
      // Update locally only if we don't have an id/uid
      final index = userEvents.indexWhere((e) => identical(e, event));
      if (index != -1) userEvents[index] = event;
      return;
    }
    await _firestore.updateUserEvent(
      uid: uid,
      eventId: event.id!,
      event: event.toJson(),
    );
    final i = userEvents.indexWhere((e) => e.id == event.id);
    if (i != -1) userEvents[i] = event;
  }

  Future<void> deleteUserEvent(String eventId) async {
    final cachedUser = await _userCache.getCachedUserData();
    final uid = cachedUser?.id;
    if (uid == null || uid.isEmpty) {
      userEvents.removeWhere((e) => e.id == eventId);
      return;
    }
    await _firestore.deleteUserEvent(uid: uid, eventId: eventId);
    userEvents.removeWhere((e) => e.id == eventId);
  }

  List<Map<String, dynamic>> _convertTimetableToFirestoreSeed(
    Map<String, List<Map<String, dynamic>>> legacy,
  ) {
    final List<Map<String, dynamic>> seed = [];
    legacy.forEach((day, entries) {
      for (final entry in entries) {
        final start = entry['time'] as DateTime;
        final end = DateTime(
          start.year,
          start.month,
          start.day,
          start.hour + 2,
          start.minute,
        );
        seed.add({
          'title': day.toLowerCase(),
          'course': entry['course'] ?? '',
          'venue': entry['room'] ?? '',
          'participants': entry['teacher'] ?? '',
          'start_time': start.toIso8601String(),
          'end_time': end.toIso8601String(),
          'event_type': 'class',
        });
      }
    });
    return seed;
  }
}
