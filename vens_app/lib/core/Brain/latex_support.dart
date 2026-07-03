import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class FormattedMathText extends StatelessWidget {
  final String content;
  final TextStyle? textStyle;
  final double mathScale;

  const FormattedMathText({
    super.key,
    required this.content,
    this.textStyle,
    this.mathScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultTextStyle = theme.textTheme.bodyLarge ?? const TextStyle();
    final mergedTextStyle = defaultTextStyle
        .merge(textStyle)
        .copyWith(textBaseline: TextBaseline.alphabetic);

    return RichText(
      text: TextSpan(
        style: mergedTextStyle,
        children: FormattedMathText.buildTextSpans(
          context,
          content,
          mergedTextStyle,
          mathScale: mathScale,
        ),
      ),
    );
  }

  /// Build text + LaTeX spans, supporting **bold**, $...$, $$...$$, \( ... \), \[ ... \]
  static List<InlineSpan> buildTextSpans(
    BuildContext context,
    String text,
    TextStyle style, {
    double mathScale = 1.0,
  }) {
    // Sanitize obvious issues first
    text = _preSanitizeRaw(text);

    final List<InlineSpan> spans = [];

    // Protect escaped dollars so they are treated as literal text
    const String sentinelDollar = '\u{E000}';
    text = text.replaceAll(r'\$', sentinelDollar);

    // Normalize incoming text: convert various newline notations to spaces for layout
    String normalized = text
        .replaceAll(RegExp(r'\\n'), ' ')
        .replaceAll('/n', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
    // Collapse repeated whitespace
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Tokenize: $$…$$, $…$, \(…\), \[…\], **…**
    final regex = RegExp(
      r'(\$\$([\s\S]+?)\$\$)' // 1:whole, 2:display content
      r'|(\$([^$]+?)\$)' // 3:whole, 4:inline content
      r'|(\\\((.+?)\\\))' // 5:whole, 6:inline via \( \)
      r'|(\\\[([\s\S]+?)\\\])' // 7:whole, 8:display via \[ \]
      r'|(\*\*([^*]+)\*\*)', // 9:whole, 10:bold content
    );

    int start = 0;
    while (true) {
      final match = regex.firstMatch(normalized.substring(start));
      if (match == null) {
        final tail = normalized
            .substring(start)
            .replaceAll(sentinelDollar, r'\$');
        if (tail.isNotEmpty) spans.add(TextSpan(text: tail));
        break;
      }

      if (match.start > 0) {
        spans.add(
          TextSpan(
            text: normalized
                .substring(start, start + match.start)
                .replaceAll(sentinelDollar, r'\$'),
          ),
        );
      }

      // **bold**
      if (match.group(10) != null) {
        spans.add(
          TextSpan(
            text: match.group(10)!.replaceAll(sentinelDollar, r'\$'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }
      // $$ display $$
      else if (match.group(2) != null) {
        spans.add(
          WidgetSpan(
            child: _buildMathExpression(
              context,
              match.group(2)!.replaceAll(sentinelDollar, r'\$'),
              style,
              isDisplay: true,
              mathScale: mathScale,
            ),
            alignment: PlaceholderAlignment.middle,
          ),
        );
      }
      // $ inline $
      else if (match.group(4) != null) {
        spans.add(
          WidgetSpan(
            child: _buildMathExpression(
              context,
              match.group(4)!.replaceAll(sentinelDollar, r'\$'),
              style,
              isDisplay: false,
              mathScale: mathScale,
            ),
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
          ),
        );
      }
      // \( inline \)
      else if (match.group(6) != null) {
        spans.add(
          WidgetSpan(
            child: _buildMathExpression(
              context,
              match.group(6)!.replaceAll(sentinelDollar, r'\$'),
              style,
              isDisplay: false,
              mathScale: mathScale,
            ),
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
          ),
        );
      }
      // \[ display \]
      else if (match.group(8) != null) {
        spans.add(
          WidgetSpan(
            child: _buildMathExpression(
              context,
              match.group(8)!.replaceAll(sentinelDollar, r'\$'),
              style,
              isDisplay: true,
              mathScale: mathScale,
            ),
            alignment: PlaceholderAlignment.middle,
          ),
        );
      } else {
        // Fallback: treat as plain text
        spans.add(
          TextSpan(
            text: normalized
                .substring(start, start + match.end)
                .replaceAll(sentinelDollar, r'\$'),
          ),
        );
      }

      start += match.end;
    }

    return spans;
  }

  static Widget _buildMathExpression(
    BuildContext context,
    String expression,
    TextStyle style, {
    bool isDisplay = false,
    double mathScale = 1.0,
  }) {
    // Sanitize the expression: replace newlines with spaces to prevent LaTeX errors
    String sanitizedExpression =
        expression.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();

    // Fix common LaTeX issues
    sanitizedExpression = _fixLatexExpression(sanitizedExpression);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double deviceScale = MediaQuery.textScalerOf(context).scale(1);
        final mathWidget = Math.tex(
          sanitizedExpression,
          mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
          textStyle: style,
          textScaleFactor: deviceScale * mathScale,
          onErrorFallback: (error) {
            // Graceful fallback: render the raw expression as plain text
            return Text(sanitizedExpression, style: style, softWrap: true);
          },
        );

        // Add subtle spacing around math for better readability
        final Widget padded = Padding(
          padding:
              isDisplay
                  ? const EdgeInsets.symmetric(vertical: 6)
                  : const EdgeInsets.symmetric(horizontal: 4),
          child: mathWidget,
        );

        if (isDisplay) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: padded,
          );
        }

        // Inline math must support baseline; avoid wrapping in scroll views
        return padded;
      },
    );
  }

  static String _fixLatexExpression(String expression) {
    // Fix common LaTeX formatting issues
    String fixed = expression;

    // Normalize common unicode math symbols that may appear from copy/paste
    fixed = fixed
        .replaceAll('−', '-') // minus
        .replaceAll('–', '-') // en dash
        .replaceAll('—', '-') // em dash
        // Map unicode operators to proper LaTeX commands (single backslash)
        .replaceAll('×', '\\times ')
        .replaceAll('÷', '\\div ');

    // Collapse over-escaped LaTeX commands down to a single backslash
    final cmd = RegExp(
      r'\\{2,}(frac|sqrt|text|mathrm|left|right|times|div|cdot|pm|mp|leq|geq|neq|approx|sin|cos|tan|log|ln|sum|int|lim|to|rightarrow|leftarrow|cdots|dots|alpha|beta|theta|pi|Omega|omega|mu|sigma|Delta|nabla|infty|partial|vec|bar|hat)',
    );
    fixed = fixed.replaceAllMapped(cmd, (m) => '\\${m.group(1)!}');

    // Remove raw line breaks (\\) used outside alignment environments.
    fixed = fixed.replaceAll(RegExp(r'\\{2,}(?![a-zA-Z])'), ' ');

    // Ensure common LaTeX structures are intact (idempotent tweaks)
    fixed = fixed.replaceAll(r'\\text{', r'\\text{');
    fixed = fixed.replaceAll(r'\\mathrm{', r'\\mathrm{');
    fixed = fixed.replaceAll(r'\\frac{', r'\\frac{');
    fixed = fixed.replaceAll(r'\\int_{', r'\\int_{');
    fixed = fixed.replaceAll(r'\\sum_{', r'\\sum_{');
    fixed = fixed.replaceAll(r'\\sqrt{', r'\\sqrt{');
    fixed = fixed.replaceAll(r'\\left(', r'\\left(');
    fixed = fixed.replaceAll(r'\\right)', r'\\right)');
    fixed = fixed.replaceAll(r'\\left[', r'\\left[');
    fixed = fixed.replaceAll(r'\\right]', r'\\right]');
    fixed = fixed.replaceAll(r'\\left\\{', r'\\left\\{');
    fixed = fixed.replaceAll(r'\\right\\}', r'\\right\\}');

    // Remove any extra whitespace around math delimiters
    fixed = fixed.replaceAll(RegExp(r'\s*\$\s*'), r'\$');
    fixed = fixed.replaceAll(RegExp(r'\s*\$\$\s*'), r'\$\$');

    // Normalize curly quotes and primes
    fixed = fixed
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('’', "'")
        .replaceAll('‘', "'");

    // Attempt to balance stray \\left/\\right by dropping an unmatched token
    final leftCount =
        RegExp(r'\\left(?=[\\s\\(\\[\\{])').allMatches(fixed).length;
    final rightCount =
        RegExp(r'\\right(?=[\\s\\)\\]\\}])').allMatches(fixed).length;
    if (leftCount != rightCount) {
      if (leftCount > rightCount) {
        fixed = fixed.replaceFirst(RegExp(r'\\left(?=[\\s\\(\\[\\{])'), '');
      } else {
        fixed = fixed.replaceFirst(RegExp(r'\\right(?=[\\s\\)\\]\\}])'), '');
      }
    }

    return fixed;
  }

  // Attempts to clean up raw strings that contain stray LaTeX markers that would
  // otherwise trigger Math.tex parse errors. This runs before splitting into
  // inline/display math tokens.
  static String _preSanitizeRaw(String raw) {
    String s = raw;

    // If there is an odd number of inline math delimiters, drop them to avoid
    // feeding half-open fragments to the parser (common case: a trailing $).
    final int dollarCount = RegExp(r'\$').allMatches(s).length;
    if (dollarCount % 2 != 0) {
      s = s.replaceAll(r'$', '');
    }

    // When there are no inline math delimiters, unwrap common text-mode macros
    // into plain text to avoid unexpected "\\" errors (e.g. 32\\text{ items}).
    if (!RegExp(r'\$').hasMatch(s)) {
      s = s.replaceAllMapped(
        RegExp(r'\\text\{([^}]*)\}'),
        (m) => m.group(1) ?? '',
      );
      s = s.replaceAllMapped(
        RegExp(r'\\mathrm\{([^}]*)\}'),
        (m) => m.group(1) ?? '',
      );
    }

    // Normalize accidental spaces after backslash in common commands
    s = s.replaceAll(RegExp(r'\\\s+text\{'), r'\\text{');
    s = s.replaceAll(RegExp(r'\\\s*frac\{'), r'\\frac{');

    return s;
  }
}
