part of '../schedule_test_page.dart';

class _AgendaView extends StatelessWidget {
  final ScheduleRepository scheduleRepo;

  const _AgendaView({required this.scheduleRepo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Obx(() {
      final upcomingEvents = _getUpcomingEvents();

      if (upcomingEvents.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_available,
                size: 64,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No upcoming events',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: upcomingEvents.length,
        itemBuilder: (context, index) {
          final entry = upcomingEvents[index];
          return _buildAgendaSection(
            entry['date'] as DateTime,
            entry['events'] as List<TimeTableModel>,
            colorScheme,
            textTheme,
          );
        },
      );
    });
  }

  List<Map<String, dynamic>> _getUpcomingEvents() {
    final now = DateTime.now();
    final next7Days = List.generate(7, (i) => now.add(Duration(days: i)));

    final grouped = <Map<String, dynamic>>[];

    for (final day in next7Days) {
      final events =
          scheduleRepo
              .getCombinedEventsForDay(day)
              .whereType<TimeTableModel>()
              .where((e) => e.startTime.isAfter(now))
              .toList();

      if (events.isNotEmpty) {
        events.sort((a, b) => a.startTime.compareTo(b.startTime));
        grouped.add({'date': day, 'events': events});
      }
    }

    return grouped;
  }

  Widget _buildAgendaSection(
    DateTime date,
    List<TimeTableModel> events,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final isToday = _isSameDay(date, DateTime.now());
    final isTomorrow = _isSameDay(
      date,
      DateTime.now().add(const Duration(days: 1)),
    );

    String dateLabel;
    if (isToday) {
      dateLabel = 'TODAY';
    } else if (isTomorrow) {
      dateLabel = 'TOMORROW';
    } else {
      dateLabel = DateFormat.EEEE().format(date).toUpperCase();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(
                dateLabel,
                style: textTheme.labelLarge?.copyWith(
                  color:
                      isToday
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat.MMMd().format(date),
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        ...events.map(
          (event) => _buildAgendaEventCard(event, colorScheme, textTheme),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAgendaEventCard(
    TimeTableModel event,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    Color eventColor = colorScheme.primaryContainer;
    IconData eventIcon = Icons.event;

    switch (event.eventType) {
      case 'academic':
        eventColor = colorScheme.primaryContainer;
        eventIcon = Icons.school;
        break;
      case 'personal':
        eventColor = colorScheme.secondaryContainer;
        eventIcon = Icons.person;
        break;
      case 'leisure':
        eventColor = colorScheme.tertiaryContainer;
        eventIcon = Icons.sports_esports;
        break;
    }

    final timeRange =
        '${DateFormat.jm().format(event.startTime)} - ${DateFormat.jm().format(event.endTime)}';
    final duration = event.endTime.difference(event.startTime);
    final durationText =
        duration.inHours > 0
            ? '${duration.inHours}h ${duration.inMinutes % 60}m'
            : '${duration.inMinutes}m';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: eventColor,
          child: Icon(eventIcon, size: 20),
        ),
        title: Text(
          event.course ?? 'Event',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(timeRange, style: textTheme.bodySmall),
                const SizedBox(width: 8),
                Text('($durationText)', style: textTheme.bodySmall),
              ],
            ),
            if (event.venue != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(event.venue!, style: textTheme.bodySmall),
                ],
              ),
            ],
            if (event.participants != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(event.participants!, style: textTheme.bodySmall),
                ],
              ),
            ],
          ],
        ),
        trailing: _buildTimeUntil(event.startTime, colorScheme, textTheme),
      ),
    );
  }

  Widget _buildTimeUntil(
    DateTime eventTime,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final now = DateTime.now();
    final difference = eventTime.difference(now);

    if (difference.isNegative) return const SizedBox.shrink();

    String timeText;
    if (difference.inMinutes < 60) {
      timeText = '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      timeText = '${difference.inHours}h';
    } else {
      timeText = '${difference.inDays}d';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        timeText,
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
