// Quiz customization: select topic, difficulty, question count
// import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vens_hub/core/router/app_router.dart';
import 'package:vens_hub/core/router/routes.dart';
// import 'package:vens_hub/presentation/screens/quiz/quiz_page.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_bloc.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_event.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_state.dart';
import 'package:vens_hub/core/constants/constants.dart';
// import 'package:vens_hub/core/di/injection_container.dart' as di;

// import '../../../core/services/analytics/analytics_service.dart'; // Correct: Ensure di is imported

class CustomizeQuizPage extends StatefulWidget {
  const CustomizeQuizPage({super.key});

  @override
  State<CustomizeQuizPage> createState() => _CustomizeQuizPageState();
}

class _CustomizeQuizPageState extends State<CustomizeQuizPage> {
  Difficulty _difficulty = Difficulty.easy;
  QuestionType _questionType = QuestionType.multipleChoice;
  int numberOfQuestions = 1;
  String _questionCategory = 'Theory'; // 'Theory' or 'Calculation'
  final ScrollController _scrollController = ScrollController();
  bool _showFloatingButton = false;
  final options = ['3', '5', '10'];

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final bool shouldShow = _scrollController.offset > 100;
    if (shouldShow != _showFloatingButton) {
      setState(() => _showFloatingButton = shouldShow);
    }
  }

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Dispatch ResetQuiz to ensure a clean state when the page is first loaded.
    // This is important if the user navigates back to this page after a quiz.
    // context.read<QuizBloc>().add(const ResetQuiz());

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _startQuiz() {
    final quizBloc = context.read<QuizBloc>();
    quizBloc.add(
      UpdateQuizPreferences(
        difficulty: _difficulty,
        questionType: _questionType,
        numberOfQuestions: numberOfQuestions,
      ),
    );

    // Navigate immediately based on user's chosen type to show the proper screen/spinner
    _navigated = true;
    switch (_questionType) {
      case QuestionType.theory:
        AppRouter.navigateTo(AppRoutes.theoryTimerSetup);
        break;
      case QuestionType.gapFill:
        AppRouter.navigateTo(AppRoutes.gapFillQuiz);
        break;
      default:
        AppRouter.navigateTo(AppRoutes.quiz);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<QuizBloc, QuizState>(
      listener: (context, state) {
        debugPrint(
          "QuizState changed: isLoading=${state.isLoading}, questionsCount=${state.allQuestions.length}, questionType=${state.questionType}",
        );

        // Guard: Do not navigate if no question type is selected (e.g., after Reset or initial load)
        if (state.questionType == null) return;

        // Navigate based on selected type. For types that pre-generate questions, wait until loaded.
        Future.microtask(() {
          if (state.questionType == QuestionType.theory) {
            // For theory, send user to the timer setup first
            if (!_navigated) {
              _navigated = true;
              AppRouter.navigateTo(AppRoutes.theoryTimerSetup);
            }
            return;
          }

          if (state.questionType == QuestionType.gapFill) {
            if (!state.isLoading && state.allQuestions.isNotEmpty) {
              AppRouter.navigateTo(AppRoutes.gapFillQuiz);
            }
            return;
          }

          // Default (e.g., multiple choice): wait until questions are available
          if (!state.isLoading && state.allQuestions.isNotEmpty) {
            AppRouter.navigateTo(AppRoutes.quiz);
          }
        });
      },
      child: BlocBuilder<QuizBloc, QuizState>(
        builder: (context, state) {
          if (state.isLoading) {
            return Center(
              child: SpinKitPulsingGrid(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          } else {
            return _buildQuizCustomizationBody(context);
          }
        },
      ),
    );
  }

  Widget _buildQuizCustomizationBody(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        floatingActionButton:
            _showFloatingButton
                ? FloatingActionButton(
                  onPressed: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.arrow_upward, color: Colors.black),
                )
                : null,
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            BlocBuilder<QuizBloc, QuizState>(
              builder: (context, state) {
                final topInset = MediaQuery.of(context).padding.top;
                return SliverAppBar(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  expandedHeight: 260.0 + topInset,
                  floating: false,
                  // Let the bar scroll away instead of persisting
                  pinned: false,
                  stretch: true,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
                    // We'll render the topic title manually inside the background stack
                    background: Builder(
                      builder: (context) {
                        final theme = Theme.of(context);
                        final isLight = theme.brightness == Brightness.light;
                        final primary = theme.colorScheme.primary;
                        final surface = theme.colorScheme.surface;
                        final borderColor = theme.colorScheme.onSurface
                            .withValues(alpha: isLight ? 0.06 : 0.12);
                        final logoColor =
                            isLight
                                ? primary.withValues(alpha: 0.22)
                                : primary.withValues(alpha: 0.35);
                        const double maxContentWidth = 1000;
                        final safeTop = MediaQuery.of(context).padding.top;

                        // Compute the visible middle color of the original gradient (premultiplied midpoint
                        // composited over the same surface background), then use it as a solid fill.
                        final double a0 = isLight ? 0.18 : 0.12; // start alpha
                        final double r0 = primary.r,
                            g0 = primary.g,
                            b0 = primary.b; // normalized 0..1
                        final double r1 = surface.r,
                            g1 = surface.g,
                            b1 = surface.b; // normalized 0..1
                        const double a1 = 1.0; // end alpha (surface is opaque)
                        final double aMid = (a0 + a1) / 2.0;
                        final double rPre = (a0 * r0 + a1 * r1) / 2.0;
                        final double gPre = (a0 * g0 + a1 * g1) / 2.0;
                        final double bPre = (a0 * b0 + a1 * b1) / 2.0;
                        final double rComp = rPre + (1.0 - aMid) * r1;
                        final double gComp = gPre + (1.0 - aMid) * g1;
                        final double bComp = bPre + (1.0 - aMid) * b1;
                        final Color headerMidColor = Color.fromARGB(
                          255,
                          (rComp * 255.0).round(),
                          (gComp * 255.0).round(),
                          (bComp * 255.0).round(),
                        );

                        return Container(
                          color: surface,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Centered gradient panel aligned with page padding
                              Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: maxContentWidth,
                                      ),
                                      child: Hero(
                                        tag:
                                            'topic-${state.course}-${state.choosenTopic}',
                                        child: Container(
                                          height: 220 + safeTop,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            color: headerMidColor,
                                            border: Border.all(
                                              color: borderColor,
                                              width: 1.2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: theme.colorScheme.shadow
                                                    .withValues(alpha: 0.20),
                                                blurRadius: 20,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            children: [
                                              // Back button inside the container (top-left)
                                              Positioned(
                                                left: 12,
                                                top: 12 + safeTop,
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: IconButton(
                                                    icon: Icon(
                                                      CupertinoIcons.back,
                                                      color:
                                                          theme
                                                              .colorScheme
                                                              .onSurface,
                                                    ),
                                                    onPressed: () {
                                                      HapticFeedback.lightImpact();
                                                      AppRouter.pop();
                                                    },
                                                  ),
                                                ),
                                              ),
                                              // Title bottom-left, always within the panel
                                              Positioned(
                                                left: 20,
                                                right: 20,
                                                bottom: 18,
                                                child: Text(
                                                  state.choosenTopic ??
                                                      "No Topic",
                                                  style: theme
                                                      .textTheme
                                                      .headlineLarge
                                                      ?.copyWith(
                                                        color:
                                                            theme
                                                                .colorScheme
                                                                .onSurface,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              // Watermark logo kept inside the container (top-right)
                                              Positioned(
                                                right: 20,
                                                top: 16 + safeTop * 0.6,
                                                child: IgnorePointer(
                                                  ignoring: true,
                                                  child: SvgPicture.asset(
                                                    'assets/svg/transp_11_inlined.svg',
                                                    height: 96,
                                                    colorFilter:
                                                        ColorFilter.mode(
                                                          logoColor,
                                                          BlendMode.srcIn,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Note: all interactive/header elements are now inside the panel above
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 32),
                        _buildDifficultySection(context),
                        const SizedBox(height: 24),
                        _buildQuestionCategorySection(context),
                        const SizedBox(height: 30),
                        _buildNumberSection(context),
                        const SizedBox(height: 40),
                        _buildStartButton(context),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 5),
          Text(
            'Customize Your Quiz',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Personalize your learning experience by selecting your preferences below',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultySection(BuildContext context) {
    return _AnimatedSettingsCard(
      title: 'Difficulty Level',
      subtitle: 'Choose how challenging you want your quiz to be',
      icon: Icons.trending_up,
      child: Column(
        children: [
          _AnimatedDifficultyOption(
            title: 'Easy',
            description: 'Perfect for beginners and concept learning',
            icon: Icons.sentiment_satisfied,
            iconColor: Colors.green,
            value: Difficulty.easy,
            groupValue: _difficulty,
            onChanged: (val) => setState(() => _difficulty = val!),
          ),
          _AnimatedDifficultyOption(
            title: 'Medium',
            description: 'For intermediate learners ready for a challenge',
            icon: Icons.sentiment_neutral,
            iconColor: Colors.orange,
            value: Difficulty.medium,
            groupValue: _difficulty,
            onChanged: (val) => setState(() => _difficulty = val!),
          ),
          _AnimatedDifficultyOption(
            title: "Hard",
            description: 'Advanced questions to test your expertise',
            icon: Icons.sentiment_very_dissatisfied,
            iconColor: Colors.red,
            value: Difficulty.hard,
            groupValue: _difficulty,
            onChanged: (val) => setState(() => _difficulty = val!),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCategorySection(BuildContext context) {
    return _AnimatedSettingsCard(
      title: 'Question Type',
      subtitle: 'Choose the type of questions you want',
      icon: Icons.category,
      child: Column(
        children: [
          _AnimatedDifficultyOption(
            title: 'Theory',
            description: 'Conceptual questions without calculations',
            icon: Icons.menu_book,
            iconColor: Colors.blue,
            value: 'Theory',
            groupValue: _questionCategory,
            onChanged: (val) => setState(() => _questionCategory = val!),
          ),
          _AnimatedDifficultyOption(
            title: 'Calculation',
            description: 'Mathematical and computational problems',
            icon: Icons.calculate,
            iconColor: Colors.green,
            value: 'Calculation',
            groupValue: _questionCategory,
            onChanged: (val) => setState(() => _questionCategory = val!),
          ),
        ],
      ),
    );
  }

  // Hidden Question Format section - keeping code but not displaying
  Widget _buildQuestionTypeSection(BuildContext context) {
    return _AnimatedSettingsCard(
      title: 'Question Format',
      subtitle: 'Select your preferred way of answering',
      icon: Icons.question_answer,
      child: Column(
        children: [
          KAnimatedRadioButton(
            title: 'Multiple Choice',
            description: 'Classic quiz format with carefully selected options',
            icon: Icons.check_circle_outline,
            iconColor: Colors.blue,
            value: QuestionType.multipleChoice,
            groupValue: _questionType,
            onChanged: (val) => setState(() => _questionType = val!),
          ),
          KAnimatedRadioButton(
            title: 'Practical',
            description: 'Real-world problem solving and application',
            icon: Icons.code,
            iconColor: Colors.purple,
            value: QuestionType.practical,
            groupValue: _questionType,
            onChanged: (val) => setState(() => _questionType = val!),
          ),
          KAnimatedRadioButton(
            title: 'Theory',
            description:
                'Conceptual explanations and theoretical understanding',
            icon: Icons.menu_book,
            iconColor: Colors.brown,
            value: QuestionType.theory,
            groupValue: _questionType,
            onChanged: (val) => setState(() => _questionType = val!),
          ),
          KAnimatedRadioButton(
            title: 'Fill in the Gaps',
            description: 'Complete sentences with missing words or values',
            icon: Icons.edit,
            iconColor: Colors.orange,
            value: QuestionType.gapFill,
            groupValue: _questionType,
            onChanged: (val) => setState(() => _questionType = val!),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberSection(BuildContext context) {
    final theme = Theme.of(context);
    return _AnimatedSettingsCard(
      title: 'Number of Questions',
      subtitle: 'Choose how many questions you want to answer',
      icon: Icons.format_list_numbered,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            transform: Matrix4.diagonal3Values(
              numberOfQuestions > 5 ? 1.1 : 1.0,
              numberOfQuestions > 5 ? 1.1 : 1.0,
              1.0,
            ),
            child: Text(
              '$numberOfQuestions',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.outline.withValues(
                alpha: 0.2,
              ),
              thumbColor: theme.colorScheme.primary,
              overlayColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              valueIndicatorColor: theme.colorScheme.primary,
              valueIndicatorTextStyle: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
              trackHeight: 12,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 28),
            ),
            child: Slider(
              value: numberOfQuestions.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$numberOfQuestions',
              onChanged:
                  (value) => setState(() => numberOfQuestions = value.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return BlocBuilder<QuizBloc, QuizState>(
      builder: (context, state) {
        return Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).colorScheme.primary,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.lightImpact();

                _startQuiz();
              },
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Start Quiz',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedSettingsCard extends StatelessWidget {
  const _AnimatedSettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            // Punchier gradient: stronger primary tint and a darker complementary tint
            primary.withValues(
              alpha: theme.brightness == Brightness.light ? 0.18 : 0.14,
            ),
            theme.colorScheme.primaryContainer.withValues(
              alpha: theme.brightness == Brightness.light ? 0.12 : 0.10,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Card(
        color: surface,
        elevation: 8,
        shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedDifficultyOption<T> extends StatelessWidget {
  const _AnimatedDifficultyOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final T value;
  final T groupValue;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:
            isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(value);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class KAnimatedRadioButton<T> extends StatelessWidget {
  const KAnimatedRadioButton({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final T value;
  final T groupValue;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:
            isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(value);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class KAnimatedRadioButtonNumber<T> extends StatelessWidget {
  const KAnimatedRadioButtonNumber({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final T value;
  final T groupValue;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:
            isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(value);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
