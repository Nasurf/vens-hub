import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Unified math rendering handled via FormattedMathText
import 'package:vens_hub/data/models/question_model.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_bloc.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_event.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_state.dart';
import 'package:vens_hub/presentation/screens/quiz/CompletionScreen/completion_screen.dart';
import 'package:vens_hub/presentation/widgets/common/ai_assistant_modal.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:vens_hub/presentation/widgets/quiz/answer_feedback_widget.dart';
import 'package:vens_hub/presentation/widgets/quiz/mcq_shared_widgets.dart';
import 'package:get/get.dart';

import 'package:vens_hub/presentation/blocs/home/home_controller.dart';

// Note: replaced ad-hoc LaTeX parsing with FormattedMathText for consistency

class MultipleChoiceQuizScreenDesktop extends StatefulWidget {
  const MultipleChoiceQuizScreenDesktop({super.key});

  @override
  State<MultipleChoiceQuizScreenDesktop> createState() =>
      _MultipleChoiceQuizScreenDesktopState();
}

class _MultipleChoiceQuizScreenDesktopState
    extends State<MultipleChoiceQuizScreenDesktop> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  void _showAnswerFeedback(BuildContext builderContext) {
    final quizState = builderContext.read<QuizBloc>().state;
    if (quizState.currentQuestion is! Question) {
      return;
    }
    final currentQuestion = quizState.currentQuestion as Question;

    if (quizState.selectedAnswer == null) {
      return;
    }

    final isCorrect = _isAnswerCorrect(
      quizState.selectedAnswer!,
      currentQuestion.correctAnswer,
    );

    AnswerFeedbackWidget.show(
      builderContext,
      isCorrect: isCorrect,
      questionText: currentQuestion.text,
      explanation: currentQuestion.explanation ?? 'No explanation available.',
      isLastQuestion: quizState.isLastQuestion,
      onNext: _handleAnswerProgression,
    );
  }

  Future<void> _handleAnswerProgression() async {
    if (!mounted) return;
    final quizBloc = context.read<QuizBloc>();

    if (quizBloc.state.isLastQuestion) {
      await _finishQuiz(quizBloc);
    } else {
      quizBloc.add(const NextQuestion());
    }
  }

  Future<void> _finishQuiz(QuizBloc quizBloc) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    int? streakBefore;
    int? streakAfter;
    bool isFirstCompletion = false;

    try {
      if (Get.isRegistered<HomeController>()) {
        final HomeController home = Get.find<HomeController>();
        streakBefore = home.streakCount.value;
        isFirstCompletion = await home.markQuizCompletedToday();
        streakAfter = home.streakCount.value;
      }
    } catch (e) {
      debugPrint('Error updating streak: $e');
    }

    if (!mounted) return;
    // Pop loading dialog
    Navigator.of(context).pop();

    // If streak was updated, show StreaksPage first
    // if (isFirstCompletion) {
    //   await Get.toNamed(AppRoutes.streaks);
    // }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (ctx) => CompletionPage(
              numOfQuestions: quizBloc.state.allQuestions.length,
              numOfCorrectAnswers: quizBloc.state.numOfCorrectAnswers,
              streakBefore: streakBefore,
              streakAfter: streakAfter,
              isFirstCompletion: isFirstCompletion,
            ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  'Exit Quiz?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                content: Text(
                  'Are you sure you want to exit? Your progress will be lost.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancel',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      context.read<QuizBloc>().add(const ResetQuiz());
                      Navigator.of(context).pop(true);
                    },
                    child: Text(
                      'Exit',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  void _showAiAssistant() {
    final quizState = context.read<QuizBloc>().state;
    if (quizState.currentQuestion is! Question) return;
    final currentQuestion = quizState.currentQuestion as Question;

    showDialog(
      context: context,
      builder: (BuildContext modalContext) {
        return AIAssistantModal(
          context: "Quiz Question: ${currentQuestion.text}",
          initialQuestion: "Can you help me understand this question?",
        );
      },
    );
  }

  void _handleBackNavigation(BuildContext navigationContext) async {
    final shouldPop = await _onWillPop();
    if (shouldPop && navigationContext.mounted) {
      Navigator.pop(navigationContext);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<QuizBloc, QuizState>(
      listener: (context, state) {
        if (state.isAnswerChoosen && state.selectedAnswer != null) {
          _showAnswerFeedback(context);
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            margin: EdgeInsets.all(20),
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                SpinKitPulse(
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 60,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Preparing Your Quiz',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Generating unique questions...',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state.allQuestions.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text('Quiz')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 50),
                    const SizedBox(height: 20),
                    Text(
                      'No questions available for this quiz.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        context.read<QuizBloc>().add(const ResetQuiz());
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        textStyle: Theme.of(context).textTheme.labelLarge,
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldPop = await _onWillPop();
            if (shouldPop) {
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontalPadding =
                        constraints.maxWidth > 1200
                            ? 72.0
                            : constraints.maxWidth > 900
                            ? 48.0
                            : 24.0;
                    final verticalPadding =
                        constraints.maxHeight > 900 ? 32.0 : 24.0;
                    final availableWidth =
                        constraints.maxWidth - (horizontalPadding * 2);
                    final maxContentWidth =
                        availableWidth > 0
                            ? (availableWidth > 1040.0
                                ? 1040.0
                                : availableWidth)
                            : constraints.maxWidth;
                    final hasQuestion = state.currentQuestion is Question;

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: Column(
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: maxContentWidth,
                              ),
                              child: McqHeaderCard(
                                courseName:
                                    state.course.isNotEmpty
                                        ? state.course
                                        : 'Course',
                                currentIndex: state.currentQuestionIndex,
                                total: state.allQuestions.length,
                                onBack: () => _handleBackNavigation(context),
                                trailing: Tooltip(
                                  message: 'Ask the AI assistant for a hint',
                                  child: FilledButton.tonalIcon(
                                    onPressed:
                                        hasQuestion ? _showAiAssistant : null,
                                    icon: const Icon(
                                      Icons.bolt_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('AI Assistant'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                margin: EdgeInsets.zero,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 24,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: maxContentWidth,
                                ),
                                child:
                                    hasQuestion
                                        ? MultipleChoiceBody(state: state)
                                        : Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20.0),
                                            child: Text(
                                              'This question type is not supported in this screen.',
                                              style:
                                                  Theme.of(
                                                    context,
                                                  ).textTheme.titleMedium,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            bottomNavigationBar: const _BottomBar(),
          ),
        );
      },
    );
  }

  bool _isAnswerCorrect(int answerIndex, String? correctAnswer) {
    if (correctAnswer == null) return false;
    final idx = int.tryParse(correctAnswer);
    if (idx != null) return answerIndex == idx;
    return correctAnswer == answerIndex.toString();
  }
}

class MultipleChoiceBody extends StatelessWidget {
  final QuizState state;

  const MultipleChoiceBody({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    final question = state.currentQuestion! as Question;
    final correctIndex = _resolveCorrectAnswerIndex(question);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: McqQuestionCard(
        questionText: question.text,
        options: question.options ?? const [],
        index: state.currentQuestionIndex,
        total: state.allQuestions.length,
        selectedIndex: state.selectedAnswer,
        isAnswered: state.isAnswerChoosen,
        correctIndex: correctIndex,
        onSelect: (optionIndex) {
          if (!state.isAnswerChoosen) {
            context.read<QuizBloc>().add(ChoseAnswer(answerIndex: optionIndex));
          }
        },
        scoreChip: _ScoreChip(score: state.numOfCorrectAnswers),
        helperText: 'Select the best answer to continue',
        maxWidth: 960,
        contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      ),
    );
  }
}

int? _resolveCorrectAnswerIndex(Question question) {
  final raw = question.correctAnswer?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }

  final numeric = int.tryParse(raw);
  if (numeric != null) {
    return numeric;
  }

  if (raw.length == 1) {
    final code = raw.toUpperCase().codeUnitAt(0);
    if (code >= 65 && code <= 90) {
      return code - 65;
    }
  }

  return null;
}

class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<QuizBloc>().state;
    final isAnswered = state.isAnswerChoosen;
    final hasSelection = state.selectedAnswer != null;
    final canSubmit = hasSelection && !isAnswered;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed:
                            isAnswered
                                ? () {
                                  final quizBloc = context.read<QuizBloc>();
                                  if (quizBloc.state.isLastQuestion) {
                                    // Use the same finish logic
                                    final state =
                                        context
                                            .findAncestorStateOfType<
                                              _MultipleChoiceQuizScreenDesktopState
                                            >();
                                    state?._finishQuiz(quizBloc);
                                  } else {
                                    quizBloc.add(const NextQuestion());
                                  }
                                }
                                : (canSubmit
                                    ? () {
                                      final selected = state.selectedAnswer;
                                      if (selected != null) {
                                        context.read<QuizBloc>().add(
                                          SubmitAnswer(answerIndex: selected),
                                        );
                                      }
                                    }
                                    : null),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        child: Text(
                          isAnswered
                              ? (state.isLastQuestion
                                  ? 'See Results'
                                  : 'Next Question')
                              : (hasSelection
                                  ? 'Submit Answer'
                                  : 'Choose an Answer'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final int score;
  const _ScoreChip({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.stars_rounded,
            size: 16,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 6),
          Text(
            '$score',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
