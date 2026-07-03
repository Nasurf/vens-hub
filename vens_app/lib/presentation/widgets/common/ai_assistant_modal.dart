// AI assistant modal: chat overlay for study help
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vens_hub/core/services/ai/gemini_client.dart';
import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/core/Brain/latex_support.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';

class AIAssistantModal extends StatefulWidget {
  final String? context;
  final String? initialQuestion;

  const AIAssistantModal({super.key, this.context, this.initialQuestion});

  @override
  State<AIAssistantModal> createState() => _AIAssistantModalState();
}

class _AIAssistantModalState extends State<AIAssistantModal> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocus = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late final GeminiService _aiService;

  @override
  void initState() {
    super.initState();
    _aiService = di.sl<GeminiService>();

    if (widget.context != null) {
      _messages.add(
        ChatMessage(
          text: "Context: ${widget.context}",
          isUser: false,
          isContext: true,
        ),
      );
    }

    if (widget.initialQuestion != null) {
      _questionController.text = widget.initialQuestion!;
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    _textFieldFocus.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: question, isUser: true));
      _isLoading = true;
    });

    _questionController.clear();
    _scrollToBottom();

    try {
      final prompt = _buildPrompt(question);
      final response = await _aiService.sendMessage(prompt);

      if (response.isNotEmpty && response.first.containsKey('answer')) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: response.first['answer'] ?? 'No response received',
              isUser: false,
            ),
          );
        });
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Sorry, I encountered an error: ${e.toString()}',
            isUser: false,
            isError: true,
          ),
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  String _buildPrompt(String question) {
    final contextPart =
        widget.context != null ? "Context: ${widget.context}\n\n" : "";

    return '''${contextPart}Question: $question

Please provide a helpful, clear answer. Format your response as JSON:
[{"answer": "your detailed answer here"}]

Make sure to:
- Explain concepts clearly
- Use examples when helpful
- Format mathematical expressions properly
- Be concise but thorough''';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('AI Assistant'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _messages.clear();
                  if (widget.context != null) {
                    _messages.add(
                      ChatMessage(
                        text: "Context: ${widget.context}",
                        isUser: false,
                        isContext: true,
                      ),
                    );
                  }
                });
              },
            ),
          ],
        ),
        body: Column(
          children: [Expanded(child: _buildChatArea()), _buildInputArea()],
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return _buildLoadingMessage();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  message.isContext
                      ? theme.colorScheme.secondary
                      : message.isError
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
              child: Icon(
                message.isContext
                    ? Icons.info_outline
                    : message.isError
                    ? Icons.error_outline
                    : Icons.smart_toy,
                size: 16,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    message.isUser
                        ? theme.colorScheme.primary
                        : message.isContext
                        ? theme.colorScheme.secondary.withValues(alpha: 0.1)
                        : message.isError
                        ? theme.colorScheme.error.withValues(alpha: 0.1)
                        : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FormattedMathText(
                    content: message.text,
                    textStyle: TextStyle(
                      color:
                          message.isUser
                              ? theme.colorScheme.onPrimary
                              : message.isError
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (!message.isUser && !message.isContext) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: message.text),
                            );
                            AppNotifier.success(
                              context: context,
                              message: 'Copied to clipboard',
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary,
              child: Icon(
                Icons.person,
                size: 16,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingMessage() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primary,
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'AI is thinking...',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: TextField(
                  controller: _questionController,
                  focusNode: _textFieldFocus,
                  decoration: const InputDecoration(
                    hintText: 'Ask me anything...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  enabled: !_isLoading,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color:
                    _isLoading
                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                        : theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon:
                    _isLoading
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                        : Icon(Icons.send, color: theme.colorScheme.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isContext;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isContext = false,
    this.isError = false,
  });
}

// Standardized AI Assistant Button Widget
class AIAssistantButton extends StatelessWidget {
  final String? context;
  final String? initialQuestion;
  final IconData? icon;
  final String? tooltip;

  const AIAssistantButton({
    super.key,
    this.context,
    this.initialQuestion,
    this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon ?? Icons.smart_toy_outlined),
      tooltip: tooltip ?? 'AI Assistant',
      onPressed: () {
        showDialog(
          context: context,
          builder:
              (context) => AIAssistantModal(
                context: this.context,
                initialQuestion: initialQuestion,
              ),
        );
      },
    );
  }
}
