import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/profile.dart';
import '../../models/recipe.dart';
import '../../services/recipe_library.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../../widgets/mascot.dart';

/// Shown when Discover has nobody new: recipes from the bundled library, picked for this person
/// (`prd.md > Recipes`, `prd.md > Added at Final Review`). No network, no AI.
class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key, required this.me, this.onCheckAgain});

  final UserProfile me;
  final Future<void> Function()? onCheckAgain;

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  RecipeLibrary? _library;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    RecipeLibrary.load().then((lib) {
      if (mounted) setState(() => _library = lib);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lib = _library;
    final wingman = Wingman(widget.me.cherryAvatar);
    final recipes = lib?.selection(widget.me, page: _page) ?? const <Recipe>[];
    return RefreshIndicator(
      color: BakeColors.cherryRed,
      onRefresh: () async => widget.onCheckAgain?.call(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          const Center(child: Mascot(MascotPose.duoCooking, size: 160)),
          Text('No one new right now', textAlign: TextAlign.center, style: text.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '${wingman.name} picked a few recipes for you while you wait. Pull down to check for new people.',
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: BakeColors.muted),
          ),
          const SizedBox(height: 16),
          if (lib == null)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: BakeColors.cherryRed))),
          for (var i = 0; i < recipes.length; i++)
            RecipeTile(recipe: recipes[i]).animate(key: ValueKey('${recipes[i].id}-$_page')).fadeIn(delay: (60 * i).ms).moveY(begin: 8, end: 0),
          if (recipes.isNotEmpty)
            OutlinedButton.icon(
              key: const Key('recipes-new-ideas'),
              onPressed: () => setState(() => _page++),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('New ideas'),
            ),
        ],
      ),
    );
  }
}

class RecipeTile extends StatelessWidget {
  const RecipeTile({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BakeShapes.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(BakeShapes.cardRadius),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe))),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BakeShapes.cardRadius),
              border: Border.all(color: BakeColors.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: BakeColors.softPink, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: Text(recipe.emoji, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipe.title, style: text.titleMedium),
                      const SizedBox(height: 2),
                      Text('${recipe.cuisine} · ⏱ ${recipe.minutes} min', style: text.bodyMedium?.copyWith(color: BakeColors.deepCherry)),
                      if (recipe.blurb.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(recipe.blurb, style: text.bodyMedium?.copyWith(color: BakeColors.muted)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: BakeColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(recipe.cuisine)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
        children: [
          Text(recipe.emoji, style: const TextStyle(fontSize: 54)),
          Text(recipe.title, style: text.headlineMedium),
          const SizedBox(height: 4),
          Text('⏱ ${recipe.minutes} minutes · for two', style: text.titleMedium?.copyWith(color: BakeColors.deepCherry)),
          if (recipe.blurb.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(recipe.blurb, style: text.bodyLarge?.copyWith(color: BakeColors.muted)),
          ],
          const SizedBox(height: 20),
          Text('Ingredients', style: text.titleLarge),
          for (final i in recipe.ingredients) Padding(padding: const EdgeInsets.only(top: 6), child: Text('• $i', style: text.bodyLarge)),
          const SizedBox(height: 20),
          Text('Steps', style: text.titleLarge),
          for (var s = 0; s < recipe.steps.length; s++)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('${s + 1}. ${recipe.steps[s]}', style: text.bodyLarge)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: BakeColors.softPink, borderRadius: BorderRadius.circular(14)),
            child: Text('⚠️ ${recipe.allergyNote}', style: text.bodyMedium),
          ),
        ],
      ),
    );
  }
}
