import 'package:flutter/material.dart';
import 'package:vens_hub/presentation/widgets/common/ai_assistant_modal.dart';

class AIAssistantHelper {
  /// Show AI assistant modal with optional context and initial question
  static void show(
    BuildContext context, {
    String? contextInfo,
    String? initialQuestion,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AIAssistantModal(
            context: contextInfo,
            initialQuestion: initialQuestion,
          ),
    );
  }

  /// Show AI assistant for study materials
  static void showForStudy(BuildContext context) {
    show(
      context,
      contextInfo:
          "Study Materials - Ask questions about your study materials, concepts, or need help with problems.",
    );
  }

  /// Show AI assistant for quiz help
  static void showForQuiz(BuildContext context, {String? quizContext}) {
    show(
      context,
      contextInfo:
          quizContext ?? "Quiz - Ask for help with quiz questions or concepts.",
    );
  }

  /// Show AI assistant for selected text
  static void showForText(BuildContext context, String selectedText) {
    show(
      context,
      contextInfo: "Selected text: $selectedText",
      initialQuestion: "Can you explain this text?",
    );
  }

  /// Show AI assistant for problem solving
  static void showForProblem(BuildContext context, {String? problemContext}) {
    show(
      context,
      contextInfo:
          problemContext ??
          "Problem Solving - Ask for help with engineering problems or calculations.",
    );
  }
}
