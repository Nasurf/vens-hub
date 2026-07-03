import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_bloc.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_event.dart';
import 'package:vens_hub/core/router/app_router.dart';
import 'package:vens_hub/core/router/routes.dart';

class TheoryTimerSetupScreen extends StatefulWidget {
  const TheoryTimerSetupScreen({super.key});

  @override
  State<TheoryTimerSetupScreen> createState() => _TheoryTimerSetupScreenState();
}

class _TheoryTimerSetupScreenState extends State<TheoryTimerSetupScreen> {
  bool _timed = true;
  int _selectedMinutes = 15; // Default to 15 minutes
  bool _isCustom = false;
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _minsController = TextEditingController();

  @override
  void dispose() {
    _hoursController.dispose();
    _minsController.dispose();
    super.dispose();
  }

  void _onStart() {
    final minutes = _timed ? _chosenMinutes() : null;
    context.read<QuizBloc>().add(
      SetTheoryTimer(isTimed: _timed, minutes: minutes),
    );
    AppRouter.navigateTo(AppRoutes.theoryQuiz);
  }

  int? _chosenMinutes() {
    if (!_timed) return null;
    if (_isCustom) {
      final h = int.tryParse(_hoursController.text) ?? 0;
      final m = int.tryParse(_minsController.text) ?? 0;
      final total = h * 60 + m;
      return total > 0 ? total : null;
    }
    return _selectedMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: _buildHeaderCard(theme),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTimedToggle(theme),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child:
                              _timed
                                  ? _buildTimeOptions(theme)
                                  : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 28),
                        _buildStartButton(theme),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    final isLight = theme.brightness == Brightness.light;
    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;
    final borderColor = theme.colorScheme.onSurface.withValues(
      alpha: isLight ? 0.06 : 0.12,
    );
    final logoColor =
        isLight
            ? primary.withValues(alpha: 0.22)
            : primary.withValues(alpha: 0.35);

    final double a0 = isLight ? 0.18 : 0.12;
    final double r0 = primary.r, g0 = primary.g, b0 = primary.b;
    final double r1 = surface.r, g1 = surface.g, b1 = surface.b;
    const double a1 = 1.0;
    final double aMid = (a0 + a1) / 2.0;
    final double rPre = (a0 * r0 + a1 * r1) / 2.0;
    final double gPre = (a0 * g0 + a1 * g1) / 2.0;
    final double bPre = (a0 * b0 + a1 * b1) / 2.0;
    final double rComp = rPre + (1.0 - aMid) * r1;
    final double gComp = gPre + (1.0 - aMid) * g1;
    final double bComp = bPre + (1.0 - aMid) * b1;
    final Color headerMidColor = Color.fromARGB(
      255,
      (rComp * 255.0).round(),
      (gComp * 255.0).round(),
      (bComp * 255.0).round(),
    );

    return Container(
      decoration: BoxDecoration(
        color: headerMidColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        // SafeArea already applied to the whole page; avoid double top padding
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                CupertinoIcons.back,
                color: theme.colorScheme.onSurface,
              ),
              onPressed: () => AppRouter.pop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exam Mode Setup',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose if you want a countdown for theory to mirror test conditions.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimedToggle(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/svg/stopwatch_1.svg',
              height: 28,
              // colorFilter: ColorFilter.mode(theme.colorScheme.primary, BlendMode.srcIn),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Timed Theory?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enable a countdown to train under real exam pressure.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            CupertinoSlidingSegmentedControl<bool>(
              groupValue: _timed,
              children: const {false: Text('No'), true: Text('Yes')},
              onValueChanged: (val) {
                if (val == null) return;
                HapticFeedback.selectionClick();
                setState(() => _timed = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOptions(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How long should the timer run?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                Slider(
                  value: _selectedMinutes.toDouble(),
                  min: 5.0, // 5 minutes
                  max: 120.0, // 2 hours in minutes
                  divisions: (120 - 5) ~/ 5, // 5 minute intervals
                  label: _formatSliderLabel(_selectedMinutes),
                  onChanged: (double value) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isCustom = false; // Reset custom if slider is used
                      _selectedMinutes = value.round();
                    });
                  },
                ),
                Text(
                  _formatSliderLabel(_selectedMinutes),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            // Optionally, keep the custom dialog if needed, or remove it
            // if the slider covers all desired options.
            // If keeping, ensure _isCustom logic is handled correctly
            // when slider is used.
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomMinutesDialog(ThemeData theme) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set custom duration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _hoursController,
                decoration: const InputDecoration(
                  labelText: 'Hours',
                  hintText: 'e.g. 1',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _minsController,
                decoration: const InputDecoration(
                  labelText: 'Minutes',
                  hintText: 'e.g. 30',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final h = int.tryParse(_hoursController.text) ?? 0;
                final m = int.tryParse(_minsController.text) ?? 0;
                final total = h * 60 + m;
                if (total > 0) {
                  Navigator.pop(context, total);
                } else {
                  HapticFeedback.heavyImpact();
                }
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );

    if (result != null && result > 0) {
      setState(() {
        _isCustom = true;
        _selectedMinutes = result; // Update slider to reflect custom time
        final h = result ~/ 60;
        final m = result % 60;
        _hoursController.text = h.toString();
        _minsController.text = m.toString();
      });
    }
  }

  String _formatSliderLabel(int minutes) {
    final int totalMinutes = minutes;
    final int hours = totalMinutes ~/ 60;
    final int mins = totalMinutes % 60;

    if (hours > 0 && mins > 0) {
      return '$hours hr $mins min';
    } else if (hours > 0) {
      return '$hours hr${hours > 1 ? 's' : ''}';
    }
    return '$mins min';
  }

  Widget _buildStartButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(_timed ? 'Start with Timer' : 'Start Without Timer'),
        onPressed: _onStart,
      ),
    );
  }
}
