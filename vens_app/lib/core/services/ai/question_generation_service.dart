import 'dart:convert';
import 'dart:developer' as dev;

import 'package:vens_hub/core/Brain/data_formatting.dart';
import 'package:vens_hub/core/constants/constants.dart';
import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/core/error/exceptions.dart';
import 'package:vens_hub/core/services/ai/gemini_client.dart';
import 'package:vens_hub/data/models/question_model.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';
import 'package:get/get.dart';

/// Central service responsible for generating quiz questions via Gemini.
/// Consolidates the previous `Brain` class and scattered Gemini helpers
/// into a single, reusable component.
class QuestionGenerationService {
  QuestionGenerationService({GeminiService? gemini})
    : _gemini = gemini ?? di.sl<GeminiService>();

  final GeminiService _gemini;

  String get _dollarSign => r"$";

  /// Generates multiple choice questions using Gemini.
  Future<List<Question>> generateMultipleChoice({
    required String course,
    required String topic,
    required Difficulty difficulty,
    required int numberOfQuestions,
  }) async {
    try {
      dev.log(
        'Generating $numberOfQuestions ${difficulty.name} MCQ questions for $course – $topic',
      );

      final prompt = _buildMultipleChoicePrompt(
        course: course,
        topic: topic,
        difficulty: difficulty,
        numberOfQuestions: numberOfQuestions,
      );

      final generated = await _gemini.sendMessage(prompt);
      final questions = <Question>[];

      for (final entry in generated) {
        final data = Map<String, dynamic>.from(entry);
        try {
          _validateQuestionFormat(data);
          final options = _extractOptions(data);
          final correctIndex = _extractCorrectAnswerIndex(data, options.length);
          final question = Question(
            id: _buildQuestionId('mcq'),
            type: 'multiple_choice',
            text: _fixLatex(data['question']?.toString() ?? ''),
            courseName: data['course_name']?.toString() ?? course,
            topic: data['topic']?.toString() ?? topic,
            difficulty: data['difficulty']?.toString() ?? difficulty.name,
            options: options,
            correctAnswer: correctIndex.toString(),
            explanation: _fixLatex(data['explanation']?.toString() ?? ''),
          );
          questions.add(question);
        } on QuestionGenerationException catch (e) {
          dev.log('Skipping invalid MCQ payload: ${e.message}');
          try {
            dev.log('Payload: ${jsonEncode(data)}');
          } catch (_) {}
        }
      }

      if (questions.isEmpty) {
        throw QuestionGenerationException('API produced no valid MCQ results');
      }

      return questions;
    } catch (e) {
      dev.log('MCQ generation failed: $e');
      AppNotifier.error(
        context: Get.context,
        title: 'AI unavailable',
        message: 'Falling back to sample multiple choice questions.',
      );
      return _fallbackMcqQuestions(course, topic, difficulty);
    }
  }

  /// Generates drag-and-drop gap fill questions.
  Future<List<GapFillQuestion>> generateGapFill({
    required String course,
    required String topic,
    required Difficulty difficulty,
    required int numberOfQuestions,
  }) async {
    try {
      dev.log(
        'Generating $numberOfQuestions ${difficulty.name} gap-fill questions for $course – $topic',
      );

      final prompt = _buildGapFillPrompt(
        course: course,
        topic: topic,
        difficulty: difficulty,
        numberOfQuestions: numberOfQuestions,
      );

      final generated = await _gemini.sendMessage(prompt);
      final questions = <GapFillQuestion>[];

      for (final entry in generated) {
        final data = Map<String, dynamic>.from(entry);

        try {
          _validateGapFillFormat(data);
          final normalizedOptions = _extractOptions(data);
          final answers = _extractAnswers(data);
          final question = GapFillQuestion(
            courseName: data['course_name']?.toString() ?? course,
            topic: data['topic']?.toString() ?? topic,
            difficulty: data['difficulty']?.toString() ?? difficulty.name,
            prompt: _fixLatex(data['prompt']?.toString() ?? ''),
            answers: answers,
            explanation: _fixLatex(data['explanation']?.toString() ?? ''),
            options: normalizedOptions,
            isDragAndDrop: (data['isDragAndDrop'] as bool?) ?? true,
          );
          questions.add(question);
        } on QuestionGenerationException catch (e) {
          dev.log('Skipping invalid gap-fill payload: ${e.message}');
          try {
            dev.log('Payload: ${jsonEncode(data)}');
          } catch (_) {}
        }
      }

      if (questions.isEmpty) {
        throw QuestionGenerationException(
          'API produced no valid gap-fill questions',
        );
      }

      return questions;
    } catch (e) {
      dev.log('Gap-fill generation failed: $e');
      AppNotifier.error(
        context: Get.context,
        title: 'AI unavailable',
        message: 'Falling back to sample fill-in-the-gap questions.',
      );
      return _fallbackGapFillQuestions(course, topic, difficulty);
    }
  }

  /// Generates a single theory question distinct from the provided list.
  Future<TheoryQuestion> generateSingleTheoryQuestion({
    required String course,
    required String topic,
    required Difficulty difficulty,
    List<String> existingQuestions = const [],
  }) async {
    try {
      final prompt = _buildSingleTheoryPrompt(
        course: course,
        topic: topic,
        difficulty: difficulty,
        existingQuestions: existingQuestions,
      );

      final generated = await _gemini.sendMessage(prompt);
      if (generated.isEmpty) {
        throw QuestionGenerationException('Gemini returned no theory data');
      }

      final raw = generated.first;

      final data = Map<String, dynamic>.from(raw);
      _validateTheoryQuestionFormat(data);

      TheoryQuestion fixup(TheoryQuestion q) => q.copyWith(
        question: _fixLatex(q.question),
        sampleAnswer: _fixLatex(q.sampleAnswer),
        keyConcepts: q.keyConcepts.map(_fixLatex).toList(),
        markingCriteria: q.markingCriteria.map(_fixLatex).toList(),
      );

      return fixup(
        TheoryQuestion.fromJson(data).copyWith(
          courseName: data['course_name']?.toString() ?? course,
          topic: data['topic']?.toString() ?? topic,
          difficulty: data['difficulty']?.toString() ?? difficulty.name,
        ),
      );
    } catch (e) {
      dev.log('Theory question generation failed: $e');
      if (e is QuestionGenerationException) rethrow;
      throw QuestionGenerationException(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Prompt builders
  // ---------------------------------------------------------------------------

  String _buildMultipleChoicePrompt({
    required String course,
    required String topic,
    required Difficulty difficulty,
    required int numberOfQuestions,
  }) {
    return '''
Generate $numberOfQuestions unique ${difficulty.name} multiple choice questions for the course $course on the topic $topic, tailored for a middle school student.

Requirements

Format:
- Output JSON array.
- Each object must include: course_name, topic, difficulty, question,
  options (>=4), correct_answer (index), explanation.

Content:
1. At least 3 calculation-based questions when possible; remainder conceptual.
2. Use LaTeX for mathematics and escape backslashes.
3. Explanations should reference formulas and include LaTeX.
4. Align difficulty with ${difficulty.name} level.
5. Ensure questions target the $topic within $course.
''';
  }

  String _buildGapFillPrompt({
    required String course,
    required String topic,
    required Difficulty difficulty,
    required int numberOfQuestions,
  }) {
    return '''
Generate $numberOfQuestions unique ${difficulty.name} drag-and-drop fill-in-the-gap questions for the course $course on $topic.

Output JSON array with fields:
- course_name, topic, difficulty, prompt (use ___ for gaps), answers (array),
  options (single shared array of 6-8 items), explanation, isDragAndDrop (true).

Constraints:
- Each prompt has 1-3 gaps.
- Include all correct answers in the options list and add plausible distractors.
- Use LaTeX for math and escape backslashes.
- Provide concise explanations.
''';
  }

  String _buildSingleTheoryPrompt({
    required String course,
    required String topic,
    required Difficulty difficulty,
    required List<String> existingQuestions,
  }) {
    final existing =
        existingQuestions.isEmpty
            ? 'None.'
            : existingQuestions.map((q) => '- $q').join('\n');

    return '''
Generate 1 unique ${difficulty.name} theory or calculation question for $course on $topic.

Previously used questions to avoid:
$existing

Return a JSON array with a single object containing:
- course_name, topic, difficulty, question, question_type, sample_answer,
  key_concepts (array), marking_criteria (array).
- Use LaTeX with escaped backslashes.
''';
  }

  // ---------------------------------------------------------------------------
  // Validation helpers
  // ---------------------------------------------------------------------------

  void _validateQuestionFormat(Map<String, dynamic> data) {
    const required = {
      'course_name',
      'topic',
      'difficulty',
      'question',
      'options',
      'explanation',
    };

    for (final key in required) {
      if (!data.containsKey(key)) {
        throw QuestionGenerationException('Missing key in MCQ JSON: $key');
      }
    }

    _normalizeCorrectAnswerField(data);
    if (!data.containsKey('correct_answer')) {
      throw QuestionGenerationException('Missing correct_answer field');
    }
  }

  void _validateTheoryQuestionFormat(Map<String, dynamic> data) {
    const required = {
      'course_name',
      'topic',
      'difficulty',
      'question',
      'question_type',
      'sample_answer',
      'key_concepts',
      'marking_criteria',
    };

    for (final key in required) {
      if (!data.containsKey(key)) {
        throw QuestionGenerationException('Missing key in theory JSON: $key');
      }
    }
  }

  void _validateGapFillFormat(Map<String, dynamic> data) {
    const required = {
      'course_name',
      'topic',
      'difficulty',
      'prompt',
      'answers',
      'options',
      'explanation',
    };

    for (final key in required) {
      if (!data.containsKey(key)) {
        throw QuestionGenerationException('Missing key in gap-fill JSON: $key');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Normalisation helpers
  // ---------------------------------------------------------------------------

  List<String> _extractOptions(Map<String, dynamic> data) {
    final raw = data['options'];
    if (raw is! List) {
      throw QuestionGenerationException('Options must be a list');
    }
    return raw.map((e) => _fixLatex(e.toString())).toList();
  }

  List<String> _extractAnswers(Map<String, dynamic> data) {
    final raw = data['answers'];
    if (raw is! List) {
      throw QuestionGenerationException('Answers must be a list');
    }
    return raw.map((e) => _fixLatex(e.toString())).toList();
  }

  int _extractCorrectAnswerIndex(Map<String, dynamic> data, int optionCount) {
    final raw = data['correct_answer'];
    if (raw is int) {
      return _validateCorrectAnswerIndex(raw, optionCount);
    }
    if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      if (parsed != null) {
        return _validateCorrectAnswerIndex(parsed, optionCount);
      }
      // Fallback: match by option label
      final options = _extractOptions(data);
      final index = options.indexWhere(
        (option) => option.toLowerCase() == raw.trim().toLowerCase(),
      );
      if (index >= 0) {
        return index;
      }
    }
    throw QuestionGenerationException('Invalid correct_answer value: $raw');
  }

  int _validateCorrectAnswerIndex(int index, int optionCount) {
    if (index < 0 || index >= optionCount) {
      throw QuestionGenerationException('Correct answer index out of range');
    }
    return index;
  }

  void _normalizeCorrectAnswerField(Map<String, dynamic> data) {
    if (data.containsKey('correct_answer')) return;

    final candidates = [
      'correctAnswer',
      'answer_index',
      'answerIndex',
      'correct_option',
      'correctOption',
      'correct_option_index',
      'correctOptionIndex',
      'correct_option_text',
      'correctOptionText',
      'answer',
      'answer_text',
      'answerText',
    ];

    dynamic raw;
    for (final key in candidates) {
      if (data.containsKey(key)) {
        raw = data[key];
        break;
      }
    }

    if (raw == null) {
      return;
    }

    final options = _extractOptions(data);

    if (raw is List && raw.isNotEmpty) {
      raw = raw.first;
    } else if (raw is Map) {
      raw = raw['index'] ?? raw['value'] ?? raw['text'];
    }

    if (raw is num) {
      data['correct_answer'] = raw.toInt();
      return;
    }

    if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      if (parsed != null) {
        data['correct_answer'] = parsed;
        return;
      }

      final index = options.indexWhere(
        (option) => option.toLowerCase() == raw.trim().toLowerCase(),
      );
      if (index >= 0) {
        data['correct_answer'] = index;
      }
    }
  }

  String _fixLatex(String input) {
    return input.replaceAll('dollarSign', _dollarSign).replaceAll(r'\\', r'\');
  }

  // ---------------------------------------------------------------------------
  // Fall-back content to keep UI functional when AI fails.
  // ---------------------------------------------------------------------------

  List<Question> _fallbackMcqQuestions(
    String course,
    String topic,
    Difficulty difficulty,
  ) {
    return [
      Question(
        id: _buildQuestionId('mcq'),
        type: 'multiple_choice',
        text:
            "Ohm's Law relates voltage (V), current (I) and resistance (R). Which formula is correct?",
        courseName: course,
        topic: topic,
        difficulty: difficulty.name,
        options: [
          r"$ V = I \\times R $",
          r"$ V = R \\times P $",
          r"$ V = I / R $",
          r"$ V = P / I $",
        ],
        correctAnswer: '0',
        explanation: r"Ohm's Law is $ V = IR $.",
      ),
      Question(
        id: _buildQuestionId('mcq'),
        type: 'multiple_choice',
        text: "The SI unit of electrical resistance is:",
        courseName: course,
        topic: topic,
        difficulty: difficulty.name,
        options: ['ohm', 'ampere', 'volt', 'watt'],
        correctAnswer: '0',
        explanation: r"Resistance is measured in ohms ($ \\Omega $).",
      ),
    ];
  }

  List<GapFillQuestion> _fallbackGapFillQuestions(
    String course,
    String topic,
    Difficulty difficulty,
  ) {
    return [
      GapFillQuestion(
        courseName: course,
        topic: topic,
        difficulty: difficulty.name,
        prompt:
            "Ohm's Law states that voltage equals current times ___. The formula is $_dollarSign V = I \\times ___ $_dollarSign.",
        answers: ['resistance', 'R'],
        explanation:
            "Ohm's Law: $_dollarSign V = IR $_dollarSign where V is voltage, I is current, and R is resistance.",
        options: [
          'resistance',
          'voltage',
          'current',
          'power',
          'energy',
          'R',
          'V',
          'I',
        ],
        isDragAndDrop: true,
      ),
      GapFillQuestion(
        courseName: course,
        topic: topic,
        difficulty: difficulty.name,
        prompt:
            "The unit of electrical resistance is the ___. Another symbol commonly used is $_dollarSign ___ $_dollarSign.",
        answers: ['ohm', '\\Omega'],
        explanation:
            "Resistance is measured in ohms, symbolized as $_dollarSign \\Omega $_dollarSign.",
        options: ['ohm', 'ampere', 'volt', 'watt', '\\Omega', 'A', 'V', 'W'],
        isDragAndDrop: true,
      ),
    ];
  }

  String _buildQuestionId(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond
        .toString()
        .padLeft(4, '0')
        .substring(0, 4);
    return '$prefix-$timestamp-$random';
  }
}
