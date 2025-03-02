import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:markdown/markdown.dart' as md show Element;
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LeetCode Chat Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        cardColor: const Color(0xFF1E1E1E),
        primaryColor: const Color.fromARGB(255, 91, 133, 195),
        primaryColorDark: const Color(0xFF1E1E1E),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: Color(0xFF6B7280)),
        ),
      ),
      home: const LeetCodeChatPage(),
    );
  }
}

class Message {
  final String content;
  final bool isUser;

  Message({required this.content, required this.isUser});
}

class LeetCodeChatPage extends StatefulWidget {
  const LeetCodeChatPage({super.key});

  @override
  State<LeetCodeChatPage> createState() => _LeetCodeChatPageState();
}

class _LeetCodeChatPageState extends State<LeetCodeChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  late final ChatSession _chatSession;

  @override
  void initState() {
    super.initState();
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.text(
        'You are a LeetCode expert. Analyze problems and answer coding questions. '
        'Provide detailed explanations, code samples, and complexity analysis. '
        'Format code with markdown and write code C++. Keep responses clear and structured.',
      ),
    );
    _chatSession = model.startChat();
  }

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add(Message(content: message, isUser: true));
      _isLoading = true;
    });

    try {
      final response = await _chatSession.sendMessage(Content.text(message));
      setState(() {
        _messages.add(Message(content: response.text ?? "", isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages
            .add(Message(content: "Error: ${e.toString()}", isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('LeetCode AI Helper'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ChatBubble(
                  message: message.content,
                  isUser: message.isUser,
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Type your question or problem URL...',
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;

  const ChatBubble({super.key, required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).primaryColorDark
                    : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(0),
                  bottomRight: isUser
                      ? const Radius.circular(0)
                      : const Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: MarkdownBody(
                data: message,
                selectable: true,
                styleSheet:
                    MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFFE5E7EB),
                      fontSize: 16),
                  h1: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFFE5E7EB),
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                  h2: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFFE5E7EB),
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  h3: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFFE5E7EB),
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  listBullet: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFFE5E7EB)),
                  blockquote: TextStyle(
                      color: isUser ? Colors.white70 : const Color(0xFFABADB0),
                      fontStyle: FontStyle.italic),
                  code: TextStyle(
                    color: isUser ? Colors.white : const Color(0xFFE5E7EB),
                    fontFamily: 'monospace',
                  ),
                  textScaleFactor: 1.0,
                  blockSpacing: 8,
                ),
                builders: {
                  'code': CustomInlineCodeBuilder(isUser: isUser),
                  'pre': CodeBlockBuilder(isUser: isUser),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CodeBlockBuilder extends MarkdownElementBuilder {
  final bool isUser;

  CodeBlockBuilder({required this.isUser});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    String language = '';
    String code = element.textContent;

    if (element.attributes['class'] != null) {
      String languageClass = element.attributes['class']!;
      if (languageClass.startsWith('language-')) {
        language = languageClass.substring(9);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: isUser ? const Color(0x403B82F6) : const Color(0xFF262626),
            borderRadius: BorderRadius.circular(8),
          ),
          width: double.infinity,
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (language.isNotEmpty)
                Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      language.toUpperCase(),
                      style: TextStyle(
                        color:
                            isUser ? Colors.white70 : const Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )),
              HighlightView(
                code,
                language: language.isNotEmpty ? language : 'plaintext',
                theme: atomOneDarkTheme,
                padding: const EdgeInsets.all(12),
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomInlineCodeBuilder extends MarkdownElementBuilder {
  final bool isUser;

  CustomInlineCodeBuilder({required this.isUser});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Text(
      element.textContent,
      style: TextStyle(
        color: isUser ? Colors.white : const Color(0xFFE5E7EB),
        fontFamily: 'monospace',
      ),
    );
  }
}
