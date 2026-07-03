import 'dart:convert';
import 'dart:developer';

import 'package:flutter/services.dart' show rootBundle;
import 'package:vens_hub/core/legacy_brain/timetable.dart' as legacy;
import 'package:vens_hub/core/services/data/firestore_service.dart';

class TimetableAdmin {
  final FireStoreServices firestore;

  TimetableAdmin({required this.firestore});

  Future<void> replaceEEE400FromLegacy() async {
    final entries = _convertLegacyToEntries(legacy.timetable);
    await firestore.replaceTimetable(
      departmentCode: 'EEE',
      level: '400',
      entries: entries,
    );
  }

  Future<void> replaceFromJsonPath({
    required String jsonPath,
    required String departmentCode,
    required String level,
  }) async {
    final contents = await rootBundle.loadString(jsonPath);
    final decoded = jsonDecode(contents);
    final entries = _parseJsonToEntries(decoded);
    await firestore.replaceTimetable(
      departmentCode: departmentCode,
      level: level.replaceAll('L', '').trim(),
      entries: entries,
    );
  }

  Future<void> upsertFromJsonPath({
    required String jsonPath,
    required String departmentCode,
    required String level,
  }) async {
    final contents = await rootBundle.loadString(jsonPath);
    final decoded = jsonDecode(contents);
    final entries = _parseJsonToEntries(decoded);
    await firestore.upsertTimetableEntries(
      departmentCode: departmentCode,
      level: level.replaceAll('L', '').trim(),
      entries: entries,
    );
  }

  Future<void> deleteTimetable({
    required String departmentCode,
    required String level,
  }) async {
    await firestore.deleteTimetable(
      departmentCode: departmentCode,
      level: level.replaceAll('L', '').trim(),
    );
  }

  /// Uploads all timetables from a nested JSON file structured as:
  /// { "DEPT_CODE": { "LEVEL": { "Day": { "TimeSlot": [...classes] } } } }
  ///
  /// This is the format of `timetable_by_dept_level.json`.
  ///
  /// Returns a map of { "DEPT_LEVEL": entryCount } for each uploaded timetable.
  ///
  /// **NOTE: The file must be in assets/ and declared in pubspec.yaml**
  /// Use path like 'assets/timetable_by_dept_level.json'
  Future<Map<String, int>> uploadAllFromNestedJson({
    required String jsonPath,
    bool replace = true,
  }) async {
    log('Loading timetable JSON from assets: $jsonPath');
    final contents = await rootBundle.loadString(jsonPath);
    final Map<String, dynamic> root = jsonDecode(contents);
    final Map<String, int> results = {};

    for (final deptEntry in root.entries) {
      final String deptCode = deptEntry.key;
      final Map<String, dynamic> levels = Map<String, dynamic>.from(
        deptEntry.value,
      );

      for (final levelEntry in levels.entries) {
        final String level = levelEntry.key.replaceAll('L', '').trim();
        final Map<String, dynamic> days = Map<String, dynamic>.from(
          levelEntry.value,
        );

        final List<Map<String, dynamic>> entries = _parseDaysToEntries(days);

        if (entries.isEmpty) {
          log('Skipping ${deptCode}_$level: no entries found');
          continue;
        }

        log('Uploading ${entries.length} entries for ${deptCode}_$level');

        if (replace) {
          await firestore.replaceTimetable(
            departmentCode: deptCode,
            level: level,
            entries: entries,
          );
        } else {
          await firestore.upsertTimetableEntries(
            departmentCode: deptCode,
            level: level,
            entries: entries,
          );
        }

        results['${deptCode}_$level'] = entries.length;
      }
    }

    return results;
  }

  /// Parses the days -> time_slots -> classes structure into flat entries.
  List<Map<String, dynamic>> _parseDaysToEntries(Map<String, dynamic> days) {
    final List<Map<String, dynamic>> entries = [];

    for (final dayEntry in days.entries) {
      final String dayName = dayEntry.key.toLowerCase();
      final Map<String, dynamic> timeSlots = Map<String, dynamic>.from(
        dayEntry.value,
      );

      for (final slotEntry in timeSlots.entries) {
        final String timeSlot = slotEntry.key; // e.g., "10:30-11:30"
        final List<dynamic> classes = slotEntry.value as List<dynamic>;

        // Parse start and end times from the slot
        final times = timeSlot.split('-');
        if (times.length != 2) continue;

        final startTime = _parseTimeString(times[0].trim());
        final endTime = _parseTimeString(times[1].trim());

        for (final classData in classes) {
          final Map<String, dynamic> cls = Map<String, dynamic>.from(classData);

          entries.add({
            'title': dayName,
            'course': cls['code'] ?? '',
            'venue': cls['venue'] ?? '',
            'participants': cls['capacity']?.toString() ?? '',
            'start_time': startTime.toIso8601String(),
            'end_time': endTime.toIso8601String(),
            // Store raw data for reference if needed
            'raw_data': cls['raw'] ?? '',
          });
        }
      }
    }

    return entries;
  }

  /// Parses a time string like "10:30" or "7:00" into a DateTime.
  /// Assumes 12-hour format based on typical academic schedule:
  /// - 1:xx-7:xx: PM (afternoon/evening classes: 13:00-19:xx)
  /// - 8:00: PM (evening class: 20:00)
  /// - 8:30-11:59: AM (morning classes: 8:30-11:59)
  /// - 12:xx: PM (noon/afternoon: 12:xx)
  DateTime _parseTimeString(String time) {
    final parts = time.split(':');
    int hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    // Convert 12-hour to 24-hour format based on academic schedule pattern
    if (hour >= 1 && hour <= 7) {
      // 1:xx - 7:xx are all PM (afternoon/evening)
      hour += 12;
    } else if (hour == 8 && minute == 0) {
      // 8:00 is PM (evening class)
      hour += 12;
    }
    // 8:30-11:59 stay as AM (morning classes)
    // 12:xx stays as 12 (noon/afternoon, already PM in 24-hour)

    return DateTime(2000, 1, 1, hour, minute);
  }

  List<Map<String, dynamic>> _convertLegacyToEntries(
    Map<String, List<Map<String, dynamic>>> data,
  ) {
    final List<Map<String, dynamic>> seed = [];
    data.forEach((day, entries) {
      for (final entry in entries) {
        final DateTime start = entry['time'] as DateTime;
        final DateTime end = DateTime(
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
        });
      }
    });
    return seed;
  }

  List<Map<String, dynamic>> _parseJsonToEntries(dynamic root) {
    if (root is List) {
      return root
          .map<Map<String, dynamic>>(
            (e) => _normalizeEntry(Map<String, dynamic>.from(e)),
          )
          .toList();
    }
    if (root is Map<String, dynamic>) {
      // Expect weekday -> list
      final List<Map<String, dynamic>> out = [];
      for (final entry in root.entries) {
        final String day = entry.key.toString().toLowerCase();
        final value = entry.value;
        if (value is List) {
          for (final item in value) {
            final normalized = _normalizeEntry(Map<String, dynamic>.from(item));
            if (!normalized.containsKey('title')) {
              normalized['title'] = day;
            }
            out.add(normalized);
          }
        } else if (value is Map<String, dynamic>) {
          final normalized = _normalizeEntry(Map<String, dynamic>.from(value));
          if (!normalized.containsKey('title')) {
            normalized['title'] = day;
          }
          out.add(normalized);
        }
      }
      return out;
    }
    throw ArgumentError(
      'Unsupported JSON root for timetable import. Expecting List or Map.',
    );
  }

  Map<String, dynamic> _normalizeEntry(Map<String, dynamic> e) {
    // Title
    final String? title = (e['title'] ?? e['day'])?.toString().toLowerCase();

    // Course
    final String? course = (e['course'] ?? e['subject'])?.toString();

    // Venue/Room
    final String? venue = (e['venue'] ?? e['room'])?.toString();

    // Participants/Teacher
    final String? participants =
        (e['participants'] ?? e['teacher'])?.toString();

    // Times
    final dynamic st = e['start_time'] ?? e['time'];
    final dynamic et = e['end_time'];
    final DateTime start = _parseTime(st);
    final DateTime end =
        et != null ? _parseTime(et) : start.add(const Duration(hours: 2));

    return {
      if (title != null) 'title': title,
      'course': course ?? '',
      'venue': venue ?? '',
      'participants': participants ?? '',
      'start_time': start.toIso8601String(),
      'end_time': end.toIso8601String(),
    };
  }

  DateTime _parseTime(dynamic value) {
    if (value == null) {
      throw ArgumentError('time value cannot be null');
    }
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        final parts = value.split(':');
        if (parts.length >= 2) {
          final hour = int.tryParse(parts[0]) ?? 0;
          final minute = int.tryParse(parts[1]) ?? 0;
          return DateTime(2000, 1, 1, hour, minute);
        }
        rethrow;
      }
    }
    if (value is Map<String, dynamic>) {
      final hour =
          value['hour'] is int
              ? value['hour'] as int
              : int.tryParse('${value['hour']}') ?? 0;
      final minute =
          value['minute'] is int
              ? value['minute'] as int
              : int.tryParse('${value['minute']}') ?? 0;
      return DateTime(2000, 1, 1, hour, minute);
    }
    return DateTime(2000, 1, 1);
  }
}
