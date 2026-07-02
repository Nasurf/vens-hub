import 'package:equatable/equatable.dart';
import 'package:vens_hub/core/constants/constants.dart';

class QuizState extends Equatable {
  final String course;
  final List<dynamic>? topics;
  final String? choosenTopic;
  final bool isLoading;
  final Difficulty? difficulty;
  final QuestionType? questionType;
  final int? numberOfQuestions;
  final List<Object> allQuestions;
  final int currentQuestionIndex;
  final int? selectedAnswer;
  final bool isAnswerChoosen;
  final int numOfCorrectAnswers;
  final Map<int, List<String>> gapFillUserAnswers;
  final Map<int, bool> gapFillIsCorrect;
  final Map<int, int>
  gapFillCorrectCountByQuestion;
  final Map<int, int> gapFillTotalGapsByQuestion;
  final Map<int, int> mcqSelectedAnswers;
  final Map<int, bool> mcqIsCorrect;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final bool? isTheoryTimed;
  final int? theoryTimeMinutes;

  // Adaptive learning: per-course mastery after quiz submission
  final Map<String, Map<String, dynamic>>? adaptiveProgress;

  bool get isLastQuestion => currentQuestionIndex >= allQuestions.length - 1;
  Object? get currentQuestion =>
      allQuestions.isNotEmpty ? allQuestions[currentQuestionIndex] : null;

  const QuizState({
    this.course = "",
    this.topics,
    this.choosenTopic,
    this.isLoading = false,
    this.difficulty,
    this.questionType,
    this.numberOfQuestions,
    this.allQuestions = const [],
    this.currentQuestionIndex = 0,
    this.selectedAnswer,
    this.isAnswerChoosen = false,
    this.numOfCorrectAnswers = 0,
    this.gapFillUserAnswers = const {},
    this.gapFillIsCorrect = const {},
    this.gapFillCorrectCountByQuestion = const {},
    this.gapFillTotalGapsByQuestion = const {},
    this.mcqSelectedAnswers = const {},
    this.mcqIsCorrect = const {},
    this.startedAt,
    this.endedAt,
    this.isTheoryTimed,
    this.theoryTimeMinutes,
    this.adaptiveProgress,
  });

  QuizState copyWith({
    String? course,
    List<dynamic>? topics,
    String? choosenTopic,
    bool? isLoading,
    Difficulty? difficulty,
    QuestionType? questionType,
    int? numberOfQuestions,
    List<Object>? allQuestions,
    int? currentQuestionIndex,
    Object? selectedAnswer = _sentinel,
    bool? isAnswerChoosen,
    int? numOfCorrectAnswers,
    Map<int, List<String>>? gapFillUserAnswers,
    Map<int, bool>? gapFillIsCorrect,
    Map<int, int>? gapFillCorrectCountByQuestion,
    Map<int, int>? gapFillTotalGapsByQuestion,
    Map<int, int>? mcqSelectedAnswers,
    Map<int, bool>? mcqIsCorrect,
    DateTime? startedAt,
    Object? endedAt = _sentinel,
    bool? isTheoryTimed,
    Object? theoryTimeMinutes = _sentinel,
    Object? adaptiveProgress = _sentinel,
  }) {
    return QuizState(
      course: course ?? this.course,
      topics: topics ?? this.topics,
      choosenTopic: choosenTopic ?? this.choosenTopic,
      isLoading: isLoading ?? this.isLoading,
      difficulty: difficulty ?? this.difficulty,
      questionType: questionType ?? this.questionType,
      numberOfQuestions: numberOfQuestions ?? this.numberOfQuestions,
      allQuestions: allQuestions ?? this.allQuestions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      selectedAnswer:
          selectedAnswer != _sentinel ? selectedAnswer as int? : this.selectedAnswer,
      isAnswerChoosen: isAnswerChoosen ?? this.isAnswerChoosen,
      numOfCorrectAnswers: numOfCorrectAnswers ?? this.numOfCorrectAnswers,
      gapFillUserAnswers: gapFillUserAnswers ?? this.gapFillUserAnswers,
      gapFillIsCorrect: gapFillIsCorrect ?? this.gapFillIsCorrect,
      gapFillCorrectCountByQuestion: gapFillCorrectCountByQuestion ?? this.gapFillCorrectCountByQuestion,
      gapFillTotalGapsByQuestion: gapFillTotalGapsByQuestion ?? this.gapFillTotalGapsByQuestion,
      mcqSelectedAnswers: mcqSelectedAnswers ?? this.mcqSelectedAnswers,
      mcqIsCorrect: mcqIsCorrect ?? this.mcqIsCorrect,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt != _sentinel ? endedAt as DateTime? : this.endedAt,
      isTheoryTimed: isTheoryTimed ?? this.isTheoryTimed,
      theoryTimeMinutes: theoryTimeMinutes != _sentinel ? theoryTimeMinutes as int? : this.theoryTimeMinutes,
      adaptiveProgress: adaptiveProgress != _sentinel ? adaptiveProgress as Map<String, Map<String, dynamic>>? : this.adaptiveProgress,
    );
  }

  static const Object _sentinel = Object();

  @override
  List<Object?> get props => [
    course,
    topics,
    choosenTopic,
    isLoading,
    difficulty,
    questionType,
    numberOfQuestions,
    allQuestions,
    currentQuestionIndex,
    selectedAnswer,
    isAnswerChoosen,
    numOfCorrectAnswers,
    gapFillUserAnswers,
    gapFillIsCorrect,
    gapFillCorrectCountByQuestion,
    gapFillTotalGapsByQuestion,
    mcqSelectedAnswers,
    mcqIsCorrect,
    startedAt,
    endedAt,
    isTheoryTimed,
    theoryTimeMinutes,
    adaptiveProgress,
  ];
}
