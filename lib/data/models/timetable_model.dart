import 'package:cloud_firestore/cloud_firestore.dart';

class TimeTableModel {
  final String? id;
  final String title;
  final String? course;
  final String? venue;
  final String? participants;
  final DateTime startTime;
  final DateTime endTime;
  final String? eventType; // e.g., 'academic' | 'leisure'
  final bool? allDay; // all-day event indicator
  final String? repeatRule; // e.g., 'none' | 'daily' | 'weekly' | 'monthly'
  final int? reminderMinutesBefore; // e.g., 10, 30, 60
  final bool isPersonal;

  TimeTableModel({
    this.id,
    required this.title,
    this.course,
    this.venue,
    this.participants,
    required this.startTime,
    required this.endTime,
    this.eventType,
    this.allDay,
    this.repeatRule,
    this.reminderMinutesBefore,
    this.isPersonal = false,
  });

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) {
      throw ArgumentError('start_time/end_time cannot be null');
    }
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      // Try ISO first, then HH:mm fallback anchored to 2000-01-01
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
    // Support maps like {hour: 10, minute: 30}
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
    throw ArgumentError('Unsupported time format: ${value.runtimeType}');
  }

  factory TimeTableModel.fromJson(Map<String, dynamic> json) {
    return TimeTableModel(
      id: json['id'] as String?,
      title: json['title'] as String,
      course: json['course'] as String?,
      venue: json['venue'] as String?,
      participants: json['participants'] as String?,
      startTime: _parseDateTime(json['start_time']),
      endTime: _parseDateTime(json['end_time']),
      eventType: json['event_type'] as String?,
      allDay: json['all_day'] as bool?,
      repeatRule: json['repeat_rule'] as String?,
      reminderMinutesBefore:
          (json['reminder_minutes_before'] is int)
              ? json['reminder_minutes_before'] as int
              : int.tryParse('${json['reminder_minutes_before']}'),
      isPersonal: json['is_personal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'course': course,
      'venue': venue,
      'participants': participants,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      if (eventType != null) 'event_type': eventType,
      if (allDay != null) 'all_day': allDay,
      if (repeatRule != null) 'repeat_rule': repeatRule,
      if (reminderMinutesBefore != null)
        'reminder_minutes_before': reminderMinutesBefore,
      'is_personal': isPersonal,
    };
  }

  TimeTableModel copyWith({
    String? id,
    String? title,
    String? course,
    String? venue,
    String? participants,
    DateTime? startTime,
    DateTime? endTime,
    String? eventType,
    bool? allDay,
    String? repeatRule,
    int? reminderMinutesBefore,
    bool? isPersonal,
  }) {
    return TimeTableModel(
      id: id ?? this.id,
      title: title ?? this.title,
      course: course ?? this.course,
      venue: venue ?? this.venue,
      participants: participants ?? this.participants,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      eventType: eventType ?? this.eventType,
      allDay: allDay ?? this.allDay,
      repeatRule: repeatRule ?? this.repeatRule,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      isPersonal: isPersonal ?? this.isPersonal,
    );
  }
}
