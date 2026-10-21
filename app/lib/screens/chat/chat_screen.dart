import 'package:flutter/material.dart';

import '../../models/chat_match.dart';
import '../../models/message.dart';
import '../../services/chat_service.dart';
import '../../services/functions_service.dart';
import '../../theme/colors.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/chat_cards.dart';
import '../../widgets/mascot.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chat,
    required this.functions,
    required this.matchId,
    required this.myUid,
    required this.otherName,
  });

  final ChatService chat;
  final FunctionsService functions;
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

  bool _girlCherry(ChatMatch? match) => match?.cherryFor[widget.myUid] == 'girl';

  MascotPose _cherryPose(ChatMatch? match) => _girlCherry(match) ? MascotPose.girlHello : MascotPose.boyHello;

  Future<void> _confirm(int version) async {
    try {
      await widget.functions.confirmDatePlan(widget.matchId, version);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't confirm just now — please try again.")),
      );
    }
  }

  Widget _messageView(ChatMessage m, ChatMatch? match) {
    final girl = _girlCherry(match);
    final bubble = ChatBubble(message: m, mine: m.sender == widget.myUid, cherryPose: _cherryPose(match));
    switch (m.type) {
      case 'dateCard':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (m.text.isNotEmpty) bubble,
            DateCardView(
              message: m,
              plan: match?.datePlan ?? const DatePlan(status: 'none', version: 0),
              myUid: widget.myUid,
              otherUid: match?.otherUser(widget.myUid) ?? '',
              otherName: widget.otherName,
              planningPose: girl ? MascotPose.girlPlanning : MascotPose.boyPlanning,
              onConfirm: _confirm,
            ),
          ],
        );
      case 'recipe':
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [bubble, RecipeCardView(message: m)]);
      case 'song':
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [bubble, SongCardView(message: m)]);
      case 'cherryGoodbye':
        return CherryGoodbyeView(message: m, goodbyePose: girl ? MascotPose.girlGoodbye : MascotPose.boyGoodbye);
      default:
        return bubble;
    }
  }

  Future<void> _askCherryToLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ask Cherry to leave?'),
        content: const Text("Cherry will say goodbye and won't come back to this chat."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, leave')),
        ],
      ),
    );
    if (ok == true) await widget.functions.dismissCherry(widget.matchId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatMatch?>(
      stream: widget.chat.match(widget.matchId),
      builder: (context, matchSnap) {
        final match = matchSnap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.otherName),
            actions: [
              if (match?.cherryPresent ?? false)
                IconButton(
                  key: const Key('dismiss-cherry'),
                  tooltip: 'Ask Cherry to leave',
                  onPressed: _askCherryToLeave,
                  icon: const Text('🍒👋', style: TextStyle(fontSize: 18)),
                ),
            ],
          ),
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
                        itemBuilder: (context, i) => _messageView(messages[i], match),
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
