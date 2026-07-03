import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_bloc.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_event.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_state.dart';
import 'package:vens_hub/core/router/app_router.dart';
import 'package:get/get.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:vens_hub/presentation/screens/quiz/DailyCongrats/daily_congrats_page.dart';
import 'package:vens_hub/data/models/question_model.dart';
import 'package:vens_hub/core/Brain/data_formatting.dart' as df;
import 'package:vens_hub/presentation/screens/quiz/Review/review_page.dart';
import 'package:vens_hub/core/services/data/firestore_service.dart';
import 'package:vens_hub/adaptive/lib/src/adaptive_service.dart';

import 'package:google_fonts/google_fonts.dart';

class CompletionPageMobile extends StatefulWidget {
  final int numOfQuestions;
  final int numOfCorrectAnswers;
  final int? streakBefore;
  final int? streakAfter;
  final bool isFirstCompletion;

  const CompletionPageMobile({
    super.key,
    required this.numOfQuestions,
    required this.numOfCorrectAnswers,
    this.streakBefore,
    this.streakAfter,
    this.isFirstCompletion = false,
  });

  @override
  State<CompletionPageMobile> createState() => _CompletionPageMobileState();
}

class _CompletionPageMobileState extends State<CompletionPageMobile>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  Duration? _elapsed;
  String _selectedQuote = '';
  bool _logged = false;

  static const List<String> _quotes = [
    'Every expert was once a beginner.',
    'Progress, not perfection.',
    'Knowledge is power.',
    'Keep learning, keep growing.',
    'Success is a journey, not a destination.',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _initializeData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initializeData() async {
    final quizState = context.read<QuizBloc>().state;
    final DateTime start = quizState.startedAt ?? DateTime.now();
    final Duration elapsed = DateTime.now().difference(start);
    final String quote = _quotes[Random().nextInt(_quotes.length)];

    if (mounted) {
      setState(() {
        _elapsed = elapsed;
        _selectedQuote = quote;
      });
    }

    if (!_logged) {
      _logged = true;
      _logQuizAttempt(quizState, start, elapsed);
    }
  }

  void _logQuizAttempt(
    QuizState quizState,
    DateTime start,
    Duration elapsed,
  ) async {
    final userId = Get.find<HomeController>().currentUser.value?.id;
    if (userId != null && userId.isNotEmpty) {
      try {
        await FireStoreServices.find.addDailyQuizAttempt(
          uid: userId,
          startedAt: start,
          elapsed: elapsed,
          questionsCount: widget.numOfQuestions,
          correctCount: widget.numOfCorrectAnswers,
          course: {
            'id': '',
            'title': quizState.course,
            'code': '',
            'semester': '',
            'tags': <String>[],
            'topics': <String>[],
          },
          topic: quizState.choosenTopic ?? '',
          questionType: (quizState.questionType?.name ?? 'unknown'),
          items: _buildAttemptItems(quizState),
        );
      } catch (_) {}

      // Submit per-topic results to adaptive engine
      _syncAdaptiveResults(quizState, userId);
    }
  }

  void _syncAdaptiveResults(QuizState state, String userId) {
    final List<Map<String, dynamic>> results = [];
    for (int i = 0; i < state.allQuestions.length; i++) {
      final q = state.allQuestions[i];
      bool correct = false;
      String? topic;
      if (q is Question) {
        correct = state.mcqIsCorrect[i] ?? false;
        topic = q.topic;
      } else if (q is df.GapFillQuestion) {
        final matched = state.gapFillCorrectCountByQuestion[i] ?? 0;
        final total = state.gapFillTotalGapsByQuestion[i] ?? q.answers.length;
        correct = total > 0 && matched >= total;
        topic = q.topic;
      } else if (q is df.TheoryQuestion) {
        continue;
      }
      results.add({
        'topicName': topic ?? state.choosenTopic ?? 'General',
        'courseCode': state.course,
        'isCorrect': correct,
        'questionId': int.tryParse(q.id) ?? null,
      });
    }
    if (results.isNotEmpty) {
      AdaptiveService().submitBatch(userId, results);
    }
  }

  List<Map<String, dynamic>> _buildAttemptItems(QuizState state) {
    final List<Map<String, dynamic>> items = [];
    for (int i = 0; i < state.allQuestions.length; i++) {
      final q = state.allQuestions[i];
      if (q is Question) {
        final bool correct = state.mcqIsCorrect[i] ?? false;
        items.add({'index': i, 'type': 'mcq', 'correct': correct});
      } else if (q is df.GapFillQuestion) {
        final int matched = state.gapFillCorrectCountByQuestion[i] ?? 0;
        final int total =
            state.gapFillTotalGapsByQuestion[i] ?? q.answers.length;
        items.add({
          'index': i,
          'type': 'gapFill',
          'matched': matched,
          'total': total,
        });
      }
    }
    return items;
  }

  void _openReview() {
    final state = context.read<QuizBloc>().state;
    Get.toNamed(
      AppRoutes.review,
      arguments: ReviewData(
        questions: state.allQuestions,
        mcqSelectedAnswers: state.mcqSelectedAnswers,
        mcqIsCorrect: state.mcqIsCorrect,
        gapFillUserAnswers: state.gapFillUserAnswers,
        gapFillIsCorrect: state.gapFillIsCorrect.map(
          (key, value) => MapEntry(key, [value]),
        ),
      ),
    );
  }

  Future<void> _handleContinue() async {
    final quizBloc = context.read<QuizBloc>();
    final bool shouldShowCongrats = widget.isFirstCompletion;
    final int previousStreak = widget.streakBefore ?? 0;
    final int currentStreak = widget.streakAfter ?? previousStreak;
    final String courseTitle = quizBloc.state.course;

    if (shouldShowCongrats) {
      await AppRouter.navigateTo(
        AppRoutes.dailyCongrats,
        DailyCongratsArgs(
          previousStreakCount: previousStreak,
          currentStreakCount: currentStreak,
          courseTitle: courseTitle,
        ),
      );
    }

    quizBloc.add(const ResetQuiz());
    AppRouter.navigateAndClearAll(AppRoutes.main);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final percentage =
        widget.numOfQuestions > 0
            ? (widget.numOfCorrectAnswers / widget.numOfQuestions)
            : 0.0;

    return Scaffold(
      backgroundColor: cs.surface,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 24),
                                // Score Circle
                                _buildScoreCircle(context, percentage),
                                const SizedBox(height: 32),

                                // Results Text
                                _buildResultsText(context, percentage),
                                const SizedBox(height: 32),

                                // Stats Cards
                                _buildStatsGrid(context),
                                const SizedBox(height: 32),

                                // Streak Info (only when streak was updated)
                                if (widget.isFirstCompletion &&
                                    widget.streakAfter != null &&
                                    widget.streakAfter! > 0)
                                  _buildStreakBadge(context),

                                const SizedBox(height: 24),

                                // Time and Quote
                                if (_elapsed != null) _buildTimeInfo(context),
                                if (_selectedQuote.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  _buildQuote(context),
                                ],
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Action Buttons
                      _buildActionButtons(context),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStreakBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade700,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            '${widget.streakAfter} Day Streak!',
            style: GoogleFonts.rubik(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final wrongAnswers = (widget.numOfQuestions - widget.numOfCorrectAnswers)
        .clamp(0, widget.numOfQuestions);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total',
            value: widget.numOfQuestions.toString(),
            icon: Icons.quiz_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Correct',
            value: widget.numOfCorrectAnswers.toString(),
            icon: Icons.check_circle_outline,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Wrong',
            value: wrongAnswers.toString(),
            icon: Icons.close_outlined,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCircle(BuildContext context, double percentage) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 16,
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              strokeCap: StrokeCap.round,
            ),
          ),

          // Progress circle
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: percentage,
              strokeWidth: 16,
              color: _getColor(percentage),
              strokeCap: StrokeCap.round,
            ),
          ),

          // Score text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(percentage * 100).toInt()}',
                style: GoogleFonts.rubik(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface,
                  height: 1,
                ),
              ),
              Text(
                'Score',
                style: GoogleFonts.rubik(
                  fontSize: 16,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getColor(double percentage) {
    if (percentage >= 0.8) return Colors.green;
    if (percentage >= 0.6) return Colors.blue;
    if (percentage >= 0.4) return Colors.orange;
    return Colors.red;
  }

  Widget _buildResultsText(BuildContext context, double percentage) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    String message;
    if (percentage >= 0.9) {
      message = "Perfect! Outstanding work! 🏆";
    } else if (percentage >= 0.7) {
      message = "Excellent! Well done! 🎉";
    } else if (percentage >= 0.5) {
      message = "Good job! Keep it up! 👏";
    } else {
      message = "Keep practicing! You've got this! 💪";
    }

    return Column(
      children: [
        Text(
          message,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '${(percentage * 100).round()}% Accuracy',
          style: theme.textTheme.titleLarge?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeInfo(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final minutes = _elapsed!.inMinutes;
    final seconds = _elapsed!.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 20,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuote(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '"$_selectedQuote"',
        style: theme.textTheme.bodyLarge?.copyWith(
          fontStyle: FontStyle.italic,
          color: cs.onSurface.withValues(alpha: 0.8),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _openReview,
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Review Answers'),
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _handleContinue,
          icon: const Icon(Icons.arrow_forward_outlined),
          label: const Text('Continue'),
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: BorderSide(color: cs.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
