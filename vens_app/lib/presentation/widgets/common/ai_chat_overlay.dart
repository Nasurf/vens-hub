import 'dart:math' as math;
import 'dart:ui';

import 'package:vens_hub/core/Brain/latex_support.dart';
import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/core/services/ai/gemini_client.dart';
import 'package:flutter/material.dart';

/// Animated, full-screen chat overlay for AI assistant.
///
/// Integrates the animated overlay design with the existing GeminiService backend
/// and LaTeX rendering support. Use [AiChatOverlay.show] to open.
class AiChatOverlay extends StatefulWidget {
  final String? contextText;
  final String? initialQuestion;

  const AiChatOverlay({super.key, this.contextText, this.initialQuestion});

  static Future<void> show(
    BuildContext context, {
    String? contextText,
    String? initialQuestion,
  }) {
    return showGeneralDialog(
      context: context,
      barrierLabel: 'AI Chat Overlay',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AiChatOverlay(
          contextText: contextText,
          initialQuestion: initialQuestion,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(position: slide, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  State<AiChatOverlay> createState() => _AiChatOverlayState();
}

class _AiChatOverlayState extends State<AiChatOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _color1;
  late final Animation<Color?> _color2;
  late final Animation<Color?> _color3;
  bool _colorsInitialized = false;
  late final GeminiService _aiService;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _aiService = di.sl<GeminiService>();

    if (widget.contextText != null && widget.contextText!.trim().isNotEmpty) {
      _messages.add(
        _ChatMessage(widget.contextText!.trim(), false, isContext: true),
      );
    }
    if (widget.initialQuestion != null &&
        widget.initialQuestion!.trim().isNotEmpty) {
      _textController.text = widget.initialQuestion!.trim();
    }

    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_colorsInitialized) return;
    final scheme = Theme.of(context).colorScheme;
    final c1 = scheme.primaryContainer.withValues(alpha: 0.14);
    final c2 = scheme.secondaryContainer.withValues(alpha: 0.14);
    final c3 = scheme.tertiaryContainer.withValues(alpha: 0.14);

    _color1 = ColorTween(begin: c1, end: c2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.33, curve: Curves.easeInOut),
      ),
    );
    _color2 = ColorTween(begin: c2, end: c3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.33, 0.66, curve: Curves.easeInOut),
      ),
    );
    _color3 = ColorTween(begin: c3, end: c1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.66, 1.0, curve: Curves.easeInOut),
      ),
    );
    _colorsInitialized = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(text, true));
      _isSending = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final prompt = _buildPrompt(text, widget.contextText);
      final response = await _aiService.sendMessage(prompt);
      String answer = 'No response received';
      if (response.isNotEmpty && response.first.containsKey('answer')) {
        answer = response.first['answer']?.toString() ?? answer;
      }
      setState(() {
        _messages.add(_ChatMessage(answer, false));
      });
    } catch (e) {
      setState(() {
        _messages.add(
          _ChatMessage('Sorry, I hit an error: $e', false, isError: true),
        );
      });
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  String _buildPrompt(String question, String? ctx) {
    final contextPart =
        (ctx != null && ctx.trim().isNotEmpty)
            ? 'Context: ${ctx.trim()}\n\n'
            : '';
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
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => _focusNode.unfocus(),
        child: Stack(
          children: [
            // Backdrop blur + dim
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),

            // Subtle animated gradient overlay
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          _color1.value ?? Colors.transparent,
                          _color2.value ?? Colors.transparent,
                          _color3.value ?? Colors.transparent,
                        ],
                        center: Alignment(
                          math.sin(_controller.value * 2 * math.pi) * 0.3,
                          math.cos(_controller.value * 2 * math.pi) * 0.3,
                        ),
                        radius: 2.0,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Main chat UI
            SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'AI Assistant',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18.0),
                          ),
                          child: IconButton(
                            tooltip: 'Close',
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Messages
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        itemCount: _messages.length + (_isSending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isSending && index == _messages.length) {
                            return _buildThinkingBubble(scheme);
                          }
                          final msg = _messages[index];
                          return msg.isUser
                              ? _buildUserMessage(msg.text, scheme)
                              : _buildAiMessage(
                                msg.text,
                                scheme,
                                isContext: msg.isContext,
                                isError: msg.isError,
                              );
                        },
                      ),
                    ),
                  ),

                  // Input
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(22.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.30),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 2.0,
                              ),
                              child: TextField(
                                controller: _textController,
                                focusNode: _focusNode,
                                maxLines: null,
                                minLines: 1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  height: 1.4,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Type your message...',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14.0,
                                  ),
                                ),
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
                                enabled: !_isSending,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20.0),
                                onTap: _isSending ? null : _sendMessage,
                                child: Container(
                                  padding: const EdgeInsets.all(10.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(18.0),
                                  ),
                                  child:
                                      _isSending
                                          ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: scheme.onPrimary,
                                            ),
                                          )
                                          : const Icon(
                                            Icons.arrow_upward,
                                            color: Colors.white,
                                            size: 20.0,
                                          ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiMessage(
    String text,
    ColorScheme scheme, {
    bool isContext = false,
    bool isError = false,
  }) {
    final bg =
        isContext
            ? Colors.white.withValues(alpha: 0.08)
            : isError
            ? scheme.error.withValues(alpha: 0.12)
            : const Color(0xFF2A2A2A).withValues(alpha: 0.95);
    final fg =
        isContext
            ? Colors.white.withValues(alpha: 0.9)
            : isError
            ? scheme.error
            : Colors.white;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0, right: 40.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18.0),
            topRight: Radius.circular(18.0),
            bottomRight: Radius.circular(18.0),
            bottomLeft: Radius.circular(6.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 8.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: FormattedMathText(
          content: text,
          textStyle: TextStyle(color: fg, fontSize: 15.0, height: 1.5),
        ),
      ),
    );
  }

  Widget _buildUserMessage(String text, ColorScheme scheme) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0, left: 40.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18.0),
            topRight: Radius.circular(18.0),
            bottomLeft: Radius.circular(18.0),
            bottomRight: Radius.circular(6.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 8.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: scheme.onPrimary,
            fontSize: 15.0,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildThinkingBubble(ColorScheme scheme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0, right: 40.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18.0),
            topRight: Radius.circular(18.0),
            bottomRight: Radius.circular(18.0),
            bottomLeft: Radius.circular(6.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 8.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Thinking...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isContext;
  final bool isError;
  _ChatMessage(
    this.text,
    this.isUser, {
    this.isContext = false,
    this.isError = false,
  });
}
