import 'package:flutter/material.dart';

import '../../models/recipe.dart';
import '../../services/functions_service.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../../widgets/mascot.dart';

/// Shown when Discover has nobody new: recipes to cook while you wait (`prd.md > Recipes`).
class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key, required this.functions, this.onCheckAgain});

  final FunctionsService functions;
  final Future<void> Function()? onCheckAgain;

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  List<Recipe>? _recipes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final recipes = await widget.functions.myRecipes(refresh: refresh);
      if (mounted) setState(() => _recipes = recipes);
    } catch (_) {
      if (mounted) setState(() => _error = "Cherry couldn't cook up recipes just now. Pull down to try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final recipes = _recipes ?? const <Recipe>[];
    return RefreshIndicator(
      color: BakeColors.cherryRed,
      onRefresh: () async {
        await widget.onCheckAgain?.call();
        await _load();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          const Center(child: Mascot(MascotPose.duoCooking, size: 170)),
          Text('No one new right now', textAlign: TextAlign.center, style: text.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'While you wait, here are a few recipes picked for you. Pull down to check for new people.',
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: BakeColors.muted),
          ),
          const SizedBox(height: 16),
          if (_loading && recipes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator(color: BakeColors.cherryRed)),
            ),
          if (_error != null) Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: BakeColors.deepCherry)),
          for (final r in recipes) _RecipeTile(recipe: r),
          if (recipes.isNotEmpty)
            OutlinedButton.icon(
              key: const Key('recipes-new-ideas'),
              onPressed: _loading ? null : () => _load(refresh: true),
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: const Text('New ideas'),
            ),
        ],
      ),
    );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({required this.recipe});

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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BakeShapes.cardRadius),
              border: Border.all(color: BakeColors.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipe.title, style: text.titleMedium),
                      const SizedBox(height: 2),
                      Text('${recipe.cuisine} · ⏱ ${recipe.minutes} min', style: text.bodyMedium?.copyWith(color: BakeColors.deepCherry)),
                      const SizedBox(height: 4),
                      Text(recipe.blurb, style: text.bodyMedium?.copyWith(color: BakeColors.muted)),
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
          Text(recipe.title, style: text.headlineMedium),
          const SizedBox(height: 4),
          Text('⏱ ${recipe.minutes} minutes', style: text.titleMedium?.copyWith(color: BakeColors.deepCherry)),
          const SizedBox(height: 8),
          Text(recipe.blurb, style: text.bodyLarge?.copyWith(color: BakeColors.muted)),
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
