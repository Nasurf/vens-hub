import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:animations/animations.dart';

import 'package:vens_hub/presentation/screens/schedule/widgets/event_details_dialog.dart';
import 'package:vens_hub/data/models/timetable_model.dart';

class ModernEventCard extends StatelessWidget {
  final dynamic event;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isPast;

  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const ModernEventCard({
    super.key,
    required this.event,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.isPast = false,
    this.margin,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final String title = event.title;
    final String? venue = event.venue;
    final DateTime? startTime = event.startTime;
    final DateTime? endTime = event.endTime;
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
        typeColor = Colors.amber; // Yellow for academic calendar events
        typeIcon = Icons.event_note_rounded;
        break;
      case 'class':
      default:
        typeColor = colorScheme.primary; // Department classes
        typeIcon = Icons.school_rounded;
        break;
    }

    if (isPast) {
      typeColor = colorScheme.outline;
    }

    String timeString = 'Time N/A';
    if (startTime != null && endTime != null) {
      timeString =
          '${DateFormat.jm().format(startTime)} - ${DateFormat.jm().format(endTime)}';
    } else if (startTime != null) {
      timeString = DateFormat.jm().format(startTime);
    }

    Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Color strip
        Container(
          width: 6,
          decoration: BoxDecoration(
            color: typeColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 14, color: typeColor),
                          const SizedBox(width: 4),
                          Text(
                            eventType.toUpperCase(),
                            style: textTheme.labelSmall?.copyWith(
                              color: typeColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (!isPast && startTime != null)
                      _buildTimeUntilBadge(startTime, colorScheme, textTheme),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    decoration: isPast ? TextDecoration.lineThrough : null,
                    color:
                        isPast
                            ? colorScheme.onSurface.withValues(alpha: 0.6)
                            : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeString,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (venue != null && venue.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          venue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );

    if (height == null) {
      content = IntrinsicHeight(child: content);
    }

    return OpenContainer<String?>(
      onClosed: (result) {
        final bool isPersonal =
            event is TimeTableModel
                ? (event as TimeTableModel).isPersonal
                : false;
        if (!isPersonal) return;

        if (result == 'edit') {
          onEdit?.call();
        } else if (result == 'delete') {
          onDelete?.call();
        }
      },
      openBuilder: (context, action) {
        return EventDetailsDialog(event: event);
      },
      closedElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      closedColor: Colors.transparent,
      closedBuilder: (context, openContainer) {
        return InkWell(
          onTap: onTap ?? openContainer,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: width,
            height: height,
            margin: margin ?? const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: content,
          ),
        );
      },
    );
  }

  Widget _buildTimeUntilBadge(
    DateTime startTime,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final now = DateTime.now();
    final diff = startTime.difference(now);

    if (diff.isNegative) return const SizedBox.shrink();

    String label;
    Color color;
    Color onColor;

    if (diff.inMinutes < 60) {
      label = 'In ${diff.inMinutes} min';
      color = colorScheme.errorContainer;
      onColor = colorScheme.onErrorContainer;
    } else if (diff.inHours < 24) {
      label = 'In ${diff.inHours} hr';
      color = colorScheme.primaryContainer;
      onColor = colorScheme.onPrimaryContainer;
    } else {
      label = 'In ${diff.inDays} days';
      color = colorScheme.surfaceContainerHighest;
      onColor = colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: onColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
