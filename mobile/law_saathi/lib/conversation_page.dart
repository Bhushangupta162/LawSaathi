import 'package:flutter/material.dart';
import 'conversation_api_helper.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  late String _greeting;

  // Define our color scheme constants
  static const Color primaryGreen = Color(0xff235543);
  static const Color lightGreen =
      Color(0xff75e4bb); // Light green for AI messages
  static const Color backgroundGreen =
      Color(0xfff0f8f5); // Very light green for app background

  @override
  void initState() {
    super.initState();
    _updateGreeting();
  }

  void _updateGreeting() {
    final currentTime = DateTime.now().hour;
    if (currentTime < 12) {
      _greeting = 'Good Morning';
    } else if (currentTime < 17) {
      _greeting = 'Good Afternoon';
    } else {
      _greeting = 'Good Evening';
    }
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

  void _sendMessage() async {
    String userInput = _controller.text;
    if (userInput.trim().isEmpty) {
      return;
    }

    setState(() {
      messages.add({"text": userInput, "isUser": true});
      _controller.clear();
      _isLoading = true;
    });

    // Scroll to bottom after adding message
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      String result = await ConversationApiHelper.sendMessage(userInput);
      setState(() {
        messages.add({"text": result, "isUser": false});
        _isLoading = false;
      });

      // Scroll to bottom after receiving response
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      setState(() {
        messages.add({
          "text": "Failed to connect to the Gemini API: $e",
          "isUser": false
        });
        _isLoading = false;
      });

      // Show an error snackbar
      _showCustomSnackBar("Connection error. Please try again.", isError: true);
    }
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: isError ? Colors.redAccent : primaryGreen,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGreen,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        toolbarHeight: 120,
        title: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _greeting,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const Text(
                    'Daksh!',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryGreen, width: 2),
                  color: Colors.white,
                ),
                child: const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 24,
                  child: Icon(
                    Icons.person,
                    size: 36,
                    color: primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: primaryGreen, size: 28),
              tooltip: 'Reset conversation',
              onPressed: () {
                ConversationApiHelper.clearConversation();
                setState(() {
                  messages.clear();
                });
                _showCustomSnackBar('Conversation reset successfully');
              },
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
          child: Column(
            children: <Widget>[
              Expanded(
                child: messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return _buildMessageTile(
                            message['text'],
                            message['isUser'],
                            isFirst: index == 0,
                            isLast: index == messages.length - 1,
                          );
                        },
                      ),
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: lightGreen.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primaryGreen,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              "Thinking...",
                              style: TextStyle(
                                color: primaryGreen,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 70,
            color: primaryGreen.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          const Text(
            "Start a conversation",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Ask me anything and I'll respond!",
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: primaryGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Send a message...',
                hintStyle: TextStyle(
                  color: Colors.black38,
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: const TextStyle(fontSize: 16),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryGreen,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(String text, bool isUser,
      {bool isFirst = false, bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 8 : 3,
        bottom: isLast ? 8 : 3,
        left: 8,
        right: 8,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(false),
          SizedBox(width: isUser ? 0 : 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isUser ? primaryGreen : lightGreen,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 16 : 4),
                  topRight: Radius.circular(isUser ? 4 : 16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _styledText(text, isUser),
            ),
          ),
          SizedBox(width: isUser ? 8 : 0),
          if (isUser) _buildAvatar(true),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isUser) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser
            ? primaryGreen.withOpacity(0.2)
            : lightGreen.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          isUser ? Icons.person : Icons.smart_toy,
          size: 18,
          color: isUser ? primaryGreen : Colors.black54,
        ),
      ),
    );
  }

  Widget _styledText(String text, bool isUser) {
    final RegExp regex = RegExp(r'\*\*([^*]+)\*\*');
    final TextStyle normalStyle = TextStyle(
      fontSize: 15,
      height: 1.3,
      color: isUser ? Colors.white : Colors.black87,
    );

    final TextStyle boldStyle = TextStyle(
      fontSize: 15,
      height: 1.3,
      fontWeight: FontWeight.bold,
      color: isUser ? Colors.white : Colors.black87,
    );

    final TextStyle headingStyle = TextStyle(
      fontSize: 18,
      height: 1.4,
      fontWeight: FontWeight.bold,
      color: isUser ? Colors.white : primaryGreen,
    );

    List<Widget> children = [];

    while (text.isNotEmpty) {
      if (text.contains('**')) {
        final match = regex.firstMatch(text);
        if (match != null) {
          final beforeMatch = text.substring(0, match.start);
          if (beforeMatch.isNotEmpty) {
            children.add(Text(beforeMatch, style: normalStyle));
          }

          String boldText = match.group(1)!;
          if (boldText.endsWith(':')) {
            // Treat as heading
            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(boldText, style: headingStyle),
              ),
            );
          } else {
            children.add(Text(boldText, style: boldStyle));
          }

          text = text.substring(match.end);
        } else {
          children.add(Text(text, style: normalStyle));
          break;
        }
      } else {
        children.add(Text(text, style: normalStyle));
        break;
      }
    }

    return Wrap(
      alignment: isUser ? WrapAlignment.end : WrapAlignment.start,
      children: children,
    );
  }
}
