import 'package:vens_hub/presentation/screens/quiz/Review/review_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_bloc.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_state.dart';
import 'package:vens_hub/data/models/question_model.dart';
import 'package:vens_hub/core/Brain/data_formatting.dart' as df;
import 'package:vens_hub/core/Brain/latex_support.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class ReviewPageDesktop extends StatelessWidget {
  final List<dynamic> questions;
  final Map<int, int> mcqSelectedAnswers;
  final Map<int, bool> mcqIsCorrect;
  final Map<int, List<String>> gapFillUserAnswers;
  final Map<int, List<bool>> gapFillIsCorrect;

  const ReviewPageDesktop({
    super.key,
    required this.questions,
    required this.mcqSelectedAnswers,
    required this.mcqIsCorrect,
    required this.gapFillUserAnswers,
    required this.gapFillIsCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: BlocBuilder<QuizBloc, QuizState>(
          builder: (context, state) {
            final ReviewData? args =
                Get.arguments is ReviewData
                    ? Get.arguments as ReviewData
                    : null;
            final questions = args?.questions ?? state.allQuestions;
            final mcqSelected =
                args?.mcqSelectedAnswers ?? state.mcqSelectedAnswers;
            final mcqIsCorrect = args?.mcqIsCorrect ?? state.mcqIsCorrect;
            final gapFillUser =
                args?.gapFillUserAnswers ?? state.gapFillUserAnswers;
            // Normalize gap-fill correctness into: full-correct per question (Map<int, bool>)
            final Map<int, bool> gapFillFullCorrect = <int, bool>{};
            final Map<int, int> gapFillCorrectCount =
                state.gapFillCorrectCountByQuestion;

            if (questions.isEmpty) {
              return const _EmptyReviewState();
            }

            final totalQuestions = questions.length;
            int totalCorrect = 0;
            int totalIncorrect = 0;

            for (int i = 0; i < questions.length; i++) {
              final q = questions[i];
              if (q is Question) {
                final isCorrect = mcqIsCorrect[i] ?? false;
                if (isCorrect) {
                  totalCorrect++;
                } else {
                  totalIncorrect++;
                }
              } else if (q is df.GapFillQuestion) {
                // Prefer args-provided per-blank correctness when available
                bool full;
                if (args?.gapFillIsCorrect[i] != null) {
                  final list = args!.gapFillIsCorrect[i]!;
                  full = list.isNotEmpty && list.every((b) => b);
                } else {
                  final matched = gapFillCorrectCount[i] ?? 0;
                  final total = q.answers.length;
                  full = total > 0 && matched == total;
                }
                gapFillFullCorrect[i] = full;
                if (full) {
                  totalCorrect++;
                } else {
                  totalIncorrect++;
                }
              }
            }

            final accuracy =
                totalQuestions == 0
                    ? 0.0
                    : (totalCorrect / totalQuestions).clamp(0.0, 1.0);

            return LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding =
                    constraints.maxWidth > 1320
                        ? 96.0
                        : constraints.maxWidth > 1100
                        ? 72.0
                        : 40.0;
                final maxContentWidth =
                    constraints.maxWidth - (horizontalPadding * 2);
                final boundedWidth = maxContentWidth.clamp(680.0, 1180.0);

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 28,
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: boundedWidth.toDouble(),
                          ),
                          child: _DesktopReviewHeader(
                            courseName: state.course,
                            topicName: state.choosenTopic,
                            totalQuestions: totalQuestions,
                            totalCorrect: totalCorrect,
                            totalIncorrect: totalIncorrect,
                            accuracy: accuracy,
                            onBack: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: boundedWidth.toDouble(),
                            ),
                            child: Scrollbar(
                              thumbVisibility: true,
                              radius: const Radius.circular(16),
                              child: ListView.separated(
                                padding: const EdgeInsets.only(bottom: 36),
                                itemBuilder: (context, index) {
                                  final q = questions[index];
                                  return _ReviewCard(
                                    index: index,
                                    question: q,
                                    mcqSelectedAnswers: mcqSelected,
                                    mcqIsCorrect: mcqIsCorrect,
                                    gapFillUserAnswers: gapFillUser,
                                    gapFillIsCorrect: gapFillFullCorrect,
                                    gapFillCorrectCount: gapFillCorrectCount,
                                    isDesktop: true,
                                  );
                                },
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 24),
                                itemCount: questions.length,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyReviewState extends StatelessWidget {
  const _EmptyReviewState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.content_paste_off_rounded,
              size: 52,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              'No questions to review',
              style: GoogleFonts.rubik(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Finish a quiz to unlock your detailed review summary.',
              textAlign: TextAlign.center,
              style: GoogleFonts.rubik(
                fontSize: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: Text(
                'Back',
                style: GoogleFonts.rubik(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopReviewHeader extends StatelessWidget {
  final String courseName;
  final String? topicName;
  final int totalQuestions;
  final int totalCorrect;
  final int totalIncorrect;
  final double accuracy;
  final VoidCallback onBack;

  const _DesktopReviewHeader({
    required this.courseName,
    required this.topicName,
    required this.totalQuestions,
    required this.totalCorrect,
    required this.totalIncorrect,
    required this.accuracy,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accuracyPercent = (accuracy * 100).clamp(0, 100).toStringAsFixed(0);
    final topicLabel =
        (topicName?.isNotEmpty ?? false) ? topicName!.trim() : 'Review Summary';

    return Container(
      padding: const EdgeInsets.fromLTRB(36, 32, 36, 32),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  shape: const CircleBorder(),
                ),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: colorScheme.onSurface,
                  size: 20,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courseName.isNotEmpty ? courseName : 'Course Overview',
                      style: GoogleFonts.rubik(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      topicLabel,
                      style: GoogleFonts.rubik(
                        fontSize: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              FilledButton.tonalIcon(
                onPressed: onBack,
                icon: const Icon(Icons.exit_to_app_rounded),
                label: Text(
                  'Exit Review',
                  style: GoogleFonts.rubik(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 640;
              final stats = [
                _ReviewStat(label: 'Total Questions', value: '$totalQuestions'),
                _ReviewStat(label: 'Correct', value: '$totalCorrect'),
                _ReviewStat(label: 'Incorrect', value: '$totalIncorrect'),
                _ReviewStat(label: 'Accuracy', value: '$accuracyPercent%'),
              ];

              return isWide
                  ? Row(
                    children: stats
                        .map(
                          (stat) =>
                              Expanded(child: _ReviewStatCard(stat: stat)),
                        )
                        .toList(growable: false),
                  )
                  : Column(
                    children: [
                      for (final stat in stats) ...[
                        _ReviewStatCard(stat: stat),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
            },
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: accuracy.isNaN ? 0 : accuracy,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewStat {
  final String label;
  final String value;

  const _ReviewStat({required this.label, required this.value});
}

class _ReviewStatCard extends StatelessWidget {
  final _ReviewStat stat;

  const _ReviewStatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.label,
            style: GoogleFonts.rubik(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stat.value,
            style: GoogleFonts.rubik(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatefulWidget {
  final int index;
  final Object question;
  final Map<int, int> mcqSelectedAnswers;
  final Map<int, bool> mcqIsCorrect;
  final Map<int, List<String>> gapFillUserAnswers;
  final Map<int, bool> gapFillIsCorrect;
  final Map<int, int> gapFillCorrectCount;
  final bool isDesktop;

  const _ReviewCard({
    required this.index,
    required this.question,
    required this.mcqSelectedAnswers,
    required this.mcqIsCorrect,
    required this.gapFillUserAnswers,
    required this.gapFillIsCorrect,
    required this.gapFillCorrectCount,
    this.isDesktop = false,
  });

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _showExplanation = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final question = widget.question;
    final bool isMcq = question is Question && question.options != null;
    final bool isGapFill = question is df.GapFillQuestion;

    late final bool? isCorrect;
    late final Widget content;

    if (isMcq) {
      final mcq = question;
      final selectedIndex = widget.mcqSelectedAnswers[widget.index];
      final correctStr = mcq.correctAnswer;
      final correctIndex = int.tryParse(correctStr ?? '');

      // Logic fix: Check if selected index matches parsed correct index
      final bool computedCorrect =
          selectedIndex != null &&
          ((correctIndex != null && selectedIndex == correctIndex) ||
              (correctStr == selectedIndex.toString()));
      isCorrect = widget.mcqIsCorrect[widget.index] ?? computedCorrect;

      final explanation = mcq.explanation?.trim();
      final hasExplanation = explanation?.isNotEmpty == true;

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormattedMathText(
            content: mcq.text,
            textStyle: GoogleFonts.rubik(
              fontSize: widget.isDesktop ? 18 : 16,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          if (mcq.options != null)
            ...mcq.options!.asMap().entries.map((entry) {
              final optionIndex = entry.key;
              final optionText = entry.value;
              final isSelected = selectedIndex == optionIndex;
              final isCorrectOption = optionIndex == correctIndex;

              Color bgColor = Colors.transparent;
              Color borderColor = cs.outlineVariant.withValues(alpha: 0.5);
              Color textColor = cs.onSurface;
              IconData? icon;
              Color? iconColor;

              if (isCorrectOption) {
                bgColor = Colors.green.withValues(alpha: 0.1);
                borderColor = Colors.green;
                textColor = Colors.green.shade800;
                icon = Icons.check_circle;
                iconColor = Colors.green;
              } else if (isSelected && !isCorrectOption) {
                bgColor = Colors.red.withValues(alpha: 0.1);
                borderColor = Colors.red;
                textColor = Colors.red.shade800;
                icon = Icons.cancel;
                iconColor = Colors.red;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FormattedMathText(
                        content: optionText,
                        textStyle: GoogleFonts.rubik(
                          color: textColor,
                          fontWeight:
                              isSelected || isCorrectOption
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(icon, color: iconColor, size: 20),
                    ],
                  ],
                ),
              );
            }),

          if (hasExplanation) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () => setState(() => _showExplanation = !_showExplanation),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 20, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Explanation',
                      style: GoogleFonts.rubik(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showExplanation
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: cs.primary,
                    ),
                  ],
                ),
              ),
            ),
            if (_showExplanation)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FormattedMathText(
                  content: explanation!,
                  textStyle: GoogleFonts.rubik(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ],
      );
    } else if (isGapFill) {
      final gf = question;
      final userAnswers = widget.gapFillUserAnswers[widget.index] ?? const [];
      final matched = widget.gapFillCorrectCount[widget.index] ?? 0;
      final total = gf.answers.length;
      final bool full = matched == total && total > 0;
      isCorrect = full;

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormattedMathText(
            content: gf.prompt,
            textStyle: GoogleFonts.rubik(
              fontSize: widget.isDesktop ? 18 : 16,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ...gf.answers.asMap().entries.map((entry) {
            final gapIndex = entry.key;
            final correctAnswer = entry.value;
            final userAnswer =
                gapIndex < userAnswers.length ? userAnswers[gapIndex] : '';
            // Simple check for now, ideally pass per-gap correctness
            final isCorrectGap =
                userAnswer.trim().toLowerCase() ==
                correctAnswer.trim().toLowerCase();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isCorrectGap
                        ? Colors.green.withValues(alpha: 0.05)
                        : Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isCorrectGap
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Gap ${gapIndex + 1}',
                        style: GoogleFonts.rubik(
                          color:
                              isCorrectGap
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        isCorrectGap ? Icons.check : Icons.close,
                        color: isCorrectGap ? Colors.green : Colors.red,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userAnswer.isEmpty ? '(Empty)' : userAnswer,
                    style: GoogleFonts.rubik(
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  if (!isCorrectGap) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Correct: $correctAnswer',
                      style: GoogleFonts.rubik(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      );
    } else {
      isCorrect = null;
      content = const SizedBox.shrink();
    }

    final matchedForStatus =
        (question is df.GapFillQuestion)
            ? (widget.gapFillCorrectCount[widget.index] ?? 0)
            : ((isCorrect == true) ? 1 : 0);
    final totalForStatus =
        (question is df.GapFillQuestion) ? (question).answers.length : 1;
    final bool fullStatus =
        matchedForStatus == totalForStatus && totalForStatus > 0;
    final bool noneStatus = matchedForStatus == 0;
    final bool partialStatus = !fullStatus && !noneStatus;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (totalForStatus == 0) {
      statusColor = cs.outline;
      statusLabel = 'Needs Review';
      statusIcon = Icons.help_outline_rounded;
    } else if (fullStatus) {
      statusColor = Colors.green;
      statusLabel = 'Correct';
      statusIcon = Icons.check_circle_rounded;
    } else if (partialStatus) {
      statusColor = const Color(0xFFB45309);
      statusLabel = 'Partially Correct';
      statusIcon = Icons.auto_fix_high_rounded;
    } else {
      statusColor = Colors.red;
      statusLabel = 'Incorrect';
      statusIcon = Icons.cancel_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Question ${widget.index + 1}',
                  style: GoogleFonts.rubik(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: statusColor.withValues(alpha: 0.8),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.rubik(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(24), child: content),
        ],
      ),
    );
  }
}
