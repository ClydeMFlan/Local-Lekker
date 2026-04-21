import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../services/chat_service.dart';
import '../../services/supabase_service.dart';
import '../../models/chat_message.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:shared_preferences/shared_preferences.dart';

class ChatThreadPage extends StatefulWidget {
  final String conversationId;

  const ChatThreadPage({super.key, required this.conversationId});

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  final TextEditingController _controller = TextEditingController();
  final Logger _logger = Logger();
  bool _showEmojiPicker = false;
  bool _isSending = false;
  final Map<String, String> _nameCache = {};
  String? _currentUserId;
  String _threadTitle = 'Chat';

  @override
  void initState() {
    super.initState();
    _currentUserId = SupabaseService.instance.getCurrentUser()?.id;
    _prefetchParticipantNames();
    _loadThreadTitle();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.instance.getCurrentUser();
    return Scaffold(
      appBar: AppBar(
        title: Text(_threadTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete conversation',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ChatService.instance.streamMessages(
                widget.conversationId,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  _logger.e('Stream error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          'Error loading messages:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? [];
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _handleMessagesLoaded(messages);
                });
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet.\nStart the conversation!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = user?.id == msg.senderId;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.12)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nameFor(msg.senderId),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              msg.content,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Read receipt indicator - only for sent messages
                                if (isMe)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      // Green if anyone has read it, blue if not
                                      color: msg.readBy.isNotEmpty
                                          ? Colors.green
                                          : Colors.blue,
                                    ),
                                  ),
                                Text(
                                  _formatTime(msg.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _showEmojiPicker
                              ? Icons.keyboard
                              : Icons.emoji_emotions_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _showEmojiPicker = !_showEmojiPicker;
                          });
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: 'Type a message',
                            border: OutlineInputBorder(),
                          ),
                          onTap: () {
                            if (_showEmojiPicker) {
                              setState(() {
                                _showEmojiPicker = false;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: () async {
                                final text = _controller.text.trim();
                                if (text.isEmpty) return;
                                setState(() {
                                  _isSending = true;
                                });
                                try {
                                  _logger.i('Sending message: "$text"');
                                  await ChatService.instance.sendMessage(
                                    conversationId: widget.conversationId,
                                    content: text,
                                  );
                                  _controller.clear();
                                  _logger.i('Message sent successfully');
                                  await _markConversationRead(DateTime.now());
                                } catch (e) {
                                  _logger.e('Failed to send message: $e');
                                  if (mounted) {
                                    // Extract readable error message
                                    String errorMsg = 'Failed to send message';
                                    if (e.toString().contains(
                                      'row-level security',
                                    )) {
                                      errorMsg =
                                          'Permission denied. Please contact support.';
                                    } else if (e.toString().contains(
                                      'network',
                                    )) {
                                      errorMsg =
                                          'Network error. Check connection.';
                                    } else if (e.toString().contains(
                                      'timeout',
                                    )) {
                                      errorMsg =
                                          'Request timed out. Try again.';
                                    }

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          errorMsg,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isSending = false;
                                    });
                                  }
                                }
                              },
                              icon: const Icon(Icons.send, size: 18),
                              label: const Text('Send'),
                            ),
                    ],
                  ),
                ),
                if (_showEmojiPicker)
                  SizedBox(
                    height: 250,
                    child: EmojiPicker(
                      onEmojiSelected: (category, emoji) {
                        _controller.text += emoji.emoji;
                      },
                      config: Config(
                        height: 256,
                        checkPlatformCompatibility: true,
                        emojiViewConfig: EmojiViewConfig(
                          emojiSizeMax:
                              28 *
                              (foundation.defaultTargetPlatform ==
                                      TargetPlatform.iOS
                                  ? 1.20
                                  : 1.0),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _loadThreadTitle() async {
    if (_currentUserId == null) return;
    try {
      final conversation = await ChatService.instance.fetchConversationById(
        widget.conversationId,
      );
      if (conversation == null) return;

      // Check if this is an admin conversation
      if (conversation.isAdmin) {
        // Check if current user is admin
        final userRole = await SupabaseService.instance.getUserRole(
          userId: _currentUserId!,
        );

        if (userRole?.toLowerCase() == 'admin') {
          // Admin viewing member's support request
          final otherParticipantId = conversation.participantIds.firstWhere(
            (id) => id != _currentUserId,
            orElse: () => '',
          );
          if (otherParticipantId.isEmpty) {
            if (mounted) setState(() => _threadTitle = 'Support Chat');
            return;
          }

          final names = await ChatService.instance.fetchDisplayNames([
            otherParticipantId,
          ]);
          final displayName = names[otherParticipantId] ?? 'Member';
          if (mounted) {
            setState(() {
              _threadTitle = 'Support: $displayName';
            });
          }
        } else {
          // Member/Partner viewing admin support
          if (mounted) {
            setState(() {
              _threadTitle = 'Support Chat';
            });
          }
        }
        return;
      }

      final otherParticipantId = conversation.participantIds.firstWhere(
        (id) => id != _currentUserId,
        orElse: () => '',
      );
      if (otherParticipantId.isEmpty) return;

      // Identify if current user is a trusted partner
      final currentUserBusinessName = await ChatService.instance
          .fetchBusinessNameForUser(_currentUserId!);

      // Always try to show the other participant's business name first
      final otherBusinessName = await ChatService.instance
          .fetchBusinessNameForUser(otherParticipantId);

      if (currentUserBusinessName != null &&
          currentUserBusinessName.isNotEmpty) {
        // Trusted partner view: show business name only, fallback to member name
        final displayName = otherBusinessName;
        if (mounted) {
          setState(() {
            _threadTitle = (displayName != null && displayName.isNotEmpty)
                ? displayName
                : 'Chat';
          });
        }
      } else {
        // Member view: prefer business name, fallback to member name
        if (otherBusinessName != null && otherBusinessName.isNotEmpty) {
          if (mounted) {
            setState(() {
              _threadTitle = otherBusinessName;
            });
          }
        } else {
          final names = await ChatService.instance.fetchDisplayNames([
            otherParticipantId,
          ]);
          final displayName = names[otherParticipantId] ?? 'Chat';
          if (mounted) {
            setState(() {
              _threadTitle = displayName;
            });
          }
        }
      }
    } catch (e) {
      _logger.w('Failed to load thread title: $e');
    }
  }

  Future<void> _prefetchParticipantNames() async {
    final conversation = await ChatService.instance.fetchConversationById(
      widget.conversationId,
    );
    if (conversation == null) return;

    final ids = conversation.participantIds
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return;

    try {
      final names = await ChatService.instance.fetchDisplayNames(ids);
      if (!mounted) return;
      setState(() {
        _nameCache.addAll(names);
      });
    } catch (e) {
      _logger.w('Failed to prefetch participant names: $e');
    }
  }

  Future<void> _handleMessagesLoaded(List messages) async {
    if (messages.isEmpty || _currentUserId == null) return;

    // Mark messages as read
    await ChatService.instance.markMessagesAsRead(
      conversationId: widget.conversationId,
      userId: _currentUserId!,
    );

    // Use the newest message timestamp to mark as read, regardless of order
    final latestCreatedAt = messages
        .whereType<ChatMessage>()
        .map((m) => m.createdAt)
        .fold<DateTime?>(null, (latest, ts) {
          if (latest == null) return ts;
          return ts.isAfter(latest) ? ts : latest;
        });

    if (latestCreatedAt != null) {
      await _markConversationRead(latestCreatedAt);
    }

    final missingIds = messages
        .whereType<ChatMessage>()
        .map((m) => m.senderId)
        .where((id) => !_nameCache.containsKey(id))
        .toSet();

    if (missingIds.isEmpty) return;

    ChatService.instance
        .fetchDisplayNames(missingIds.toList())
        .then((names) {
          if (!mounted) return;
          setState(() {
            _nameCache.addAll(names);
          });
        })
        .catchError((e) {
          _logger.w('Failed to load sender names: $e');
        });
  }

  String _nameFor(String senderId) {
    // Always show the actual name from the name cache
    final name = _nameCache[senderId];
    if (name != null && name.trim().isNotEmpty) {
      return name;
    }
    // Fallback to "You" only if we can't find the name
    if (senderId == _currentUserId) return 'You';
    return 'Unknown user';
  }

  Future<void> _markConversationRead(DateTime seenAt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _prefKey(widget.conversationId),
        seenAt.millisecondsSinceEpoch,
      );
      // Also try to persist to backend for shared unread state
      await ChatService.instance.recordLastRead(widget.conversationId, seenAt);
    } catch (e) {
      _logger.w('Failed to persist last read: $e');
    }
  }

  String _prefKey(String conversationId) => 'chat_last_read_$conversationId';

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text(
          'Are you sure you want to delete this conversation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteConversation();
    }
  }

  Future<void> _deleteConversation() async {
    try {
      await ChatService.instance.deleteConversation(widget.conversationId);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Conversation deleted')));
    } catch (e) {
      _logger.e('Failed to delete conversation: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete conversation')),
      );
    }
  }
}
