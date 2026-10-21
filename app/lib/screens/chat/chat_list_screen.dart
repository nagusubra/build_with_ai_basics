import 'package:flutter/material.dart';

import '../../models/chat_match.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../theme/colors.dart';
import '../../widgets/mascot.dart';
import '../dev/verification_lab_screen.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key, required this.auth, required this.chat, required this.myUid});

  final AuthService auth;
  final ChatService chat;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          // DEV ONLY until onboarding (slice 5) and My profile (slice 8) exist.
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (choice) {
              if (choice == 'lab') {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VerificationLabScreen()));
              } else if (choice == 'signout') {
                auth.signOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'lab', child: Text('Verification lab (dev)')),
              PopupMenuItem(value: 'signout', child: Text('Sign out (dev)')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<ChatMatch>>(
        stream: chat.matchesFor(myUid),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: BakeColors.cherryRed));
          }
          final matches = snap.data!;
          if (matches.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Mascot(MascotPose.duoCooking, size: 180),
                  Text('No matches yet', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _MatchTile(chat: chat, match: matches[i], myUid: myUid),
          );
        },
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.chat, required this.match, required this.myUid});

  final ChatService chat;
  final ChatMatch match;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: chat.displayName(match.otherUser(myUid)),
      builder: (context, snap) {
        final name = snap.data ?? '…';
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: BakeColors.softPink,
              child: Text(name.characters.first, style: const TextStyle(color: BakeColors.deepCherry, fontWeight: FontWeight.w800)),
            ),
            title: Text(name, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(match.cherryPresent ? '🍒 Cherry is here' : 'Just the two of you'),
            trailing: const Icon(Icons.chevron_right, color: BakeColors.muted),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(chat: chat, matchId: match.id, myUid: myUid, otherName: name),
              ),
            ),
          ),
        );
      },
    );
  }
}
