import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../../services/profile_service.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../../widgets/onboarding.dart';
import '../quiz/questions.dart';

/// A BakeOut profile where food is the personality (`prd.md > Profile Preview`).
/// Skipped answers simply don't appear.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key, required this.profile, required this.profiles, this.commonGround});

  final UserProfile profile;
  final ProfileService profiles;

  /// Shown on someone else's profile, e.g. "You both love Italian food!"
  final String? commonGround;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = profile;
    final cuisines = p.foodList('topCuisines').isNotEmpty ? p.foodList('topCuisines') : p.foodList('cuisines').take(3).toList();
    final diet = p.foodText('foodType') == 'Other' ? p.foodText('foodTypeOther') : p.foodText('foodType');
    final adventure = p.food['adventure'];
    final music = [...p.foodList('musicGenres'), if (p.foodText('favouriteSong') != null) '“${p.foodText('favouriteSong')}”'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.photos.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(BakeShapes.cardRadius),
            child: AspectRatio(
              aspectRatio: 0.85,
              child: PageView(children: [for (final path in p.photos) StoragePhoto(path: path, profiles: profiles)]),
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Flexible(
              child: Text('${p.name ?? ''}${p.age != null ? ', ${p.age}' : ''} 🍒', style: text.headlineMedium),
            ),
            if (p.verified) ...[
              const SizedBox(width: 6),
              const Tooltip(message: 'Verified', child: Icon(Icons.verified_rounded, color: BakeColors.leafGreen)),
            ],
          ],
        ),
        if (p.city != null) Text(p.city!, style: text.bodyLarge?.copyWith(color: BakeColors.muted)),
        const SizedBox(height: 6),
        Text(profileHeadline(p), style: text.titleMedium?.copyWith(color: BakeColors.deepCherry, fontStyle: FontStyle.italic)),
        if (commonGround != null) ...[
          const SizedBox(height: 10),
          _Pill(text: commonGround!),
        ],
        const SizedBox(height: 16),
        _InfoCard(
          title: 'My Food Personality',
          rows: [
            ('Cooking style', p.foodList('cookingPersonality').join(' & ')),
            ('Food preference', diet),
            ('Favourite cuisines', cuisines.join(', ')),
            ('Signature dish', p.foodText('signatureDish')),
            ('Comfort food', p.foodText('comfortFood')),
            ('Food adventure level', adventure is num ? '$adventure/10' : null),
            ('Cooking', p.foodText('cookingRelationship')),
          ],
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: 'Our Kitchen Could Look Like',
          rows: [
            ('Ideal date', p.foodText('idealDate')),
            ('Cooking time', p.foodText('cookingTime')),
            ('Cooking soundtrack', music.join(', ')),
          ],
        ),
        for (final e in profilePrompts.entries)
          if (p.prompts[e.key] != null) ...[
            const SizedBox(height: 12),
            _InfoCard(title: e.value, body: p.prompts[e.key]),
          ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, this.rows = const [], this.body});

  final String title;
  final List<(String, String?)> rows;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shown = rows.where((r) => (r.$2 ?? '').trim().isNotEmpty).toList();
    if (shown.isEmpty && body == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BakeShapes.cardRadius),
        border: Border.all(color: BakeColors.line),
        boxShadow: BakeShapes.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium?.copyWith(color: BakeColors.deepCherry)),
          const SizedBox(height: 8),
          if (body != null) Text(body!, style: text.bodyLarge),
          for (final r in shown)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: RichText(
                text: TextSpan(
                  style: text.bodyLarge,
                  children: [
                    TextSpan(text: '${r.$1}: ', style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: r.$2),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: BakeColors.softPink, borderRadius: BorderRadius.circular(999)),
          child: Text(text, style: const TextStyle(color: BakeColors.deepCherry, fontWeight: FontWeight.w800)),
        ),
      );
}
