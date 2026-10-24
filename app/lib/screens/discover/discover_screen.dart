import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

import '../../data/daily.dart';
import '../../models/profile.dart';
import '../../models/recipe.dart';
import '../../services/discover_service.dart';
import '../../services/profile_service.dart';
import '../../services/recipe_library.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../../widgets/mascot.dart';
import '../../widgets/mascot_rive.dart';
import '../../widgets/onboarding.dart';
import '../profile/profile_view.dart';
import '../quiz/questions.dart';
import '../recipes/recipes_page.dart';

/// Swipeable cards of people looking for the same thing (`prd.md > Discover`).
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.me,
    required this.discover,
    required this.profiles,
    required this.whenEmpty,
  });

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
  int _hearts = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DiscoverScreen old) {
    super.didUpdateWidget(old);
    if (old.me.lookingFor != widget.me.lookingFor ||
        old.me.filters.signature != widget.me.filters.signature) {
      setState(() => _people = null);
      _load();
    }
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
      HapticFeedback.mediumImpact();
      setState(() => _hearts++);
      widget.discover.like(widget.me.uid, them);
    } else if (direction == CardSwiperDirection.left) {
      HapticFeedback.selectionClick();
      widget.discover.pass(widget.me.uid, them);
    }
    setState(() => _left--);
    return true;
  }

  void _openProfile(UserProfile p) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(p.name ?? '')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            ProfileView(
              profile: p,
              profiles: widget.profiles,
              commonGround: somethingInCommon(widget.me, p),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final people = _people;
    if (people == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedMascot(Wingman(widget.me.cherryAvatar).hello, size: 120),
            const SizedBox(height: 8),
            Text(
              'Finding food lovers for you…',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: BakeColors.muted),
            ),
          ],
        ),
      );
    }
    if (_left <= 0) return widget.whenEmpty(_load);

    return Column(
      children: [
        DailyHeader(me: widget.me),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              CardSwiper(
                controller: _swiper,
                cardsCount: people.length,
                numberOfCardsDisplayed: people.length.clamp(1, 2),
                allowedSwipeDirection: const AllowedSwipeDirection.only(
                  left: true,
                  right: true,
                ),
                onSwipe: _onSwipe,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                cardBuilder: (context, i, _, _) => _PersonCard(
                  key: Key('discover-card-${people[i].uid}'),
                  person: people[i],
                  common: somethingInCommon(widget.me, people[i]),
                  profiles: widget.profiles,
                  onTap: () => _openProfile(people[i]),
                ),
              ),
              if (_hearts > 0)
                IgnorePointer(
                  child:
                      const Icon(
                            Icons.favorite_rounded,
                            color: BakeColors.cherryRed,
                            size: 120,
                          )
                          .animate(key: ValueKey(_hearts))
                          .scale(
                            begin: const Offset(0.3, 0.3),
                            end: const Offset(1.3, 1.3),
                            duration: 450.ms,
                            curve: Curves.easeOutBack,
                          )
                          .then()
                          .fadeOut(duration: 250.ms),
                ),
            ],
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

/// Today's hello from the person's own Jack or Jill, and (unless [showDish] is off) the Dish of the Day.
class DailyHeader extends StatefulWidget {
  const DailyHeader({super.key, required this.me, this.showDish = true});

  final UserProfile me;
  final bool showDish;

  @override
  State<DailyHeader> createState() => _DailyHeaderState();
}

class _DailyHeaderState extends State<DailyHeader> {
  Recipe? _dish;

  @override
  void initState() {
    super.initState();
    if (widget.showDish) {
      RecipeLibrary.load().then((lib) {
        if (mounted) setState(() => _dish = lib.dishOfTheDay(widget.me));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final wingman = Wingman(widget.me.cherryAvatar);
    final greeting = dailyGreeting(widget.me.name, DateTime.now());
    final dish = _dish;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const AnimatedMascot(
                MascotPose.duoWelcome,
                size: 84,
                animationAsset: MascotMotion.welcomeAsset,
                posterAsset: MascotMotion.welcomePosterAsset,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  key: const Key('daily-greeting'),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
                  decoration: const BoxDecoration(
                    color: BakeColors.softPink,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${wingman.name} · ${greeting.hello}',
                        style: text.labelLarge?.copyWith(
                          color: BakeColors.deepCherry,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(greeting.line, style: text.bodyMedium),
                    ],
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 300.ms).moveY(begin: 6, end: 0),
          if (dish != null) ...[
            const SizedBox(height: 6),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                key: const Key('dish-of-the-day'),
                borderRadius: BorderRadius.circular(999),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(recipe: dish),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: BakeColors.line),
                  ),
                  child: Row(
                    children: [
                      Text(dish.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Dish of the day  ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: BakeColors.deepCherry,
                                ),
                              ),
                              TextSpan(text: dish.title),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${dish.minutes} min',
                        style: text.bodySmall?.copyWith(
                          color: BakeColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
          ],
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    super.key,
    required this.person,
    required this.common,
    required this.profiles,
    required this.onTap,
  });

  final UserProfile person;
  final String? common;
  final ProfileService profiles;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = person;
    final diet = p.foodText('foodType') == 'Other'
        ? p.foodText('foodTypeOther')
        : p.foodText('foodType');
    final cuisines = p.foodList('topCuisines').isNotEmpty
        ? p.foodList('topCuisines')
        : p.foodList('cuisines').take(3).toList();
    final style = p.foodList('cookingPersonality');
    String withEmoji(String label) {
      final e = emojiFor(label);
      return e == null ? label : '$e $label';
    }

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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  p.photos.isEmpty
                      ? const ColoredBox(
                          color: BakeColors.softPink,
                          child: Center(
                            child: AnimatedMascot(
                              MascotPose.duoWelcome,
                              size: 160,
                              animationAsset: MascotMotion.welcomeAsset,
                              posterAsset: MascotMotion.welcomePosterAsset,
                            ),
                          ),
                        )
                      : StoragePhoto(path: p.photos.first, profiles: profiles),
                  if (p.city != null)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '📍 ${p.city!.split(',').first}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${p.name ?? ''}, ${p.age ?? ''}',
                          style: text.headlineSmall,
                        ),
                      ),
                      if (p.verified) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          color: BakeColors.leafGreen,
                          size: 22,
                        ),
                      ],
                    ],
                  ),
                  if (style.isNotEmpty)
                    Text(
                      style.first,
                      style: text.titleMedium?.copyWith(
                        color: BakeColors.deepCherry,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (diet != null) _Tag(withEmoji(diet)),
                      for (final c in cuisines) _Tag(withEmoji(c)),
                      if (p.foodText('signatureDish') != null)
                        _Tag('⭐ ${p.foodText('signatureDish')}'),
                    ],
                  ),
                  if (common != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      '🍒 $common',
                      style: text.titleMedium?.copyWith(
                        color: BakeColors.cherryRed,
                      ),
                    ),
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
    decoration: BoxDecoration(
      color: BakeColors.warmCream,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: BakeColors.line),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
  });

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
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Icon(icon, size: 34, color: color),
      ),
    ),
  );
}
