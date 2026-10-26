import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/profile_service.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// Lets onboarding pages offer "Log out" while someone is still setting up their profile.
class OnboardingExit extends InheritedWidget {
  const OnboardingExit({super.key, required this.onLogOut, required super.child});

  final VoidCallback onLogOut;

  static OnboardingExit? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<OnboardingExit>();

  @override
  bool updateShouldNotify(OnboardingExit oldWidget) => false;
}

/// Shared frame for onboarding steps: optional progress bar, title, body, and a bottom action.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.progress,
    this.action,
    this.secondaryAction,
    this.onBack,
    this.top,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final double? progress;
  final Widget? action;
  final Widget? secondaryAction;
  final VoidCallback? onBack;
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final exit = OnboardingExit.maybeOf(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8, 4, exit == null ? 20 : 4, 0),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_ios_new_rounded, color: BakeColors.deepCherry))
                  else
                    const SizedBox(width: 48),
                  if (progress != null)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          color: BakeColors.leafGreen,
                          backgroundColor: BakeColors.softPink,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (exit != null)
                    PopupMenuButton<String>(
                      key: const Key('onboarding-menu'),
                      icon: const Icon(Icons.more_horiz_rounded, color: BakeColors.muted),
                      onSelected: (_) => exit.onLogOut(),
                      itemBuilder: (_) => const [
                        PopupMenuItem<String>(
                          key: Key('onboarding-logout'),
                          value: 'logout',
                          child: Row(children: [Icon(Icons.logout_rounded, size: 20), SizedBox(width: 10), Text('Log out')]),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  ?top,
                  Text(title, style: text.headlineMedium).animate().fadeIn(duration: 300.ms).moveY(begin: 8, end: 0),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(subtitle!, style: text.bodyLarge?.copyWith(color: BakeColors.muted)),
                  ],
                  const SizedBox(height: 20),
                  child,
                ],
              ),
            ),
            if (action != null || secondaryAction != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(children: [?action, ?secondaryAction]),
              ),
          ],
        ),
      ),
    );
  }
}

/// One colourful answer tile in the quiz.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({super.key, required this.label, required this.emoji, required this.selected, required this.onTap});

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: 180.ms,
        decoration: BoxDecoration(
          color: selected ? BakeColors.softPink : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? BakeColors.cherryRed : BakeColors.line, width: selected ? 2 : 1),
          boxShadow: selected ? BakeShapes.softShadow : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: 180.ms,
                  child: const Icon(Icons.check_circle_rounded, color: BakeColors.cherryRed),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact chip-style choice for long lists (cuisines, music).
class ChoiceChipTile extends StatelessWidget {
  const ChoiceChipTile({super.key, required this.label, required this.emoji, required this.selected, required this.onTap});

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: 180.ms,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? BakeColors.softPink : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? BakeColors.cherryRed : BakeColors.line, width: selected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

InputDecoration bakeField(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: BakeColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: BakeColors.line)),
    );

/// A profile photo stored in Firebase Storage: fades in when loaded, and offers a retry
/// if the network let it down.
class StoragePhoto extends StatefulWidget {
  const StoragePhoto({super.key, required this.path, required this.profiles, this.fit = BoxFit.cover});

  final String path;
  final ProfileService profiles;
  final BoxFit fit;

  @override
  State<StoragePhoto> createState() => _StoragePhotoState();
}

class _StoragePhotoState extends State<StoragePhoto> {
  late Future<String> _url = widget.profiles.photoUrl(widget.path);
  int _attempt = 0;

  @override
  void didUpdateWidget(StoragePhoto old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _url = widget.profiles.photoUrl(widget.path);
  }

  void _retry() => setState(() {
        _attempt++;
        _url = widget.profiles.photoUrl(widget.path);
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snap) {
        if (snap.hasError) return _PhotoPlaceholder(onRetry: _retry);
        if (!snap.hasData) return const _PhotoPlaceholder();
        return Image.network(
          snap.data!,
          key: ValueKey('${snap.data}#$_attempt'),
          fit: widget.fit,
          frameBuilder: (context, child, frame, wasSync) => wasSync
              ? child
              : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 250), child: child),
          errorBuilder: (_, _, _) => _PhotoPlaceholder(onRetry: _retry),
        );
      },
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onRetry,
        child: ColoredBox(
          color: BakeColors.softPink,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🍒', style: TextStyle(fontSize: 40)),
                  if (onRetry != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text('Tap to reload', style: TextStyle(color: BakeColors.muted, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}
