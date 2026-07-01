import 'package:flutter/material.dart';
import 'package:vens_hub/core/Brain/data_formatting.dart' as df;
import 'package:vens_hub/core/Brain/latex_support.dart';
import 'package:vens_hub/presentation/widgets/common/report_issue_dialog.dart';

class DragDropGapFillWidget extends StatefulWidget {
  final df.GapFillQuestion question;
  final int questionIndex;
  final Map<int, List<String>> userAnswers;
  final Map<int, bool> isCorrect;
  final Function(List<String>) onAnswerSubmitted;

  const DragDropGapFillWidget({
    super.key,
    required this.question,
    required this.questionIndex,
    required this.userAnswers,
    required this.isCorrect,
    required this.onAnswerSubmitted,
  });

  @override
  State<DragDropGapFillWidget> createState() => _DragDropGapFillWidgetState();
}

class _DragDropGapFillWidgetState extends State<DragDropGapFillWidget> {
  late List<String?> _selectedAnswers;
  late List<String> _availableOptions;
  bool _isSubmitted = false;
  int? _activeGapIndex; // which gap is currently targeted for option selection
  List<bool>? _gapCorrectness; // computed after submission, order-insensitive

  @override
  void initState() {
    super.initState();
    _initializeAnswers();
    _checkIfSubmitted();
  }

  void _initializeAnswers() {
    final gapCount = widget.question.answers.length;
    _selectedAnswers = List.filled(gapCount, null);

    // Initialize available options (shuffled)
    _availableOptions = List<String>.from(widget.question.options);
    _availableOptions.shuffle();

    // If already submitted, populate with user answers
    if (widget.userAnswers.containsKey(widget.questionIndex)) {
      final userAnswers = widget.userAnswers[widget.questionIndex]!;
      for (
        int i = 0;
        i < userAnswers.length && i < _selectedAnswers.length;
        i++
      ) {
        _selectedAnswers[i] = userAnswers[i];
      }
    }

    // Default active gap to the first empty gap
    _activeGapIndex = _selectedAnswers.indexWhere((a) => a == null);
  }

  void _checkIfSubmitted() {
    _isSubmitted = widget.isCorrect.containsKey(widget.questionIndex);
    if (_isSubmitted) {
      _computeGapCorrectness();
    }
  }

  @override
  void didUpdateWidget(DragDropGapFillWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkIfSubmitted();
    // Keep the active gap valid after updates
    if (_activeGapIndex == null ||
        _activeGapIndex! < 0 ||
        _activeGapIndex! >= _selectedAnswers.length) {
      _activeGapIndex = _selectedAnswers.indexWhere((a) => a == null);
    }
  }

  void _computeGapCorrectness() {
    final List<String> correct =
        widget.question.answers.map((e) => e.trim().toLowerCase()).toList();
    final Map<String, int> remaining = {};
    for (final c in correct) {
      remaining[c] = (remaining[c] ?? 0) + 1;
    }
    final List<bool> results = [];
    for (final sel in _selectedAnswers) {
      if (sel == null) {
        results.add(false);
        continue;
      }
      final s = sel.trim().toLowerCase();
      final left = remaining[s] ?? 0;
      if (left > 0) {
        results.add(true);
        remaining[s] = left - 1;
      } else {
        results.add(false);
      }
    }
    _gapCorrectness = results;
  }

  void _submitAnswer() {
    final answers =
        _selectedAnswers
            .where((answer) => answer != null)
            .cast<String>()
            .toList();
    if (answers.length == widget.question.answers.length) {
      widget.onAnswerSubmitted(answers);
    }
  }

  // Note: selecting an answer is handled by _handleOptionTap which routes to the active gap

  void _clearAnswer(int gapIndex) {
    if (_isSubmitted) return;

    setState(() {
      _selectedAnswers[gapIndex] = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCorrect = widget.isCorrect[widget.questionIndex];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question header with report button on right edge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Question ${widget.questionIndex + 1}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Report issue',
                    icon: Icon(
                      Icons.more_vert,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () async {
                      final value = await showMenu(
                        context: context,
                        position: const RelativeRect.fromLTRB(1000, 80, 16, 0),
                        items: [
                          const PopupMenuItem<int>(
                            value: 1,
                            child: Text('Report issue'),
                          ),
                        ],
                      );

                      if (!context.mounted) return;

                      if (value == 1) {
                        await showReportIssueDialog(
                          context,
                          payload: ReportIssuePayload(
                            questionType: 'gap_fill',
                            questionText: widget.question.prompt,
                            courseName: widget.question.courseName,
                            topic: widget.question.topic,
                            difficulty: widget.question.difficulty,
                            questionIndex: widget.questionIndex,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Question prompt with selectable gaps
              _buildPromptWithSelectableGaps(),

              const SizedBox(height: 16),

              // Single options bank (Duolingo style)
              _buildOptionsBank(),

              // Spacing before result/button so it doesn't stick to options
              const SizedBox(height: 12),

              // Submit button or result
              if (!_isSubmitted)
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed:
                        _selectedAnswers.every((answer) => answer != null)
                            ? _submitAnswer
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: const Text('Check Answer'),
                  ),
                )
              else
                _buildResult(isCorrect),

              // Explanation
              if (_isSubmitted && isCorrect != null) _buildExplanation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptWithSelectableGaps() {
    final parts = widget.question.prompt.split('___');
    int gapIndex = 0;

    final TextStyle baseStyle =
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle();

    // Collect inline spans for text/math and embed gap widgets inline
    final List<InlineSpan> spans = [];

    for (int i = 0; i < parts.length; i++) {
      // Add text/math part as inline spans so wrapping works
      if (parts[i].isNotEmpty) {
        spans.addAll(
          FormattedMathText.buildTextSpans(
            context,
            parts[i],
            baseStyle,
            mathScale: 1.0,
          ),
        );
      }

      // Add a selectable gap inline if not the last part
      if (i < parts.length - 1 && gapIndex < _selectedAnswers.length) {
        spans.add(
          WidgetSpan(
            child: _buildSelectableGap(gapIndex),
            alignment: PlaceholderAlignment.middle,
          ),
        );
        gapIndex++;
      }
    }

    return RichText(text: TextSpan(style: baseStyle, children: spans));
  }

  Widget _buildSelectableGap(int gapIndex) {
    final selectedAnswer = _selectedAnswers[gapIndex];
    final bool isCorrect =
        _isSubmitted && (_gapCorrectness?[gapIndex] ?? false);
    final isActive =
        _activeGapIndex == gapIndex ||
        (_activeGapIndex == null && selectedAnswer == null);

    return GestureDetector(
      onTap:
          _isSubmitted
              ? null
              : () {
                setState(() => _activeGapIndex = gapIndex);
              },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                _isSubmitted
                    ? (isCorrect ? const Color(0xFF0D3B1E) : Colors.red)
                    : (isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline),
            width: 2,
          ),
          color:
              _isSubmitted
                  ? (isCorrect
                      ? const Color(0xFF0D3B1E).withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.08))
                  : Theme.of(context).colorScheme.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedAnswer ?? 'Tap to choose',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color:
                    _isSubmitted
                        ? (isCorrect ? const Color(0xFF0D3B1E) : Colors.red)
                        : (selectedAnswer != null
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ),
            if (selectedAnswer != null && !_isSubmitted)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: InkWell(
                  onTap: () => _clearAnswer(gapIndex),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int? _nextEmptyGapIndex({int? startAfter}) {
    final start = startAfter != null ? startAfter + 1 : 0;
    for (int i = start; i < _selectedAnswers.length; i++) {
      if (_selectedAnswers[i] == null) return i;
    }
    for (int i = 0; i < start && i < _selectedAnswers.length; i++) {
      if (_selectedAnswers[i] == null) return i;
    }
    return null;
  }

  void _handleOptionTap(String option) {
    if (_isSubmitted) return;
    if (_selectedAnswers.contains(option)) return; // already used

    final targetIndex = _activeGapIndex ?? _nextEmptyGapIndex();
    if (targetIndex == null) return;

    setState(() {
      _selectedAnswers[targetIndex] = option;
      _activeGapIndex = _nextEmptyGapIndex(startAfter: targetIndex);
    });
  }

  Widget _buildOptionsBank() {
    // All options shown once; disable those already used
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Options',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _availableOptions.map((option) {
                final isUsed = _selectedAnswers.contains(option);
                return InkWell(
                  onTap: isUsed ? null : () => _handleOptionTap(option),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color:
                          isUsed
                              ? Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest
                              : Theme.of(context).colorScheme.surfaceContainer,
                      border: Border.all(
                        color:
                            isUsed
                                ? Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.6)
                                : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Text(
                      option,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            isUsed
                                ? Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5)
                                : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  // Old inline gap with options removed; options are shown below the prompt now.

  Widget _buildResult(bool? isCorrect) {
    // Compute partial credit: how many gaps match any correct answer (order-insensitive)
    final List<String> correctAnswers =
        widget.question.answers.map((a) => a.trim().toLowerCase()).toList();
    final List<String> userAnswers =
        (widget.userAnswers[widget.questionIndex] ?? const [])
            .map((a) => a.trim().toLowerCase())
            .toList();

    int countMatches(List<String> user, List<String> correct) {
      final Map<String, int> remaining = {};
      for (final c in correct) {
        remaining[c] = (remaining[c] ?? 0) + 1;
      }
      int matches = 0;
      for (final u in user) {
        final left = remaining[u] ?? 0;
        if (left > 0) {
          matches++;
          remaining[u] = left - 1;
        }
      }
      return matches;
    }

    final int totalGaps = correctAnswers.length;
    final int matched = countMatches(userAnswers, correctAnswers);
    final bool allCorrect = matched == totalGaps && totalGaps > 0;
    final bool someCorrect = matched > 0 && matched < totalGaps;

    const Color successColor = Color(0xFF0D3B1E);
    const Color warningColor = Color(0xFFB45309); // dark orange
    const Color errorColor = Colors.red;

    final Color bgColor =
        allCorrect
            ? successColor.withValues(alpha: 0.12)
            : (someCorrect
                ? warningColor.withValues(alpha: 0.12)
                : errorColor.withValues(alpha: 0.10));
    final Color borderColor =
        allCorrect ? successColor : (someCorrect ? warningColor : errorColor);
    final IconData icon =
        allCorrect
            ? Icons.check_circle
            : (someCorrect ? Icons.priority_high_rounded : Icons.cancel);
    final String label =
        allCorrect ? 'Correct!' : (someCorrect ? 'Almost got it' : 'Incorrect');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: borderColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, color: borderColor),
          ),
          const SizedBox(width: 8),
          Text(
            '($matched/$totalGaps correct)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildExplanation() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explanation:',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          FormattedMathText(
            content: widget.question.explanation,
            textStyle: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
