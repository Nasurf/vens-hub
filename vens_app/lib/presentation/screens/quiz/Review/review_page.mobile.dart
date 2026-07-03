import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:vens_hub/data/models/question_model.dart';
import 'package:vens_hub/core/Brain/data_formatting.dart' as df;
import 'package:vens_hub/core/Brain/latex_support.dart';
import 'package:google_fonts/google_fonts.dart';

class ReviewPageMobile extends StatefulWidget {
  final List<dynamic> questions;
  final Map<int, int> mcqSelectedAnswers;
  final Map<int, bool> mcqIsCorrect;
  final Map<int, List<String>> gapFillUserAnswers;
  final Map<int, List<bool>> gapFillIsCorrect;

  const ReviewPageMobile({
    super.key,
    required this.questions,
    required this.mcqSelectedAnswers,
    required this.mcqIsCorrect,
    required this.gapFillUserAnswers,
    required this.gapFillIsCorrect,
  });

  @override
  State<ReviewPageMobile> createState() => _ReviewPageMobileState();
}

class _ReviewPageMobileState extends State<ReviewPageMobile> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Simulate loading time for smooth transition
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Lottie.asset(
                  'assets/lottie/loading.json',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return CircularProgressIndicator(color: cs.primary);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Preparing review...',
                style: GoogleFonts.rubik(
                  fontSize: 16,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate stats
    int totalCorrect = 0;
    int totalQuestions = widget.questions.length;

    for (int i = 0; i < widget.questions.length; i++) {
      if (widget.questions[i] is Question) {
        if (widget.mcqIsCorrect[i] == true) totalCorrect++;
      } else if (widget.questions[i] is df.GapFillQuestion) {
        final correctList = widget.gapFillIsCorrect[i] ?? [];
        if (correctList.isNotEmpty && correctList.every((correct) => correct)) {
          totalCorrect++;
        }
      }
    }

    final accuracy = totalQuestions > 0 ? (totalCorrect / totalQuestions) : 0.0;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.close_rounded, color: cs.onSurface),
        ),
        title: Text(
          'Review Answers',
          style: GoogleFonts.rubik(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                _buildStatBadge(
                  context,
                  '${(accuracy * 100).round()}%',
                  'Score',
                  _getScoreColor(accuracy),
                ),
                const SizedBox(width: 12),
                Container(width: 1, height: 24, color: cs.outlineVariant),
                const SizedBox(width: 12),
                Text(
                  '$totalCorrect / $totalQuestions Correct',
                  style: GoogleFonts.rubik(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: widget.questions.length,
        itemBuilder: (context, index) {
          final question = widget.questions[index];

          if (question is Question) {
            return _MCQReviewCard(
              question: question,
              index: index,
              selectedAnswer: widget.mcqSelectedAnswers[index],
              isCorrect: widget.mcqIsCorrect[index] ?? false,
            );
          } else if (question is df.GapFillQuestion) {
            return _GapFillReviewCard(
              question: question,
              index: index,
              userAnswers: widget.gapFillUserAnswers[index] ?? [],
              correctAnswers: widget.gapFillIsCorrect[index] ?? [],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Color _getScoreColor(double accuracy) {
    if (accuracy >= 0.8) return Colors.green;
    if (accuracy >= 0.6) return Colors.blue;
    if (accuracy >= 0.4) return Colors.orange;
    return Colors.red;
  }

  Widget _buildStatBadge(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.rubik(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.rubik(
              color: color.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MCQReviewCard extends StatefulWidget {
  final Question question;
  final int index;
  final int? selectedAnswer;
  final bool isCorrect;

  const _MCQReviewCard({
    required this.question,
    required this.index,
    required this.selectedAnswer,
    required this.isCorrect,
  });

  @override
  State<_MCQReviewCard> createState() => _MCQReviewCardState();
}

class _MCQReviewCardState extends State<_MCQReviewCard> {
  bool _showExplanation = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final question = widget.question;
    final bool isCorrect = widget.isCorrect;
    final int? selectedAnswer = widget.selectedAnswer;
    final String? explanation = question.explanation?.trim();
    final bool hasExplanation = explanation?.isNotEmpty == true;

    // Parse correct answer index
    final int? correctAnswerIndex = int.tryParse(question.correctAnswer ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isCorrect
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Question ${widget.index + 1}',
                  style: GoogleFonts.rubik(
                    color:
                        isCorrect ? Colors.green.shade800 : Colors.red.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (!isCorrect)
                  Text(
                    'Incorrect',
                    style: GoogleFonts.rubik(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FormattedMathText(
                  content: question.text,
                  textStyle: GoogleFonts.rubik(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 24),

                if (question.options != null)
                  ...question.options!.asMap().entries.map((entry) {
                    final optionIndex = entry.key;
                    final optionText = entry.value;
                    final isSelected = selectedAnswer == optionIndex;

                    // Logic fix: Check if this option is the correct one based on index
                    final isCorrectOption = optionIndex == correctAnswerIndex;

                    Color bgColor = Colors.transparent;
                    Color borderColor = cs.outlineVariant.withValues(
                      alpha: 0.5,
                    );
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
                    onTap:
                        () => setState(
                          () => _showExplanation = !_showExplanation,
                        ),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 20,
                            color: cs.primary,
                          ),
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
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _GapFillReviewCard extends StatelessWidget {
  final df.GapFillQuestion question;
  final int index;
  final List<String> userAnswers;
  final List<bool> correctAnswers;

  const _GapFillReviewCard({
    required this.question,
    required this.index,
    required this.userAnswers,
    required this.correctAnswers,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final allCorrect = correctAnswers.every((correct) => correct);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  allCorrect
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  allCorrect ? Icons.check_circle : Icons.warning_rounded,
                  color: allCorrect ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Question ${index + 1}',
                  style: GoogleFonts.rubik(
                    color:
                        allCorrect
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FormattedMathText(
                  content: question.prompt,
                  textStyle: GoogleFonts.rubik(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 24),

                ...question.answers.asMap().entries.map((entry) {
                  final gapIndex = entry.key;
                  final correctAnswer = entry.value;
                  final userAnswer =
                      gapIndex < userAnswers.length
                          ? userAnswers[gapIndex]
                          : '';
                  final isCorrect =
                      gapIndex < correctAnswers.length
                          ? correctAnswers[gapIndex]
                          : false;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          isCorrect
                              ? Colors.green.withValues(alpha: 0.05)
                              : Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isCorrect
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
                                    isCorrect
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              isCorrect ? Icons.check : Icons.close,
                              color: isCorrect ? Colors.green : Colors.red,
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
                        if (!isCorrect) ...[
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
            ),
          ),
        ],
      ),
    );
  }
}
