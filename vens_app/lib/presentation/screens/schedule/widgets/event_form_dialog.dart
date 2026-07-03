// Event form dialog for creating and editing schedule events
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vens_hub/data/models/timetable_model.dart';

class EventFormDialog extends StatefulWidget {
  final TimeTableModel? event;
  final DateTime? selectedDate;
  final Function(TimeTableModel) onSave;

  const EventFormDialog({
    super.key,
    this.event,
    this.selectedDate,
    required this.onSave,
  });

  @override
  State<EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends State<EventFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _participantsController;
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String _selectedType = 'personal';
  String _repeatRule = 'none';
  int? _reminderMinutesBefore;
  bool _allDay = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _locationController = TextEditingController(text: widget.event?.venue ?? '');
    _participantsController = TextEditingController(
      text: widget.event?.participants ?? '',
    );

    final now = DateTime.now();
    _selectedDate = widget.event?.startTime ?? widget.selectedDate ?? now;

    if (widget.event != null) {
      _startTime = TimeOfDay.fromDateTime(widget.event!.startTime);
      _endTime = TimeOfDay.fromDateTime(widget.event!.endTime);
      _selectedType = widget.event!.eventType ?? 'personal';
      _repeatRule = widget.event!.repeatRule ?? 'none';
      _reminderMinutesBefore = widget.event!.reminderMinutesBefore;
      _allDay = widget.event!.allDay ?? false;
    } else {
      final nextHour = now.minute == 0 ? now.hour : now.hour + 1;
      _startTime = TimeOfDay(hour: nextHour.clamp(0, 23).toInt(), minute: 0);
      _endTime = TimeOfDay(hour: (nextHour + 1).clamp(1, 23).toInt(), minute: 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _participantsController.dispose();
    super.dispose();
  }

  DateTime get _startDateTime => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _allDay ? 0 : _startTime.hour,
    _allDay ? 0 : _startTime.minute,
  );

  DateTime get _endDateTime => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _allDay ? 23 : _endTime.hour,
    _allDay ? 59 : _endTime.minute,
  );

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Choose event date',
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      helpText: isStart ? 'Choose start time' : 'Choose end time',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
        final startMinutes = _minutesFromTime(_startTime);
        final endMinutes = _minutesFromTime(_endTime);
        if (endMinutes <= startMinutes) {
          final adjusted = (startMinutes + 60).clamp(0, 1439);
          _endTime = TimeOfDay(hour: adjusted ~/ 60, minute: adjusted % 60);
        }
      } else {
        _endTime = picked;
      }
    });
  }

  int _minutesFromTime(TimeOfDay time) => time.hour * 60 + time.minute;

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (!_allDay && !_endDateTime.isAfter(_startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }

    final title = _titleController.text.trim();
    final newEvent = TimeTableModel(
      id: widget.event?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      course: title,
      venue: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      participants: _participantsController.text.trim().isEmpty
          ? null
          : _participantsController.text.trim(),
      startTime: _startDateTime,
      endTime: _endDateTime,
      eventType: _selectedType,
      allDay: _allDay,
      repeatRule: _repeatRule,
      reminderMinutesBefore: _reminderMinutesBefore,
      isPersonal: true,
    );

    widget.onSave(newEvent);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      child: Icon(
                        widget.event == null
                            ? Icons.add_task_rounded
                            : Icons.edit_calendar_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.event == null
                                ? 'Create calendar item'
                                : 'Edit calendar item',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            DateFormat('EEEE, MMM d').format(_selectedDate),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    context,
                    label: 'Title',
                    hint: 'e.g. Study group, quiz, meeting',
                    icon: Icons.title_rounded,
                  ),
                  validator: (value) =>
                      (value?.trim().isEmpty ?? true)
                              ? 'Please enter a title'
                              : null,
                ),
                const SizedBox(height: 16),
                _PickerTile(
                  label: 'Date',
                  value: DateFormat('MMM d, y').format(_selectedDate),
                  icon: Icons.calendar_today_rounded,
                  onTap: _selectDate,
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All-day event'),
                  subtitle: const Text('Hide start and end times for this item'),
                  value: _allDay,
                  onChanged: (value) => setState(() => _allDay = value),
                ),
                if (!_allDay) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PickerTile(
                          label: 'Start',
                          value: _startTime.format(context),
                          icon: Icons.schedule_rounded,
                          onTap: () => _selectTime(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PickerTile(
                          label: 'End',
                          value: _endTime.format(context),
                          icon: Icons.schedule_send_rounded,
                          onTap: () => _selectTime(false),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: _inputDecoration(
                    context,
                    label: 'Category',
                    icon: Icons.category_rounded,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'personal', child: Text('Personal')),
                    DropdownMenuItem(value: 'class', child: Text('Class')),
                    DropdownMenuItem(value: 'academic', child: Text('Academic')),
                    DropdownMenuItem(value: 'leisure', child: Text('Leisure')),
                  ],
                  onChanged: (value) => setState(() => _selectedType = value!),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _repeatRule,
                        decoration: _inputDecoration(
                          context,
                          label: 'Repeat',
                          icon: Icons.repeat_rounded,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'none',
                            child: Text('Does not repeat'),
                          ),
                          DropdownMenuItem(value: 'daily', child: Text('Daily')),
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                        ],
                        onChanged: (value) => setState(() => _repeatRule = value!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: _reminderMinutesBefore,
                        decoration: _inputDecoration(
                          context,
                          label: 'Reminder',
                          icon: Icons.notifications_active_rounded,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: null,
                            child: Text('No reminder'),
                          ),
                          DropdownMenuItem(value: 10, child: Text('10 min before')),
                          DropdownMenuItem(value: 30, child: Text('30 min before')),
                          DropdownMenuItem(value: 60, child: Text('1 hour before')),
                          DropdownMenuItem(value: 1440, child: Text('1 day before')),
                        ],
                        onChanged: (value) => setState(() => _reminderMinutesBefore = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    context,
                    label: 'Location',
                    hint: 'Optional',
                    icon: Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _participantsController,
                  decoration: _inputDecoration(
                    context,
                    label: 'Participants',
                    hint: 'Optional names or group',
                    icon: Icons.group_outlined,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(widget.event == null ? 'Create' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.expand_more_rounded),
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
