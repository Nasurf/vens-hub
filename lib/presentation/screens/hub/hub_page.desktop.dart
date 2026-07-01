import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:vens_hub/presentation/screens/hub/hub_page.mobile.dart'
    show
        HubController,
        PerformanceOverTimeCard,
        SubjectBreakdownCard,
        EfficiencyScatterCard,
        InsightsCard;
import 'package:intl/intl.dart';
import 'package:vens_hub/presentation/widgets/common/themed_hub_icon.dart';

class DesktopHubPage extends StatefulWidget {
  const DesktopHubPage({super.key});

  @override
  State<DesktopHubPage> createState() => _DesktopHubPageState();
}

class _DesktopHubPageState extends State<DesktopHubPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _activityKey = GlobalKey();
  final GlobalKey _performanceKey = GlobalKey();
  final GlobalKey _subjectsKey = GlobalKey();
  final GlobalKey _efficiencyKey = GlobalKey();
  final GlobalKey _insightsKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final controller =
        Get.isRegistered<HubController>()
            ? Get.find<HubController>()
            : Get.put(HubController());

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const ThemedHubIcon(selected: true, size: 36),
                    const SizedBox(width: 10),
                    Text(
                      'Hub',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Segmented control (desktop adopts mobile design, sized for wide screens)
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Obx(() {
                      final int selected = controller.currentTabIndex.value;
                      const titles = ['Day', 'Week', 'Month'];
                      return SizedBox(
                        height: 40,
                        width: double.infinity,
                        child: Row(
                          children: List.generate(3, (index) {
                            final bool isActive = selected == index;
                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => controller.onTabChanged(index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isActive ? null : Colors.transparent,
                                    gradient:
                                        isActive
                                            ? LinearGradient(
                                              colors: [
                                                colorScheme.primary.withValues(
                                                  alpha: 0.15,
                                                ),
                                                colorScheme.primary.withValues(
                                                  alpha: 0.05,
                                                ),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                            : null,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          isActive
                                              ? colorScheme.primary.withValues(
                                                alpha: 0.5,
                                              )
                                              : colorScheme.outline.withValues(
                                                alpha: 0.1,
                                              ),
                                      width: isActive ? 1.5 : 1,
                                    ),
                                    boxShadow:
                                        isActive
                                            ? [
                                              BoxShadow(
                                                color: colorScheme.primary
                                                    .withValues(alpha: 0.15),
                                                blurRadius: 8,
                                                spreadRadius: 0,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                            : null,
                                  ),
                                  child: Text(
                                    titles[index],
                                    style: textTheme.labelLarge?.copyWith(
                                      color:
                                          isActive
                                              ? colorScheme.primary
                                              : colorScheme.onSurfaceVariant,
                                      fontWeight:
                                          isActive
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 16),

                _DesktopSectionNavigator(
                  onActivityTap: () => _scrollToSection(_activityKey),
                  onPerformanceTap: () => _scrollToSection(_performanceKey),
                  onSubjectsTap: () => _scrollToSection(_subjectsKey),
                  onEfficiencyTap: () => _scrollToSection(_efficiencyKey),
                  onInsightsTap: () => _scrollToSection(_insightsKey),
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double maxWidth = constraints.maxWidth;
                      const double gap = 20;
                      final bool useTwoColumns = maxWidth >= 880;
                      final double cardWidth =
                          useTwoColumns ? (maxWidth - gap) / 2 : maxWidth;

                      return RefreshIndicator(
                        onRefresh: controller.refreshAll,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                key: _activityKey,
                                child: DesktopActivityChart(
                                  controller: controller,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: [
                                  SizedBox(
                                    key: _performanceKey,
                                    width: cardWidth,
                                    child: PerformanceOverTimeCard(
                                      controller: controller,
                                    ),
                                  ),
                                  SizedBox(
                                    key: _subjectsKey,
                                    width: cardWidth,
                                    child: SubjectBreakdownCard(
                                      controller: controller,
                                    ),
                                  ),
                                  SizedBox(
                                    key: _efficiencyKey,
                                    width: cardWidth,
                                    child: EfficiencyScatterCard(
                                      controller: controller,
                                    ),
                                  ),
                                  SizedBox(
                                    key: _insightsKey,
                                    width: cardWidth,
                                    child: InsightsCard(controller: controller),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopSectionNavigator extends StatelessWidget {
  const _DesktopSectionNavigator({
    required this.onActivityTap,
    required this.onPerformanceTap,
    required this.onSubjectsTap,
    required this.onEfficiencyTap,
    required this.onInsightsTap,
  });

  final VoidCallback onActivityTap;
  final VoidCallback onPerformanceTap;
  final VoidCallback onSubjectsTap;
  final VoidCallback onEfficiencyTap;
  final VoidCallback onInsightsTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        _DesktopNavChip(
          label: 'Activity',
          icon: Icons.bar_chart_rounded,
          onTap: onActivityTap,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(width: 10),
        _DesktopNavChip(
          label: 'Performance',
          icon: Icons.trending_up,
          onTap: onPerformanceTap,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(width: 10),
        _DesktopNavChip(
          label: 'Subjects',
          icon: Icons.library_books_outlined,
          onTap: onSubjectsTap,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(width: 10),
        _DesktopNavChip(
          label: 'Efficiency',
          icon: Icons.speed_outlined,
          onTap: onEfficiencyTap,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(width: 10),
        _DesktopNavChip(
          label: 'Insights',
          icon: Icons.lightbulb_outline,
          onTap: onInsightsTap,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
      ],
    );
  }
}

class _DesktopNavChip extends StatelessWidget {
  const _DesktopNavChip({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DesktopActivityChart extends StatelessWidget {
  const DesktopActivityChart({super.key, required this.controller});

  final HubController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Obx(() {
      final bool isLoading = controller.loading.value;
      if (isLoading) {
        return Container(
          height: 420,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _PeriodSelectorDesktop(controller: controller),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Quiz activity',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Quizzes done',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 420,
              width: double.infinity,
              child: Obx(() {
                final int tab = controller.currentTabIndex.value;
                List<int> series;
                double minX = 0, maxX = 23, intervalX = 2;
                Widget Function(double, TitleMeta) labelBuilder;
                if (tab == 0) {
                  series = controller.hourlyCounts.toList();
                  minX = 0;
                  maxX = 23;
                  intervalX = 2;
                  labelBuilder = (value, meta) {
                    final int h = value.toInt();
                    if (h < 0 || h > 23) return const SizedBox.shrink();
                    if (h % 2 != 0) return const SizedBox.shrink();
                    final label = _hourLabelDesktop(h);
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        label,
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  };
                } else if (tab == 1) {
                  series = controller.weekDailyCounts.toList();
                  minX = 0;
                  maxX = 6;
                  intervalX = 1;
                  const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  labelBuilder = (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i > 6) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        letters[i],
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  };
                } else {
                  series = controller.monthWeeklyCounts.toList();
                  minX = 1;
                  maxX = 4.3;
                  intervalX = 1;
                  labelBuilder = (value, meta) {
                    final i = value.toInt();
                    if (i < 1 || i > 4) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        i.toString(),
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  };
                }

                final spots = <FlSpot>[];
                if (tab == 0) {
                  for (int i = 0; i < 24; i++) {
                    spots.add(FlSpot(i.toDouble(), series[i].toDouble()));
                  }
                } else if (tab == 1) {
                  for (int i = 0; i < 7; i++) {
                    final value = i < series.length ? series[i] : 0;
                    spots.add(FlSpot(i.toDouble(), value.toDouble()));
                  }
                } else {
                  for (int i = 1; i <= 4; i++) {
                    final value = i - 1 < series.length ? series[i - 1] : 0;
                    spots.add(FlSpot(i.toDouble(), value.toDouble()));
                  }
                }

                return LineChart(
                  LineChartData(
                    minY: 0,
                    minX: minX,
                    maxX: maxX,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine:
                          (value) => FlLine(
                            color: colorScheme.outline.withValues(alpha: 0.15),
                            strokeWidth: 1,
                          ),
                      getDrawingVerticalLine:
                          (value) => FlLine(
                            color: colorScheme.outline.withValues(alpha: 0.12),
                            strokeWidth: 1,
                          ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          interval: _suggestLeftIntervalDesktop(series),
                          getTitlesWidget:
                              (value, meta) => Text(
                                value.toInt().toString(),
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: intervalX,
                          getTitlesWidget: labelBuilder,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                          width: 1,
                        ),
                        left: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                          width: 1,
                        ),
                        right: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                          width: 1,
                        ),
                        bottom: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        barWidth: 3,
                        color: colorScheme.primary,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: colorScheme.primary.withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Obx(() {
                final int tab = controller.currentTabIndex.value;
                final String label =
                    tab == 0 ? 'Time of day' : (tab == 1 ? 'Weekday' : 'Weeks');
                return Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              }),
            ),
          ],
        ),
      );
    });
  }
}

double _suggestLeftIntervalDesktop(List<int> counts) {
  final int maxVal =
      counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);
  if (maxVal <= 4) return 1;
  if (maxVal <= 10) return 2;
  if (maxVal <= 20) return 5;
  return (maxVal / 5).ceilToDouble();
}

String _hourLabelDesktop(int h) {
  if (h == 0) return '00:00';
  if (h == 12) return '12:00';
  if (h < 12) return '${h.toString().padLeft(2, '0')}:00';
  return '${h.toString().padLeft(2, '0')}:00';
}

class _PeriodSelectorDesktop extends StatelessWidget {
  final HubController controller;
  const _PeriodSelectorDesktop({required this.controller});

  String _ordinal(int n) {
    if (n == 1) return '1st';
    if (n == 2) return '2nd';
    if (n == 3) return '3rd';
    return '${n}th';
  }

  String _dayLabel(DateTime d) {
    return DateFormat('E, d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Obx(() {
      final int tab = controller.currentTabIndex.value;
      late String label;
      if (tab == 0) {
        label = _dayLabel(controller.selectedDay.value);
      } else if (tab == 1) {
        label = '${_ordinal(controller.selectedWeekOfMonth.value)} week';
      } else {
        final monthName = DateFormat('MMMM').format(
          DateTime(
            controller.selectedYear.value,
            controller.selectedMonth.value,
          ),
        );
        label = monthName;
      }
      return PopupMenuButton<int>(
        onSelected: (value) async {
          if (tab == 1) {
            await controller.setWeekOfMonth(value);
          } else if (tab == 2) {
            await controller.setMonth(value);
          }
        },
        itemBuilder: (ctx) {
          if (tab == 1) {
            return List.generate(4, (i) {
              final w = i + 1;
              return PopupMenuItem<int>(
                value: w,
                child: Text('${_ordinal(w)} week'),
              );
            });
          }
          if (tab == 2) {
            return List.generate(12, (i) {
              final m = i + 1;
              final name = DateFormat(
                'MMMM',
              ).format(DateTime(controller.selectedYear.value, m));
              return PopupMenuItem<int>(value: m, child: Text(name));
            });
          }
          return <PopupMenuEntry<int>>[
            const PopupMenuItem<int>(
              enabled: false,
              height: 0,
              child: SizedBox.shrink(),
            ),
          ];
        },
        onOpened: () async {
          if (controller.currentTabIndex.value == 0) {
            final now = controller.selectedDay.value;
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(now.year - 1, 1, 1),
              lastDate: DateTime(now.year + 1, 12, 31),
              helpText: 'Select day',
            );
            if (picked != null) {
              await controller.setDay(picked);
            }
          }
        },
        position: PopupMenuPosition.under,
        tooltip: '',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      );
    });
  }
}
