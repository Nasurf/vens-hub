import 'dart:convert';
import 'dart:developer' as dev;

import 'package:get/get.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';
import 'package:vens_hub/core/error/exceptions.dart';

import 'package:vens_hub/data/models/question_model.dart';
// import 'package:vens_hub/core/services/ai/gemini_client.dart'; // Updated Gemini import
// import 'package:vens_hub/core/config/app_config.dart'; // Added AppConfig import
import '../Brain/data_formatting.dart';
import '../constants/constants.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/gemini.dart';

// Improved Brain Class
class Brain {
  final String course;
  final String topic;
  final Difficulty difficulty;
  final QuestionType questionType;
  final GeminiApi _geminiApi;
  final int numberOfQuestions;

  Brain({
    required this.course,
    required this.topic,
    required this.difficulty,
    required this.numberOfQuestions,
    required this.questionType,
  }) : _geminiApi = GeminiApi(modelType: "gemini-2.5-flash-lite");

  String dollarSign = r"$";
  String slash = r"\";

  String get _generatePrompt =>
      questionType == QuestionType.theory
          ? _theoryPrompt
          : questionType == QuestionType.gapFill
          ? _gapFillPrompt
          : _multipleChoicePrompt;

  String get _multipleChoicePrompt => '''
  Generate $numberOfQuestions unique ${difficulty.name} multiple choice questions for the course $course on the topic $topic, tailored for a Middle school Student to help them learn. These questions should help the student understand the course material.

Requirements

Format:
- **Output**: JSON
- **Fields**:
  - **course_name**: The name of the course.
  - **topic**: The specific topic of the question.
  - **difficulty**: The difficulty level of the question.
  - **question**: The text of the question.
  - **Options**: A list of answer choices (at least 4).
  - **Correct Answer**: The index of the correct option.
  - **Explanation**: A clear and educational explanation that supports the student's understanding.

Content:
1. **Question Types and Distribution**:
   - At least 3 calculation-based questions.
   - Remaining questions should test conceptual understanding.
   - Each question must have 4 distinct and plausible options.

2. **Mathematical Formatting**:
   - Use LaTeX for all mathematical expressions.
   - Ensure all mathematics is written in LaTeX.
   - IMPORTANT: Because the output is JSON, every backslash must be JSON-escaped (use **double backslashes**). E.g., write `\\frac{a}{b}` instead of `\frac{a}{b}`.
   - Format: \$LaTeX_expression\$ (inline) or \$\$LaTeX_expression\$\$ (block)
   - Examples: \$\\frac{12}{4} = 3 \\text{Ohms}\$, \$\\int_{0}^{1} x^2 \\, dx\$
   - Ensure all LaTeX commands begin with a backslash (e.g., \\frac, \\int).

3. **Explanations**:
   - Provide brief solutions.
   - Include relevant formulas with LaTeX formatting.
   - Connect concepts to practical applications.
   - Focus on building understanding.
   - Include units where applicable.

4. **Difficulty Alignment**:
   - Match ${difficulty.name} level expectations.
   - Calculations should be appropriate for the course level.
   - Distractors should be plausible but clearly incorrect.

5. **Content Focus**:
   - Questions should directly relate to $topic.
   - Reference standard electrical engineering notation.
   - Include practical applications where relevant.

### Example JSON Output
```json
[
  {
    "course_name": "$course",
    "topic": "$topic",
    "difficulty": "${difficulty.name}",
    "question": "What is the value of resistance R in the given circuit?",
    "options": ["10 Ohms", "20 Ohms", "30 Ohms", "40 Ohms"],
    "correct_answer": 1,
    "explanation": "Using Ohm's Law \$dollarSign( V = IR )\$dollarSign, the resistance can be calculated as: \$dollarSign R = frac{V}{I} = frac{12}{0.6} = 20 text{ Ohms }\$dollarSign. This result matches option 2."
  }Y
]
''';

  String _singleTheoryPrompt(List<String> existingQuestions) => '''
Generate 1 unique ${difficulty.name} theory or calculation question for the course $course on the topic $topic, designed for students to provide detailed written answers. This question should test deep understanding and problem-solving skills.

**Existing Questions to Avoid:**
${existingQuestions.isEmpty ? "None yet." : existingQuestions.map((q) => "- $q").join("\n")}

Ensure the new question is distinct from the ones listed above.

Requirements

Format:
- **Output**: JSON
- **Fields**:
  - **course_name**: The name of the course.
  - **topic**: The specific topic of the question.
  - **difficulty**: The difficulty level of the question.
  - **question**: The text of the question.
  - **question_type**: Either "theory" or "calculation".
  - **sample_answer**: A comprehensive model answer.
  - **key_concepts**: A list of key concepts that should be addressed.
  - **marking_criteria**: Criteria for evaluating student answers.

Content:
1. **Question Types**:
   - The question can be a theory question (requiring conceptual explanations, comparisons, or applications) or a calculation problem (requiring step-by-step solutions).
   - The question must be directly related to $topic.

2. **Mathematical Formatting**:
   - Use LaTeX for all mathematical expressions.
   - IMPORTANT: Because the output is JSON, every backslash must be JSON-escaped (use **double backslashes**). E.g., write `\\frac{a}{b}` instead of `\frac{a}{b}`.
   - Format: \$LaTeX_expression\$ (inline) or \$\$LaTeX_expression\$\$ (block)
   - Examples: \$\\frac{12}{4} = 3 \\text{Ohms}\$, \$\\int_{0}^{1} x^2 \\, dx\$

3. **Sample Answers**:
   - Provide a complete, detailed answer.
   - Include step-by-step solutions for calculations.
   - Show all formulas and reasoning.
   - Include units and final answers.
   - Use LaTeX formatting for mathematical content.

4. **Difficulty Alignment**:
   - ${difficulty.name} level should match course expectations.
   - Theory questions should require appropriate depth of explanation.
   - Calculations should be appropriately complex.

5. **Content Focus**:
   - The question must relate specifically to $topic within $course.
   - Include practical applications and real-world examples.
   - Test understanding of fundamental principles.

### Example JSON Output
```json
{
  "course_name": "$course",
  "topic": "$topic",
  "difficulty": "${difficulty.name}",
  "question": "Explain Ohm's Law and calculate the current flowing through a resistor of 10Ω when 5V is applied across it.",
  "question_type": "calculation",
  "sample_answer": "Ohm's Law states that voltage is directly proportional to current: \$V = IR\$. Given: R = 10Ω, V = 5V. Using \$I = \\frac{V}{R} = \\frac{5}{10} = 0.5 \\text{A}\$. Therefore, the current is 0.5 amperes.",
  "key_concepts": ["Ohm's Law", "Voltage-current relationship", "Circuit analysis"],
  "marking_criteria": ["Correct statement of Ohm's Law", "Proper formula usage", "Correct calculation", "Appropriate units"]
}
```
''';

  String get _gapFillPrompt => '''
Generate $numberOfQuestions unique ${difficulty.name} drag-and-drop fill-in-the-gap questions for the course $course on the topic $topic, designed for students to drag and drop the correct answers into the gaps. These questions should test knowledge recall and understanding.

Requirements

Format:
- **Output**: JSON
- **Fields**:
  - **course_name**: The name of the course.
  - **topic**: The specific topic of the question.
  - **difficulty**: The difficulty level of the question.
  - **prompt**: The text with gaps marked as ___ (three underscores).
  - **answers**: An array of correct answers for each gap in order.
  - **options**: A single array of 4 options that includes all correct answers plus distractors, DO NOT LET DISTRACTORS BE TOO SIMILAR TO OTHER OPTIONS SO AS NOT TO CAUSE CONFUSION.
  - **explanation**: A SIMPLE EXPLANATION STATING WHY DOES OPTIONS WHERE USED IN THAT SENTENCE.
  - **isDragAndDrop**: Always set to true.

Content:
1. **Gap Design**:
   - Use exactly ___ (three underscores) to mark each gap.
   - Each question should have 1-3 gaps maximum.
   - Gaps should test key concepts, formulas, or important facts.
   - Questions should be directly related to $topic.

2. **Options Design**:
   - Provide a single list of 6-8 options that includes all correct answers.
   - Include plausible distractors that are related but incorrect.
   - Mix up the order of options so correct answers aren't always in the same position.
   - Keep options concise (1-3 words typically).
   - Make sure all correct answers are included in the options list.

3. **Mathematical Formatting**:
   - Use LaTeX for all mathematical expressions.
   - IMPORTANT: Because the output is JSON, every backslash must be JSON-escaped (use **double backslashes**). E.g., write `\\frac{a}{b}` instead of `\frac{a}{b}`.
   - Format: \$LaTeX_expression\$ (inline) or \$\$LaTeX_expression\$\$ (block)
   - Examples: \$\\frac{12}{4} = 3 \\text{Ohms}\$, \$\\int_{0}^{1} x^2 \\, dx\$

4. **Answers**:
   - Provide exact answers that students should fill in.
   - Include alternative acceptable answers if applicable.
   - Keep answers concise (1-3 words typically).
   - Include units where applicable.

5. **Explanations**:
   - Provide context for why the answer is correct.
   - Include relevant formulas with LaTeX formatting.
   - Connect to broader concepts.
   - Use LaTeX formatting for mathematical content.

6. **Difficulty Alignment**:
   - ${difficulty.name} level should match course expectations.
   - Gaps should test appropriate level of detail.

### Example JSON Output
```json
[
  {
    "course_name": "$course",
    "topic": "$topic",
    "difficulty": "${difficulty.name}",
    "prompt": "The process of ___ allows plants to convert sunlight into chemical energy.",
    "answers": ["photosynthesis"],
    "options": ["photosynthesis", "respiration", "fermentation", "digestion",],
    "explanation": "Photosynthesis is the process by which plants convert light energy into chemical energy (glucose).",
    "isDragAndDrop": true
  },
  {
    "course_name": "$course",
    "topic": "$topic", 
    "difficulty": "${difficulty.name}",
    "prompt": "Ohm's Law states that voltage equals current times ___. The formula is \$V = I \\times ___\$.",
    "answers": ["resistance", "R"],
    "options": ["resistance", "voltage", "current", "power", "energy" ],
    "explanation": "Ohm's Law is fundamental in electrical engineering: \$V = IR\$, where V is voltage, I is current, and R is resistance. This relationship shows that voltage is directly proportional to both current and resistance.",
    "isDragAndDrop": true
  }
]
```
''';

  String get _theoryPrompt => '''
Generate $numberOfQuestions unique ${difficulty.name} theory and calculation questions for the course $course on the topic $topic, designed for students to provide detailed written answers. These questions should test deep understanding and problem-solving skills.

Requirements

Format:
- **Output**: JSON
- **Fields**:
  - **course_name**: The name of the course.
  - **topic**: The specific topic of the question.
  - **difficulty**: The difficulty level of the question.
  - **question**: The text of the question.
  - **question_type**: Either "theory" or "calculation".
  - **sample_answer**: A comprehensive model answer.
  - **key_concepts**: A list of key concepts that should be addressed.
  - **marking_criteria**: Criteria for evaluating student answers.

Content:
1. **Question Types and Distribution**:
   - Mix of theory questions (conceptual explanations) and calculation problems.
   - Theory questions should ask for explanations, comparisons, or applications.
   - Calculation questions should require step-by-step solutions.
   - Questions should be directly related to $topic.

2. **Mathematical Formatting**:
   - Use LaTeX for all mathematical expressions.
   - IMPORTANT: Because the output is JSON, every backslash must be JSON-escaped (use **double backslashes**). E.g., write `\\frac{a}{b}` instead of `\frac{a}{b}`.
   - Format: \$LaTeX_expression\$ (inline) or \$\$LaTeX_expression\$\$ (block)
   - Examples: \$\\frac{12}{4} = 3 \\text{Ohms}\$, \$\\int_{0}^{1} x^2 \\, dx\$

3. **Sample Answers**:
   - Provide complete, detailed answers.
   - Include step-by-step solutions for calculations.
   - Show all formulas and reasoning.
   - Include units and final answers.
   - Use LaTeX formatting for mathematical content.

4. **Difficulty Alignment**:
   - ${difficulty.name} level should match course expectations.
   - Theory questions should require appropriate depth of explanation.
   - Calculations should be appropriately complex.

5. **Content Focus**:
   - All questions must relate specifically to $topic within $course.
   - Include practical applications and real-world examples.
   - Test understanding of fundamental principles.

### Example JSON Output
```json
[
  {
    "course_name": "$course",
    "topic": "$topic",
    "difficulty": "${difficulty.name}",
    "question": "Explain Ohm's Law and calculate the current flowing through a resistor of 10Ω when 5V is applied across it.",
    "question_type": "calculation",
    "sample_answer": "Ohm's Law states that voltage is directly proportional to current: \$dollarSign V = IR \$dollarSign. Given: R = 10Ω, V = 5V. Using \$dollarSign I = \\frac{V}{R} = \\frac{5}{10} = 0.5 \\text{A} \$dollarSign. Therefore, the current is 0.5 amperes.",
    "key_concepts": ["Ohm's Law", "Voltage-current relationship", "Circuit analysis"],
    "marking_criteria": ["Correct statement of Ohm's Law", "Proper formula usage", "Correct calculation", "Appropriate units"]
  }
]
''';

  Future<List<Object>> generateAndSaveQuestions() async {
    if (questionType == QuestionType.theory) {
      // This path should ideally not be taken for theory questions anymore.
      // The generation will be handled one-by-one by the BLoC.
      dev.log(
        "Warning: generateAndSaveQuestions called for theory questions. This is deprecated.",
      );
      throw UnsupportedError(
        "Theory questions should be generated individually via generateSingleTheoryQuestion.",
      );
    }

    // This block handles multipleChoice, practical, and calculations
    try {
      dev.log(
        "Starting to generate questions for topic: $topic, difficulty: ${difficulty.name}",
      );

      List<Question> questions = [];

      // First try to use the Gemini API
      try {
        dev.log("Attempting to use Gemini API...");
        dev.log("Prompt sent to Gemini: $_generatePrompt");
        final generatedQuestions = await _geminiApi.sendMessage(
          _generatePrompt,
        );
        dev.log(
          "Received ${generatedQuestions.length} questions from Gemini API",
        );

        for (final questionEntry in generatedQuestions) {
          final questionData = Map<String, dynamic>.from(questionEntry);
          dev.log('Processing question data: ${jsonEncode(questionData)}');
          String fixLatex(String s) =>
              s.replaceAll('dollarSign', r'$').replaceAll(r'\\', r'\');

          try {
            _validateQuestionFormat(questionData);

            // Handle different correct answer formats
            final correctAnswer =
                questionData["correct_answer"] ??
                questionData["correctAnswer"] ??
                questionData["answer_index"] ??
                questionData["answerIndex"];

            final question = Question(
              id: '',
              type: 'multiple_choice',
              text: fixLatex(questionData["question"]),
              courseName: questionData["course_name"],
              topic: questionData["topic"],
              difficulty: questionData["difficulty"],
              correctAnswer: correctAnswer?.toString(),
              options: List<String>.from(
                (questionData["options"] as List<dynamic>).map(
                  (e) => fixLatex(e.toString()),
                ),
              ),
              explanation: fixLatex(questionData["explanation"]),
            );

            questions.add(question);
          } on QuestionGenerationException catch (validationError) {
            dev.log(
              "Skipping invalid question object: ${validationError.message}",
            );
            try {
              dev.log('Invalid question payload: ${jsonEncode(questionData)}');
            } catch (_) {}
          }
        }

        if (questions.isEmpty) {
          throw QuestionGenerationException('API produced no valid questions');
        }

        dev.log(
          "Successfully processed ${questions.length} questions from API",
        );

        // TODO: surface success feedback through AppNotifier if needed.
        return questions;
      } catch (apiError) {
        dev.log("Gemini API error: $apiError");
        dev.log("Falling back to mock data");

        AppNotifier.error(
          context: Get.context,
          title: 'Error',
          message: 'Failed to generate questions. Using fallback.',
        );
        return _fallbackMcqQuestions();
      }
    } catch (e) {
      dev.log("Fatal error in generateAndSaveQuestions: $e");
      // As a last resort, return fallback
      return _fallbackMcqQuestions();
    }
  }

  List<Question> _fallbackMcqQuestions() {
    // Minimal offline MCQ set to keep UI functional
    return [
      Question(
        id: 'mcq-1',
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
        id: 'mcq-2',
        type: 'multiple_choice',
        text: "The SI unit of electrical resistance is:",
        courseName: course,
        topic: topic,
        difficulty: difficulty.name,
        options: ["ohm", "ampere", "volt", "watt"],
        correctAnswer: '0',
        explanation: r"Resistance is measured in ohms ($ \\Omega $).",
      ),
    ];
  }

  Future<TheoryQuestion> generateSingleTheoryQuestion({
    List<String> existingQuestionTexts = const [],
  }) async {
    try {
      dev.log(
        "Starting to generate a single theory question for topic: $topic, difficulty: ${difficulty.name}",
      );

      final prompt = _singleTheoryPrompt(existingQuestionTexts);
      dev.log("Prompt sent to Gemini for a single theory question: $prompt");

      // We expect a single JSON object, not a list.
      final generatedQuestionData = await _geminiApi.sendMessage(
        prompt,
        expectList: false, // Tell the API to expect a single JSON object
      );

      if (generatedQuestionData.isEmpty) {
        throw QuestionGenerationException(
          "Gemini API returned no data for the question.",
        );
      }

      // Since expectMultiple is false, the result should be the first element.
      final questionData = generatedQuestionData.first;
      dev.log("Received theory question data from Gemini API: $questionData");

      String fixLatex(String s) {
        if (s.isEmpty) return s;

        // Replace dollarSign placeholder with actual dollar sign
        s = s.replaceAll('dollarSign', r'$');

        // Fix double backslashes to single backslashes for LaTeX commands
        s = s.replaceAll(r'\\', r'\');

        // Fix common LaTeX formatting issues
        s = s.replaceAll(r'\text{', r'\text{');
        s = s.replaceAll(r'\mathrm{', r'\mathrm{');
        s = s.replaceAll(r'\frac{', r'\frac{');
        s = s.replaceAll(r'\int_{', r'\int_{');
        s = s.replaceAll(r'\sum_{', r'\sum_{');
        s = s.replaceAll(r'\sqrt{', r'\sqrt{');
        s = s.replaceAll(r'\left(', r'\left(');
        s = s.replaceAll(r'\right)', r'\right)');
        s = s.replaceAll(r'\left[', r'\left[');
        s = s.replaceAll(r'\right]', r'\right]');
        s = s.replaceAll(r'\left\{', r'\left\{');
        s = s.replaceAll(r'\right\}', r'\right\}');

        // Fix spacing issues
        s = s.replaceAll(r'\,', r'\,');
        s = s.replaceAll(r'\;', r'\;');
        s = s.replaceAll(r'\!', r'\!');

        // Remove any extra whitespace around LaTeX expressions
        s = s.replaceAll(RegExp(r'\s*\$\s*'), r'$');
        s = s.replaceAll(RegExp(r'\s*\$\$\s*'), r'$$');

        return s;
      }

      _validateTheoryQuestionFormat(questionData);

      final question = TheoryQuestion(
        courseName: questionData["course_name"],
        topic: questionData["topic"],
        difficulty: questionData["difficulty"],
        question: fixLatex(questionData["question"]),
        questionType: questionData["question_type"],
        sampleAnswer: fixLatex(questionData["sample_answer"]),
        keyConcepts: List<String>.from(
          (questionData["key_concepts"] as List<dynamic>).map(
            (e) => fixLatex(e.toString()),
          ),
        ),
        markingCriteria: List<String>.from(
          (questionData["marking_criteria"] as List<dynamic>).map(
            (e) => fixLatex(e.toString()),
          ),
        ),
      );

      dev.log("Successfully parsed a single theory question.");
      return question;
    } catch (e) {
      dev.log("Fatal error in generateSingleTheoryQuestion: $e");
      if (e is AIServiceException) {
        throw QuestionGenerationException(
          'Failed to generate single theory question due to AI service error: ${e.message}',
        );
      }
      throw QuestionGenerationException(
        'Failed to generate or process single theory question: ${e.toString()}',
      );
    }
  }

  void _validateTheoryQuestionFormat(Map<String, dynamic> data) {
    final requiredKeys = [
      'course_name',
      'topic',
      'difficulty',
      'question',
      'question_type',
      'sample_answer',
      'key_concepts',
      'marking_criteria',
    ];
    for (final key in requiredKeys) {
      if (!data.containsKey(key)) {
        throw QuestionGenerationException(
          'Missing key in theory question JSON: $key',
        );
      }
    }
  }

  Future<List<TheoryQuestion>> generateTheoryQuestions() async {
    try {
      dev.log(
        "Starting to generate theory questions for topic: $topic, difficulty: ${difficulty.name}",
      );

      List<TheoryQuestion> questions = [];

      try {
        dev.log("Attempting to use Gemini API for theory questions...");
        dev.log("Prompt sent to Gemini for theory questions: $_generatePrompt");
        final generatedQuestions = await _geminiApi.sendMessage(
          _generatePrompt,
        );
        dev.log(
          "Received ${generatedQuestions.length} theory questions from Gemini API",
        );

        for (final questionData in generatedQuestions) {
          String fixLatex(String s) {
            if (s.isEmpty) return s;

            // Replace dollarSign placeholder with actual dollar sign
            s = s.replaceAll('dollarSign', r'$');

            // Fix double backslashes to single backslashes for LaTeX commands
            s = s.replaceAll(r'\\', r'\');

            // Fix common LaTeX formatting issues
            s = s.replaceAll(r'\text{', r'\text{');
            s = s.replaceAll(r'\mathrm{', r'\mathrm{');
            s = s.replaceAll(r'\frac{', r'\frac{');
            s = s.replaceAll(r'\int_{', r'\int_{');
            s = s.replaceAll(r'\sum_{', r'\sum_{');
            s = s.replaceAll(r'\sqrt{', r'\sqrt{');
            s = s.replaceAll(r'\left(', r'\left(');
            s = s.replaceAll(r'\right)', r'\right)');
            s = s.replaceAll(r'\left[', r'\left[');
            s = s.replaceAll(r'\right]', r'\right]');
            s = s.replaceAll(r'\left\{', r'\left\{');
            s = s.replaceAll(r'\right\}', r'\right\}');

            // Fix spacing issues
            s = s.replaceAll(r'\,', r'\,');
            s = s.replaceAll(r'\;', r'\;');
            s = s.replaceAll(r'\!', r'\!');

            // Remove any extra whitespace around LaTeX expressions
            s = s.replaceAll(RegExp(r'\s*\$\s*'), r'$');
            s = s.replaceAll(RegExp(r'\s*\$\$\s*'), r'$$');

            return s;
          }

          try {
            _validateTheoryQuestionFormat(questionData);

            final question = TheoryQuestion(
              courseName: questionData["course_name"],
              topic: questionData["topic"],
              difficulty: questionData["difficulty"],
              question: fixLatex(questionData["question"]),
              questionType: questionData["question_type"],
              sampleAnswer: fixLatex(questionData["sample_answer"]),
              keyConcepts: List<String>.from(
                (questionData["key_concepts"] as List<dynamic>?)
                        ?.map((e) => fixLatex(e.toString()))
                        .toList() ??
                    [],
              ),
              markingCriteria: List<String>.from(
                (questionData["marking_criteria"] as List<dynamic>?)
                        ?.map((e) => fixLatex(e.toString()))
                        .toList() ??
                    [],
              ),
            );

            questions.add(question);
          } on QuestionGenerationException catch (validationError) {
            dev.log(
              "Skipping invalid theory question object: ${validationError.message}",
            );
          }
        }

        if (questions.isEmpty) {
          throw QuestionGenerationException(
            'API produced no valid theory questions',
          );
        }

        dev.log(
          "Successfully processed ${questions.length} theory questions from API",
        );

        return questions;
      } catch (apiError) {
        dev.log("Gemini API error for theory questions: $apiError");
        rethrow;
      }
    } catch (e) {
      dev.log("Fatal error in generateTheoryQuestions: $e");
      throw QuestionGenerationException('Failed to process theory questions');
    }
  }

  Future<List<GapFillQuestion>> generateGapFillQuestions() async {
    try {
      dev.log(
        "Starting to generate gap fill questions for topic: $topic, difficulty: ${difficulty.name}",
      );

      List<GapFillQuestion> questions = [];

      try {
        dev.log("Attempting to use Gemini API for gap fill questions...");
        dev.log(
          "Prompt sent to Gemini for gap fill questions: $_generatePrompt",
        );
        final generatedQuestions = await _geminiApi.sendMessage(
          _generatePrompt,
        );
        dev.log(
          "Received ${generatedQuestions.length} gap fill questions from Gemini API",
        );

        for (final questionData in generatedQuestions) {
          String fixLatex(String s) {
            if (s.isEmpty) return s;

            // Replace dollarSign placeholder with actual dollar sign
            s = s.replaceAll('dollarSign', r'$');

            // Fix double backslashes to single backslashes for LaTeX commands
            s = s.replaceAll(r'\\', r'\');

            // Fix common LaTeX formatting issues
            s = s.replaceAll(r'\text{', r'\text{');
            s = s.replaceAll(r'\mathrm{', r'\mathrm{');
            s = s.replaceAll(r'\frac{', r'\frac{');
            s = s.replaceAll(r'\int_{', r'\int_{');
            s = s.replaceAll(r'\sum_{', r'\sum_{');
            s = s.replaceAll(r'\sqrt{', r'\sqrt{');
            s = s.replaceAll(r'\left(', r'\left(');
            s = s.replaceAll(r'\right)', r'\right)');
            s = s.replaceAll(r'\left[', r'\left[');
            s = s.replaceAll(r'\right]', r'\right]');
            s = s.replaceAll(r'\left\{', r'\left\{');
            s = s.replaceAll(r'\right\}', r'\right\}');

            // Fix spacing issues
            s = s.replaceAll(r'\,', r'\,');
            s = s.replaceAll(r'\;', r'\;');
            s = s.replaceAll(r'\!', r'\!');

            // Remove any extra whitespace around LaTeX expressions
            s = s.replaceAll(RegExp(r'\s*\$\s*'), r'$');
            s = s.replaceAll(RegExp(r'\s*\$\$\s*'), r'$$');

            return s;
          }

          try {
            // Normalize and validate data to be tolerant of model variability
            final List<String> answersRaw = List<String>.from(
              questionData["answers"] ?? [],
            );
            final List<String> optionsRaw =
                (questionData["options"] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                <String>[];

            // Ensure options include all answers (case-insensitive) and are unique
            final Set<String> normalizedOptionsSet = {
              for (final opt in optionsRaw) opt.trim(),
            };
            for (final ans in answersRaw) {
              final ansTrim = ans.trim();
              final contains = normalizedOptionsSet.any(
                (o) => o.toLowerCase() == ansTrim.toLowerCase(),
              );
              if (!contains) {
                normalizedOptionsSet.add(ansTrim);
              }
            }
            final List<String> normalizedOptions =
                normalizedOptionsSet.toList();

            // Build a normalized data map and validate it
            final normalizedData =
                Map<String, dynamic>.from(questionData)
                  ..['answers'] = answersRaw
                  ..['options'] = normalizedOptions;

            _validateGapFillQuestionFormat(normalizedData);

            final question = GapFillQuestion(
              courseName: questionData["course_name"],
              topic: questionData["topic"],
              difficulty: questionData["difficulty"],
              prompt: fixLatex(questionData["prompt"]),
              answers: answersRaw,
              explanation: fixLatex(questionData["explanation"]),
              options: normalizedOptions,
              isDragAndDrop: questionData["isDragAndDrop"] ?? true,
            );

            questions.add(question);
          } on QuestionGenerationException catch (validationError) {
            dev.log(
              "Skipping invalid gap fill question object: ${validationError.message}",
            );
          }
        }

        if (questions.isEmpty) {
          throw QuestionGenerationException(
            'API produced no valid gap fill questions',
          );
        }

        dev.log(
          "Successfully processed ${questions.length} gap fill questions from API",
        );

        return questions;
      } catch (apiError) {
        dev.log("Gemini API error for gap fill questions: $apiError");
        // Provide a small fallback so the UI remains usable
        return _fallbackGapFillQuestions();
      }
    } catch (e) {
      dev.log("Fatal error in generateGapFillQuestions: $e");
      throw QuestionGenerationException('Failed to process gap fill questions');
    }
  }

  List<GapFillQuestion> _fallbackGapFillQuestions() {
    // Minimal offline set to keep UI functional
    return [
      GapFillQuestion(
        courseName: course,
        topic: topic,
        difficulty: difficulty.name,
        prompt:
            "Ohm's Law states that voltage equals current times ___. The formula is $dollarSign V = I \\times ___ $dollarSign.",
        answers: ["resistance", "R"],
        explanation:
            "Ohm's Law: $dollarSign V = IR $dollarSign where V is voltage, I is current, and R is resistance.",
        options: [
          "resistance",
          "voltage",
          "current",
          "power",
          "energy",
          "R",
          "V",
          "I",
        ],
        isDragAndDrop: true,
      ),
      GapFillQuestion(
        courseName: course,
        topic: topic,
        difficulty: difficulty.name,
        prompt:
            "The unit of electrical resistance is the ___. Another symbol commonly used is $dollarSign ___ $dollarSign.",
        answers: ["ohm", "\\Omega"],
        explanation:
            "Resistance is measured in ohms, symbolized as $dollarSign \\Omega $dollarSign.",
        options: ["ohm", "ampere", "volt", "watt", "\\Omega", "A", "V", "W"],
        isDragAndDrop: true,
      ),
    ];
  }

  void _normalizeCorrectAnswerField(Map<String, dynamic> data) {
    final optionsRaw = (data['options'] as List?) ?? const [];
    final options = [for (final option in optionsRaw) option.toString()];

    dynamic rawCorrectAnswer;
    for (final key in [
      'correct_answer',
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
    ]) {
      if (data.containsKey(key)) {
        rawCorrectAnswer = data[key];
        break;
      }
    }

    if (rawCorrectAnswer == null) {
      return;
    }

    dev.log(
      'Normalizing correct answer: raw=$rawCorrectAnswer options=${jsonEncode(options)}',
    );

    if (rawCorrectAnswer is List && rawCorrectAnswer.isNotEmpty) {
      rawCorrectAnswer = rawCorrectAnswer.first;
    } else if (rawCorrectAnswer is Map<String, dynamic>) {
      rawCorrectAnswer =
          rawCorrectAnswer['index'] ??
          rawCorrectAnswer['value'] ??
          rawCorrectAnswer['text'];
    }

    final resolvedIndex = _coerceCorrectAnswerIndex(rawCorrectAnswer, options);

    if (resolvedIndex != null) {
      data['correct_answer'] = resolvedIndex;
      dev.log('Resolved correct answer index: $resolvedIndex');
    } else {
      dev.log('Failed to resolve correct answer from: $rawCorrectAnswer');
    }
  }

  int? _coerceCorrectAnswerIndex(dynamic raw, List<String> options) {
    if (raw == null) return null;

    if (raw is int) {
      return raw;
    }

    if (raw is double) {
      if (raw.isFinite) {
        final rounded = raw.round();
        if ((raw - rounded).abs() < 1e-9) {
          return rounded;
        }
      }
      return null;
    }

    if (raw is num) {
      return raw.toInt();
    }

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;

      final parsedInt = int.tryParse(trimmed);
      if (parsedInt != null) {
        return parsedInt;
      }

      final optionsCount = options.length;
      final containsOptionKeyword = RegExp(
        r'(option|choice)',
        caseSensitive: false,
      ).hasMatch(trimmed);

      final digitMatch = RegExp(r'(\d+)').firstMatch(trimmed);
      if (digitMatch != null) {
        final number = int.parse(digitMatch.group(1)!);
        if (optionsCount > 0) {
          if (containsOptionKeyword) {
            final zeroBased = number - 1;
            if (_isIndexInRange(zeroBased, optionsCount)) {
              return zeroBased;
            }
          }
          if (_isIndexInRange(number, optionsCount)) {
            return number;
          }
          final zeroBased = number - 1;
          if (_isIndexInRange(zeroBased, optionsCount)) {
            return zeroBased;
          }
          return null;
        }
        return number;
      }

      final letterMatch = RegExp(
        r'(?:option|choice)?\s*([A-Za-z])',
      ).firstMatch(trimmed.toLowerCase());
      if (letterMatch != null) {
        final letter = letterMatch.group(1)!.toUpperCase();
        final index = letter.codeUnitAt(0) - 'A'.codeUnitAt(0);
        if (_isIndexInRange(index, optionsCount)) {
          return index;
        }
      }

      if (optionsCount > 0) {
        final normalizedCandidate = _normalizeForComparison(trimmed);
        if (normalizedCandidate.isNotEmpty) {
          for (var i = 0; i < optionsCount; i++) {
            final optionNormalized = _normalizeForComparison(options[i]);
            if (optionNormalized == normalizedCandidate) {
              return i;
            }
          }
        }
      }

      return null;
    }

    return null;
  }

  bool _isIndexInRange(int value, int length) {
    return value >= 0 && value < length;
  }

  String _normalizeForComparison(String value) {
    var normalized = value.toLowerCase();
    normalized = normalized.replaceAll('\\\$', '');
    normalized = normalized.replaceAll('\\', '');
    normalized = normalized.replaceAll(RegExp(r'\s+'), '');
    normalized = normalized.replaceAll(
      RegExp(r'''[{}\[\]\(\),.;:"'`~!@#%&*+\-=<>?/|\$]'''),
      '',
    );
    return normalized;
  }

  void _validateGapFillQuestionFormat(Map<String, dynamic> data) {
    final requiredKeys = [
      'course_name',
      'topic',
      'difficulty',
      'prompt',
      'answers',
      'explanation',
      'options',
    ];
    for (final key in requiredKeys) {
      if (!data.containsKey(key)) {
        throw QuestionGenerationException(
          'Missing key in gap fill question JSON: $key',
        );
      }
    }

    // Validate that options is a list
    if (data['options'] == null || data['options'] is! List) {
      throw QuestionGenerationException('Options must be a list');
    }

    final options = data['options'] as List;
    final answers = (data['answers'] as List?) ?? <dynamic>[];
    // Ensure options are at least as many as answers; no strict upper bound
    if (options.length < answers.length) {
      throw QuestionGenerationException(
        'Options must contain at least all answers',
      );
    }

    // Validate that all answers are included in the options (case-insensitive)
    final optionsLower =
        options.map((e) => e.toString().trim().toLowerCase()).toSet();
    for (final answer in answers) {
      if (!optionsLower.contains(answer.toString().trim().toLowerCase())) {
        throw QuestionGenerationException(
          'All answers must be included in the options list',
        );
      }
    }
  }

  void _validateQuestionFormat(Map<String, dynamic> data) {
    final requiredKeys = [
      'course_name',
      'topic',
      'difficulty',
      'question',
      'options',
      'explanation',
    ];

    // Check for required keys
    for (final key in requiredKeys) {
      if (!data.containsKey(key)) {
        throw QuestionGenerationException('Missing key in question JSON: $key');
      }
    }

    final hasCorrectAnswerField = [
      'correct_answer',
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
    ].any(data.containsKey);

    if (!hasCorrectAnswerField) {
      throw QuestionGenerationException(
        'Missing correct answer field in question JSON',
      );
    }

    // Check for correct answer in different possible formats
    // Validate options is a list and has at least 2 options
    if (data['options'] == null ||
        data['options'] is! List ||
        (data['options'] as List).length < 2) {
      throw QuestionGenerationException(
        'Options must be a list with at least 2 items',
      );
    }

    _normalizeCorrectAnswerField(data);

    if (!data.containsKey('correct_answer')) {
      throw QuestionGenerationException(
        'Missing correct answer field in question JSON',
      );
    }

    // Validate correct answer is within range
    final optionsLength = (data['options'] as List).length;
    final correctAnswer = data['correct_answer'];

    if (correctAnswer is int) {
      if (!_isIndexInRange(correctAnswer, optionsLength)) {
        throw QuestionGenerationException(
          'Invalid correct answer format or out of range',
        );
      }
      return;
    }

    if (correctAnswer is double) {
      final rounded = correctAnswer.round();
      if ((correctAnswer - rounded).abs() < 1e-9 &&
          _isIndexInRange(rounded, optionsLength)) {
        data['correct_answer'] = rounded;
        return;
      }
    }

    if (correctAnswer is String) {
      final parsed = int.tryParse(correctAnswer.trim());
      if (parsed != null && _isIndexInRange(parsed, optionsLength)) {
        data['correct_answer'] = parsed;
        return;
      }
    }

    throw QuestionGenerationException(
      'Invalid correct answer format or out of range',
    );
  }
}
