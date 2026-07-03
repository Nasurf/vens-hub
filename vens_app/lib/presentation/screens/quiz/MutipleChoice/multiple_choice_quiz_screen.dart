// Multiple choice quiz with adaptive feedback
import 'package:vens_hub/presentation/screens/quiz/MutipleChoice/multiple_choice_quiz_page.desktop.dart';
import 'package:vens_hub/presentation/screens/quiz/MutipleChoice/multiple_choice_quiz_page.mobile.dart';
import 'package:vens_hub/presentation/widgets/common/app_layout.dart';
import 'package:flutter/material.dart';

class MultipleChoiceQuizScreen extends StatefulWidget {
  const MultipleChoiceQuizScreen({super.key});

  @override
  State<MultipleChoiceQuizScreen> createState() =>
      _MultipleChoiceQuizScreenState();
}

class _MultipleChoiceQuizScreenState extends State<MultipleChoiceQuizScreen> {
  @override
  Widget build(BuildContext context) {
    return AppLayoutBuilder(
      mobile: MultipleChoiceQuizScreenMobile(),
      desktop: MultipleChoiceQuizScreenDesktop(),
    );
  }
}
