/// Adaptive Engine — HTTP Client Service
///
/// V2.5: No local BKT computation. Sends submission to Cloudflare Worker.
/// Worker is authoritative for correctness checking and BKT state update.
/// Client stores the returned KC state locally via get_storage.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'adaptive_types.dart';
import 'package:vens_hub/core/config/environment_config.dart';

/// Result of a submission attempt.
sealed class SubmitResult {
  const SubmitResult();
}

/// Submission was accepted and processed by server.
class SubmitApplied extends SubmitResult {
  final SubmitAnswerResult result;
  const SubmitApplied(this.result);
}

/// Duplicate attempt — same result returned.
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

/// Service that wraps HTTP calls to the Cloudflare Worker adaptive endpoints.
///
/// Usage:
/// ```dart
/// final service = AdaptiveService();
/// final result = await service.submitAnswer(input, currentKcState);
/// result.when(
///   applied: (r) => _handleResult(r),
///   duplicate: (r) => _handleResult(r),
///   error: (e) => _showError(e),
/// );
/// ```
class AdaptiveService {
  final String _baseUrl;

  AdaptiveService({String? baseUrl})
      : _baseUrl = baseUrl ?? EnvironmentConfig.apiBaseUrl;

  /// Submit an answer to the adaptive engine.
  ///
  /// [input] — the answer details.
  /// [kcState] — the current KC state for this topic (null on first attempt).
  /// Returns [SubmitApplied] on success, [SubmitDuplicate] on dedup,
  /// [SubmitError] on failure.
  Future<SubmitResult> submitAnswer(
    SubmitAnswerInput input, [
    Map<String, dynamic>? kcState,
  ]) async {
    try {
      final uri = Uri.parse('$_baseUrl/adaptive/submit-answer');
      final body = {
        ...input.toJson(),
        if (kcState != null) 'kcState': kcState,
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        final err = _tryParseError(response.body);
        return SubmitError(err);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final result = SubmitAnswerResult.fromJson(data);

      if (result.status == 'duplicate') {
        return SubmitDuplicate(result);
      }
      return SubmitApplied(result);
    } catch (e) {
      return SubmitError('Failed to submit answer', e);
    }
  }

  /// Get course-level mastery aggregation from the server.
  /// [kcStates] — the full local KC state map.
  Future<Map<String, dynamic>> getState(
    Map<String, Map<String, dynamic>> kcStates,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/adaptive/state');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'kcStates': kcStates}),
      );

      if (response.statusCode != 200) {
        return {};
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data;
    } catch (_) {
      return {};
    }
  }

  String _tryParseError(String body) {
    try {
      final data = jsonDecode(body);
      return data['error']?.toString() ?? 'Unknown server error';
    } catch (_) {
      return 'Server error (${body.length > 100 ? body.substring(0, 100) : body})';
    }
  }
}
