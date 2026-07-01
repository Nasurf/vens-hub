import 'package:vens_hub/presentation/screens/quiz/CompletionScreen/completionScreen.desktop.dart';
import 'package:vens_hub/presentation/screens/quiz/CompletionScreen/completionScreen.mobile.dart';
import 'package:vens_hub/presentation/widgets/common/app_layout.dart';
import 'package:flutter/material.dart';

class CompletionPage extends StatefulWidget {
  final int numOfQuestions;
  final int numOfCorrectAnswers;
  final int? streakBefore;
  final int? streakAfter;
  final bool isFirstCompletion;

  const CompletionPage({
    super.key,
    required this.numOfQuestions,
    required this.numOfCorrectAnswers,
    this.streakBefore,
    this.streakAfter,
    this.isFirstCompletion = false,
  });

  @override
  State<CompletionPage> createState() => _CompletionPageState();
}

class _CompletionPageState extends State<CompletionPage> {
  @override
  Widget build(BuildContext context) {
    return AppLayoutBuilder(
      mobile: CompletionPageMobile(
        numOfQuestions: widget.numOfQuestions,
        numOfCorrectAnswers: widget.numOfCorrectAnswers,
        streakBefore: widget.streakBefore,
        streakAfter: widget.streakAfter,
        isFirstCompletion: widget.isFirstCompletion,
      ),
      desktop: CompletionPageDesktop(
        numOfQuestions: widget.numOfQuestions,
        numOfCorrectAnswers: widget.numOfCorrectAnswers,
        streakBefore: widget.streakBefore,
        streakAfter: widget.streakAfter,
        isFirstCompletion: widget.isFirstCompletion,
      ),
    );
  }
}

//Do the lib/presentation/screens/quiz/CompletionScreen/completionScreen.mobile.dart lib/presentation/screens/quiz/CompletionScreen/completionScreen.desktop.dart
