import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimetableEntry {
  final String title;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color color; // Optional: for visual distinction

  TimetableEntry({
    required this.title,
    required this.startTime,
    required this.endTime,
    this.color = Colors.blue, // Default color
  });

  // Helper to format time for display
  String get startTimeString => _formatTimeOfDay(startTime);
  String get endTimeString => _formatTimeOfDay(endTime);

  String _formatTimeOfDay(TimeOfDay tod) {
    // Use intl package for better localization if needed
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    final format = DateFormat.jm(); // Use 'HH:mm' for 24-hour format
    return format.format(dt);
  }

  // Calculate duration for display or layout (optional)
  Duration get duration => DateTime(
    0,
    1,
    1,
    endTime.hour,
    endTime.minute,
  ).difference(DateTime(0, 1, 1, startTime.hour, startTime.minute));
}
