import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_match.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/discover_service.dart';
import '../services/functions_service.dart';
import '../services/profile_service.dart';
import '../theme/colors.dart';
import 'chat/chat_list_screen.dart';
import 'chat/chat_screen.dart';
import 'discover/discover_screen.dart';
import 'match/match_moment_screen.dart';
import 'profile/my_profile_screen.dart';
import 'recipes/recipes_page.dart';

/// The app after onboarding: Discover and Chats, plus the match moment whenever a new match lands.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.me,
    required this.auth,
    required this.chat,
    required this.functions,
    required this.profiles,
    required this.discover,
  });

  final UserProfile me;
  final AuthService auth;
  final ChatService chat;
  final FunctionsService functions;
  final ProfileService profiles;
  final DiscoverService discover;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  int _discoverVisit = 0;
  StreamSubscription<List<ChatMatch>>? _matches;
  final _celebrating = <String>{};

  @override
  void initState() {
    super.initState();
    _matches = widget.chat.unseenMatches(widget.me.uid).listen(_celebrate);
  }

  @override
  void dispose() {
    _matches?.cancel();
    super.dispose();
  }

  Future<void> _celebrate(List<ChatMatch> unseen) async {
    for (final match in unseen) {
      if (!_celebrating.add(match.id)) continue;
      final them = await widget.profiles.load(match.otherUser(widget.me.uid));
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => MatchMomentScreen(
          me: widget.me,
          them: them,
          profiles: widget.profiles,
          onBreakTheIce: () {
            widget.chat.markSeen(match.id, widget.me.uid);
            Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => ChatScreen(
                chat: widget.chat,
                functions: widget.functions,
                matchId: match.id,
                myUid: widget.me.uid,
                otherName: them.name ?? 'Your match',
              ),
            ));
          },
        ),
      ));
      await widget.chat.markSeen(match.id, widget.me.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      Scaffold(
        appBar: AppBar(title: const Text('Discover')),
        body: DiscoverScreen(
          key: ValueKey(_discoverVisit),
          me: widget.me,
          discover: widget.discover,
          profiles: widget.profiles,
          whenEmpty: (checkAgain) => RecipesPage(functions: widget.functions, onCheckAgain: checkAgain),
        ),
      ),
      ChatListScreen(auth: widget.auth, chat: widget.chat, functions: widget.functions, myUid: widget.me.uid),
      MyProfileScreen(me: widget.me, profiles: widget.profiles, functions: widget.functions, auth: widget.auth),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: Colors.white,
        indicatorColor: BakeColors.softPink,
        onDestinationSelected: (i) => setState(() {
          // Coming back to Discover checks for new people.
          if (i == 0 && _tab != 0) _discoverVisit++;
          _tab = i;
        }),
        destinations: const [
          NavigationDestination(key: Key('tab-discover'), icon: Icon(Icons.local_fire_department_outlined), selectedIcon: Icon(Icons.local_fire_department, color: BakeColors.cherryRed), label: 'Discover'),
          NavigationDestination(key: Key('tab-chats'), icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble, color: BakeColors.cherryRed), label: 'Chats'),
          NavigationDestination(key: Key('tab-me'), icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: BakeColors.cherryRed), label: 'Me'),
        ],
      ),
    );
  }
}
