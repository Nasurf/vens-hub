import 'package:flutter/material.dart';

import 'package:vens_hub/core/Brain/latex_support.dart';

class McqHeaderCard extends StatelessWidget {
  const McqHeaderCard({
    super.key,
    required this.courseName,
    required this.currentIndex,
    required this.total,
    required this.onBack,
    this.subtitle,
    this.trailing,
    this.margin = const EdgeInsets.fromLTRB(16, 10, 16, 10),
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 16),
    this.maxSegments = 14,
  });

  final String courseName;
  final int currentIndex;
  final int total;
  final VoidCallback onBack;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final int maxSegments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final current = total == 0 ? 0 : (currentIndex + 1).clamp(1, total);
    final left = total == 0 ? 0 : (total - current).clamp(0, total);

    final displayCourse =
        courseName.trim().isNotEmpty ? courseName.trim() : 'Course';
    final displaySubtitle = subtitle?.trim();

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: isDark ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton.filled(
                onPressed: onBack,
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.75),
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(10),
                ),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: colorScheme.onSurface,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayCourse,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (displaySubtitle != null &&
                        displaySubtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        displaySubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _McqInfoPill(
                          icon: Icons.help_outline_rounded,
                          label: '$left left',
                        ),
                        const SizedBox(width: 8),
                        _McqInfoPill(
                          icon: Icons.quiz_rounded,
                          label: '$current/$total',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          const SizedBox(height: 14),
          McqSegmentedProgress(
            current: current,
            total: total,
            maxSegments: maxSegments,
          ),
        ],
      ),
    );
  }
}

class McqSegmentedProgress extends StatelessWidget {
  const McqSegmentedProgress({
    super.key,
    required this.current,
    required this.total,
    this.maxSegments = 12,
  });

  final int current;
  final int total;
  final int maxSegments;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final segments = total <= maxSegments ? total : maxSegments;
    final ratio = total == 0 ? 0.0 : current / total;
    final filledSegments = (ratio * segments).ceil().clamp(0, segments);

    return Row(
      children: List.generate(segments * 2 - 1, (index) {
        if (index.isOdd) {
          return const SizedBox(width: 4);
        }
        final segmentIndex = index ~/ 2;
        final isFilled = segmentIndex < filledSegments;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient:
                  isFilled
                      ? LinearGradient(
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.95),
                          colorScheme.primary,
                        ],
                      )
                      : null,
              color:
                  isFilled
                      ? null
                      : colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.9,
                      ),
              boxShadow:
                  isFilled
                      ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                      : null,
            ),
          ),
        );
      }),
    );
  }
}

class McqQuestionCard extends StatelessWidget {
  const McqQuestionCard({
    super.key,
    required this.questionText,
    required this.options,
    required this.index,
    required this.total,
    required this.onSelect,
    this.selectedIndex,
    this.isAnswered = false,
    this.correctIndex,
    this.scoreChip,
    this.helperText,
    this.maxWidth = 880,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 16, 16, 20),
  });

  final String questionText;
  final List<String> options;
  final int index;
  final int total;
  final ValueChanged<int> onSelect;
  final int? selectedIndex;
  final bool isAnswered;
  final int? correctIndex;
  final Widget? scoreChip;
  final String? helperText;
  final double maxWidth;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.65),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.quiz_rounded,
                      color: colorScheme.onPrimaryContainer,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Question ${index + 1} of $total',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    if (scoreChip != null) ...[
                      const SizedBox(width: 12),
                      scoreChip!,
                    ],
                  ],
                ),
              ),
              Padding(
                padding: contentPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FormattedMathText(
                      content: questionText,
                      textStyle: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.28,
                      ),
                    ),
                    if (helperText != null &&
                        helperText!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        helperText!,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Column(
                      children: List.generate(options.length, (optionIndex) {
                        final isSelected = selectedIndex == optionIndex;
                        final isCorrect =
                            isAnswered && correctIndex == optionIndex;
                        final isWrongSelection =
                            isAnswered && isSelected && !isCorrect;

                        Color backgroundColor() {
                          if (isCorrect) {
                            return colorScheme.primaryContainer.withValues(
                              alpha: 0.45,
                            );
                          }
                          if (isWrongSelection) {
                            return colorScheme.errorContainer.withValues(
                              alpha: 0.35,
                            );
                          }
                          if (isSelected) {
                            return colorScheme.primaryContainer.withValues(
                              alpha: 0.55,
                            );
                          }
                          return colorScheme.surface;
                        }

                        Color borderColor() {
                          if (isCorrect) return colorScheme.primary;
                          if (isWrongSelection) return colorScheme.error;
                          if (isSelected) return colorScheme.primary;
                          return colorScheme.outlineVariant.withValues(
                            alpha: 0.55,
                          );
                        }

                        Color badgeBackground() {
                          if (isCorrect) return colorScheme.primary;
                          if (isWrongSelection) return colorScheme.error;
                          if (isSelected) return colorScheme.primary;
                          return colorScheme.surfaceContainerHighest;
                        }

                        Color badgeForeground() {
                          if (isCorrect) return colorScheme.onPrimary;
                          if (isWrongSelection) return colorScheme.onError;
                          if (isSelected) return colorScheme.onPrimary;
                          return colorScheme.onSurface;
                        }

                        IconData? trailingIcon;
                        Color? trailingColor;
                        if (isCorrect) {
                          trailingIcon = Icons.check_rounded;
                          trailingColor = colorScheme.primary;
                        } else if (isWrongSelection) {
                          trailingIcon = Icons.close_rounded;
                          trailingColor = colorScheme.error;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              if (!isAnswered) onSelect(optionIndex);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                color: backgroundColor(),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: borderColor(),
                                  width: 1.2,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: badgeBackground(),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      String.fromCharCode(65 + optionIndex),
                                      style: TextStyle(
                                        color: badgeForeground(),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FormattedMathText(
                                      content: options[optionIndex],
                                      textStyle: theme.textTheme.bodyLarge
                                          ?.copyWith(height: 1.25),
                                    ),
                                  ),
                                  if (trailingIcon != null) ...[
                                    const SizedBox(width: 10),
                                    Icon(
                                      trailingIcon,
                                      color: trailingColor,
                                      size: 20,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _McqInfoPill extends StatelessWidget {
  const _McqInfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
