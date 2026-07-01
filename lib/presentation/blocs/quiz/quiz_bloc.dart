import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vens_hub/core/Brain/data_formatting.dart';
import 'package:vens_hub/core/legacy_brain/brain.dart';
import 'package:vens_hub/data/models/question_model.dart';
import 'quiz_state.dart';
import 'quiz_event.dart';
import 'package:vens_hub/core/constants/constants.dart';


class QuizBloc extends Bloc<QuizEvent, QuizState> {
  QuizBloc() : super(const QuizState()) {
    // PASSES DATA FROM THE HOME START BUTTON TO THE COURSE SCREEN
    // IT ALSO PASSES THE CHOOSEN COURSE TO THE CUSTOMIZATION PAGE
    on<UpdateCourseInfo>((event, emit) {
      emit(
        state.copyWith(
          course: event.course,
          topics: event.topics,
          choosenTopic: event.choosenTopic,
        ),
      );
      log("Updated course info: ${state.course}, ${state.choosenTopic}");
    });

    // USED ON THE CUSTOMIZATION SCREEN AND PASSES THE USERS PREFERENCES TO THE QUIZ PAGE
    on<UpdateQuizPreferences>((event, emit) async {
      switch (event.questionType) {
        case QuestionType.theory:
          await _initTheoryQuiz(event, emit);
          break;
        case QuestionType.gapFill:
          await _initGapFillQuiz(event, emit);
          break;
        default:
          await _initMultipleChoiceQuiz(event, emit);
      }
    });

    on<GenerateTheoryQuestion>((event, emit) async {
      await _generateNextTheoryQuestion(emit);
    });

    on<SubmitAnswer>((event, emit) {
      log("SubmitAnswer event received with answerIndex: ${event.answerIndex}");

      if (state.currentQuestion == null) {
        log("Error: currentQuestion is null, cannot process answer");
        return;
      }

      if (state.isAnswerChoosen) {
        log("Answer already chosen, ignoring submission");
        return;
      }

      final isCorrect =
          (state.currentQuestion is Question)
              ? _isAnswerCorrect(
                event.answerIndex,
                (state.currentQuestion as Question).correctAnswer,
              )
              : false;
      log("Answer submitted: ${event.answerIndex}, Correct: $isCorrect");

      // Record selection history for review page
      final updatedMcqSelected = Map<int, int>.from(state.mcqSelectedAnswers);
      updatedMcqSelected[state.currentQuestionIndex] = event.answerIndex;

      final updatedMcqIsCorrect = Map<int, bool>.from(state.mcqIsCorrect);
      updatedMcqIsCorrect[state.currentQuestionIndex] = isCorrect;

      // Update the state with the selected answer
      emit(
        state.copyWith(
          selectedAnswer: event.answerIndex,
          isAnswerChoosen: true,
          numOfCorrectAnswers:
              isCorrect
                  ? state.numOfCorrectAnswers + 1
                  : state.numOfCorrectAnswers,
          mcqSelectedAnswers: updatedMcqSelected,
          mcqIsCorrect: updatedMcqIsCorrect,
        ),
      );

      log(
        "State updated: selectedAnswer=${event.answerIndex}, isAnswerChoosen=true",
      );

      // Emit the state again to ensure all listeners are notified
      Future.microtask(() {
        emit(state);
      });
    });

    // Select an answer without submitting. This only updates selectedAnswer.
    on<ChoseAnswer>((event, emit) {
      log("ChoseAnswer event received with answerIndex: ${event.answerIndex}");
      if (state.isAnswerChoosen) {
        // Ignore further selections after submission
        return;
      }
      emit(state.copyWith(selectedAnswer: event.answerIndex));
    });

    on<NextQuestion>((event, emit) {
      log("NextQuestion event received");

      // For theory quizzes, check if we need to generate more questions
      if (state.questionType == QuestionType.theory &&
          state.isLastQuestion &&
          state.allQuestions.length < state.numberOfQuestions!) {
        log(
          "Reached end of current theory questions, dispatching generation for the next one.",
        );
        add(const GenerateTheoryQuestion());
        return; // The GenerateTheoryQuestion handler will manage the state update
      }

      if (state.isLastQuestion) {
        log("Already at the last question, not advancing");
        return;
      }

      final nextIndex = state.currentQuestionIndex + 1;
      log("Moving to next question: $nextIndex");

      if (nextIndex >= state.allQuestions.length) {
        log("Warning: Attempted to move beyond the last question");
        return;
      }

      // First emit a state with just the selection reset
      emit(state.copyWith(selectedAnswer: null, isAnswerChoosen: false));

      // Then emit the state with the new question index
      emit(
        state.copyWith(
          currentQuestionIndex: nextIndex,
          selectedAnswer: null,
          isAnswerChoosen: false,
        ),
      );

      log(
        "State updated: currentQuestionIndex=$nextIndex, selectedAnswer=null, isAnswerChoosen=false",
      );

      // Emit the state again to ensure all listeners are notified
      Future.microtask(() {
        emit(state);
      });
    });

    on<CompletedQuestion>((event, emit) {});

    on<SubmitGapFillAnswer>((event, emit) {
      _handleSubmitGapFillAnswer(event, emit);
    });

    on<ResetQuiz>((event, emit) {
      emit(const QuizState()); // Reset to initial state
    });

    on<SetTheoryTimer>((event, emit) {
      // Set timer preferences and mark the actual start time now
      emit(
        state.copyWith(
          isTheoryTimed: event.isTimed,
          theoryTimeMinutes: event.minutes,
          startedAt: DateTime.now(),
          endedAt: null,
        ),
      );
    });
  }

  /// Helper method to check if an answer is correct, handling different answer formats
  bool _isAnswerCorrect(int answerIndex, String? correctAnswer) {
    if (correctAnswer == null) return false;

    // Try to parse as integer first
    final correctIndex = int.tryParse(correctAnswer);
    if (correctIndex != null) {
      return answerIndex == correctIndex;
    }

    // If not an integer, compare as string
    return correctAnswer == answerIndex.toString();
  }

  // ============ Private helpers to organize generation logic ============

  Future<void> _initTheoryQuiz(
    UpdateQuizPreferences event,
    Emitter<QuizState> emit,
  ) async {
    emit(
      state.copyWith(
        difficulty: event.difficulty,
        questionType: event.questionType,
        numberOfQuestions: event.numberOfQuestions,
        isLoading: true,
        allQuestions: [],
        currentQuestionIndex: 0,
        selectedAnswer: null,
        isAnswerChoosen: false,
        numOfCorrectAnswers: 0,
        startedAt: DateTime.now(),
        endedAt: null,
      ),
    );
    add(const GenerateTheoryQuestion());
  }

  Future<void> _initGapFillQuiz(
    UpdateQuizPreferences event,
    Emitter<QuizState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final brain = Brain(
        course: state.course,
        topic: state.choosenTopic!,
        difficulty: event.difficulty,
        numberOfQuestions: event.numberOfQuestions,
        questionType: event.questionType,
      );

      final questions = await brain.generateGapFillQuestions();

      emit(
        state.copyWith(
          difficulty: event.difficulty,
          questionType: event.questionType,
          numberOfQuestions: event.numberOfQuestions,
          allQuestions: questions,
          isLoading: false,
          currentQuestionIndex: 0,
          selectedAnswer: null,
          isAnswerChoosen: false,
          numOfCorrectAnswers: 0,
          gapFillUserAnswers: {},
          gapFillIsCorrect: {},
          startedAt: DateTime.now(),
          endedAt: null,
        ),
      );
    } catch (e) {
      log("Error generating gap fill questions: $e");
      emit(
        state.copyWith(
          isLoading: false,
          allQuestions: const [],
          currentQuestionIndex: 0,
          selectedAnswer: null,
          isAnswerChoosen: false,
          numOfCorrectAnswers: 0,
          gapFillUserAnswers: {},
          gapFillIsCorrect: {},
          startedAt: DateTime.now(),
          endedAt: null,
        ),
      );
    }
  }

  Future<void> _initMultipleChoiceQuiz(
    UpdateQuizPreferences event,
    Emitter<QuizState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final brain = Brain(
        course: state.course,
        topic: state.choosenTopic!,
        difficulty: event.difficulty,
        numberOfQuestions: event.numberOfQuestions,
        questionType: event.questionType,
      );

      final questions = await brain.generateAndSaveQuestions();

      if (questions.isEmpty) {
        log("Warning: No questions were generated");
      }

      emit(
        state.copyWith(
          difficulty: event.difficulty,
          questionType: event.questionType,
          numberOfQuestions: event.numberOfQuestions,
          allQuestions: questions,
          isLoading: false,
          currentQuestionIndex: 0,
          selectedAnswer: null,
          isAnswerChoosen: false,
          numOfCorrectAnswers: 0,
          startedAt: DateTime.now(),
          endedAt: null,
        ),
      );
    } catch (e) {
      log("Error generating questions: $e");
      emit(
        state.copyWith(
          isLoading: false,
          allQuestions: const [],
          currentQuestionIndex: 0,
          selectedAnswer: null,
          isAnswerChoosen: false,
          numOfCorrectAnswers: 0,
          startedAt: DateTime.now(),
          endedAt: null,
        ),
      );
    }
  }

  Future<void> _generateNextTheoryQuestion(Emitter<QuizState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final brain = Brain(
        course: state.course,
        topic: state.choosenTopic!,
        difficulty: state.difficulty!,
        numberOfQuestions: 1,
        questionType: QuestionType.theory,
      );

      final existingQuestionTexts =
          state.allQuestions
              .whereType<TheoryQuestion>()
              .map((q) => q.question)
              .toList();

      final newQuestion = await brain.generateSingleTheoryQuestion(
        existingQuestionTexts: existingQuestionTexts,
      );

      final updatedQuestions = List<Object>.from(state.allQuestions)
        ..add(newQuestion);

      final nextIndex =
          state.allQuestions.isEmpty ? 0 : state.currentQuestionIndex + 1;

      emit(
        state.copyWith(
          allQuestions: updatedQuestions,
          currentQuestionIndex: nextIndex,
          isLoading: false,
          selectedAnswer: null,
          isAnswerChoosen: false,
        ),
      );
    } catch (e) {
      log("Error generating single theory question: $e");
      emit(state.copyWith(isLoading: false));
    }
  }

  void _handleSubmitGapFillAnswer(
    SubmitGapFillAnswer event,
    Emitter<QuizState> emit,
  ) {
    log(
      "SubmitGapFillAnswer event received for question ${event.questionGlobalIndex}",
    );

    if (event.questionGlobalIndex >= state.allQuestions.length) {
      log("Error: Invalid question index");
      return;
    }

    final question = state.allQuestions[event.questionGlobalIndex];
    if (question is! GapFillQuestion) {
      log("Error: Question is not a GapFillQuestion");
      return;
    }

    // Order-insensitive matching and partial credit
    List<String> correct =
        question.answers.map((e) => e.trim().toLowerCase()).toList();
    List<String> user =
        event.userResponses.map((e) => e.trim().toLowerCase()).toList();
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
    final int totalGaps = correct.length;
    final bool isCorrect = matched == totalGaps && totalGaps > 0;

    log(
      "Gap fill answer submitted: matched=$matched total=$totalGaps allCorrect=$isCorrect",
    );

    // Update state with user answers and correctness
    final updatedUserAnswers = Map<int, List<String>>.from(
      state.gapFillUserAnswers,
    );
    updatedUserAnswers[event.questionGlobalIndex] = event.userResponses;

    final updatedIsCorrect = Map<int, bool>.from(state.gapFillIsCorrect);
    updatedIsCorrect[event.questionGlobalIndex] = isCorrect;

    final updatedCorrectCounts = Map<int, int>.from(
      state.gapFillCorrectCountByQuestion,
    );
    final updatedTotalGaps = Map<int, int>.from(
      state.gapFillTotalGapsByQuestion,
    );
    updatedCorrectCounts[event.questionGlobalIndex] = matched;
    updatedTotalGaps[event.questionGlobalIndex] = totalGaps;

    emit(
      state.copyWith(
        gapFillUserAnswers: updatedUserAnswers,
        gapFillIsCorrect: updatedIsCorrect,
        gapFillCorrectCountByQuestion: updatedCorrectCounts,
        gapFillTotalGapsByQuestion: updatedTotalGaps,
        numOfCorrectAnswers:
            isCorrect
                ? state.numOfCorrectAnswers + 1
                : state.numOfCorrectAnswers,
      ),
    );
  }
}
