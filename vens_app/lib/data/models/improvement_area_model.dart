import 'package:equatable/equatable.dart';

/// Model for individual improvement areas provided in AI evaluation feedback
class ImprovementArea extends Equatable {
  final String errorIdentified;
  final String explanation;
  final String suggestedCorrection;

  const ImprovementArea({
    required this.errorIdentified,
    required this.explanation,
    required this.suggestedCorrection,
  });

  /// Creates ImprovementArea from JSON map
  factory ImprovementArea.fromJson(Map<String, dynamic> json) {
    return ImprovementArea(
      errorIdentified: json['error_identified'] as String,
      explanation: json['explanation'] as String,
      suggestedCorrection: json['suggested_correction'] as String,
    );
  }

  /// Converts ImprovementArea to JSON map
  Map<String, dynamic> toJson() {
    return {
      'error_identified': errorIdentified,
      'explanation': explanation,
      'suggested_correction': suggestedCorrection,
    };
  }

  /// Creates a copy with updated fields
  ImprovementArea copyWith({
    String? errorIdentified,
    String? explanation,
    String? suggestedCorrection,
  }) {
    return ImprovementArea(
      errorIdentified: errorIdentified ?? this.errorIdentified,
      explanation: explanation ?? this.explanation,
      suggestedCorrection: suggestedCorrection ?? this.suggestedCorrection,
    );
  }

  @override
  List<Object?> get props => [
    errorIdentified,
    explanation,
    suggestedCorrection,
  ];

  @override
  String toString() {
    return 'ImprovementArea(error: ${errorIdentified.length > 30 ? '${errorIdentified.substring(0, 30)}...' : errorIdentified})';
  }
}
