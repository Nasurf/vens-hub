import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vens_hub/data/models/timetable_model.dart';

class EventDetailsDialog extends StatelessWidget {
  final TimeTableModel event;

  const EventDetailsDialog({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final String title = event.title;
    final String? venue = event.venue;
    final DateTime startTime = event.startTime;
    final DateTime endTime = event.endTime;
    final String eventType = event.eventType ?? 'academic';

    Color typeColor;
    IconData typeIcon;

    switch (eventType) {
      case 'personal':
        typeColor = Colors.red;
        typeIcon = Icons.person_rounded;
        break;
      case 'leisure':
        typeColor = colorScheme.secondary;
        typeIcon = Icons.sports_esports_rounded;
        break;
      case 'academic':
        typeColor = Colors.amber;
        typeIcon = Icons.event_note_rounded;
        break;
      case 'class':
      default:
        typeColor = colorScheme.primary;
        typeIcon = Icons.school_rounded;
        break;
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (event.isPersonal) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => Navigator.pop(context, 'edit'),
              tooltip: 'Edit Event',
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, 'delete'),
              tooltip: 'Delete Event',
            ),
          ],
          const SizedBox(width: 8),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(typeIcon, size: 18, color: typeColor),
                  const SizedBox(width: 8),
                  Text(
                    eventType.toUpperCase(),
                    style: textTheme.labelMedium?.copyWith(
                      color: typeColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 32),
            _buildDetailRow(
              context,
              Icons.calendar_today_rounded,
              'Date',
              DateFormat('EEEE, MMMM d, y').format(startTime),
            ),
            const SizedBox(height: 24),
            _buildDetailRow(
              context,
              Icons.access_time_rounded,
              'Time',
              '${DateFormat.jm().format(startTime)} - ${DateFormat.jm().format(endTime)}',
            ),
            if (venue != null && venue.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildDetailRow(
                context,
                Icons.location_on_outlined,
                'Location',
                venue,
              ),
            ],
            const SizedBox(height: 24),
            _buildDetailRow(
              context,
              Icons.timer_outlined,
              'Duration',
              '${endTime.difference(startTime).inMinutes} minutes',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 24, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
