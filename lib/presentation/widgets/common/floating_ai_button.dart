import 'package:flutter/material.dart';
import 'ai_assistant_modal.dart';

class FloatingAIButton extends StatelessWidget {
  final String? context;
  final String? initialQuestion;

  const FloatingAIButton({super.key, this.context, this.initialQuestion});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: "ai_assistant",
      onPressed: () {
        showDialog(
          context: context,
          builder:
              (context) => AIAssistantModal(
                context:
                    this.context ?? "General AI Assistant - Ask me anything!",
                initialQuestion: initialQuestion,
              ),
        );
      },
      child: const Icon(Icons.smart_toy),
    );
  }
}
