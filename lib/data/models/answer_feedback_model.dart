import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Model for AI-generated feedback on user answers
class AnswerFeedback extends Equatable {
  final String questionId;
  final bool isCorrect;
  final String feedback;
  final String correctAnswer;
  final List<String> hints;
  final int score;
  final String rating;
  final String overallFeedback;
  final List<String> strengths;
  final List<ImprovementArea> areasForImprovement;
  final String correctSolutionSummary;
  final List<String> enhancements;

  const AnswerFeedback({
    required this.questionId,
    required this.isCorrect,
    required this.feedback,
    required this.correctAnswer,
    required this.hints,
    required this.score,
    required this.rating,
    required this.overallFeedback,
    required this.strengths,
    required this.areasForImprovement,
    required this.correctSolutionSummary,
    required this.enhancements,
  });

  /// Creates AnswerFeedback from JSON map
  factory AnswerFeedback.fromJson(Map<String, dynamic> json) {
    return AnswerFeedback(
      questionId: json['question_id'] as String,
      isCorrect: json['is_correct'] as bool,
      feedback: json['feedback'] as String,
      correctAnswer: json['correct_answer'] as String,
      hints: List<String>.from(json['hints'] as List),
      score: json['score'] as int,
      rating: json['rating'] as String,
      overallFeedback: json['overall_feedback'] as String,
      strengths: List<String>.from(json['strengths'] as List),
      areasForImprovement:
          (json['areas_for_improvement'] as List)
              .map((e) => ImprovementArea.fromJson(e as Map<String, dynamic>))
              .toList(),
      correctSolutionSummary: json['correct_solution_summary'] as String,
      enhancements: List<String>.from(json['enhancements'] as List),
    );
  }

  /// Converts AnswerFeedback to JSON map
  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'is_correct': isCorrect,
      'feedback': feedback,
      'correct_answer': correctAnswer,
      'hints': hints,
      'score': score,
      'rating': rating,
      'overall_feedback': overallFeedback,
      'strengths': strengths,
      'areas_for_improvement':
          areasForImprovement.map((e) => e.toJson()).toList(),
      'correct_solution_summary': correctSolutionSummary,
      'enhancements': enhancements,
    };
  }

  /// Creates a copy with updated fields
  AnswerFeedback copyWith({
    String? questionId,
    bool? isCorrect,
    String? feedback,
    String? correctAnswer,
    List<String>? hints,
    int? score,
    String? rating,
    String? overallFeedback,
    List<String>? strengths,
    List<ImprovementArea>? areasForImprovement,
    String? correctSolutionSummary,
    List<String>? enhancements,
  }) {
    return AnswerFeedback(
      questionId: questionId ?? this.questionId,
      isCorrect: isCorrect ?? this.isCorrect,
      feedback: feedback ?? this.feedback,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      hints: hints ?? this.hints,
      score: score ?? this.score,
      rating: rating ?? this.rating,
      overallFeedback: overallFeedback ?? this.overallFeedback,
      strengths: strengths ?? this.strengths,
      areasForImprovement: areasForImprovement ?? this.areasForImprovement,
      correctSolutionSummary:
          correctSolutionSummary ?? this.correctSolutionSummary,
      enhancements: enhancements ?? this.enhancements,
    );
  }

  /// Helper getters for UI logic
  bool get hasStrengths => strengths.isNotEmpty;
  bool get hasImprovements => areasForImprovement.isNotEmpty;
  bool get hasEnhancements => enhancements.isNotEmpty;

  @override
  List<Object?> get props => [
    questionId,
    isCorrect,
    feedback,
    correctAnswer,
    hints,
    score,
    rating,
    overallFeedback,
    strengths,
    areasForImprovement,
    correctSolutionSummary,
    enhancements,
  ];
}

/// Enum for feedback ratings
class FeedbackRating {
  static const String excellent = 'Excellent';
  static const String good = 'Good';
  static const String satisfactory = 'Satisfactory';
  static const String needsImprovement = 'Needs Improvement';
  static const String incorrect = 'Incorrect';

  static Color getRatingColor(String rating) {
    switch (rating) {
      case excellent:
        return Colors.green;
      case good:
        return Colors.lightGreen;
      case satisfactory:
        return Colors.orange;
      case needsImprovement:
        return Colors.deepOrange;
      case incorrect:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Represents an area for improvement in feedback
class ImprovementArea extends Equatable {
  final String area;
  final String explanation;
  final String? suggestedCorrection;
  final int priority;

  const ImprovementArea({
    required this.area,
    required this.explanation,
    this.suggestedCorrection,
    this.priority = 1,
  });

  /// Creates ImprovementArea from JSON map
  factory ImprovementArea.fromJson(Map<String, dynamic> json) {
    return ImprovementArea(
      area: json['area'] as String,
      explanation: json['explanation'] as String,
      suggestedCorrection: json['suggested_correction'] as String?,
      priority: json['priority'] as int? ?? 1,
    );
  }

  /// Converts ImprovementArea to JSON map
  Map<String, dynamic> toJson() {
    return {
      'area': area,
      'explanation': explanation,
      'suggested_correction': suggestedCorrection,
      'priority': priority,
    };
  }

  /// Creates a copy with updated fields
  ImprovementArea copyWith({
    String? area,
    String? explanation,
    String? suggestedCorrection,
    int? priority,
  }) {
    return ImprovementArea(
      area: area ?? this.area,
      explanation: explanation ?? this.explanation,
      suggestedCorrection: suggestedCorrection ?? this.suggestedCorrection,
      priority: priority ?? this.priority,
    );
  }

  @override
  List<Object?> get props => [area, explanation, suggestedCorrection, priority];
}
