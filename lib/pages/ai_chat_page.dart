import 'package:flutter/material.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/widgets/ui/button.dart' as ui;
import 'package:flutter_animate/flutter_animate.dart';
import '../services/http_chat_service.dart';

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  Message({required this.text, required this.isUser, required this.timestamp});
}

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final List<Message> _messages = [];
  bool _isTyping = false;
  String? _error;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _messages.add(
      Message(
        text:
            "Hi! I'm Model Day AI, your personal modeling career assistant. I can help you analyze your Model Day data, provide insights about your jobs, events, and agents, calculate earnings, and answer any questions about your modeling career data. What would you like to know?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );

    // Listen to text changes
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        Message(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _messageController.clear();
      _isTyping = true;
      _error = null;
    });

    _scrollToBottom();

    try {
      // Get AI response from backend API
      final aiResponse = await HttpChatService.sendChatMessage(text);

      setState(() {
        _messages.add(
          Message(
            text: aiResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isTyping = false;
      });

      _scrollToBottom();

      // Re-focus the input field
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _inputFocusNode.requestFocus();
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to get AI response: $e';
        _isTyping = false;
      });
    }
  }



  Widget _buildMessageBubble(Message message) {
    final isUser = message.isUser;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive padding based on screen width
        final screenWidth = constraints.maxWidth;
        final horizontalPadding = screenWidth < 600 ? 16.0 : 24.0;
        final bubbleMaxWidth = screenWidth < 600
            ? screenWidth * 0.85
            : screenWidth < 1024
                ? screenWidth * 0.75
                : screenWidth * 0.65;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Row(
                  children: [
                    Container(
                      width: screenWidth < 600 ? 32 : 40,
                      height: screenWidth < 600 ? 32 : 40,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.smart_toy_outlined,
                          size: screenWidth < 600 ? 18 : 24,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (isUser) ...[
                    Flexible(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                        margin: const EdgeInsets.only(left: 56),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: screenWidth < 600 ? 32 : 40,
                      height: screenWidth < 600 ? 32 : 40,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person,
                          size: screenWidth < 600 ? 18 : 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ] else ...[
                    Flexible(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                        margin: const EdgeInsets.only(left: 56),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade600),
                        ),
                        child: Text(
                          message.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    ).animate().fadeIn().slideY(
          begin: 0.1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildTypingIndicator() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final horizontalPadding = screenWidth < 600 ? 16.0 : 24.0;

        return Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.smart_toy_outlined,
                    size: 24,
                    color: Colors.blue,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade600),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDot(),
                    const SizedBox(width: 4),
                    _buildDot(),
                    const SizedBox(width: 4),
                    _buildDot(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ).animate().fadeIn();
  }

  Widget _buildDot() {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        shape: BoxShape.circle,
      ),
    ).animate(onPlay: (controller) => controller.repeat()).scaleXY(
          begin: 0.5,
          end: 1,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: '/ai',
      title: 'Model Day AI Chat',
      child: Stack(
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(0),
                  decoration: BoxDecoration(color: Colors.grey[900]),
                  child: Row(
                    children: [
                      ui.Button(
                        onPressed: () => Navigator.of(context).pushNamed('/'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back,
                              color: Colors.grey[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Back to Dashboard',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.black),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = constraints.maxWidth < 600
                            ? constraints.maxWidth
                            : constraints.maxWidth < 1024
                                ? constraints.maxWidth * 0.9
                                : 1200.0;

                        return Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: _error != null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 64,
                                      color: Colors.red[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Error',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red[700],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _error!,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.only(bottom: 100), // Extra padding for input area
                                itemCount: _messages.length + (_isTyping ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _messages.length) {
                                    return _buildTypingIndicator();
                                  }
                                  return _buildMessageBubble(_messages[index]);
                                },
                              ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  final isSmallScreen = screenWidth < 600;
                  final inputPadding = isSmallScreen ? 12.0 : 16.0;
                  final buttonSize = isSmallScreen ? 44.0 : 48.0;

                  return Container(
                    padding: EdgeInsets.all(inputPadding),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isTyping ? Colors.grey.shade700 : Colors.grey.shade600,
                                  width: 1.5,
                                ),
                              ),
                              child: TextField(
                                controller: _messageController,
                                focusNode: _inputFocusNode,
                                maxLines: 5,
                                minLines: 1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                cursorColor: Colors.blue,
                                cursorWidth: 2.0,
                                showCursor: true,
                                enabled: !_isTyping,
                                decoration: InputDecoration(
                                  hintText: isSmallScreen
                                      ? 'Ask about your modeling data...'
                                      : 'Ask anything about your modeling data...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 16,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: inputPadding,
                                    vertical: 14,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                                onSubmitted: (_) => _isTyping ? null : _sendMessage(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              gradient: (_isTyping || !_hasText)
                                  ? LinearGradient(
                                      colors: [Colors.grey.shade600, Colors.grey.shade700],
                                    )
                                  : LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.blue.shade400,
                                        Colors.blue.shade600
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: (_isTyping || !_hasText)
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Colors.blue.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: (_isTyping || !_hasText)
                                    ? null
                                    : _sendMessage,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: buttonSize,
                                  height: buttonSize,
                                  padding: const EdgeInsets.all(12),
                                  child: _isTyping
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
    );
  }
}
