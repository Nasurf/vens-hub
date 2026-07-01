/// Dart mirror of TypeScript adaptive engine types.
/// No BKT computation — server-authoritative.
/// Client uses these types to format requests and parse responses.

/// Input payload sent from client to submitAnswer callable function.
class SubmitAnswerInput {
  final String sessionId;
  final String questionId;
  final String selectedAnswerId;
  final String attemptId;
  final int clientElapsedSeconds;

  const SubmitAnswerInput({
    required this.sessionId,
    required this.questionId,
    required this.selectedAnswerId,
    required this.attemptId,
    required this.clientElapsedSeconds,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'questionId': questionId,
        'selectedAnswerId': selectedAnswerId,
        'attemptId': attemptId,
        'clientElapsedSeconds': clientElapsedSeconds,
      };

  factory SubmitAnswerInput.fromJson(Map<String, dynamic> json) =>
      SubmitAnswerInput(
        sessionId: json['sessionId'] as String,
        questionId: json['questionId'] as String,
        selectedAnswerId: json['selectedAnswerId'] as String,
        attemptId: json['attemptId'] as String,
        clientElapsedSeconds: json['clientElapsedSeconds'] as int,
      );
}

/// Result returned from submitAnswer callable function.
class SubmitAnswerResult {
  /// "applied" | "duplicate"
  final String status;

  /// Updated mastery probability (0.0–1.0)
  final double masteryProb;

  /// Updated stability in days
  final double sParameter;

  /// Status label: "learning" | "reviewing"
  final String kcStatus;

  /// ISO 8601 timestamp of next review due
  final String nextReviewDue;

  /// Whether the submitted answer was correct
  final bool isCorrect;

  /// State document revision for concurrency tracking
  final int stateRevision;

  const SubmitAnswerResult({
    required this.status,
    required this.masteryProb,
    required this.sParameter,
    required this.kcStatus,
    required this.nextReviewDue,
    required this.isCorrect,
    required this.stateRevision,
  });

  factory SubmitAnswerResult.fromJson(Map<String, dynamic> json) =>
      SubmitAnswerResult(
        status: json['status'] as String,
        masteryProb: (json['masteryProb'] as num).toDouble(),
        sParameter: (json['sParameter'] as num).toDouble(),
        kcStatus: json['kcStatus'] as String,
        nextReviewDue: json['nextReviewDue'] as String,
        isCorrect: json['isCorrect'] as bool,
        stateRevision: json['stateRevision'] as int,
      );
}

/// Per-KC adaptive state (server source of truth).
/// Client reads this to display progress but never writes it.
class KcState {
  final double masteryProb;
  final double sParameter;
  final String status;
  final String lastAttemptAt;
  final String lastQualifiedReviewAt;
  final String nextReviewDue;
  final String parameterVersion;
  final int schemaVersion;
  final int totalAttempts;
  final int correctAttempts;

  const KcState({
    required this.masteryProb,
    required this.sParameter,
    required this.status,
    required this.lastAttemptAt,
    required this.lastQualifiedReviewAt,
    required this.nextReviewDue,
    required this.parameterVersion,
    required this.schemaVersion,
    required this.totalAttempts,
    required this.correctAttempts,
  });

  factory KcState.fromJson(Map<String, dynamic> json) => KcState(
        masteryProb: (json['masteryProb'] as num).toDouble(),
        sParameter: (json['sParameter'] as num).toDouble(),
        status: json['status'] as String,
        lastAttemptAt: json['lastAttemptAt'] as String,
        lastQualifiedReviewAt: json['lastQualifiedReviewAt'] as String,
        nextReviewDue: json['nextReviewDue'] as String,
        parameterVersion: json['parameterVersion'] as String? ?? '',
        schemaVersion: json['schemaVersion'] as int? ?? 2,
        totalAttempts: json['totalAttempts'] as int? ?? 0,
        correctAttempts: json['correctAttempts'] as int? ?? 0,
      );
}

/// Full adaptive state document (one per user).
class AdaptiveStateDoc {
  final String userId;
  final Map<String, KcState> states;
  final int revision;
  final int schemaVersion;
  final String updatedAt;

  const AdaptiveStateDoc({
    required this.userId,
    required this.states,
    required this.revision,
    required this.schemaVersion,
    required this.updatedAt,
  });

  factory AdaptiveStateDoc.fromJson(Map<String, dynamic> json) =>
      AdaptiveStateDoc(
        userId: json['userId'] as String? ?? '',
        states: (json['states'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, KcState.fromJson(v as Map<String, dynamic>))),
        revision: json['revision'] as int? ?? 0,
        schemaVersion: json['schemaVersion'] as int? ?? 2,
        updatedAt: json['updatedAt'] as String? ?? '',
      );
}

/// Result from getPendingReviews callable function.
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
