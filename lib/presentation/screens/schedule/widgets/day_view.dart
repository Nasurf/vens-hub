part of '../schedule_test_page.dart';

class _DayView extends StatelessWidget {
  final DateTime selectedDay;
  final ScheduleRepository scheduleRepo;
  final Function(DateTime) onDayChanged;

  const _DayView({
    required this.selectedDay,
    required this.scheduleRepo,
    required this.onDayChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        _buildDateNavigator(colorScheme, textTheme),
        Expanded(child: Obx(() => _buildTimeline(colorScheme, textTheme))),
      ],
    );
  }

  Widget _buildDateNavigator(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                () =>
                    onDayChanged(selectedDay.subtract(const Duration(days: 1))),
          ),
          Expanded(
            child: Center(
              child: Column(
                children: [
                  Text(
                    DateFormat.EEEE().format(selectedDay),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    DateFormat.yMMMd().format(selectedDay),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                () => onDayChanged(selectedDay.add(const Duration(days: 1))),
          ),
          TextButton(
            onPressed: () => onDayChanged(DateTime.now()),
            child: const Text('Today'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(ColorScheme colorScheme, TextTheme textTheme) {
    final events = scheduleRepo.getCombinedEventsForDay(selectedDay);

    if (events.isEmpty) {
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
              'No events today',
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
      itemCount: 24, // 24 hours
      itemBuilder: (context, hour) {
        final hourEvents = _getEventsForHour(events, hour);
        return _buildHourSlot(hour, hourEvents, colorScheme, textTheme);
      },
    );
  }

  List<TimeTableModel> _getEventsForHour(List<dynamic> events, int hour) {
    return events
        .where((event) {
          if (event is! TimeTableModel) return false;
          final startHour = event.startTime.hour;
          final endHour = event.endTime.hour;
          return hour >= startHour && hour < endHour;
        })
        .cast<TimeTableModel>()
        .toList();
  }

  Widget _buildHourSlot(
    int hour,
    List<TimeTableModel> events,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final timeLabel = DateFormat.jm().format(DateTime(2000, 1, 1, hour, 0));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            timeLabel,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              if (events.isEmpty)
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                  ),
                )
              else
                ...events.map(
                  (event) => _buildEventBlock(event, colorScheme, textTheme),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventBlock(
    TimeTableModel event,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final duration = event.endTime.difference(event.startTime);
    final height = (duration.inMinutes / 60) * 60.0;

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

    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: eventColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(eventIcon, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.course ?? 'Event',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (event.venue != null) ...[
              const SizedBox(height: 4),
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
              const SizedBox(height: 4),
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
      ),
    );
  }
}
