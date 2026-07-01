import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:vens_hub/domain/repositories/schedule_repository.dart';
import 'package:vens_hub/data/models/timetable_model.dart';

// Import widget components
part 'widgets/day_view.dart';
part 'widgets/week_view.dart';
part 'widgets/agenda_view.dart';
part 'widgets/quick_add_menu.dart';

/// Test page for new schedule features - Debug only
class ScheduleTestPage extends StatefulWidget {
  const ScheduleTestPage({super.key});

  @override
  State<ScheduleTestPage> createState() => _ScheduleTestPageState();
}

class _ScheduleTestPageState extends State<ScheduleTestPage> {
  final _scheduleRepo = Get.find<ScheduleRepository>();
  DateTime _selectedDay = DateTime.now();
  ScheduleView _currentView = ScheduleView.day;

  @override
  void initState() {
    super.initState();
    _scheduleRepo.ensureInitialized();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Schedule Test',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Debug Mode',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              await _scheduleRepo.refreshFromServer();
              if (mounted) setState(() {});
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showDebugInfo(context),
            tooltip: 'Debug Info',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildViewSwitcher(colorScheme),
          Expanded(child: _buildCurrentView(colorScheme, theme.textTheme)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickAddMenu(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Quick Add'),
        elevation: 2,
      ),
    );
  }

  Widget _buildViewSwitcher(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          _buildViewChip(
            'Day',
            ScheduleView.day,
            Icons.view_day_rounded,
            colorScheme,
          ),
          const SizedBox(width: 8),
          _buildViewChip(
            'Week',
            ScheduleView.week,
            Icons.view_week_rounded,
            colorScheme,
          ),
          const SizedBox(width: 8),
          _buildViewChip(
            'Agenda',
            ScheduleView.agenda,
            Icons.view_agenda_rounded,
            colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildViewChip(
    String label,
    ScheduleView view,
    IconData icon,
    ColorScheme colorScheme,
  ) {
    final isSelected = _currentView == view;
    return Expanded(
      child: Material(
        color:
            isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _currentView = view),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color:
                      isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color:
                        isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView(ColorScheme colorScheme, TextTheme textTheme) {
    switch (_currentView) {
      case ScheduleView.day:
        return _DayView(
          selectedDay: _selectedDay,
          scheduleRepo: _scheduleRepo,
          onDayChanged: (day) => setState(() => _selectedDay = day),
        );
      case ScheduleView.week:
        return _WeekView(
          selectedDay: _selectedDay,
          scheduleRepo: _scheduleRepo,
          onDayChanged: (day) => setState(() => _selectedDay = day),
        );
      case ScheduleView.agenda:
        return _AgendaView(scheduleRepo: _scheduleRepo);
    }
  }

  void _showQuickAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => _QuickAddMenu(
            selectedDay: _selectedDay,
            onEventAdded: () {
              if (mounted) setState(() {});
            },
          ),
    );
  }

  void _showDebugInfo(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.bug_report_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Debug Information'),
              ],
            ),
            content: Obx(
              () => SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDebugSection('Data Sources', [
                      _buildDebugRow(
                        'Timetable Events',
                        '${_scheduleRepo.timeTableData.length}',
                      ),
                      _buildDebugRow(
                        'User Events',
                        '${_scheduleRepo.userEvents.length}',
                      ),
                      _buildDebugRow(
                        'Academic Events',
                        '${_scheduleRepo.academicEvents.length}',
                      ),
                    ]),
                    const Divider(height: 24),
                    _buildDebugSection('Current State', [
                      _buildDebugRow(
                        'Selected Date',
                        DateFormat.yMMMd().format(_selectedDay),
                      ),
                      _buildDebugRow(
                        'Current View',
                        _currentView.name.toUpperCase(),
                      ),
                      _buildDebugRow(
                        'Loading',
                        _scheduleRepo.isLoading.value ? 'Yes' : 'No',
                      ),
                    ]),
                    const Divider(height: 24),
                    _buildDebugSection('Today', [
                      _buildDebugRow(
                        'Events Count',
                        '${_scheduleRepo.getCombinedEventsForDay(_selectedDay).length}',
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildDebugSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

enum ScheduleView { day, week, agenda }
