import 'dart:convert';
import 'dart:io';

/// Shared cross-implementation BKT test fixture loader.
///
/// Loads the same JSON fixture file used by TypeScript tests,
/// ensuring Dart and TypeScript implementations produce identical results.
class BktTestFixtures {
  final Map<String, dynamic> params;
  final List<Map<String, dynamic>> testCases;

  const BktTestFixtures({
    required this.params,
    required this.testCases,
  });

  factory BktTestFixtures.fromFile(String path) {
    final file = File(path);
    final contents = file.readAsStringSync();
    final json = jsonDecode(contents) as Map<String, dynamic>;
    return BktTestFixtures(
      params: json['params'] as Map<String, dynamic>,
      testCases: (json['testCases'] as List<dynamic>)
          .cast<Map<String, dynamic>>(),
    );
  }

  factory BktTestFixtures.fromString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return BktTestFixtures(
      params: json['params'] as Map<String, dynamic>,
      testCases: (json['testCases'] as List<dynamic>)
          .cast<Map<String, dynamic>>(),
    );
  }

  /// Get a single test case by ID.
  Map<String, dynamic>? getTestCase(String id) {
    for (final tc in testCases) {
      if (tc['id'] == id) return tc;
    }
    return null;
  }
}

/// Adaptive engine fixture loader — for cross-implementation tests.
class AdaptiveFixtures {
  static const String defaultFixturePath =
      'functions-adaptive/fixtures/bkt-test-cases.json';

  /// Load the shared BKT test fixtures.
  /// Path is relative to the Engineering-Hub project root.
  static BktTestFixtures loadBktFixtures([String? path]) {
    return BktTestFixtures.fromFile(path ?? defaultFixturePath);
  }

  /// Inline minimal fixture for unit tests that don't need the full file.
  static String get minimalJson => '''{
    "params": {
      "pLearning0": 0.15,
      "pTransition": 0.12,
      "pSlip": 0.10,
      "pGuess": 0.25,
      "sBase": 1.0,
      "sFactor": 2.0,
      "sDecay": 0.5,
      "minimumSpacingDays": 0.25,
      "reviewThreshold": 0.75,
      "schedulerType": "fixed-policy"
    },
    "testCases": [
      {
        "id": "correct-first-attempt-v2",
        "priorMastery": null,
        "isCorrect": true,
        "expected": {
          "masteryBefore": 0.15,
          "pCorrect": 0.3475,
          "posterior": 0.3884892086330935,
          "masteryAfter": 0.4618705035971223
        }
      }
    ]
  }''';
}
