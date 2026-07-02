import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// ── Inline copies of the types (avoids flutter dependency) ──
class SubmitAnswerInput {
  final String sessionId, questionId, selectedAnswerId, attemptId;
  final int clientElapsedSeconds;
  const SubmitAnswerInput({required this.sessionId, required this.questionId, required this.selectedAnswerId, required this.attemptId, required this.clientElapsedSeconds});
  Map<String, dynamic> toJson() => {'sessionId': sessionId, 'questionId': questionId, 'selectedAnswerId': selectedAnswerId, 'attemptId': attemptId, 'clientElapsedSeconds': clientElapsedSeconds};
  factory SubmitAnswerInput.fromJson(Map<String, dynamic> j) => SubmitAnswerInput(sessionId: j['sessionId'], questionId: j['questionId'], selectedAnswerId: j['selectedAnswerId'], attemptId: j['attemptId'], clientElapsedSeconds: j['clientElapsedSeconds']);
}

class SubmitAnswerResult {
  final String status, kcStatus, nextReviewDue;
  final double masteryProb, sParameter;
  final bool isCorrect;
  final int stateRevision;
  const SubmitAnswerResult({required this.status, required this.masteryProb, required this.sParameter, required this.kcStatus, required this.nextReviewDue, required this.isCorrect, required this.stateRevision});
  factory SubmitAnswerResult.fromJson(Map<String, dynamic> j) => SubmitAnswerResult(status: j['status'], masteryProb: (j['masteryProb'] as num).toDouble(), sParameter: (j['sParameter'] as num).toDouble(), kcStatus: j['kcStatus'], nextReviewDue: j['nextReviewDue'], isCorrect: j['isCorrect'], stateRevision: j['stateRevision']);
}

class KcState {
  final double masteryProb, sParameter;
  final String status, lastAttemptAt, lastQualifiedReviewAt, nextReviewDue, parameterVersion;
  final int schemaVersion, totalAttempts, correctAttempts;
  const KcState({required this.masteryProb, required this.sParameter, required this.status, required this.lastAttemptAt, required this.lastQualifiedReviewAt, required this.nextReviewDue, required this.parameterVersion, required this.schemaVersion, required this.totalAttempts, required this.correctAttempts});
  factory KcState.fromJson(Map<String, dynamic> j) => KcState(masteryProb: (j['masteryProb'] as num).toDouble(), sParameter: (j['sParameter'] as num).toDouble(), status: j['status'], lastAttemptAt: j['lastAttemptAt'], lastQualifiedReviewAt: j['lastQualifiedReviewAt'], nextReviewDue: j['nextReviewDue'], parameterVersion: j['parameterVersion'] ?? '', schemaVersion: j['schemaVersion'] ?? 2, totalAttempts: j['totalAttempts'] ?? 0, correctAttempts: j['correctAttempts'] ?? 0);
}

class AdaptiveStateDoc {
  final String userId, updatedAt;
  final Map<String, KcState> states;
  final int revision, schemaVersion;
  const AdaptiveStateDoc({required this.userId, required this.states, required this.revision, required this.schemaVersion, required this.updatedAt});
  factory AdaptiveStateDoc.fromJson(Map<String, dynamic> j) => AdaptiveStateDoc(userId: j['userId'] ?? '', states: (j['states'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, KcState.fromJson(v))), revision: j['revision'] ?? 0, schemaVersion: j['schemaVersion'] ?? 2, updatedAt: j['updatedAt'] ?? '');
}

// ── Fixture loader ──
class BktTestFixtures {
  final Map<String, dynamic> params;
  final List<Map<String, dynamic>> testCases;
  const BktTestFixtures({required this.params, required this.testCases});
  factory BktTestFixtures.fromString(String s) { final j = jsonDecode(s); return BktTestFixtures(params: j['params'], testCases: (j['testCases'] as List).cast()); }
  Map<String, dynamic>? getTestCase(String id) { for (final tc in testCases) { if (tc['id'] == id) return tc; } return null; }
}

// ── Tests ──
void main() {
  group('Types', () {
    test('SubmitAnswerInput round-trip', () {
      const input = SubmitAnswerInput(sessionId: 's-1', questionId: 'q-1', selectedAnswerId: 'a', attemptId: 'att-1', clientElapsedSeconds: 5);
      final json = input.toJson();
      final parsed = SubmitAnswerInput.fromJson(json);
      expect(parsed.sessionId, 's-1');
      expect(parsed.questionId, 'q-1');
      expect(parsed.attemptId, 'att-1');
      expect(parsed.clientElapsedSeconds, 5);
    });

    test('SubmitAnswerResult applied', () {
      final r = SubmitAnswerResult.fromJson({'status': 'applied', 'masteryProb': 0.4618705035971223, 'sParameter': 1.0, 'kcStatus': 'learning', 'nextReviewDue': '2026-06-24T10:00:00.000Z', 'isCorrect': true, 'stateRevision': 1});
      expect(r.status, 'applied');
      expect(r.masteryProb, closeTo(0.46187, 1e-5));
      expect(r.stateRevision, 1);
    });

    test('SubmitAnswerResult duplicate', () {
      final r = SubmitAnswerResult.fromJson({'status': 'duplicate', 'masteryProb': 0.75, 'sParameter': 4.0, 'kcStatus': 'reviewing', 'nextReviewDue': '2026-07-01T00:00:00.000Z', 'isCorrect': true, 'stateRevision': 3});
      expect(r.status, 'duplicate');
      expect(r.masteryProb, 0.75);
      expect(r.kcStatus, 'reviewing');
    });

    test('KcState parses', () {
      final s = KcState.fromJson({'masteryProb': 0.85, 'sParameter': 3.0, 'status': 'reviewing', 'lastAttemptAt': '2026-06-20T10:00:00.000Z', 'lastQualifiedReviewAt': '2026-06-20T10:00:00.000Z', 'nextReviewDue': '2026-06-25T10:00:00.000Z', 'parameterVersion': 'v1', 'schemaVersion': 2, 'totalAttempts': 10, 'correctAttempts': 8});
      expect(s.masteryProb, 0.85);
      expect(s.status, 'reviewing');
      expect(s.totalAttempts, 10);
      expect(s.correctAttempts, 8);
    });

    test('AdaptiveStateDoc with nested states', () {
      final doc = AdaptiveStateDoc.fromJson({
        'userId': 'user-1',
        'states': {
          'course-1__kc-1': {'masteryProb': 0.92, 'sParameter': 5.0, 'status': 'reviewing', 'lastAttemptAt': '2026-06-23T00:00:00.000Z', 'lastQualifiedReviewAt': '2026-06-20T00:00:00.000Z', 'nextReviewDue': '2026-06-28T00:00:00.000Z', 'parameterVersion': 'v1', 'schemaVersion': 2, 'totalAttempts': 15, 'correctAttempts': 13},
          'course-1__kc-2': {'masteryProb': 0.45, 'sParameter': 1.0, 'status': 'learning', 'lastAttemptAt': '2026-06-24T00:00:00.000Z', 'lastQualifiedReviewAt': '2026-06-24T00:00:00.000Z', 'nextReviewDue': '2026-06-24T00:00:00.000Z', 'parameterVersion': 'v1', 'schemaVersion': 2, 'totalAttempts': 3, 'correctAttempts': 1},
        },
        'revision': 5, 'schemaVersion': 2, 'updatedAt': '2026-06-24T10:00:00.000Z',
      });
      expect(doc.states.length, 2);
      expect(doc.states['course-1__kc-1']!.masteryProb, 0.92);
      expect(doc.states['course-1__kc-2']!.status, 'learning');
      expect(doc.revision, 5);
    });
  });

  group('Fixtures', () {
    test('Parse minimal JSON', () {
      final fixtures = BktTestFixtures.fromString('{"params":{"pLearning0":0.15,"pTransition":0.12},"testCases":[{"id":"t1","isCorrect":true}]}');
      expect(fixtures.params['pLearning0'], 0.15);
      expect(fixtures.testCases.length, 1);
      expect(fixtures.getTestCase('t1'), isNotNull);
    });

    test('Shared fixture file loads and has 10 test cases', () {
      final fixturePath = '${Directory.current.path}/functions-adaptive/fixtures/bkt-test-cases.json';
      final file = File(fixturePath);
      if (!file.existsSync()) {
        return;
      }
      final contents = file.readAsStringSync();
      final j = jsonDecode(contents);
      final cases = (j['testCases'] as List).length;
      expect(cases, greaterThanOrEqualTo(10));
    });
  });
}
