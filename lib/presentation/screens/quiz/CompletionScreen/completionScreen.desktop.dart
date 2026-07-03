import 'package:vens_hub/presentation/screens/quiz/DailyCongrats/daily_congrats_page.dart';
import 'package:confetti/confetti.dart';
import 'package:vens_hub/core/Brain/data_formatting.dart' as df;
import 'package:vens_hub/core/router/app_router.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/core/services/data/firestore_service.dart';
import 'package:vens_hub/adaptive/lib/src/adaptive_service.dart';
import 'package:vens_hub/data/models/question_model.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_bloc.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_event.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_state.dart';
import 'package:vens_hub/presentation/screens/quiz/Review/review_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class CompletionPageDesktop extends StatefulWidget {
  final int numOfQuestions;
  final int numOfCorrectAnswers;
  final int? streakBefore;
  final int? streakAfter;
  final bool isFirstCompletion;

  const CompletionPageDesktop({
    super.key,
    required this.numOfQuestions,
    required this.numOfCorrectAnswers,
    this.streakBefore,
    this.streakAfter,
    this.isFirstCompletion = false,
  });

  @override
  State<CompletionPageDesktop> createState() => _CompletionPageDesktopState();
}

class _CompletionPageDesktopState extends State<CompletionPageDesktop>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late ConfettiController _confettiController;

  Duration? _elapsed;
  bool _logged = false;
  bool _streakUpdated = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _entranceController.forward();
    _initializeData();

    // Play confetti if score is good (> 70%)
    if (widget.numOfQuestions > 0 &&
        (widget.numOfCorrectAnswers / widget.numOfQuestions) >= 0.7) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _confettiController.play();
      });
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _initializeData() async {
    final quizState = context.read<QuizBloc>().state;
    final DateTime start = quizState.startedAt ?? DateTime.now();
    final Duration elapsed = DateTime.now().difference(start);

    if (mounted) {
      setState(() {
        _elapsed = elapsed;
      });
    }

    if (!_logged) {
      _logged = true;
      _logQuizAttempt(quizState, start, elapsed);
    }

    if (!_streakUpdated && widget.streakAfter != null) {
      _streakUpdated = true;
      _markStreakCompletion();
    }
  }

  void _markStreakCompletion() async {
    final userId = Get.find<HomeController>().currentUser.value?.id;
    if (userId != null) {
      await FireStoreServices.find.markDailyQuizCompleted(userId);
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
      } else {
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

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // Background Elements (Subtle)
          Positioned(
            top: -100,
            right: -100,
            child: Opacity(
              opacity: 0.05,
              child: SvgPicture.asset(
                'assets/svg/transp_11_inlined.svg',
                width: 600,
                height: 600,
                colorFilter: ColorFilter.mode(cs.primary, BlendMode.srcIn),
              ),
            ),
          ),

          // Main Content
          AnimatedBuilder(
            animation: _entranceController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      padding: const EdgeInsets.all(32),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Split view for wider screens
                          if (constraints.maxWidth > 900) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: _ResultSummaryPanel(
                                    numOfQuestions: widget.numOfQuestions,
                                    numOfCorrectAnswers:
                                        widget.numOfCorrectAnswers,
                                    streakAfter: widget.streakAfter,
                                    isFirstCompletion: widget.isFirstCompletion,
                                    onReview: _openReview,
                                    onContinue: _handleContinue,
                                  ),
                                ),
                                const SizedBox(width: 32),
                                Expanded(
                                  flex: 6,
                                  child: _ResultDetailsPanel(
                                    numOfQuestions: widget.numOfQuestions,
                                    numOfCorrectAnswers:
                                        widget.numOfCorrectAnswers,
                                    elapsed: _elapsed,
                                  ),
                                ),
                              ],
                            );
                          } else {
                            // Stacked view for smaller screens
                            return SingleChildScrollView(
                              child: Column(
                                children: [
                                  _ResultSummaryPanel(
                                    numOfQuestions: widget.numOfQuestions,
                                    numOfCorrectAnswers:
                                        widget.numOfCorrectAnswers,
                                    streakAfter: widget.streakAfter,
                                    isFirstCompletion: widget.isFirstCompletion,
                                    onReview: _openReview,
                                    onContinue: _handleContinue,
                                  ),
                                  const SizedBox(height: 32),
                                  _ResultDetailsPanel(
                                    numOfQuestions: widget.numOfQuestions,
                                    numOfCorrectAnswers:
                                        widget.numOfCorrectAnswers,
                                    elapsed: _elapsed,
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Confetti Overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultSummaryPanel extends StatelessWidget {
  final int numOfQuestions;
  final int numOfCorrectAnswers;
  final int? streakAfter;
  final bool isFirstCompletion;
  final VoidCallback onReview;
  final VoidCallback onContinue;

  const _ResultSummaryPanel({
    required this.numOfQuestions,
    required this.numOfCorrectAnswers,
    this.streakAfter,
    this.isFirstCompletion = false,
    required this.onReview,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final percentage =
        numOfQuestions > 0 ? (numOfCorrectAnswers / numOfQuestions) : 0.0;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Text(
            'Quiz Completed',
            style: GoogleFonts.rubik(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getFeedbackText(percentage),
            style: theme.textTheme.titleMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Score Ring
          _AnimatedScoreRing(percentage: percentage),

          const SizedBox(height: 24),
          Text(
            '${(percentage * 100).round()}% Accuracy',
            style: GoogleFonts.rubik(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),

          if (isFirstCompletion && streakAfter != null && streakAfter! > 0) ...[
            const SizedBox(height: 24),
            _StreakBadge(streak: streakAfter!),
          ],

          const SizedBox(height: 40),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReview,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    side: BorderSide(color: cs.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text('Review', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getFeedbackText(double percentage) {
    if (percentage >= 0.9) return "Outstanding! You're a master! 🏆";
    if (percentage >= 0.7) return "Great job! Keep it up! 🎉";
    if (percentage >= 0.5) return "Good effort! Getting there! 💪";
    return "Keep practicing! You'll improve! 📚";
  }
}

class _ResultDetailsPanel extends StatelessWidget {
  final int numOfQuestions;
  final int numOfCorrectAnswers;
  final Duration? elapsed;

  const _ResultDetailsPanel({
    required this.numOfQuestions,
    required this.numOfCorrectAnswers,
    this.elapsed,
  });

  @override
  Widget build(BuildContext context) {
    final wrongAnswers = (numOfQuestions - numOfCorrectAnswers).clamp(
      0,
      numOfQuestions,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 500;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width:
                      isWide
                          ? (constraints.maxWidth - 16) / 2
                          : constraints.maxWidth,
                  child: _StatCard(
                    label: 'Total Questions',
                    value: '$numOfQuestions',
                    icon: Icons.quiz_outlined,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(
                  width:
                      isWide
                          ? (constraints.maxWidth - 16) / 2
                          : constraints.maxWidth,
                  child: _StatCard(
                    label: 'Correct Answers',
                    value: '$numOfCorrectAnswers',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                ),
                SizedBox(
                  width:
                      isWide
                          ? (constraints.maxWidth - 16) / 2
                          : constraints.maxWidth,
                  child: _StatCard(
                    label: 'Wrong Answers',
                    value: '$wrongAnswers',
                    icon: Icons.cancel_outlined,
                    color: Colors.red,
                  ),
                ),
                if (elapsed != null)
                  SizedBox(
                    width:
                        isWide
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth,
                    child: _StatCard(
                      label: 'Time Spent',
                      value:
                          '${elapsed!.inMinutes}m ${elapsed!.inSeconds % 60}s',
                      icon: Icons.timer_outlined,
                      color: Colors.orange,
                    ),
                  ),
              ],
            );
          },
        ),

        const SizedBox(height: 32),

        // Question Breakdown Header
        Text(
          'Question Breakdown',
          style: GoogleFonts.rubik(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),

        // Question List
        Container(
          height: 400, // Fixed height for scrolling
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _QuestionList(numOfQuestions: numOfQuestions),
          ),
        ),
      ],
    );
  }
}

class _QuestionList extends StatelessWidget {
  final int numOfQuestions;

  const _QuestionList({required this.numOfQuestions});

  @override
  Widget build(BuildContext context) {
    final state = context.read<QuizBloc>().state;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: numOfQuestions,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final question = state.allQuestions[index];
        bool isCorrect = false;
        bool isPartial = false;
        String statusText = '';

        if (question is Question) {
          isCorrect = state.mcqIsCorrect[index] ?? false;
          statusText = isCorrect ? 'Correct' : 'Incorrect';
        } else if (question is df.GapFillQuestion) {
          final matched = state.gapFillCorrectCountByQuestion[index] ?? 0;
          final total =
              state.gapFillTotalGapsByQuestion[index] ??
              question.answers.length;
          isCorrect = matched == total;
          isPartial = matched > 0 && matched < total;
          statusText = '$matched/$total';
        }

        Color statusColor =
            isCorrect
                ? Colors.green
                : isPartial
                ? Colors.orange
                : Colors.red;
        IconData statusIcon =
            isCorrect
                ? Icons.check_circle
                : isPartial
                ? Icons.remove_circle_outline
                : Icons.cancel;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Question ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedScoreRing extends StatefulWidget {
  final double percentage;

  const _AnimatedScoreRing({required this.percentage});

  @override
  State<_AnimatedScoreRing> createState() => _AnimatedScoreRingState();
}

class _AnimatedScoreRingState extends State<_AnimatedScoreRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.percentage,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = 200.0;

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Background Circle
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 16,
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  strokeCap: StrokeCap.round,
                ),
              ),
              // Progress Circle
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: _animation.value,
                  strokeWidth: 16,
                  color: _getColor(widget.percentage),
                  strokeCap: StrokeCap.round,
                ),
              ),
              // Center Text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(_animation.value * 100).toInt()}',
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
          );
        },
      ),
    );
  }

  Color _getColor(double percentage) {
    if (percentage >= 0.8) return Colors.green;
    if (percentage >= 0.6) return Colors.blue;
    if (percentage >= 0.4) return Colors.orange;
    return Colors.red;
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
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.rubik(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.rubik(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;

  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
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
            '$streak Day Streak!',
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
}
