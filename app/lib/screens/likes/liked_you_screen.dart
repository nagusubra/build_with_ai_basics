import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/profile.dart';
import '../../services/discover_service.dart';
import '../../services/profile_service.dart';
import '../../theme/colors.dart';
import '../profile/profile_view.dart';

/// People who liked me, one profile at a time, with Like back or Pass
/// (`prd.md > Added at Final Review`). Liking back makes the match straight away.
class LikedYouScreen extends StatefulWidget {
  const LikedYouScreen({
    super.key,
    required this.me,
    required this.people,
    required this.discover,
    required this.profiles,
    this.onAnswered,
  });

  final UserProfile me;
  final List<UserProfile> people;
  final DiscoverService discover;
  final ProfileService profiles;

  /// After a like back or pass, so Discover can reload without them.
  final VoidCallback? onAnswered;

  @override
  State<LikedYouScreen> createState() => _LikedYouScreenState();
}

class _LikedYouScreenState extends State<LikedYouScreen> {
  late final List<UserProfile> _people = [...widget.people];
  final _pages = PageController();
  int _index = 0;
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _answer({required bool likeBack}) async {
    final them = _people[_index];
    setState(() => _busy = true);
    try {
      if (likeBack) {
        HapticFeedback.mediumImpact();
        await widget.discover.like(widget.me.uid, them.uid);
      } else {
        HapticFeedback.selectionClick();
        await widget.discover.passOnLiker(widget.me.uid, them.uid);
      }
      widget.onAnswered?.call();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t send that just now — try again.')));
      }
      return;
    }
    if (!mounted) return;
    if (_people.length == 1) {
      // Only this screen goes; the match moment may already be on its way on top.
      Navigator.of(context).removeRoute(ModalRoute.of(context)!);
      return;
    }
    setState(() {
      _people.removeAt(_index);
      _index = _index.clamp(0, _people.length - 1);
      _busy = false;
    });
    _pages.jumpToPage(_index);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_people.length == 1 ? 'Liked you 💗' : 'Liked you 💗  ${_index + 1} of ${_people.length}')),
      body: PageView.builder(
        controller: _pages,
        itemCount: _people.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => ListView(
          key: Key('liked-you-${_people[i].uid}'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: BakeColors.softPink, borderRadius: BorderRadius.circular(16)),
              child: Text('${_people[i].name ?? 'They'} liked your profile. Like back and it’s a match!',
                  style: text.titleMedium?.copyWith(color: BakeColors.deepCherry)),
            ),
            ProfileView(profile: _people[i], profiles: widget.profiles, commonGround: somethingInCommon(widget.me, _people[i])),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('liked-pass'),
                  onPressed: _busy ? null : () => _answer(likeBack: false),
                  child: const Text('Pass'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  key: const Key('liked-like-back'),
                  onPressed: _busy ? null : () => _answer(likeBack: true),
                  icon: const Icon(Icons.favorite_rounded),
                  label: const Text('Like back'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
