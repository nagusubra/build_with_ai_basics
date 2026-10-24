import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/chat_match.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/discover_service.dart';
import '../services/functions_service.dart';
import '../services/profile_service.dart';
import '../theme/colors.dart';
import '../widgets/mascot.dart';
import '../widgets/onboarding.dart';
import 'chat/chat_list_screen.dart';
import 'chat/chat_screen.dart';
import 'discover/discover_screen.dart';
import 'discover/filters_sheet.dart';
import 'likes/liked_you_screen.dart';
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
  StreamSubscription<List<LikeNotice>>? _likes;
  final _celebrating = <String>{};
  final _announced = <String>{};
  final _likerCache = <String, UserProfile>{};
  List<UserProfile> _likers = const [];
  OverlayEntry? _banner;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    // Errors (e.g. permission denied the moment someone signs out or deletes their account)
    // just end the celebrations; there's nothing to show.
    _matches = widget.chat.unseenMatches(widget.me.uid).listen(_celebrate, onError: (_) {});
    _likes = widget.discover.likedMe(widget.me.uid).listen(_onLikes, onError: (_) {});
  }

  @override
  void dispose() {
    _matches?.cancel();
    _likes?.cancel();
    _hideBanner();
    super.dispose();
  }

  Future<void> _onLikes(List<LikeNotice> notices) async {
    final likers = <UserProfile>[];
    for (final n in notices) {
      try {
        final p = _likerCache[n.from] ??= await widget.profiles.load(n.from);
        if (canLikeBack(widget.me, p)) likers.add(p);
      } catch (e) {
        // Picked up again with the next update of the list.
        debugPrint('Could not load who liked you: $e');
      }
    }
    if (!mounted) return;
    setState(() => _likers = likers);
    final fresh = [
      for (final n in notices)
        if (!n.seen && _announced.add(n.from)) ...likers.where((p) => p.uid == n.from),
    ];
    if (fresh.isEmpty) return;
    for (final p in fresh) {
      widget.discover.markLikeSeen(widget.me.uid, p.uid).catchError((_) {});
    }
    _showBanner(fresh.first, others: fresh.length - 1);
  }

  void _openLikes([UserProfile? first]) {
    _hideBanner();
    if (_likers.isEmpty) return;
    final people = [?first, ..._likers.where((p) => p.uid != first?.uid)];
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LikedYouScreen(
        me: widget.me,
        people: people,
        discover: widget.discover,
        profiles: widget.profiles,
        onAnswered: () => setState(() => _discoverVisit++),
      ),
    ));
  }

  void _showBanner(UserProfile liker, {int others = 0}) {
    _hideBanner();
    HapticFeedback.lightImpact();
    final entry = OverlayEntry(
      builder: (_) => _LikeBanner(
        liker: liker,
        others: others,
        profiles: widget.profiles,
        onOpen: () => _openLikes(liker),
        onClose: _hideBanner,
      ),
    );
    Navigator.of(context).overlay?.insert(entry);
    _banner = entry;
    _bannerTimer = Timer(const Duration(seconds: 7), _hideBanner);
  }

  void _hideBanner() {
    _bannerTimer?.cancel();
    _banner?.remove();
    _banner = null;
  }

  Future<void> _celebrate(List<ChatMatch> unseen) async {
    for (final match in unseen) {
      if (!_celebrating.add(match.id)) continue;
      final UserProfile them;
      try {
        them = await widget.profiles.load(match.otherUser(widget.me.uid));
      } catch (e) {
        debugPrint('Could not load the new match: $e');
        _celebrating.remove(match.id);
        continue;
      }
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      await Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => MatchMomentScreen(
          me: widget.me,
          them: them,
          wingman: Wingman(match.cherryFor[widget.me.uid] ?? widget.me.cherryAvatar),
          profiles: widget.profiles,
          onBreakTheIce: () {
            widget.chat.markSeen(match.id, widget.me.uid).catchError((_) {});
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
      await widget.chat.markSeen(match.id, widget.me.uid).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    void editFilters() => showDiscoverFilters(context, me: me, profiles: widget.profiles);
    final activeFilters = me.filters.activeCount;
    final pages = [
      Scaffold(
        appBar: AppBar(
          title: const Text('Discover'),
          actions: [
            Material(
              color: BakeColors.softPink,
              shape: const StadiumBorder(side: BorderSide(color: BakeColors.line)),
              child: InkWell(
                key: const Key('discover-mode'),
                customBorder: const StadiumBorder(),
                onTap: editFilters,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text(
                    me.lookingFor == 'friends' ? '🤝 Friends' : '💞 Partner',
                    softWrap: false,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: BakeColors.deepCherry),
                  ),
                ),
              ),
            ),
            IconButton(
              key: const Key('discover-filters'),
              tooltip: 'Filters',
              onPressed: editFilters,
              icon: Badge(
                isLabelVisible: activeFilters > 0,
                label: Text('$activeFilters'),
                backgroundColor: BakeColors.cherryRed,
                child: const Icon(Icons.tune_rounded),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: Column(
          children: [
            if (_likers.isNotEmpty) _LikesPill(likers: _likers, onTap: () => _openLikes()),
            Expanded(
              child: DiscoverScreen(
                key: ValueKey(_discoverVisit),
                me: me,
                discover: widget.discover,
                profiles: widget.profiles,
                whenEmpty: (checkAgain) => RecipesPage(me: me, onCheckAgain: checkAgain, onEditFilters: editFilters),
              ),
            ),
          ],
        ),
      ),
      ChatListScreen(chat: widget.chat, functions: widget.functions, myUid: me.uid, myCherry: me.cherryAvatar),
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

/// "Priya liked you 💗", sliding in at the top of whatever screen is open.
class _LikeBanner extends StatelessWidget {
  const _LikeBanner({required this.liker, required this.others, required this.profiles, required this.onOpen, required this.onClose});

  final UserProfile liker;
  final int others;
  final ProfileService profiles;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = liker.name ?? 'Someone';
    return Positioned(
      left: 12,
      right: 12,
      top: MediaQuery.paddingOf(context).top + 8,
      child: Material(
        key: const Key('like-banner'),
        color: Colors.white,
        elevation: 8,
        shadowColor: BakeColors.deepCherry.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: BakeColors.softPink,
                  child: ClipOval(
                    child: SizedBox.square(
                      dimension: 48,
                      child: liker.photos.isEmpty
                          ? const Center(child: Text('💗', style: TextStyle(fontSize: 22)))
                          : StoragePhoto(path: liker.photos.first, profiles: profiles),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(others == 0 ? '$name liked you 💗' : '$name and $others more liked you 💗', style: text.titleMedium),
                      Text('Tap to see their profile and like back', style: text.bodyMedium?.copyWith(color: BakeColors.muted)),
                    ],
                  ),
                ),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, color: BakeColors.muted)),
              ],
            ),
          ),
        ),
      ).animate().slideY(begin: -1.2, end: 0, duration: 380.ms, curve: Curves.easeOutBack).fadeIn(duration: 200.ms),
    );
  }
}

/// Stays at the top of Discover while anyone is waiting for a like back.
class _LikesPill extends StatelessWidget {
  const _LikesPill({required this.likers, required this.onTap});

  final List<UserProfile> likers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = likers.length == 1
        ? '${likers.first.name ?? 'Someone'} liked you — like back?'
        : '${likers.length} people liked you — see who';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Material(
        color: BakeColors.cherryRed,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          key: const Key('likes-pill'),
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                const Text('💗', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).moveY(begin: -6, end: 0);
  }
}
