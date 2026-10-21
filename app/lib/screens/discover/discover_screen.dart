import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

import '../../models/profile.dart';
import '../../services/discover_service.dart';
import '../../services/profile_service.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../../widgets/mascot.dart';
import '../../widgets/onboarding.dart';
import '../profile/profile_view.dart';

/// Swipeable cards of people looking for the same thing (`prd.md > Discover`).
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.me, required this.discover, required this.profiles, required this.whenEmpty});

  final UserProfile me;
  final DiscoverService discover;
  final ProfileService profiles;

  /// Shown when there's nobody new (the Recipes page); given a way to check for new people.
  final Widget Function(Future<void> Function() checkAgain) whenEmpty;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _swiper = CardSwiperController();
  List<UserProfile>? _people;
  int _left = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _swiper.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final people = await widget.discover.candidates(widget.me);
    if (mounted) {
      setState(() {
        _people = people;
        _left = people.length;
      });
    }
  }

  bool _onSwipe(int index, int? _, CardSwiperDirection direction) {
    final them = _people![index].uid;
    if (direction == CardSwiperDirection.right) {
      widget.discover.like(widget.me.uid, them);
    } else if (direction == CardSwiperDirection.left) {
      widget.discover.pass(widget.me.uid, them);
    }
    setState(() => _left--);
    return true;
  }

  void _openProfile(UserProfile p) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(p.name ?? '')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [ProfileView(profile: p, profiles: widget.profiles, commonGround: somethingInCommon(widget.me, p))],
          ),
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final people = _people;
    if (people == null) return const Center(child: CircularProgressIndicator(color: BakeColors.cherryRed));
    if (_left <= 0) return widget.whenEmpty(_load);

    return Column(
      children: [
        Expanded(
          child: CardSwiper(
            controller: _swiper,
            cardsCount: people.length,
            numberOfCardsDisplayed: people.length.clamp(1, 2),
            allowedSwipeDirection: const AllowedSwipeDirection.only(left: true, right: true),
            onSwipe: _onSwipe,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            cardBuilder: (context, i, _, _) => _PersonCard(
              key: Key('discover-card-${people[i].uid}'),
              person: people[i],
              common: somethingInCommon(widget.me, people[i]),
              profiles: widget.profiles,
              onTap: () => _openProfile(people[i]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundButton(
                key: const Key('discover-pass'),
                icon: Icons.close_rounded,
                color: BakeColors.muted,
                onTap: () => _swiper.swipe(CardSwiperDirection.left),
              ),
              const SizedBox(width: 28),
              _RoundButton(
                key: const Key('discover-like'),
                icon: Icons.favorite_rounded,
                color: BakeColors.cherryRed,
                onTap: () => _swiper.swipe(CardSwiperDirection.right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({super.key, required this.person, required this.common, required this.profiles, required this.onTap});

  final UserProfile person;
  final String? common;
  final ProfileService profiles;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = person;
    final diet = p.foodText('foodType') == 'Other' ? p.foodText('foodTypeOther') : p.foodText('foodType');
    final cuisines = p.foodList('topCuisines').isNotEmpty ? p.foodList('topCuisines') : p.foodList('cuisines').take(3).toList();
    final style = p.foodList('cookingPersonality');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: BakeShapes.softShadow,
          border: Border.all(color: BakeColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: p.photos.isEmpty
                  ? const ColoredBox(color: BakeColors.softPink, child: Center(child: Mascot(MascotPose.duoWelcome, size: 160)))
                  : StoragePhoto(path: p.photos.first, profiles: profiles),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text('${p.name ?? ''}, ${p.age ?? ''}', style: text.headlineSmall)),
                      if (p.verified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, color: BakeColors.leafGreen, size: 22),
                      ],
                    ],
                  ),
                  if (style.isNotEmpty) Text(style.first, style: text.titleMedium?.copyWith(color: BakeColors.deepCherry)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (diet != null) _Tag(diet),
                      for (final c in cuisines) _Tag(c),
                      if (p.foodText('signatureDish') != null) _Tag('⭐ ${p.foodText('signatureDish')}'),
                      if (p.foodText('idealDate') != null) _Tag('🍳 ${p.foodText('idealDate')}'),
                    ],
                  ),
                  if (common != null) ...[
                    const SizedBox(height: 10),
                    Text('🍒 $common', style: text.titleMedium?.copyWith(color: BakeColors.cherryRed)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: BakeColors.warmCream, borderRadius: BorderRadius.circular(999), border: Border.all(color: BakeColors.line)),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: BakeColors.deepCherry.withValues(alpha: 0.2),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(18), child: Icon(icon, size: 34, color: color)),
        ),
      );
}
