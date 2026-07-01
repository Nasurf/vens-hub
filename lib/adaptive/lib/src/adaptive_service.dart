/// Adaptive Engine — Callable Function Service
///
/// V2.5: No local BKT computation. Server is authoritative.
/// Client locks UI + shows "Checking..." while waiting.

import 'adaptive_types.dart';

/// Result of a submission attempt.
sealed class SubmitResult {
  const SubmitResult();
}

/// Submission was accepted and processed by server.
class SubmitApplied extends SubmitResult {
  final SubmitAnswerResult result;
  const SubmitApplied(this.result);
}

/// Duplicate attempt — server returned cached result.
class SubmitDuplicate extends SubmitResult {
  final SubmitAnswerResult result;
  const SubmitDuplicate(this.result);
}

/// Submission failed due to network or server error.
class SubmitError extends SubmitResult {
  final String message;
  final Object? originalError;
  const SubmitError(this.message, [this.originalError]);
}

/// Service that wraps Firebase callable functions for the adaptive engine.
///
/// Usage:
/// ```dart
/// final service = AdaptiveService();
/// final result = await service.submitAnswer(input);
/// result.when(
///   applied: (r) => _handleResult(r),
///   duplicate: (r) => _handleResult(r), // same shape
///   error: (e) => _showError(e),
/// );
/// ```
class AdaptiveService {
  /// The callable function name in Firebase Functions.
  static const String _submitAnswerFn = 'submitAnswer';
  static const String _getStateFn = 'getAdaptiveState';
  static const String _getReviewsFn = 'getPendingReviews';

  /// Injected callable function caller.
  /// Expected signature: (String name, Map<String, dynamic> args) async -> Map<String, dynamic>
  final Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> args) _callFunction;

  const AdaptiveService({
    required Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> args) callFunction,
  }) : _callFunction = callFunction;

  /// Submit an answer to the server.
  /// Returns [SubmitApplied] on success, [SubmitDuplicate] on dedup, [SubmitError] on failure.
  Future<SubmitResult> submitAnswer(SubmitAnswerInput input) async {
    try {
      final response = await _callFunction(_submitAnswerFn, input.toJson());
      final result = SubmitAnswerResult.fromJson(response);
      if (result.status == 'duplicate') {
        return SubmitDuplicate(result);
      }
      return SubmitApplied(result);
    } catch (e) {
      return SubmitError('Failed to submit answer', e);
    }
  }

  /// Fetch the full adaptive state document for the current user.
  Future<AdaptiveStateDoc?> getState() async {
    try {
      final response = await _callFunction(_getStateFn, {});
      return AdaptiveStateDoc.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Fetch pending reviews that are due now.
  Future<List<PendingReview>> getPendingReviews() async {
    try {
      final response = await _callFunction(_getReviewsFn, {});
      final list = (response['pending'] as List<dynamic>?) ?? [];
      return list
          .map((e) => PendingReview.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
