import 'package:vens_hub/presentation/screens/quiz/FillTheGap/gap_fill_quiz_screen.desktop.dart';
import 'package:vens_hub/presentation/screens/quiz/FillTheGap/gap_fill_quiz_screen.mobile.dart';
import 'package:vens_hub/presentation/widgets/common/app_layout.dart';
import 'package:flutter/material.dart';

class GapFillQuizScreen extends StatefulWidget {
  const GapFillQuizScreen({super.key});

  @override
  State<GapFillQuizScreen> createState() => _GapFillQuizScreenState();
}

class _GapFillQuizScreenState extends State<GapFillQuizScreen> {
  @override
  Widget build(BuildContext context) {
    return AppLayoutBuilder(
      mobile: GapFillQuizScreenMobile(),
      desktop: GapFillQuizScreenDesktop(),
    );
  }
}
