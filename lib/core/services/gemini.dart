import 'dart:convert';
import 'dart:developer';
import 'dart:math' show min, max;
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:vens_hub/core/error/exceptions.dart';
import 'package:vens_hub/data/models/question_model.dart';
import 'package:vens_hub/data/models/answer_feedback_model.dart';

// Gemini API client using the public Google Generative AI SDK.
class GeminiApi {
  final String modelType;
  late final String _apiKey;
  late final GenerativeModel _model;
  late final ChatSession _chat;

  GeminiApi({required this.modelType}) {
    try {
      // Use dotenv to access the API key
      final apiKey = dotenv.env["GEMINI_API_KEY"];
      if (apiKey == null || apiKey.isEmpty) {
        log("AI Error: No GEMINI_API_KEY found in env variables");
        throw AIServiceException(
          message:
              "No Gemini API Key found in env variables. Please set the GEMINI_API_KEY env variable.",
        );
      }

      // Log the first few characters of the API key for debugging
      final maskedKey =
          apiKey.length > 8
              ? "${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)}"
              : "***";
      log("Initializing Gemini API with key: $maskedKey");

      _apiKey = apiKey;
      _initializeModel();
    } catch (e) {
      log("Error initializing GeminiApi: $e");
      rethrow;
    }
  }

  void _initializeModel() {
    try {
      _model = GenerativeModel(
        model: modelType,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.3,
          topK: 40,
          topP: 0.9,
          maxOutputTokens: 7000,
          responseMimeType: 'application/json',
        ),
      );
      _chat = _model.startChat();
      log("Successfully initialized Gemini model: $modelType");
    } catch (e) {
      log("Error creating GenerativeModel: $e");
      throw AIServiceException(
        message: "Failed to initialize Gemini model: $e",
      );
    }
  }

  String _sanitiseJson(String input) {
    String cleaned = input;

    // Attempt to extract content from markdown code block first
    final codeBlockRegex = RegExp(
      r'```(?:json|typescript|python|text)?\s*([\s\S]*?)\s*```',
    );
    final match = codeBlockRegex.firstMatch(input);
    if (match != null && match.group(1) != null) {
      cleaned = match.group(1)!;
      log("Extracted content from code block.");
    }

    // 0. Remove Byte Order Mark (BOM) if present
    if (cleaned.startsWith('\uFEFF')) {
      cleaned = cleaned.substring(1);
    }

    // 1. Remove trailing commas before } or ]
    cleaned = cleaned.replaceAllMapped(
      RegExp(r',\s*(\]|\})'),
      (Match m) => m.group(1)!,
    );

    // 2. Only escape backslashes that aren't part of valid JSON escape sequences
    // This regex looks for backslashes that aren't followed by a valid JSON escape character
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(?<!\\)\\(?![\\/"bfnrtu]|u[0-9a-fA-F]{4})'),
      (Match m) => r'\\\\',
    );

    // 2a. Ensure LaTeX commands (e.g. \frac, \underline) stay escaped.
    // Gemini often emits single backslashes before multi-letter commands, which JSON treats as
    // control characters (\n, \t, \u...), leading to parse errors or mangled math. We upgrade any
    // single-backslash sequence followed by >=2 letters to a double-backslash so the decoded JSON
    // still contains the intended LaTeX command.
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(?<!\\)\\([A-Za-z]{2,})'),
      (Match m) => '\\\\${m.group(1)!}',
    );

    // 3. Replace smart quotes
    cleaned = cleaned
        .replaceAll("\u201c", "\"")
        .replaceAll("\u201d", "\"")
        .replaceAll("\u2018", "\"")
        .replaceAll("\u2019", "\"");

    return cleaned.trim();
  }

  Future<List<Map<String, dynamic>>> sendMessage(
    String message, {
    bool expectList = true,
  }) async {
    try {
      if (message.isEmpty) {
        throw AIServiceException(message: "Your message is empty");
      }

      final truncatedMessage =
          message.length > 100 ? '${message.substring(0, 100)}...' : message;
      log("Sending message to Gemini API: $truncatedMessage");
      log("Using model: $modelType");

      final content = Content.text(message);
      final response = await _chat.sendMessage(content);
      final rawResponseText = response.text;

      if (rawResponseText == null || rawResponseText.isEmpty) {
        log("AI Error: Received null or empty response from Gemini API.");
        throw AIServiceException(
          message: "Empty or null response from Gemini API.",
        );
      }

      log(
        "RAW Gemini API Response (${rawResponseText.length} chars):\n$rawResponseText",
      );
      log(
        "Received response from Gemini API: ${rawResponseText.length} characters",
      );

      final previewLength = min(rawResponseText.length, 200);
      final previewText =
          "${rawResponseText.substring(0, previewLength)}${rawResponseText.length > 200 ? "..." : ""}";
      log("Response preview: $previewText");

      try {
        // Attempt to parse the JSON directly
        final jsonData = jsonDecode(rawResponseText);
        log("Successfully parsed JSON response.");

        if (expectList) {
          if (jsonData is List) {
            log("Response is a list with ${jsonData.length} items.");
            return List<Map<String, dynamic>>.from(jsonData);
          } else {
            log(
              "Error: Expected a JSON list, but got ${jsonData.runtimeType}.",
            );
            throw AIServiceException(
              message:
                  "Invalid JSON response format: Expected a List. Received type: ${jsonData.runtimeType}",
            );
          }
        } else {
          if (jsonData is Map<String, dynamic>) {
            log("Response is a single JSON object. Wrapping in a list.");
            return [jsonData];
          } else {
            log(
              "Error: Expected a JSON object, but got ${jsonData.runtimeType}.",
            );
            throw AIServiceException(
              message:
                  "Invalid JSON response format: Expected a Map. Received type: ${jsonData.runtimeType}",
            );
          }
        }
      } on FormatException catch (e) {
        log("Initial JSON parsing error: $e");

        // Check for truncation: "Unterminated string" at/near the end of the input.
        if (e.message.contains("Unterminated string") &&
            e.offset != null &&
            e.offset! >= rawResponseText.length - 2) {
          // -2 to allow for minor off-by-one
          log(
            "Suspected TRUNCATED JSON response from API. Length: ${rawResponseText.length}, Error offset: ${e.offset!}.",
          );
          final lastCharsPreview = rawResponseText.substring(
            max(0, rawResponseText.length - 500),
          );
          log("Raw response (last 500 chars or less): $lastCharsPreview");
          throw AIServiceException(
            message:
                "Truncated JSON response from Gemini API. The response appears to have been cut off. Raw response (last 500 chars): $lastCharsPreview. Error: ${e.toString()}",
          );
        }

        // If not a clear truncation, proceed with sanitization attempt.
        log("Direct parse failed: $e. Attempting sanitisation...");
        final sanitisationPreview = rawResponseText.substring(
          0,
          min(rawResponseText.length, 2000),
        );
        log("Full response preview for sanitisation: $sanitisationPreview");
        try {
          String sanitisedJson = _sanitiseJson(rawResponseText);
          final sanitisedPreview = sanitisedJson.substring(
            0,
            min(sanitisedJson.length, 2000),
          );
          log("Sanitised JSON preview: $sanitisedPreview");
          final jsonData = jsonDecode(sanitisedJson);

          if (expectList) {
            if (jsonData is List) {
              log(
                "Successfully parsed sanitised JSON response with ${jsonData.length} items",
              );
              return List<Map<String, dynamic>>.from(jsonData);
            } else {
              log(
                "Error: Expected a JSON list from sanitised data, but got ${jsonData.runtimeType}.",
              );
              throw AIServiceException(
                message:
                    "Invalid JSON response format: Expected a List after sanitisation. Received type: ${jsonData.runtimeType}",
              );
            }
          } else {
            if (jsonData is Map<String, dynamic>) {
              log(
                "Successfully parsed sanitised single JSON object. Wrapping in a list.",
              );
              return [jsonData];
            } else {
              log(
                "Error: Expected a JSON object from sanitised data, but got ${jsonData.runtimeType}.",
              );
              throw AIServiceException(
                message:
                    "Invalid JSON response format: Expected a Map after sanitisation. Received type: ${jsonData.runtimeType}",
              );
            }
          }
        } catch (e2) {
          log("Failed to parse sanitised JSON: $e2");
          final originalRawPreview = rawResponseText.substring(
            0,
            min(rawResponseText.length, 500),
          );
          log("Original raw (first 500 chars): $originalRawPreview");
          throw AIServiceException(
            message:
                "Invalid JSON Response from Gemini API after sanitisation. Error: ${e2.toString()}. Original raw (first 500 chars): $originalRawPreview. Sanitisation failed to produce valid JSON.",
          );
        }
      }
    } catch (e) {
      if (e is AIServiceException) {
        log("AI Exception: ${e.message}");
        rethrow;
      }
      log("Error communicating with Gemini API: $e");
      throw AIServiceException(
        message: "Failed to communicate with Gemini API: ${e.toString()}",
      );
    }
  }

  Future<void> resetChat() async {
    _chat = _model.startChat();
  }

  /// Attempts to parse the raw JSON coming back from Gemini. It will:
  /// 1. Try direct `jsonDecode`.
  /// 2. If that fails, run `_sanitiseJson` and try again.
  /// 3. If that still fails, extract the first JSON object in the string,
  ///    sanitise it, then try again.
  Map<String, dynamic> _parseFeedbackJson(String raw) {
    // 1) direct attempt
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}

    // 2) sanitise then parse
    try {
      final sanitised = _sanitiseJson(raw);
      return jsonDecode(sanitised) as Map<String, dynamic>;
    } catch (_) {}

    // 3) extract first JSON object, sanitise, parse
    final match = RegExp(r'\{[\s\S]*?\}', dotAll: true).firstMatch(raw);
    if (match != null) {
      try {
        final segmentSanitised = _sanitiseJson(match.group(0)!);
        return jsonDecode(segmentSanitised) as Map<String, dynamic>;
      } catch (_) {}
    }

    throw AIServiceException(
      message: "Invalid JSON response format from evaluation",
    );
  }

  /// Evaluates a student's answer to a theory or calculation question
  /// Returns structured feedback from Gemini AI
  Future<AnswerFeedback> evaluateTheoryAnswer(
    Question question,
    String userAnswer,
  ) async {
    try {
      if (userAnswer.trim().isEmpty) {
        throw AIServiceException(message: "User answer cannot be empty");
      }

      // Construct the evaluation prompt
      final prompt = _buildEvaluationPrompt(question, userAnswer);

      log("Evaluating answer for question: ${question.id}");
      log("User answer length: ${userAnswer.length} characters");

      // Create a new model instance specifically for evaluation
      final evaluationModel = GenerativeModel(
        model: modelType,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.3, // Lower temperature for more consistent evaluation
          topK: 40,
          topP: 0.8,
          maxOutputTokens: 2000,
          responseMimeType: 'application/json',
        ),
      );

      final content = Content.text(prompt);
      final response = await evaluationModel.generateContent([content]);

      if (response.text?.isEmpty ?? true) {
        throw AIServiceException(
          message: "Empty response from Gemini API during evaluation",
        );
      }

      log("Received evaluation response: ${response.text!.length} characters");

      // Parse the JSON response
      late Map<String, dynamic> feedbackJson;
      try {
        feedbackJson = _parseFeedbackJson(response.text!);
      } catch (e) {
        log("Failed to parse evaluation JSON: $e");
        log("Raw response: ${response.text}");
        rethrow;
      }

      // Validate required fields
      if (!feedbackJson.containsKey('rating') ||
          !feedbackJson.containsKey('overall_feedback') ||
          !feedbackJson.containsKey('correct_solution_summary')) {
        throw AIServiceException(
          message: "Incomplete evaluation response - missing required fields",
        );
      }

      // Create and return AnswerFeedback object
      final feedback = AnswerFeedback.fromJson(feedbackJson);
      log("Successfully created feedback with rating: ${feedback.rating}");

      return feedback;
    } catch (e) {
      if (e is AIServiceException) {
        log("AI Exception during evaluation: ${e.message}");
        rethrow;
      }
      log("Error during answer evaluation: $e");
      throw AIServiceException(
        message: "Failed to evaluate answer: ${e.toString()}",
        underlyingException: e.toString(),
      );
    }
  }

  /// Builds the detailed evaluation prompt for Gemini
  String _buildEvaluationPrompt(Question question, String userAnswer) {
    final subjectContext =
        question.subject != null
            ? "You are an expert Tutor, specializing in ${question.subject}"
            : "You are an expert Tutor, specializing in engineering and scientific subjects";

    final questionTypeGuidance =
        question.isCalculationQuestion
            ? "For this calculation problem, check the methodology, the application of formulas, and the final numerical result. Highlight any calculation errors or conceptual errors in applying formulas."
            : "For this theory question, evaluate the clarity of explanation, accuracy of definitions/concepts, and logical consistency.";

    final correctAnswerGuidance =
        question.correctAnswerSummary != null
            ? "The correct answer summary for reference: ${question.correctAnswerSummary}"
            : "";

    final solutionStepsGuidance =
        question.solutionSteps != null && question.solutionSteps!.isNotEmpty
            ? "Expected solution steps for reference: ${question.solutionSteps!.join('; ')}"
            : "";

    return '''$subjectContext. Your task is to evaluate a student's answer to a given question and provide constructive, detailed feedback.

QUESTION:
${question.text}

STUDENT'S ANSWER:
$userAnswer

$questionTypeGuidance
$correctAnswerGuidance
$solutionStepsGuidance

EVALUATION INSTRUCTIONS:
- First decide the rating (Excellent / Good / …) based strictly on accuracy *and* completeness.
- If you choose "Excellent":
  * Populate `strengths` with 1-3 concrete positive points.
  * Leave `areas_for_improvement` empty.
  * Populate `enhancements` with 1-3 optional extra insights the student could mention to enrich an already correct answer (do not frame these as errors).
- If you choose "Good" or "Satisfactory":
  * Provide `strengths`.
  * Provide 1-3 `areas_for_improvement` describing missing or incomplete aspects.
  * You may leave `enhancements` empty.
- If you choose "Needs Improvement" or "Incorrect":
  * `strengths` can have at most one motivational note (optional).
  * `areas_for_improvement` must highlight the key misconceptions and corrections.
  * Leave `enhancements` empty.
- Focus on helping the student learn and improve.

Please provide your evaluation strictly in the following JSON format:
{
  "rating": "[Choose one: Excellent, Good, Satisfactory, Needs Improvement, Incorrect]",
  "overall_feedback": "[Provide a 1-2 sentence general comment on the student's understanding and approach, considering both text and images.]",
  "strengths": ["[Point 1 where student did well (if any)]", "[Point 2...]"],
  "areas_for_improvement": [
    {
      "error_identified": "[Describe the specific part of the student's answer that is incorrect or the misconception.]",
      "explanation": "[Explain why this is incorrect and what the correct concept/method is. Be clear and concise.]",
      "suggested_correction": "[Suggest how the student could correct this part of their answer, or provide the correct step/calculation if applicable.]"
    }
  ],
  "enhancements": ["[For EXCELLENT answers only: optional deeper points or real-world connections the student could add]"] ,
  "correct_solution_summary": "[Provide a brief summary of the correct answer. For calculation problems, show key steps or the final correct numerical answer. For theory, a concise correct explanation.]"
}

Ensure your response is only the JSON object, with no preceding or succeeding text.''';
  }

  /// Evaluates a student's answer with images to a theory or calculation question
  /// Returns structured feedback from Gemini AI
  Future<AnswerFeedback> evaluateTheoryAnswerWithImages(
    Question question,
    String userAnswer,
    List<dynamic> images,
  ) async {
    try {
      if (userAnswer.trim().isEmpty && images.isEmpty) {
        throw AIServiceException(
          message: "User must provide either text answer or images",
        );
      }

      log(
        "Evaluating answer with ${images.length} images for question: ${question.id}",
      );
      log("User answer length: ${userAnswer.length} characters");

      // Create a new model instance specifically for evaluation with images
      final evaluationModel = GenerativeModel(
        model: modelType,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.3, // Lower temperature for more consistent evaluation
          topK: 40,
          topP: 0.8,
          maxOutputTokens: 2000,
          responseMimeType: 'application/json',
        ),
      );

      // Build the prompt with image context
      final prompt = _buildEvaluationPromptWithImages(
        question,
        userAnswer,
        images.length,
      );

      // Create content with text and images
      final contentParts = <Part>[TextPart(prompt)];

      // Add images as data parts (support dynamic items without importing dart:io)
      for (final image in images) {
        try {
          if (image is Uint8List) {
            contentParts.add(DataPart('image/jpeg', image));
          } else {
            final dynamic dyn = image;
            final bytes = await dyn.readAsBytes();
            contentParts.add(DataPart('image/jpeg', bytes as Uint8List));
          }
        } catch (e) {
          // Skip invalid image input
          log('Skipping non-readable image input: $e');
        }
      }

      final content = Content.multi(contentParts);
      final response = await evaluationModel.generateContent([content]);

      if (response.text?.isEmpty ?? true) {
        throw AIServiceException(
          message: "Empty response from Gemini API during evaluation",
        );
      }

      log("Received evaluation response: ${response.text!.length} characters");

      // Parse the JSON response
      late Map<String, dynamic> feedbackJson;
      try {
        feedbackJson = _parseFeedbackJson(response.text!);
      } catch (e) {
        log("Failed to parse evaluation JSON: $e");
        log("Raw response: ${response.text}");
        rethrow;
      }

      // Validate required fields
      if (!feedbackJson.containsKey('rating') ||
          !feedbackJson.containsKey('overall_feedback') ||
          !feedbackJson.containsKey('correct_solution_summary')) {
        throw AIServiceException(
          message: "Incomplete evaluation response - missing required fields",
        );
      }

      // Create and return AnswerFeedback object
      final feedback = AnswerFeedback.fromJson(feedbackJson);
      log("Successfully created feedback with rating: ${feedback.rating}");

      return feedback;
    } catch (e) {
      if (e is AIServiceException) {
        log("AI Exception during evaluation: ${e.message}");
        rethrow;
      }
      log("Error during answer evaluation with images: $e");
      throw AIServiceException(
        message: "Failed to evaluate answer with images: ${e.toString()}",
        underlyingException: e.toString(),
      );
    }
  }

  /// Evaluates a student's answer with image bytes (for web platform)
  /// Returns structured feedback from Gemini AI
  Future<AnswerFeedback> evaluateTheoryAnswerWithImageBytes(
    Question question,
    String userAnswer,
    List<Uint8List> imageBytes,
  ) async {
    try {
      if (userAnswer.trim().isEmpty && imageBytes.isEmpty) {
        throw AIServiceException(
          message: "User must provide either text answer or images",
        );
      }

      log(
        "Evaluating answer with ${imageBytes.length} images (bytes) for question: ${question.id}",
      );
      log("User answer length: ${userAnswer.length} characters");

      // Create a new model instance specifically for evaluation with images
      final evaluationModel = GenerativeModel(
        model: modelType,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.3, // Lower temperature for more consistent evaluation
          topK: 40,
          topP: 0.8,
          maxOutputTokens: 2000,
          responseMimeType: 'application/json',
        ),
      );

      // Build the prompt with image context
      final prompt = _buildEvaluationPromptWithImages(
        question,
        userAnswer,
        imageBytes.length,
      );

      // Create content with text and images
      final contentParts = <Part>[TextPart(prompt)];

      // Add images as data parts
      for (final bytes in imageBytes) {
        contentParts.add(DataPart('image/jpeg', bytes));
      }

      final content = Content.multi(contentParts);
      final response = await evaluationModel.generateContent([content]);

      if (response.text?.isEmpty ?? true) {
        throw AIServiceException(
          message: "Empty response from Gemini API during evaluation",
        );
      }

      log("Received evaluation response: ${response.text!.length} characters");

      // Parse the JSON response
      late Map<String, dynamic> feedbackJson;
      try {
        feedbackJson = _parseFeedbackJson(response.text!);
      } catch (e) {
        log("Failed to parse evaluation JSON: $e");
        log("Raw response: ${response.text}");
        rethrow;
      }

      // Validate required fields
      if (!feedbackJson.containsKey('rating') ||
          !feedbackJson.containsKey('overall_feedback') ||
          !feedbackJson.containsKey('correct_solution_summary')) {
        throw AIServiceException(
          message: "Incomplete evaluation response - missing required fields",
        );
      }

      // Create and return AnswerFeedback object
      final feedback = AnswerFeedback.fromJson(feedbackJson);
      log("Successfully created feedback with rating: ${feedback.rating}");

      return feedback;
    } catch (e) {
      if (e is AIServiceException) {
        log("AI Exception during evaluation: ${e.message}");
        rethrow;
      }
      log("Error during answer evaluation with image bytes: $e");
      throw AIServiceException(
        message: "Failed to evaluate answer with image bytes: ${e.toString()}",
        underlyingException: e.toString(),
      );
    }
  }

  /// Builds the evaluation prompt for answers with images
  String _buildEvaluationPromptWithImages(
    Question question,
    String userAnswer,
    int imageCount,
  ) {
    final subjectContext =
        question.subject != null
            ? "You are an expert AI TuteBot, specializing in ${question.subject}"
            : "You are an expert AI TuteBot, specializing in engineering and scientific subjects";

    final questionTypeGuidance =
        question.isCalculationQuestion
            ? "For this calculation problem, check the methodology, the application of formulas, and the final numerical result. Pay special attention to the work shown in the images. Highlight any calculation errors or conceptual errors in applying formulas."
            : "For this theory question, evaluate the clarity of explanation, accuracy of definitions/concepts, and logical consistency. Consider both the written answer and any diagrams or visual explanations in the images.";

    final correctAnswerGuidance =
        question.correctAnswerSummary != null
            ? "The correct answer summary for reference: ${question.correctAnswerSummary}"
            : "";

    final solutionStepsGuidance =
        question.solutionSteps != null && question.solutionSteps!.isNotEmpty
            ? "Expected solution steps for reference: ${question.solutionSteps!.join('; ')}"
            : "";

    final imageContext =
        imageCount > 0
            ? "\n\nThe student has also provided $imageCount image(s) showing their work. Please analyze these images carefully for:\n- Written calculations or solutions\n- Diagrams or sketches\n- Step-by-step working\n- Any visual representations of concepts"
            : "";

    return '''$subjectContext. Your task is to evaluate a student's answer to a given question and provide constructive, detailed feedback.

QUESTION:
${question.text}

STUDENT'S WRITTEN ANSWER:
${userAnswer.isNotEmpty ? userAnswer : "[No written answer provided - see images]"}
$imageContext

$questionTypeGuidance
$correctAnswerGuidance
$solutionStepsGuidance

EVALUATION INSTRUCTIONS:
- First decide the rating (Excellent / Good / …) based strictly on accuracy *and* completeness.
- If you choose "Excellent":
  * Populate `strengths` with 1-3 concrete positive points.
  * Leave `areas_for_improvement` empty.
  * Populate `enhancements` with 1-3 optional extra insights the student could mention to enrich an already correct answer (do not frame these as errors).
- If you choose "Good" or "Satisfactory":
  * Provide `strengths`.
  * Provide 1-3 `areas_for_improvement` describing missing or incomplete aspects.
  * You may leave `enhancements` empty.
- If you choose "Needs Improvement" or "Incorrect":
  * `strengths` can have at most one motivational note (optional).
  * `areas_for_improvement` must highlight the key misconceptions and corrections.
  * Leave `enhancements` empty.
- Focus on helping the student learn and improve.

Please provide your evaluation strictly in the following JSON format:
{
  "rating": "[Choose one: Excellent, Good, Satisfactory, Needs Improvement, Incorrect]",
  "overall_feedback": "[Provide a 1-2 sentence general comment on the student's understanding and approach, considering both text and images.]",
  "strengths": ["[Point 1 where student did well (if any)]", "[Point 2...]"],
  "areas_for_improvement": [
    {
      "error_identified": "[Describe the specific part of the student's answer (text or image) that is incorrect or the misconception.]",
      "explanation": "[Explain why this is incorrect and what the correct concept/method is. Be clear and concise.]",
      "suggested_correction": "[Suggest how the student could correct this part of their answer, or provide the correct step/calculation if applicable.]"
    }
  ],
  "enhancements": ["[For EXCELLENT answers only: optional deeper points or real-world connections the student could add]"] ,
  "correct_solution_summary": "[Provide a brief summary of the correct answer. For calculation problems, show key steps or the final correct numerical answer. For theory, a concise correct explanation.]"
}

Ensure your response is only the JSON object, with no preceding or succeeding text.''';
  }
}
