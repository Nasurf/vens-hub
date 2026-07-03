/// Adaptive Engine — HTTP Client Service
///
/// V2.5: No local BKT computation. Sends submission to Cloudflare Worker.
/// Worker is authoritative for correctness checking, BKT state update,
/// and persisting attempts + mastery to D1.
///
/// V2.6: Passes X-User-Id header so Worker can persist user performance data.
/// Client still caches KC state locally (get_storage) as fast cache,
/// but server is the source of truth for persistence.

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
/// All user-scoped requests pass the Firebase UID via X-User-Id header
/// so the Worker can persist attempt logs and mastery state to D1.
///
/// Usage:
/// ```dart
/// final service = AdaptiveService();
/// final result = await service.submitAnswer(input, currentKcState, userId);
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

  Map<String, String> _headers(String? userId) {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (userId != null && userId.isNotEmpty) {
      h['X-User-Id'] = userId;
    }
    return h;
  }

  /// Submit an answer to the adaptive engine.
  ///
  /// [input] — the answer details.
  /// [kcState] — the current KC state for this topic (null on first attempt).
  /// [userId] — Firebase UID for server-side persistence (optional but recommended).
  /// Returns [SubmitApplied] on success, [SubmitDuplicate] on dedup,
  /// [SubmitError] on failure.
  Future<SubmitResult> submitAnswer(
    SubmitAnswerInput input, [
    Map<String, dynamic>? kcState,
    String? userId,
  ]) async {
    try {
      final uri = Uri.parse('$_baseUrl/adaptive/submit-answer');
      final body = {
        ...input.toJson(),
        if (kcState != null) 'kcState': kcState,
      };

      final response = await http.post(
        uri,
        headers: _headers(userId),
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
    Map<String, Map<String, dynamic>> kcStates, [
    String? userId,
  ]) async {
    try {
      final uri = Uri.parse('$_baseUrl/adaptive/state');
      final response = await http.post(
        uri,
        headers: _headers(userId),
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

  // ── User Performance Endpoints ────────────────────────────────────

  /// Get all mastery records for the user.
  Future<List<Map<String, dynamic>>> getUserMastery(String userId) async {
    try {
      final uri = Uri.parse('$_baseUrl/user/mastery');
      final response = await http.get(uri, headers: _headers(userId));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['topics'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// Get mastery for a specific course.
  Future<Map<String, dynamic>> getUserCourseMastery(
      String userId, String courseCode) async {
    try {
      final uri = Uri.parse('$_baseUrl/user/mastery/${Uri.encodeComponent(courseCode)}');
      final response = await http.get(uri, headers: _headers(userId));
      if (response.statusCode != 200) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Get course-level stats (rollup of all mastered topics).
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final uri = Uri.parse('$_baseUrl/user/stats');
      final response = await http.get(uri, headers: _headers(userId));
      if (response.statusCode != 200) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Seed local KC state to the server (one-time upload from Flutter local cache).
  Future<int> seedMastery(
      String userId, Map<String, Map<String, dynamic>> kcStates) async {
    try {
      final uri = Uri.parse('$_baseUrl/user/seed-mastery');
      final response = await http.post(
        uri,
        headers: _headers(userId),
        body: jsonEncode({'kcStates': kcStates}),
      );
      if (response.statusCode != 200) return 0;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['seeded'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Batch submit quiz results — accepts a list of per-topic answers.
  /// Used by the completion screen to sync quiz results to the server.
  /// Each item: { topicName, courseCode, isCorrect, questionId?, selectedAnswerIndex?, elapsedSeconds? }
  Future<int> submitBatch(
    String userId,
    List<Map<String, dynamic>> results,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/adaptive/submit-batch');
      final response = await http.post(
        uri,
        headers: _headers(userId),
        body: jsonEncode({'results': results}),
      );
      if (response.statusCode != 200) return 0;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['count'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────

  String _tryParseError(String body) {
    try {
      final data = jsonDecode(body);
      return data['error']?.toString() ?? 'Unknown server error';
    } catch (_) {
      return 'Server error (${body.length > 100 ? body.substring(0, 100) : body})';
    }
  }
}
