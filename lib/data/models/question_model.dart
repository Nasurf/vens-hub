import 'package:equatable/equatable.dart';

/// Represents a question in the application.
class Question extends Equatable {
  final String id;
  final String type; // e.g., 'theory', 'calculation', 'multiple_choice'
  final String text; // The question text itself
  final String? subject; // Optional: e.g., 'Physics', 'Calculus'
  final String? correctAnswerSummary; // Summary of the correct answer
  final List<String>? solutionSteps; // Detailed steps for the solution
  final bool isCalculationQuestion; // Helper to distinguish question types
  final String? courseName; // Legacy field for brain.dart compatibility
  final String? topic; // Legacy field for brain.dart compatibility
  final String? difficulty; // Legacy field for brain.dart compatibility
  final String? correctAnswer; // Legacy field for brain.dart compatibility
  final List<String>? options; // Legacy field for brain.dart compatibility
  final String? explanation; // Legacy field for brain.dart compatibility

  const Question({
    required this.id,
    required this.type,
    required this.text,
    this.subject,
    this.correctAnswerSummary,
    this.solutionSteps,
    this.isCalculationQuestion = false,
    this.courseName,
    this.topic,
    this.difficulty,
    this.correctAnswer,
    this.options,
    this.explanation,
  });

  @override
  List<Object?> get props => [
    id,
    type,
    text,
    subject,
    correctAnswerSummary,
    solutionSteps,
    isCalculationQuestion,
    courseName,
    topic,
    difficulty,
    correctAnswer,
    options,
    explanation,
  ];

  /// Creates a Question from a JSON map.
  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      type: json['type'] as String,
      text: json['text'] as String,
      subject: json['subject'] as String?,
      correctAnswerSummary: json['correctAnswerSummary'] as String?,
      solutionSteps:
          (json['solutionSteps'] as List<dynamic>?)
              ?.map((step) => step as String)
              .toList(),
      isCalculationQuestion: json['isCalculationQuestion'] as bool? ?? false,
      courseName:
          json['course_name'] as String? ?? json['courseName'] as String?,
      topic: json['topic'] as String?,
      difficulty: json['difficulty'] as String?,
      correctAnswer:
          json['correct_answer']?.toString() ??
          json['correctAnswer'] as String?,
      options:
          (json['options'] as List<dynamic>?)
              ?.map((option) => option as String)
              .toList(),
      explanation: json['explanation'] as String?,
    );
  }

  /// Converts this Question to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'text': text,
      'subject': subject,
      'correctAnswerSummary': correctAnswerSummary,
      'solutionSteps': solutionSteps,
      'isCalculationQuestion': isCalculationQuestion,
      'courseName': courseName,
      'topic': topic,
      'difficulty': difficulty,
      'correctAnswer': correctAnswer,
      'options': options,
      'explanation': explanation,
    };
  }

  /// Creates a copy of this Question with updated fields.
  Question copyWith({
    String? id,
    String? type,
    String? text,
    String? subject,
    String? correctAnswerSummary,
    List<String>? solutionSteps,
    bool? isCalculationQuestion,
    String? courseName,
    String? topic,
    String? difficulty,
    String? correctAnswer,
    List<String>? options,
    String? explanation,
  }) {
    return Question(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      subject: subject ?? this.subject,
      correctAnswerSummary: correctAnswerSummary ?? this.correctAnswerSummary,
      solutionSteps: solutionSteps ?? this.solutionSteps,
      isCalculationQuestion:
          isCalculationQuestion ?? this.isCalculationQuestion,
      courseName: courseName ?? this.courseName,
      topic: topic ?? this.topic,
      difficulty: difficulty ?? this.difficulty,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      options: options ?? this.options,
      explanation: explanation ?? this.explanation,
    );
  }
}
