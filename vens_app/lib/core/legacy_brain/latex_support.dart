import 'package:flutter/material.dart';
import 'package:vens_hub/core/Brain/latex_support.dart';

/// Legacy wrapper compatibility: delegate to unified renderer
class LatexElement extends StatelessWidget {
  final String expression;

  const LatexElement({super.key, required this.expression});

  @override
  Widget build(BuildContext context) {
    return FormattedMathText(content: expression);
  }
}
