import 'package:equatable/equatable.dart';
import 'package:vens_hub/core/constants/constants.dart';
import 'package:meta/meta.dart';

@immutable
abstract class QuizEvent extends Equatable {
  const QuizEvent();

  @override
  List<Object?> get props => [];
}

class StartQuiz extends QuizEvent {
  const StartQuiz();

  @override
  List<Object?> get props => [];
}

class NextQuestion extends QuizEvent {
  const NextQuestion();

  @override
  List<Object?> get props => [];
}

class CompletedQuestion extends QuizEvent {
  const CompletedQuestion();

  @override
  List<Object?> get props => [];
}

class ChoseAnswer extends QuizEvent {
  final int answerIndex;

  const ChoseAnswer({required this.answerIndex});

  @override
  List<Object?> get props => [answerIndex];
}

class UpdateCourseInfo extends QuizEvent {
  final String course;
  final List<dynamic>? topics;
  final String? choosenTopic;

  const UpdateCourseInfo({
    required this.course,
    this.topics,
    this.choosenTopic,
  });

  @override
  List<Object?> get props => [course, topics, choosenTopic];
}

class UpdateQuizPreferences extends QuizEvent {
  final Difficulty difficulty;
  final QuestionType questionType;
  final int numberOfQuestions;

  const UpdateQuizPreferences({
    required this.difficulty,
    required this.questionType,
    required this.numberOfQuestions,
  });

  @override
  List<Object?> get props => [difficulty, questionType, numberOfQuestions];
}

class ResetQuiz extends QuizEvent {
  const ResetQuiz();

  @override
  List<Object?> get props => [];
}

class GenerateTheoryQuestion extends QuizEvent {
  const GenerateTheoryQuestion();

  @override
  List<Object?> get props => [];
}

class SubmitAnswer extends QuizEvent {
  final int answerIndex;

  const SubmitAnswer({required this.answerIndex});

  @override
  List<Object?> get props => [answerIndex];
}

class SubmitGapFillAnswer extends QuizEvent {
  final int questionGlobalIndex;
  final List<String> userResponses;

  const SubmitGapFillAnswer({
    required this.questionGlobalIndex,
    required this.userResponses,
  });

  @override
  List<Object?> get props => [questionGlobalIndex, userResponses];
}

class GenerateGapFillQuestion extends QuizEvent {
  const GenerateGapFillQuestion();

  @override
  List<Object?> get props => [];
}

class SetTheoryTimer extends QuizEvent {
  final bool isTimed;
  final int? minutes;

  const SetTheoryTimer({required this.isTimed, this.minutes});

  @override
  List<Object?> get props => [isTimed, minutes];
}

/// Process quiz results through the adaptive engine.
/// Fires at quiz end to submit all answers to the BKT Worker
/// and store the resulting mastery state locally.
class ProcessAdaptiveResults extends QuizEvent {
  /// Map of question global index → selected answer index
  final Map<int, int> questionAnswers;

  const ProcessAdaptiveResults({required this.questionAnswers});

  @override
  List<Object?> get props => [questionAnswers];
}
