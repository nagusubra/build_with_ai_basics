import 'package:flutter/material.dart';

import '../../models/chat_match.dart';
import '../../models/message.dart';
import '../../services/chat_service.dart';
import '../../theme/colors.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/mascot.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chat,
    required this.matchId,
    required this.myUid,
    required this.otherName,
  });

  final ChatService chat;
  final String matchId;
  final String myUid;
  final String otherName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await widget.chat.send(widget.matchId, widget.myUid, text);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  MascotPose _cherryPose(ChatMatch? match) =>
      match?.cherryFor[widget.myUid] == 'girl' ? MascotPose.girlHello : MascotPose.boyHello;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatMatch?>(
      stream: widget.chat.match(widget.matchId),
      builder: (context, matchSnap) {
        final match = matchSnap.data;
        return Scaffold(
          appBar: AppBar(title: Text(widget.otherName)),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<ChatMessage>>(
                    stream: widget.chat.messages(widget.matchId),
                    builder: (context, snap) {
                      final messages = snap.data ?? const <ChatMessage>[];
                      if (messages.isEmpty) {
                        return Center(
                          child: Text(
                            'Say hello to ${widget.otherName} 👋',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: BakeColors.muted),
                          ),
                        );
                      }
                      _scrollToEnd();
                      return ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        itemCount: messages.length,
                        itemBuilder: (context, i) => ChatBubble(
                          message: messages[i],
                          mine: messages[i].sender == widget.myUid,
                          cherryPose: _cherryPose(match),
                        ),
                      );
                    },
                  ),
                ),
                _Composer(controller: _input, onSend: _send),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: BakeColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('chat-input'),
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Message',
                filled: true,
                fillColor: BakeColors.warmCream,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            key: const Key('chat-send'),
            onPressed: onSend,
            style: IconButton.styleFrom(backgroundColor: BakeColors.cherryRed),
            icon: const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
