import 'package:flutter/material.dart';

import '../../models/chat_match.dart';
import '../../models/message.dart';
import '../../services/chat_service.dart';
import '../../services/functions_service.dart';
import '../../theme/colors.dart';
import '../../widgets/mascot.dart';
import '../../widgets/mascot_rive.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({
    super.key,
    required this.chat,
    required this.functions,
    required this.myUid,
    this.myCherry,
  });

  final ChatService chat;
  final FunctionsService functions;
  final String myUid;

  /// The person's own cherry from their profile, for the empty state.
  final String? myCherry;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  // Subscribed once, so the list doesn't re-read or flicker whenever the screen rebuilds.
  late final Stream<List<ChatMatch>> _matches = widget.chat.matchesFor(widget.myUid);

  ChatService get chat => widget.chat;
  FunctionsService get functions => widget.functions;
  String get myUid => widget.myUid;
  String? get myCherry => widget.myCherry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: StreamBuilder<List<ChatMatch>>(
        stream: _matches,
        builder: (context, snap) {
          if (snap.hasError && !snap.hasData) {
            return _Note(pose: Wingman(myCherry).tryAgain, title: 'Couldn’t load your chats', body: 'Check your connection and come back in a moment.');
          }
          if (!snap.hasData) {
            return const CherryLoading(caption: 'Getting your chats…');
          }
          final matches = snap.data!;
          if (matches.isEmpty) {
            return _Note(
              rig: Wingman(myCherry).rig(WingmanRig.think),
              title: 'No matches yet',
              body: 'When you and someone both like each other, ${Wingman(myCherry).name} will be waiting here to break the ice.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => i == matches.length
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Every chat starts with a cherry and ends with a cooking date 🍳',
                        textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: BakeColors.muted)),
                  )
                : _MatchTile(key: ValueKey(matches[i].id), chat: chat, functions: functions, match: matches[i], myUid: myUid),
          );
        },
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({this.pose, this.rig, required this.title, required this.body})
      : assert(pose != null || rig != null);

  /// Static hero pose (failures and other moments that shouldn't animate).
  final MascotPose? pose;

  /// Animated wingman rig clip (`Wingman.rig`).
  final WingmanPose? rig;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedWingman(rig!, size: 130),
            Text(title, style: text.titleLarge),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: text.bodyLarge?.copyWith(color: BakeColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _MatchTile extends StatefulWidget {
  const _MatchTile({super.key, required this.chat, required this.functions, required this.match, required this.myUid});

  final ChatService chat;
  final FunctionsService functions;
  final ChatMatch match;
  final String myUid;

  @override
  State<_MatchTile> createState() => _MatchTileState();
}

class _MatchTileState extends State<_MatchTile> {
  late final Stream<ChatMessage?> _last = widget.chat.lastMessage(widget.match.id);

  ChatService get chat => widget.chat;
  FunctionsService get functions => widget.functions;
  ChatMatch get match => widget.match;
  String get myUid => widget.myUid;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final wingman = Wingman(match.cherryFor[myUid]);
    return FutureBuilder<String>(
      future: chat.displayName(match.otherUser(myUid)),
      builder: (context, nameSnap) {
        final name = nameSnap.data ?? '…';
        return StreamBuilder<ChatMessage?>(
          stream: _last,
          builder: (context, lastSnap) {
            final last = lastSnap.data;
            final unread = isUnread(match, last, myUid);
            return Card(
              key: Key('chat-tile-${match.id}'),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: BakeColors.softPink,
                  child: Text(name.characters.first, style: const TextStyle(color: BakeColors.deepCherry, fontWeight: FontWeight.w800, fontSize: 18)),
                ),
                title: Row(
                  children: [
                    Expanded(child: Text(name, style: text.titleMedium)),
                    if (last != null) Text(_ago(last.sentAt), style: text.bodySmall?.copyWith(color: BakeColors.muted)),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (last != null)
                      Text(
                        chatPreview(last, me: myUid, wingmanName: wingman.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unread ? BakeColors.charcoal : BakeColors.muted,
                          fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(chatStatus(match, wingmanName: wingman.name),
                        style: text.bodySmall?.copyWith(color: BakeColors.deepCherry, fontWeight: FontWeight.w700)),
                  ],
                ),
                trailing: unread
                    ? Container(
                        key: Key('chat-unread-${match.id}'),
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(color: BakeColors.cherryRed, shape: BoxShape.circle),
                      )
                    : const Icon(Icons.chevron_right, color: BakeColors.muted),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chat: chat,
                      functions: functions,
                      matchId: match.id,
                      myUid: myUid,
                      otherName: name,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${t.day}/${t.month}';
}
