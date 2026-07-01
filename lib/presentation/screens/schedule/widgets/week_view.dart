part of '../schedule_test_page.dart';

class _WeekView extends StatelessWidget {
  final DateTime selectedDay;
  final ScheduleRepository scheduleRepo;
  final Function(DateTime) onDayChanged;

  const _WeekView({
    required this.selectedDay,
    required this.scheduleRepo,
    required this.onDayChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final weekStart = _getWeekStart(selectedDay);
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Column(
      children: [
        _buildWeekNavigator(weekStart, colorScheme, textTheme),
        Expanded(
          child: Obx(() => _buildWeekGrid(weekDays, colorScheme, textTheme)),
        ),
      ],
    );
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  Widget _buildWeekNavigator(
    DateTime weekStart,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final weekEnd = weekStart.add(const Duration(days: 6));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                () =>
                    onDayChanged(selectedDay.subtract(const Duration(days: 7))),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${DateFormat.MMMd().format(weekStart)} - ${DateFormat.MMMd().format(weekEnd)}',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                () => onDayChanged(selectedDay.add(const Duration(days: 7))),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekGrid(
    List<DateTime> weekDays,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildDayHeaders(weekDays, colorScheme, textTheme),
          _buildWeekContent(weekDays, colorScheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildDayHeaders(
    List<DateTime> weekDays,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children:
            weekDays.map((day) {
              final isToday = _isSameDay(day, DateTime.now());
              final isSelected = _isSameDay(day, selectedDay);

              return Expanded(
                child: InkWell(
                  onTap: () => onDayChanged(day),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? colorScheme.primaryContainer.withValues(
                                alpha: 0.5,
                              )
                              : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat.E().format(day),
                          style: textTheme.labelSmall?.copyWith(
                            color:
                                isToday
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isToday ? colorScheme.primary : null,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: textTheme.bodyMedium?.copyWith(
                              color:
                                  isToday
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurface,
                              fontWeight:
                                  isToday ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildWeekContent(
    List<DateTime> weekDays,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          weekDays.map((day) {
            final events = scheduleRepo.getCombinedEventsForDay(day);
            return Expanded(
              child: _buildDayColumn(day, events, colorScheme, textTheme),
            );
          }).toList(),
    );
  }

  Widget _buildDayColumn(
    DateTime day,
    List<dynamic> events,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        children:
            events.isEmpty
                ? [
                  const SizedBox(height: 100),
                  Icon(
                    Icons.event_busy,
                    size: 24,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                ]
                : events.map((event) {
                  if (event is! TimeTableModel) return const SizedBox.shrink();
                  return _buildWeekEventCard(event, colorScheme, textTheme);
                }).toList(),
      ),
    );
  }

  Widget _buildWeekEventCard(
    TimeTableModel event,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    Color eventColor = colorScheme.primaryContainer;

    switch (event.eventType) {
      case 'academic':
        eventColor = colorScheme.primaryContainer;
        break;
      case 'personal':
        eventColor = colorScheme.secondaryContainer;
        break;
      case 'leisure':
        eventColor = colorScheme.tertiaryContainer;
        break;
    }

    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: eventColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.jm().format(event.startTime),
            style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            event.course ?? 'Event',
            style: textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
