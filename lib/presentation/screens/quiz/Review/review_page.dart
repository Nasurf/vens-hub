// Quiz review with detailed answer explanations
import 'package:vens_hub/presentation/screens/quiz/Review/review_page.desktop.dart';
import 'package:vens_hub/presentation/screens/quiz/Review/review_page.mobile.dart';
import 'package:vens_hub/presentation/widgets/common/app_layout.dart';
import 'package:flutter/material.dart';

class ReviewData {
  final List<dynamic> questions;
  final Map<int, int> mcqSelectedAnswers;
  final Map<int, bool> mcqIsCorrect;
  final Map<int, List<String>> gapFillUserAnswers;
  final Map<int, List<bool>> gapFillIsCorrect;

  const ReviewData({
    required this.questions,
    required this.mcqSelectedAnswers,
    required this.mcqIsCorrect,
    required this.gapFillUserAnswers,
    required this.gapFillIsCorrect,
  });
}

class ReviewPage extends StatefulWidget {
  final ReviewData data;

  const ReviewPage({super.key, required this.data});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  @override
  Widget build(BuildContext context) {
    return AppLayoutBuilder(
      mobile: ReviewPageMobile(
        questions: widget.data.questions,
        mcqSelectedAnswers: widget.data.mcqSelectedAnswers,
        mcqIsCorrect: widget.data.mcqIsCorrect,
        gapFillUserAnswers: widget.data.gapFillUserAnswers,
        gapFillIsCorrect: widget.data.gapFillIsCorrect,
      ),
      desktop: ReviewPageDesktop(
        questions: widget.data.questions,
        mcqSelectedAnswers: widget.data.mcqSelectedAnswers,
        mcqIsCorrect: widget.data.mcqIsCorrect,
        gapFillUserAnswers: widget.data.gapFillUserAnswers,
        gapFillIsCorrect: widget.data.gapFillIsCorrect,
      ),
    );
  }
}
