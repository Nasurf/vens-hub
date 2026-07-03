part of '../schedule_test_page.dart';

class _QuickAddMenu extends StatelessWidget {
  final DateTime selectedDay;
  final VoidCallback onEventAdded;

  const _QuickAddMenu({required this.selectedDay, required this.onEventAdded});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Add Event',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTemplateButton(
            context,
            '📚 Class',
            'Add a class or lecture',
            () => _addFromTemplate(context, EventTemplate.classEvent),
          ),
          _buildTemplateButton(
            context,
            '🔬 Lab',
            'Add a lab session',
            () => _addFromTemplate(context, EventTemplate.lab),
          ),
          _buildTemplateButton(
            context,
            '📝 Study Session',
            'Add study time',
            () => _addFromTemplate(context, EventTemplate.study),
          ),
          _buildTemplateButton(
            context,
            '👥 Group Meeting',
            'Add a group meeting',
            () => _addFromTemplate(context, EventTemplate.meeting),
          ),
          _buildTemplateButton(
            context,
            '🎯 Personal Task',
            'Add a personal task',
            () => _addFromTemplate(context, EventTemplate.personal),
          ),
          const Divider(),
          _buildTemplateButton(
            context,
            '⚡ Custom Event',
            'Create from scratch',
            () => _showCustomEventDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateButton(
    BuildContext context,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _addFromTemplate(BuildContext context, EventTemplate template) {
    final startTime = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
      template.defaultStartHour,
      0,
    );
    final endTime = startTime.add(Duration(hours: template.defaultDuration));

    _showQuickEventDialog(
      context,
      template: template,
      startTime: startTime,
      endTime: endTime,
    );
  }

  void _showQuickEventDialog(
    BuildContext context, {
    required EventTemplate template,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final titleController = TextEditingController(text: template.defaultTitle);
    final venueController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Add ${template.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: venueController,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Time'),
                  subtitle: Text(
                    '${DateFormat.jm().format(startTime)} - ${DateFormat.jm().format(endTime)}',
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    // Could add time editing logic here
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Please enter a title')),
                      );
                    }
                    return;
                  }

                  final event = TimeTableModel(
                    title: _getDayName(selectedDay.weekday).toLowerCase(),
                    course: titleController.text.trim(),
                    venue:
                        venueController.text.trim().isEmpty
                            ? null
                            : venueController.text.trim(),
                    startTime: startTime,
                    endTime: endTime,
                    eventType: template.eventType,
                  );

                  try {
                    await Get.find<ScheduleRepository>().addUserEvent(event);
                    if (ctx.mounted) Navigator.pop(ctx);
                    onEventAdded();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Event added successfully'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Failed to add event: $e')),
                      );
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  void _showCustomEventDialog(BuildContext context) {
    // Show full event creation dialog
    _showQuickEventDialog(
      context,
      template: EventTemplate.custom,
      startTime: DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
        9,
        0,
      ),
      endTime: DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
        10,
        0,
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return days[weekday - 1];
  }
}

class EventTemplate {
  final String name;
  final String defaultTitle;
  final String eventType;
  final int defaultStartHour;
  final int defaultDuration;

  const EventTemplate({
    required this.name,
    required this.defaultTitle,
    required this.eventType,
    required this.defaultStartHour,
    required this.defaultDuration,
  });

  static const classEvent = EventTemplate(
    name: 'Class',
    defaultTitle: 'Class',
    eventType: 'academic',
    defaultStartHour: 9,
    defaultDuration: 2,
  );

  static const lab = EventTemplate(
    name: 'Lab',
    defaultTitle: 'Lab Session',
    eventType: 'academic',
    defaultStartHour: 14,
    defaultDuration: 2,
  );

  static const study = EventTemplate(
    name: 'Study Session',
    defaultTitle: 'Study Time',
    eventType: 'personal',
    defaultStartHour: 18,
    defaultDuration: 2,
  );

  static const meeting = EventTemplate(
    name: 'Meeting',
    defaultTitle: 'Group Meeting',
    eventType: 'personal',
    defaultStartHour: 15,
    defaultDuration: 1,
  );

  static const personal = EventTemplate(
    name: 'Personal Task',
    defaultTitle: 'Personal Task',
    eventType: 'personal',
    defaultStartHour: 10,
    defaultDuration: 1,
  );

  static const custom = EventTemplate(
    name: 'Custom Event',
    defaultTitle: '',
    eventType: 'personal',
    defaultStartHour: 9,
    defaultDuration: 1,
  );
}
