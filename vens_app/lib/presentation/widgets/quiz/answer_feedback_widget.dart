import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class FormattedMathText extends StatelessWidget {
  final String content;
  final TextStyle? textStyle;
  final TextAlign textAlign;
  final double mathScale;

  const FormattedMathText({
    super.key,
    required this.content,
    this.textStyle,
    this.textAlign = TextAlign.start,
    this.mathScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final base = textStyle ?? DefaultTextStyle.of(context).style;
    final regex = RegExp(r'(\$\$.*?\$\$|\$.*?\$)', dotAll: true);
    final spans = <InlineSpan>[];
    int last = 0;

    for (final m in regex.allMatches(content)) {
      if (m.start > last) {
        spans.add(TextSpan(text: content.substring(last, m.start)));
      }
      final raw = m.group(0)!;
      final isBlock = raw.startsWith(r'$$');
      final tex =
          isBlock
              ? raw.substring(2, raw.length - 2)
              : raw.substring(1, raw.length - 1);

      spans.add(
        WidgetSpan(
          alignment:
              isBlock
                  ? PlaceholderAlignment.middle
                  : PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Math.tex(
              tex,
              mathStyle: isBlock ? MathStyle.display : MathStyle.text,
              textStyle: base.copyWith(
                fontSize: (base.fontSize ?? 14) * mathScale,
              ),
            ),
          ),
        ),
      );
      last = m.end;
    }
    if (last < content.length) {
      spans.add(TextSpan(text: content.substring(last)));
    }
    return RichText(
      textAlign: textAlign,
      text: TextSpan(style: base, children: spans),
    );
  }
}

class AnswerFeedbackWidget {
  static Future<void> show(
    BuildContext context, {
    required bool isCorrect,
    required String questionText,
    required String explanation,
    required bool isLastQuestion,
    required VoidCallback onNext,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    var removed = false;
    void safeRemove() {
      if (removed) return;
      removed = true;
      try {
        entry.remove();
      } catch (_) {}
    }

    entry = OverlayEntry(
      builder:
          (_) => _OverlayRoot(
            child: _AnswerFeedbackCard(
              isCorrect: isCorrect,
              questionText: questionText,
              explanation: explanation,
              isLastQuestion: isLastQuestion,
              onNext: () {
                safeRemove();
                onNext();
              },
              onClose: safeRemove,
            ),
          ),
    );

    overlay.insert(entry);
  }
}

class _OverlayRoot extends StatefulWidget {
  final Widget child;
  const _OverlayRoot({required this.child});
  @override
  State<_OverlayRoot> createState() => _OverlayRootState();
}

class _OverlayRootState extends State<_OverlayRoot> {
  bool expanded = false;
  void setExpanded(bool v) => setState(() => expanded = v);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(color: Colors.black.withValues(alpha: 0.3)),
        ),
        Positioned.fill(
          child: SafeArea(
            child: _ExpandScope(
              expanded: expanded,
              setExpanded: setExpanded,
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpandScope extends InheritedWidget {
  final bool expanded;
  final ValueChanged<bool> setExpanded;
  const _ExpandScope({
    required this.expanded,
    required this.setExpanded,
    required super.child,
  });
  static _ExpandScope of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<_ExpandScope>()!;
  @override
  bool updateShouldNotify(_ExpandScope o) => expanded != o.expanded;
}

class _AnswerFeedbackCard extends StatefulWidget {
  final bool isCorrect;
  final String questionText;
  final String explanation;
  final bool isLastQuestion;
  final VoidCallback onNext;
  final VoidCallback onClose;

  const _AnswerFeedbackCard({
    required this.isCorrect,
    required this.questionText,
    required this.explanation,
    required this.isLastQuestion,
    required this.onNext,
    required this.onClose,
  });

  @override
  State<_AnswerFeedbackCard> createState() => _AnswerFeedbackCardState();
}

class _AnswerFeedbackCardState extends State<_AnswerFeedbackCard> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = _ExpandScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final cardColor =
        widget.isCorrect ? cs.primaryContainer : cs.errorContainer;
    final textColor =
        widget.isCorrect ? cs.onPrimaryContainer : cs.onErrorContainer;

    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 1.1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Align(
        alignment: scope.expanded ? Alignment.center : Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          margin: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: cardColor,
              elevation: 12,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(
                          widget.isCorrect ? Icons.check_circle : Icons.cancel,
                          size: 28,
                          color: textColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.isCorrect ? 'Excellent!' : 'Not quite right',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: widget.onClose,
                          icon: Icon(Icons.close_rounded, color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Question
                    Text(
                      'Question',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: textColor.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: textColor.withValues(alpha: 0.18),
                        ),
                      ),
                      child: FormattedMathText(
                        content: widget.questionText,
                        textStyle: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: textColor, height: 1.25),
                      ),
                    ),

                    // Explanation (if expanded)
                    if (scope.expanded) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Explanation',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: textColor.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: textColor.withValues(alpha: 0.20),
                          ),
                        ),
                        child: FormattedMathText(
                          content:
                              widget.explanation.isNotEmpty
                                  ? widget.explanation
                                  : 'No explanation available.',
                          textStyle: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: textColor, height: 1.35),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: textColor.withValues(alpha: 0.55),
                              ),
                              foregroundColor: textColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => scope.setExpanded(!scope.expanded),
                            child: Text(
                              scope.expanded ? 'Hide' : 'Explanation',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: textColor,
                              foregroundColor: cardColor,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: widget.onNext,
                            child: Text(
                              widget.isLastQuestion
                                  ? 'See Results'
                                  : 'Next Question',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
