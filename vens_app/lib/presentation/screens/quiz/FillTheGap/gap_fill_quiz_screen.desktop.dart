import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:vens_hub/core/Brain/data_formatting.dart' as df;
import 'package:vens_hub/core/Brain/latex_support.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_bloc.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_event.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_state.dart';
import 'package:vens_hub/core/constants/constants.dart';
import 'package:vens_hub/presentation/screens/quiz/CompletionScreen/completion_screen.dart';
import 'package:vens_hub/presentation/screens/quiz/FillTheGap/drag_drop_gap_fill_widget.dart';
import 'package:vens_hub/presentation/widgets/common/report_issue_dialog.dart';
import 'package:flutter/cupertino.dart';

class GapFillQuizScreenDesktop extends StatefulWidget {
  const GapFillQuizScreenDesktop({super.key});

  @override
  State<GapFillQuizScreenDesktop> createState() =>
      _GapFillQuizScreenDesktopState();
}

class _GapFillQuizScreenDesktopState extends State<GapFillQuizScreenDesktop>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressAnimationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _animateToPage(int page) {
    _fadeController.reset();
    _pageController
        .animateToPage(
          page,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        )
        .then((_) {
          _fadeController.forward();
        });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<QuizBloc, QuizState>(
      listener: (context, state) {
        if (!state.isLoading &&
            state.allQuestions.isEmpty &&
            state.questionType == QuestionType.gapFill) {
          log("Bloc listener: No gap fill questions loaded.");
        }
        // Animate progress when answers change
        final questionsAnswered = state.gapFillIsCorrect.length;
        if (questionsAnswered > 0) {
          _progressAnimationController.animateTo(
            questionsAnswered / state.allQuestions.length,
          );
        }
      },
      builder: (context, state) {
        final List<df.GapFillQuestion> gapFillQuestions =
            state.allQuestions.whereType<df.GapFillQuestion>().toList();

        // Enhanced loading state
        if (state.isLoading && gapFillQuestions.isEmpty) {
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
              child: SafeArea(
                child: Column(
                  children: [
                    // Modern app bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.back),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Fill in the Gaps',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Enhanced loading content
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
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 60,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Preparing Your Quiz',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
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
            ),
          );
        }

        // Enhanced error state
        if (!state.isLoading && gapFillQuestions.isEmpty) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.errorContainer,
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Modern app bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.back),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Fill in the Gaps',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buildErrorScreen(
                        'Failed to generate questions. Please go back and try again.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final totalPages = gapFillQuestions.length;
        final questionsAnswered = state.gapFillIsCorrect.length;
        final allQuestionsAnswered =
            questionsAnswered >= gapFillQuestions.length;

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  Theme.of(context).colorScheme.surface,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Modern app bar with enhanced styling
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(CupertinoIcons.back),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.choosenTopic?.isNotEmpty == true
                                    ? state.choosenTopic!
                                    : (state.course.isNotEmpty
                                        ? state.course
                                        : 'Fill in the Gaps'),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Interactive Quiz',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Enhanced progress section
                  _buildEnhancedProgressBar(
                    context,
                    state,
                    gapFillQuestions.length,
                    totalPages,
                  ),

                  // Main content
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: totalPages,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPageIndex = index;
                          });
                          _fadeController.reset();
                          _fadeController.forward();
                        },
                        itemBuilder: (context, pageIndex) {
                          return _buildPage(
                            context,
                            state,
                            gapFillQuestions,
                            pageIndex,
                          );
                        },
                      ),
                    ),
                  ),

                  // Enhanced bottom navigation
                  _buildEnhancedBottomNavigation(
                    context,
                    state,
                    gapFillQuestions,
                    totalPages,
                    allQuestionsAnswered,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedProgressBar(
    BuildContext context,
    QuizState state,
    int totalQuestions,
    int totalPages,
  ) {
    final questionsAnswered = state.gapFillIsCorrect.length;
    final progress =
        totalQuestions > 0 ? questionsAnswered / totalQuestions : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Question ${_currentPageIndex + 1}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'of $totalPages',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      questionsAnswered == totalQuestions
                          ? Theme.of(
                            context,
                          ).colorScheme.tertiary.withValues(alpha: 0.2)
                          : Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      questionsAnswered == totalQuestions
                          ? Icons.check_circle
                          : Icons.pending,
                      size: 16,
                      color:
                          questionsAnswered == totalQuestions
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$questionsAnswered/$totalQuestions',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progressAnimation.value * progress,
                  minHeight: 8,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    QuizState state,
    List<df.GapFillQuestion> questions,
    int pageIndex,
  ) {
    final questionIndex = pageIndex;
    final question = questions[questionIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GapFillQuestionCard(
        question: question,
        questionIndex: questionIndex,
        state: state,
        onAnswerSubmitted: (answers) {
          context.read<QuizBloc>().add(
            SubmitGapFillAnswer(
              questionGlobalIndex: questionIndex,
              userResponses: answers,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedBottomNavigation(
    BuildContext context,
    QuizState state,
    List<df.GapFillQuestion> questions,
    int totalPages,
    bool allQuestionsAnswered,
  ) {
    bool currentPageAnswered = state.gapFillIsCorrect.containsKey(
      _currentPageIndex,
    );

    final isLastPage = _currentPageIndex == totalPages - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Previous button
            if (_currentPageIndex > 0)
              Expanded(
                child: Container(
                  height: 50,
                  margin: const EdgeInsets.only(right: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => _animateToPage(_currentPageIndex - 1),
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              )
            else
              const Expanded(child: SizedBox()),

            // Next/Results button
            Expanded(
              flex: 2,
              child: Container(
                height: 50,
                margin: EdgeInsets.only(left: _currentPageIndex > 0 ? 8 : 0),
                child: ElevatedButton.icon(
                  onPressed:
                      currentPageAnswered
                          ? () {
                            if (isLastPage && allQuestionsAnswered) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => CompletionPage(
                                        numOfQuestions: questions.length,
                                        numOfCorrectAnswers:
                                            state.numOfCorrectAnswers,
                                      ),
                                ),
                              );
                            } else if (!isLastPage) {
                              _animateToPage(_currentPageIndex + 1);
                            }
                          }
                          : null,
                  icon: Icon(
                    isLastPage && allQuestionsAnswered
                        ? Icons.flag
                        : Icons.chevron_right,
                  ),
                  label: Text(
                    isLastPage && allQuestionsAnswered
                        ? 'See Results'
                        : 'Next Question',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        currentPageAnswered
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                    foregroundColor:
                        currentPageAnswered
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: currentPageAnswered ? 2 : 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Oops!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text(
                    'Go Back',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GapFillQuestionCard extends StatefulWidget {
  final df.GapFillQuestion question;
  final int questionIndex;
  final QuizState state;
  final Function(List<String>) onAnswerSubmitted;

  const GapFillQuestionCard({
    super.key,
    required this.question,
    required this.questionIndex,
    required this.state,
    required this.onAnswerSubmitted,
  });

  @override
  State<GapFillQuestionCard> createState() => _GapFillQuestionCardState();
}

class _GapFillQuestionCardState extends State<GapFillQuestionCard>
    with TickerProviderStateMixin {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  bool _isSubmitted = false;
  late AnimationController _submitAnimationController;
  late Animation<double> _submitAnimation;
  late AnimationController _resultAnimationController;
  late Animation<double> _resultAnimation;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _checkIfSubmitted();

    _submitAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _submitAnimation = CurvedAnimation(
      parent: _submitAnimationController,
      curve: Curves.easeInOut,
    );

    _resultAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _resultAnimation = CurvedAnimation(
      parent: _resultAnimationController,
      curve: Curves.elasticOut,
    );
  }

  void _initializeControllers() {
    final gapCount = '___'.allMatches(widget.question.prompt).length;
    _controllers = List.generate(gapCount, (index) => TextEditingController());
    _focusNodes = List.generate(gapCount, (index) => FocusNode());

    for (final controller in _controllers) {
      controller.addListener(_onInputChanged);
    }

    if (widget.state.gapFillUserAnswers.containsKey(widget.questionIndex)) {
      final userAnswers =
          widget.state.gapFillUserAnswers[widget.questionIndex]!;
      for (int i = 0; i < userAnswers.length && i < _controllers.length; i++) {
        _controllers[i].text = userAnswers[i];
      }
    }
  }

  void _checkIfSubmitted() {
    _isSubmitted = widget.state.gapFillIsCorrect.containsKey(
      widget.questionIndex,
    );
    if (_isSubmitted) {
      _resultAnimationController.forward();
    }
  }

  @override
  void didUpdateWidget(GapFillQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkIfSubmitted();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.removeListener(_onInputChanged);
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _submitAnimationController.dispose();
    _resultAnimationController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  void _submitAnswer() {
    _submitAnimationController.forward().then((_) {
      _submitAnimationController.reverse();
    });

    final answers = _controllers.map((controller) => controller.text).toList();
    widget.onAnswerSubmitted(answers);

    // Animate result after submission
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _resultAnimationController.forward();
      }
    });
  }

  bool get _canSubmit =>
      _controllers.any((controller) => controller.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    if (widget.question.options.isNotEmpty) {
      return DragDropGapFillWidget(
        question: widget.question,
        questionIndex: widget.questionIndex,
        userAnswers: widget.state.gapFillUserAnswers,
        isCorrect: widget.state.gapFillIsCorrect,
        onAnswerSubmitted: widget.onAnswerSubmitted,
      );
    }

    final isCorrect = widget.state.gapFillIsCorrect[widget.questionIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
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
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: PopupMenuButton<int>(
                    icon: Icon(
                      Icons.more_vert,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem<int>(
                            value: 1,
                            child: Row(
                              children: [
                                Icon(Icons.report_outlined),
                                SizedBox(width: 8),
                                Text('Report issue'),
                              ],
                            ),
                          ),
                        ],
                    onSelected: (value) async {
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
                ),
              ],
            ),
          ),

          // Question content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question prompt with enhanced styling
                _buildEnhancedPromptWithInputs(),

                const SizedBox(height: 24),

                // Submit button or result with animations
                if (!_isSubmitted)
                  Row(
                    children: [
                      const Spacer(),
                      ScaleTransition(
                        scale: Tween<double>(
                          begin: 1.0,
                          end: 0.95,
                        ).animate(_submitAnimation),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow:
                                _canSubmit
                                    ? [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _canSubmit ? _submitAnswer : null,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text(
                              'Check Answer',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _canSubmit
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                              foregroundColor:
                                  _canSubmit
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: _canSubmit ? 2 : 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(_resultAnimation),
                    child: FadeTransition(
                      opacity: _resultAnimation,
                      child: _buildEnhancedResult(isCorrect),
                    ),
                  ),

                // Enhanced explanation section
                if (_isSubmitted && isCorrect != null)
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(_resultAnimation),
                    child: FadeTransition(
                      opacity: _resultAnimation,
                      child: _buildEnhancedExplanation(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedPromptWithInputs() {
    final parts = widget.question.prompt.split('___');
    final List<Widget> children = [];
    int inputIndex = 0;

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        children.add(
          FormattedMathText(
            content: parts[i],
            textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
          ),
        );
      }

      if (i < parts.length - 1 && inputIndex < _controllers.length) {
        children.add(
          Container(
            constraints: const BoxConstraints(minWidth: 100, maxWidth: 200),
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: IntrinsicWidth(
              child: TextField(
                controller: _controllers[inputIndex],
                focusNode: _focusNodes[inputIndex],
                enabled: !_isSubmitted,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color:
                      _isSubmitted
                          ? Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7)
                          : Theme.of(context).colorScheme.primary,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  hintText: 'Answer',
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.normal,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  filled: true,
                  fillColor:
                      _isSubmitted
                          ? Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5)
                          : Theme.of(context).colorScheme.surface,
                ),
                onSubmitted: (_) {
                  if (inputIndex < _focusNodes.length - 1) {
                    _focusNodes[inputIndex + 1].requestFocus();
                  } else if (_canSubmit) {
                    _submitAnswer();
                  }
                },
              ),
            ),
          ),
        );
        inputIndex++;
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }

  Widget _buildEnhancedResult(bool? isCorrect) {
    if (isCorrect == null) return const SizedBox();

    final correct =
        widget.question.answers.map((e) => e.trim().toLowerCase()).toList();
    final user =
        (widget.state.gapFillUserAnswers[widget.questionIndex] ?? const [])
            .map((e) => e.trim().toLowerCase())
            .toList();
    final Map<String, int> remaining = {};
    for (final c in correct) {
      remaining[c] = (remaining[c] ?? 0) + 1;
    }
    int matched = 0;
    for (final u in user) {
      final left = remaining[u] ?? 0;
      if (left > 0) {
        matched++;
        remaining[u] = left - 1;
      }
    }
    final int total = correct.length;
    final bool allCorrect = matched == total && total > 0;
    final bool someCorrect = matched > 0 && matched < total;

    const Color successColor = Color(0xFF0F7B0F);
    const Color warnColor = Color(0xFFE65100);
    const Color errorColor = Color(0xFFD32F2F);

    final Color primaryColor =
        allCorrect ? successColor : (someCorrect ? warnColor : errorColor);
    final Color bgColor = primaryColor.withValues(alpha: 0.1);
    final IconData icon =
        allCorrect
            ? Icons.check_circle
            : (someCorrect ? Icons.info : Icons.cancel);
    final String label =
        allCorrect
            ? 'Perfect!'
            : (someCorrect ? 'Partially Correct' : 'Try Again');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$matched out of $total answers correct',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$matched/$total',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedExplanation() {
    const Color successColor = Color(0xFF0F7B0F);

    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          expansionTileTheme: ExpansionTileThemeData(
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          title: Text(
            'View Explanation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: FormattedMathText(
                      content: widget.question.explanation,
                      textStyle: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Correct Answers:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        widget.question.answers
                            .map(
                              (answer) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: successColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: successColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check,
                                      size: 16,
                                      color: successColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      answer,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: successColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
