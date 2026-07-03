import 'dart:convert';
import 'dart:developer';
import 'dart:math' show min;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:vens_hub/core/error/exceptions.dart';
import 'package:vens_hub/core/services/performance/performance_service.dart'; // Import PerformanceService
import 'package:vens_hub/core/di/injection_container.dart'
    as di; // Added for GetIt
import 'package:firebase_performance/firebase_performance.dart'; // Required for Trace type

// Renamed to GeminiService
class GeminiService {
  final String modelType;
  late final GenerativeModel _model;
  late final ChatSession _chat;

  GeminiService({required this.modelType, String? apiKey}) {
    // Added optional apiKey parameter
    try {
      final effectiveApiKey =
          apiKey ??
          dotenv
              .env["GEMINI_API_KEY"]; // Use provided apiKey or fallback to dotenv
      if (effectiveApiKey == null || effectiveApiKey.isEmpty) {
        log("AI Error: No API KEY found or provided");
        throw AIServiceException(
          // Changed to AIServiceException
          message:
              "No Gemini API Key found or provided. Please add GEMINI_API_KEY to your .env file or provide it directly.",
        );
      }

      // Log the first few characters of the API key for debugging
      final maskedKey =
          effectiveApiKey.length > 8
              ? "${effectiveApiKey.substring(0, 4)}...${effectiveApiKey.substring(effectiveApiKey.length - 4)}"
              : "***";
      log("Initializing Gemini API with key: $maskedKey");

      _initializeModel(effectiveApiKey);
    } catch (e) {
      log("Error initializing GeminiService: $e"); // Updated class name in log
      if (e is AIServiceException) {
        rethrow; // To avoid re-wrapping if already our type
      }
      throw AIServiceException(
        message: "Failed to initialize GeminiService",
        underlyingException: e,
      );
    }
  }

  void _initializeModel(String effectiveApiKey) {
    // Parameter name updated
    try {
      _model = GenerativeModel(
        model: modelType,
        apiKey: effectiveApiKey, // Use effectiveApiKey
        generationConfig: GenerationConfig(
          temperature: 0.2,
          topK: 40,
          topP: 0.9,
          maxOutputTokens: 7000,
          responseMimeType: 'application/json',
        ),
      );
      _chat = _model.startChat(history: []);
      log("Successfully initialized Gemini model: $modelType");
    } catch (e) {
      log("Error creating GenerativeModel: $e");
      throw AIServiceException(
        message: "Failed to initialize Gemini model",
        underlyingException: e,
      ); // Changed to AIServiceException
    }
  }

  Future<List<Map<String, dynamic>>> sendMessage(
    String message, {
    bool expectList = true,
  }) async {
    final performanceService =
        di.sl.isRegistered<PerformanceService>()
            ? di.sl<PerformanceService>()
            : null;
    final Trace? trace = performanceService?.newTrace('gemini_send_message');
    await trace?.start();
    trace?.putAttribute('message_length', message.length.toString());
    trace?.putAttribute('model_type', modelType);

    try {
      if (message.isEmpty) {
        throw AIServiceException(message: "Your message is empty");
      }

      final truncatedMessage =
          message.length > 100 ? '${message.substring(0, 100)}...' : message;
      log("Sending message to Gemini API: $truncatedMessage");
      log("Using model: $modelType");

      List<Map<String, dynamic>> result;
      try {
        final content = Content.text(message);
        final response = await _chat.sendMessage(content);

        if (response.text?.isEmpty ?? true) {
          trace?.putAttribute('error', 'empty_response');
          throw AIServiceException(message: "Empty Response From The API");
        }

        log(
          "Received response from Gemini API: ${response.text!.length} characters",
        );
        trace?.putAttribute(
          'response_length',
          response.text!.length.toString(),
        );

        final previewText =
            response.text!.length > 200
                ? "${response.text!.substring(0, 200)}..."
                : response.text!;
        log("Response preview: $previewText");

        try {
          if (expectList) {
            final parsed = jsonDecode(response.text!) as List<dynamic>;
            log(
              "Successfully parsed JSON list with ${parsed.length} items",
            );
            result = List<Map<String, dynamic>>.from(parsed);
          } else {
            final parsed = jsonDecode(response.text!)
                as Map<String, dynamic>;
            log("Successfully parsed single JSON object");
            result = [parsed];
          }
        } on FormatException catch (e) {
          log("JSON parsing error: ${e.toString()}");
          trace?.putAttribute('error', 'json_parsing_format_exception');

          String fixedJson = response.text!;

          if (expectList) {
            final jsonPattern = RegExp(r'\[\s*\{.*\}\s*\]', dotAll: true);
            final match = jsonPattern.firstMatch(fixedJson);
            if (match != null) {
              fixedJson = match.group(0)!;
            } else {
              final truncatedResponse = response.text!.substring(
                0,
                min(300, response.text!.length),
              );
              log("Full response preview: $truncatedResponse...");
              trace?.putAttribute('error', 'json_parsing_no_match');
              throw AIServiceException(
                message: "Invalid JSON Response",
                underlyingException: e,
              );
            }
          } else {
            final jsonPattern = RegExp(r'\{.*\}', dotAll: true);
            final match = jsonPattern.firstMatch(fixedJson);
            if (match != null) {
              fixedJson = match.group(0)!;
            } else {
              final truncatedResponse = response.text!.substring(
                0,
                min(300, response.text!.length),
              );
              trace?.putAttribute('error', 'json_parsing_no_match');
              throw AIServiceException(
                message: "Invalid JSON Response",
                underlyingException: e,
              );
            }
          }

          log("Extracted JSON from response: ${fixedJson.length} characters");
          try {
            if (expectList) {
              final parsed = jsonDecode(fixedJson) as List<dynamic>;
              result = List<Map<String, dynamic>>.from(parsed);
            } else {
              final parsed = jsonDecode(fixedJson)
                  as Map<String, dynamic>;
              result = [parsed];
            }
            log(
              "Successfully parsed extracted JSON with ${result.length} items",
            );
          } catch (e2) {
            log("Failed to parse extracted JSON: $e2");
            trace?.putAttribute('error', 'json_parsing_fixed_failed');
            throw AIServiceException(
              message: "Invalid JSON Response after attempting fix",
              underlyingException: e2,
            );
          }
        }
      } catch (apiError) {
        trace?.putAttribute('error', 'api_call_error');
        if (apiError is AIServiceException) {
          rethrow;
        }
        log("API call error: $apiError");
        throw AIServiceException(
          message: "API call failed",
          underlyingException: apiError,
        );
      }
      await trace?.stop();
      return result;
    } catch (e) {
      trace?.putAttribute('error', 'general_gemini_service_error');
      await trace?.stop();
      if (e is AIServiceException) {
        log("AI Service Exception: ${e.message}");
        rethrow;
      }
      log("Error communicating with Gemini API: $e");
      throw AIServiceException(
        message: "Failed to communicate with Gemini API",
        underlyingException: e,
      );
    }
  }

  Future<void> resetChat() async {
    _chat = _model.startChat(history: []);
  }
}
