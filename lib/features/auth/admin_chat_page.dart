import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../services/chat_service.dart';
import '../../services/supabase_service.dart';
import '../chat/chat_thread_page.dart';

class AdminChatPage extends StatefulWidget {
  const AdminChatPage({super.key});

  @override
  State<AdminChatPage> createState() => _AdminChatPageState();
}

class _AdminChatPageState extends State<AdminChatPage> {
  final Logger _logger = Logger();
  bool _isLoading = true;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _initializeAdminChat();
  }

  Future<void> _initializeAdminChat() async {
    setState(() => _isLoading = true);
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) {
        _logger.e('No user authenticated');
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // Get or create admin conversation
      final conversation = await ChatService.instance
          .getOrCreateAdminConversation(user.id);

      setState(() {
        _conversationId = conversation.id;
        _isLoading = false;
      });

      // Navigate to the chat thread page
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatThreadPage(conversationId: conversation.id),
          ),
        );
      }
    } catch (e) {
      _logger.e('Failed to initialize admin chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open support chat: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Chat'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading support chat...'),
                ],
              ),
            )
          : const Center(child: Text('Redirecting to chat...')),
    );
  }
}
