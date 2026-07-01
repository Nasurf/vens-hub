import 'dart:convert';
import 'dart:developer';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:vens_hub/core/error/exceptions.dart'; // For AIServiceException
import 'package:firebase_performance/firebase_performance.dart';
import 'package:vens_hub/core/services/performance/performance_service.dart';
import 'package:vens_hub/core/services/analytics/analytics_service.dart';
import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/core/utils/app_logger.dart';

/// Class representing a single multiple choice question
class MultipleChoiceQuestion {
  final String question;
  final List<String> options;
  final int answerIndex;
  final String explanation;

  MultipleChoiceQuestion({
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.explanation,
  });

  /// Convert question to a map for JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'answerIndex': answerIndex,
      'explanation': explanation,
    };
  }

  /// Create a question from JSON map
  factory MultipleChoiceQuestion.fromJson(Map<String, dynamic> json) {
    return MultipleChoiceQuestion(
      question: json['question'],
      options: List<String>.from(json['options']),
      answerIndex: json['answerIndex'],
      explanation: json['explanation'],
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Question: $question');
    buffer.writeln('Options:');
    for (int i = 0; i < options.length; i++) {
      buffer.writeln('${String.fromCharCode(65 + i)}. ${options[i]}');
    }
    buffer.writeln('Answer: ${String.fromCharCode(65 + answerIndex)}');
    buffer.writeln('Explanation: $explanation');
    return buffer.toString();
  }
}

/// Enum representing question difficulty levels
enum QuestionDifficulty { easy, medium, hard, expert }

/// Class for generating multiple choice questions using OpenAI API
class MultipleChoiceGenerator {
  final OpenAIService _openAiService;

  MultipleChoiceGenerator({required OpenAIService openAiService})
    : _openAiService = openAiService;

  /// Generate a specified number of multiple choice questions
  Future<List<MultipleChoiceQuestion>> generateQuestions({
    required String topic,
    required String course,
    required QuestionDifficulty difficulty,
    required int questionCount,
    int optionCount = 4,
  }) async {
    if (questionCount <= 0) {
      throw ArgumentError('Question count must be greater than zero');
    }

    if (optionCount < 2 || optionCount > 6) {
      throw ArgumentError('Option count must be between 2 and 6');
    }

    final prompt = _buildPrompt(
      topic: topic,
      course: course,
      difficulty: difficulty,
      questionCount: questionCount,
      optionCount: optionCount,
    );

    final messages = [
      {'role': 'system', 'content': _getSystemPrompt()},
      {'role': 'user', 'content': prompt},
    ];

    try {
      final response = await _openAiService.createChatCompletion(
        messages: messages,
        temperature: 0.7,
        model: 'gpt-4o-mini', // Use appropriate model based on your needs
        maxTokens: 2000,
      );

      final content = response['choices'][0]['message']['content'];
      return _parseQuestionsFromResponse(content);
    } catch (e) {
      throw Exception('Failed to generate questions: $e');
    }
  }

  /// Build the prompt for the AI to generate questions
  String _buildPrompt({
    required String topic,
    required String course,
    required QuestionDifficulty difficulty,
    required int questionCount,
    required int optionCount,
  }) {
    return '''
    Generate $questionCount multiple-choice questions about "$topic" for a $course course.
    Difficulty level: ${difficulty.name}.
    Each question should have $optionCount options.
    For each question, provide:
    1. The question text
    2. $optionCount possible answer options
    3. The index of the correct answer (0-based)
    4. A detailed explanation of why the answer is correct
    
    Return the questions in a JSON array format as specified in the system message.
    ''';
  }

  /// Get the system prompt that instructs the AI on output format
  String _getSystemPrompt() {
    return '''
    You are an expert question generator for educational assessments.
    Generate multiple-choice questions in the following JSON format:
    
    [
      {
        "question": "Question text goes here?",
        "options": ["Option A", "Option B", "Option C", "Option D"],
        "answerIndex": 0,
        "explanation": "Detailed explanation of why Option A is correct"
      },
      ...more questions...
    ]
    
    Ensure each question is factually accurate, clear, and appropriate for the specified difficulty level.
    The options should include only one correct answer and plausible distractors.
    The explanation should be thorough and educational.
    Return ONLY the JSON array with no additional text.
    ''';
  }

  /// Parse the AI response into a list of MultipleChoiceQuestion objects
  List<MultipleChoiceQuestion> _parseQuestionsFromResponse(String response) {
    try {
      // Extract JSON if wrapped in other text
      final jsonPattern = RegExp(r'\[[\s\S]*\]');
      final match = jsonPattern.firstMatch(response);
      final jsonStr = match != null ? match.group(0) : response;

      final List<dynamic> parsedJson = jsonDecode(jsonStr!);
      return parsedJson
          .map((json) => MultipleChoiceQuestion.fromJson(json))
          .toList();
    } catch (e) {
      throw FormatException(
        'Failed to parse response: $e\n\nResponse was: $response',
      );
    }
  }
}

/// OpenAI service class from previous code
class OpenAIService {
  late final String apiKey;
  final String baseUrl;

  OpenAIService({String? apiKey, this.baseUrl = 'https://api.openai.com/v1'}) {
    if (apiKey != null && apiKey.isNotEmpty) {
      this.apiKey = apiKey;
    } else {
      final envApiKey = dotenv.env['OPENAI_API_KEY'];
      if (envApiKey == null || envApiKey.isEmpty) {
        log(
          "AI Error: No OPENAI_API_KEY found in constructor or env variables",
        );
        throw AIServiceException(
          message:
              "No OpenAI API Key found. Please provide it in the constructor or set the OPENAI_API_KEY env variable.",
        );
      }
      this.apiKey = envApiKey;
    }
    final maskedKey =
        this.apiKey.length > 8
            ? "${this.apiKey.substring(0, 4)}...${this.apiKey.substring(this.apiKey.length - 4)}"
            : "***";
    log("Initializing OpenAI API with key: $maskedKey");
  }

  /// Creates the headers needed for OpenAI API requests
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
  }

  /// Generates a chat completion using OpenAI API
  Future<Map<String, dynamic>> createChatCompletion({
    required List<Map<String, String>> messages,
    String model = 'gpt-4o-mini',
    double temperature = 0.7,
    int maxTokens = 1000,
  }) async {
    final performanceService =
        di.sl.isRegistered<PerformanceService>()
            ? di.sl<PerformanceService>()
            : null;
    final analyticsService = di.sl<AnalyticsService>();

    final url = '$baseUrl/chat/completions';
    final httpMetric = performanceService?.newHttpMetric(url, HttpMethod.Post);

    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    // Start monitoring
    httpMetric?.start();
    if (httpMetric != null) {
      httpMetric.requestPayloadSize = body.length;
      httpMetric.putAttribute('model', model);
      httpMetric.putAttribute('message_count', messages.length.toString());
      httpMetric.putAttribute('temperature', temperature.toString());
    }

    final startTime = DateTime.now();

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: _getHeaders(),
        body: body,
      );

      final duration = DateTime.now().difference(startTime);

      // Set HTTP metric data
      if (httpMetric != null) {
        httpMetric.httpResponseCode = response.statusCode;
        httpMetric.responsePayloadSize = response.body.length;
        httpMetric.putAttribute(
          'response_length',
          response.body.length.toString(),
        );
      }

      if (response.statusCode == 200) {
        httpMetric?.putAttribute('success', 'true');

        // Log analytics for successful API call
        await analyticsService.logPerformanceMetric(
          metricName: 'openai_api_call',
          value: duration.inMilliseconds,
          unit: 'ms',
          tags: {
            'model': model,
            'message_count': messages.length,
            'response_size': response.body.length,
            'success': true,
          },
        );

        await analyticsService.logFeatureUsage(
          featureName: 'openai_chat_completion',
          outcome: 'success',
          metadata: {
            'model': model,
            'duration_ms': duration.inMilliseconds,
            'response_size': response.body.length,
          },
        );

        return jsonDecode(response.body);
      } else {
        httpMetric?.putAttribute('success', 'false');
        httpMetric?.putAttribute('error_code', response.statusCode.toString());

        // Log analytics for failed API call
        await analyticsService.logPerformanceMetric(
          metricName: 'openai_api_call_failed',
          value: duration.inMilliseconds,
          unit: 'ms',
          tags: {
            'model': model,
            'status_code': response.statusCode,
            'error_type': 'http_error',
          },
        );

        await analyticsService.logError(
          'OpenAI API call failed',
          error: 'HTTP ${response.statusCode}: ${response.body}',
          fatal: false,
        );

        throw Exception('Failed to generate chat completion: ${response.body}');
      }
    } catch (e) {
      final duration = DateTime.now().difference(startTime);

      httpMetric?.putAttribute('success', 'false');
      httpMetric?.putAttribute('error_type', e.runtimeType.toString());

      // Log analytics for exception
      await analyticsService.logPerformanceMetric(
        metricName: 'openai_api_call_exception',
        value: duration.inMilliseconds,
        unit: 'ms',
        tags: {'model': model, 'error_type': e.runtimeType.toString()},
      );

      await analyticsService.logError(
        'OpenAI API connection error',
        error: e,
        fatal: false,
      );

      throw Exception('Error connecting to OpenAI API: $e');
    } finally {
      httpMetric?.stop();
    }
  }
}

// Example usage
void main() async {
  // Initialize the OpenAI service
  // The API key will be loaded from the .env file (OPENAI_API_KEY)
  // Ensure your .env file is set up with OPENAI_API_KEY=your_actual_key
  await dotenv.load(fileName: ".env"); // Load .env file
  final openAiService = OpenAIService();

  // Initialize the question generator
  final questionGenerator = MultipleChoiceGenerator(
    openAiService: openAiService,
  );

  try {
    // Generate questions
    final questions = await questionGenerator.generateQuestions(
      topic: 'Dc Electric Machines',
      course: 'Diploma in Electrical Engineering',
      difficulty: QuestionDifficulty.expert,
      questionCount: 10,
      optionCount: 4,
    );

    // Print the generated questions
    for (int i = 0; i < questions.length; i++) {
      AppLogger.i('Question ${i + 1}:\n');
      AppLogger.i(questions[i]);
      AppLogger.i('-----------------------------------\n');
    }

    // Save questions to a JSON file if needed
    // File('questions.json').writeAsString(jsonEncode(questions.map((q) => q.toJson()).toList()));
  } catch (e) {
    AppLogger.e('Error generating questions', error: e);
  }
}
