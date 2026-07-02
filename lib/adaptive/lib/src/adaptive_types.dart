/// Dart mirror of the adaptive engine response types.
/// No BKT computation — server-authoritative.
/// Client uses these to format requests and parse Worker responses.

/// Input payload sent to /adaptive/submit-answer.
class SubmitAnswerInput {
  final String sessionId;
  final String questionId;
  final int selectedAnswerIndex;
  final String attemptId;
  final int clientElapsedSeconds;

  const SubmitAnswerInput({
    required this.sessionId,
    required this.questionId,
    required this.selectedAnswerIndex,
    required this.attemptId,
    this.clientElapsedSeconds = 0,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'questionId': questionId,
        'selectedAnswerIndex': selectedAnswerIndex,
        'attemptId': attemptId,
        'clientElapsedSeconds': clientElapsedSeconds,
      };

  factory SubmitAnswerInput.fromJson(Map<String, dynamic> json) =>
      SubmitAnswerInput(
        sessionId: json['sessionId'] as String,
        questionId: json['questionId'] as String,
        selectedAnswerIndex: json['selectedAnswerIndex'] as int,
        attemptId: json['attemptId'] as String,
        clientElapsedSeconds: json['clientElapsedSeconds'] as int? ?? 0,
      );
}

/// Result returned from /adaptive/submit-answer.
class SubmitAnswerResult {
  /// "applied" | "duplicate"
  final String status;

  /// Whether the submitted answer was correct
  final bool isCorrect;

  /// The correct answer index
  final int correctAnswerIndex;

  /// The correct answer label (e.g., "A")
  final String? correctAnswer;

  /// The correct answer text
  final String? correctAnswerText;

  /// Explanation from D1
  final String? explanation;

  /// The KC key (topic_name)
  final String kcKey;

  /// Mastery probability before this answer
  final double masteryBefore;

  /// Updated mastery probability (0.0–1.0)
  final double masteryProb;

  /// Updated stability in days
  final double sParameter;

  /// Status label: "learning" | "reviewing"
  final String kcStatus;

  /// Total attempts on this KC
  final int totalAttempts;

  /// Correct attempts on this KC
  final int correctAttempts;

  /// The full updated KC state for client-side caching
  final Map<String, dynamic> updatedKcState;

  const SubmitAnswerResult({
    required this.status,
    required this.isCorrect,
    required this.correctAnswerIndex,
    this.correctAnswer,
    this.correctAnswerText,
    this.explanation,
    required this.kcKey,
    required this.masteryBefore,
    required this.masteryProb,
    required this.sParameter,
    required this.kcStatus,
    required this.totalAttempts,
    required this.correctAttempts,
    required this.updatedKcState,
  });

  factory SubmitAnswerResult.fromJson(Map<String, dynamic> json) =>
      SubmitAnswerResult(
        status: json['status'] as String? ?? 'applied',
        isCorrect: json['isCorrect'] as bool? ?? false,
        correctAnswerIndex: json['correctAnswerIndex'] as int? ?? -1,
        correctAnswer: json['correctAnswer'] as String?,
        correctAnswerText: json['correctAnswerText'] as String?,
        explanation: json['explanation'] as String?,
        kcKey: json['kcKey'] as String? ?? '',
        masteryBefore: (json['masteryBefore'] as num?)?.toDouble() ?? 0.0,
        masteryProb: (json['masteryAfter'] as num?)?.toDouble() ?? 0.0,
        sParameter: (json['sParameter'] as num?)?.toDouble() ?? 1.0,
        kcStatus: json['kcStatus'] as String? ?? 'learning',
        totalAttempts: json['totalAttempts'] as int? ?? 0,
        correctAttempts: json['correctAttempts'] as int? ?? 0,
        updatedKcState:
            Map<String, dynamic>.from(json['updatedKcState'] as Map? ?? {}),
      );
}

/// Per-KC adaptive state (for local caching).
class KcState {
  final double masteryProb;
  final double sParameter;
  final String status;
  final String lastAttemptAt;
  final int totalAttempts;
  final int correctAttempts;

  const KcState({
    required this.masteryProb,
    required this.sParameter,
    required this.status,
    required this.lastAttemptAt,
    this.totalAttempts = 0,
    this.correctAttempts = 0,
  });

  factory KcState.fromJson(Map<String, dynamic> json) => KcState(
        masteryProb: (json['masteryProb'] as num?)?.toDouble() ?? 0.15,
        sParameter: (json['sParameter'] as num?)?.toDouble() ?? 1.0,
        status: json['status'] as String? ?? 'learning',
        lastAttemptAt: json['lastAttemptAt'] as String? ?? '',
        totalAttempts: json['totalAttempts'] as int? ?? 0,
        correctAttempts: json['correctAttempts'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'masteryProb': masteryProb,
        'sParameter': sParameter,
        'status': status,
        'lastAttemptAt': lastAttemptAt,
        'totalAttempts': totalAttempts,
        'correctAttempts': correctAttempts,
      };
}

/// Full adaptive state document (one per user, stored locally).
class AdaptiveStateDoc {
  final String userId;
  final Map<String, KcState> states;
  final String updatedAt;

  const AdaptiveStateDoc({
    this.userId = '',
    this.states = const {},
    this.updatedAt = '',
  });

  factory AdaptiveStateDoc.fromJson(Map<String, dynamic> json) =>
      AdaptiveStateDoc(
        userId: json['userId'] as String? ?? '',
        states: (json['states'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, KcState.fromJson(v as Map<String, dynamic>))),
        updatedAt: json['updatedAt'] as String? ?? '',
      );
}

/// A pending review KC.
class PendingReview {
  final String kcKey;
  final double masteryProb;
  final String nextReviewDue;

  const PendingReview({
    required this.kcKey,
    required this.masteryProb,
    required this.nextReviewDue,
  });

  factory PendingReview.fromJson(Map<String, dynamic> json) => PendingReview(
        kcKey: json['kcKey'] as String,
        masteryProb: (json['masteryProb'] as num).toDouble(),
        nextReviewDue: json['nextReviewDue'] as String,
      );
}
