import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/profile.dart';
import '../../services/profile_service.dart';
import '../../theme/colors.dart';
import '../../widgets/mascot.dart';
import '../../widgets/onboarding.dart';
import 'questions.dart';

const _cherryLines = [
  'Ooh, a proper foodie! 🍒',
  'Your future cooking partner is going to love this 😋',
  'Almost there — save room for dessert! 🧁',
  'Last bits! You’re cooking now 🔥',
];

/// The food quiz: one card at a time, every answer saved as it's given (`prd.md > Food Profile Quiz`).
/// In edit mode ([startAt] set) it shows just that one card.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.profile, required this.profiles, this.startAt, this.onDone});

  final UserProfile profile;
  final ProfileService profiles;
  final int? startAt;
  final VoidCallback? onDone;

  bool get editing => startAt != null;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final Map<String, dynamic> _food = {...widget.profile.food};
  late final Map<String, TextEditingController> _texts = {
    for (final q in quizQuestions)
      if (q.kind == QuizKind.text) q.field: TextEditingController(text: widget.profile.foodText(q.field)),
    for (final q in quizQuestions)
      if (q.otherField != null) q.otherField!: TextEditingController(text: widget.profile.foodText(q.otherField!)),
    for (final q in quizQuestions)
      if (q.extraTextField != null) q.extraTextField!: TextEditingController(text: widget.profile.foodText(q.extraTextField!)),
    for (final p in profilePrompts.keys) 'prompt.$p': TextEditingController(text: widget.profile.prompts[p]),
  };
  late int _index = widget.startAt ?? firstUnansweredIndex(widget.profile.food).clamp(0, quizQuestions.length - 1);
  Timer? _debounce;

  QuizQuestion get _q => quizQuestions[_index];

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in _texts.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(String field, Object? value, {bool debounce = false}) {
    setState(() => _food[field] = value);
    _debounce?.cancel();
    if (debounce) {
      _debounce = Timer(const Duration(milliseconds: 600), () => widget.profiles.saveFoodAnswer(widget.profile.uid, field, value));
    } else {
      widget.profiles.saveFoodAnswer(widget.profile.uid, field, value);
    }
  }

  List<String> _list(String field) => List<String>.from(_food[field] as List? ?? const []);

  void _toggle(QuizQuestion q, String label) {
    final picks = _list(q.field);
    if (picks.contains(label)) {
      picks.remove(label);
    } else {
      if (q.maxPicks != null && picks.length >= q.maxPicks!) picks.removeAt(0);
      picks.add(label);
    }
    _set(q.field, picks);
    if (q.field == 'cuisines') {
      final top = _list('topCuisines').where(picks.contains).toList();
      if (top.length != _list('topCuisines').length) _set('topCuisines', top);
    }
  }

  Future<void> _next() async {
    _debounce?.cancel();
    for (final e in _texts.entries) {
      if (!e.key.startsWith('prompt.') && _food.containsKey(e.key)) {
        await widget.profiles.saveFoodAnswer(widget.profile.uid, e.key, _food[e.key]);
      }
    }
    if (_q.kind == QuizKind.prompts) {
      await widget.profiles.savePrompts(widget.profile.uid, {
        for (final p in profilePrompts.keys) p: _texts['prompt.$p']!.text,
      });
    }
    if (widget.editing) {
      widget.onDone?.call();
      return;
    }
    if (_index == quizQuestions.length - 1) {
      await widget.profiles.markQuizDone(widget.profile.uid);
      widget.onDone?.call();
      return;
    }
    setState(() => _index++);
  }

  void _back() {
    if (widget.editing) {
      Navigator.pop(context);
    } else if (_index > 0) {
      setState(() => _index--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    final answered = isAnswered(q, _food);
    final showCherry = !widget.editing && _index > 0 && _index % 3 == 0;
    return OnboardingPage(
      key: ValueKey(q.field),
      title: q.title,
      subtitle: q.subtitle,
      progress: widget.editing ? null : 0.1 + 0.6 * (_index / quizQuestions.length),
      onBack: widget.editing || _index > 0 ? _back : null,
      top: showCherry ? _CherryPopIn(line: _cherryLines[(_index ~/ 3 - 1) % _cherryLines.length], pose: _cheerPose) : null,
      action: FilledButton(
        key: const Key('quiz-next'),
        onPressed: answered ? _next : null,
        child: Text(widget.editing ? 'Save' : (_index == quizQuestions.length - 1 ? 'Finish' : 'Next')),
      ),
      secondaryAction: !q.required && !widget.editing
          ? TextButton(key: const Key('quiz-skip'), onPressed: _next, child: const Text('Skip for now'))
          : null,
      child: _body(q),
    );
  }

  MascotPose get _cheerPose => widget.profile.cherryAvatar == 'girl' ? MascotPose.girlCheer : MascotPose.boyCheer;

  Widget _body(QuizQuestion q) {
    switch (q.kind) {
      case QuizKind.single:
        return Column(
          children: [
            for (final o in q.options)
              ChoiceTile(
                key: Key('opt-${o.label}'),
                label: o.label,
                emoji: o.emoji,
                selected: _food[q.field] == o.label,
                onTap: () => _set(q.field, o.label),
              ),
            if (q.otherField != null && _food[q.field] == 'Other')
              TextField(
                key: const Key('quiz-other'),
                controller: _texts[q.otherField],
                decoration: bakeField('Tell us more'),
                onChanged: (v) => _set(q.otherField!, v, debounce: true),
              ),
          ],
        );
      case QuizKind.multi:
        final picks = _list(q.field);
        final chips = q.options.length > 7;
        final tiles = [
          for (final o in q.options)
            chips
                ? ChoiceChipTile(
                    key: Key('opt-${o.label}'),
                    label: o.label,
                    emoji: o.emoji,
                    selected: picks.contains(o.label),
                    onTap: () => _toggle(q, o.label),
                  )
                : ChoiceTile(
                    key: Key('opt-${o.label}'),
                    label: o.label,
                    emoji: o.emoji,
                    selected: picks.contains(o.label),
                    onTap: () => _toggle(q, o.label),
                  ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            chips ? Wrap(spacing: 8, runSpacing: 8, children: tiles) : Column(children: tiles),
            if (q.extraTextField != null) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _texts[q.extraTextField],
                decoration: bakeField(q.extraTextHint ?? ''),
                onChanged: (v) => _set(q.extraTextField!, v, debounce: true),
              ),
            ],
          ],
        );
      case QuizKind.topPicks:
        final cuisines = _list('cuisines');
        final picks = _list(q.field);
        final emoji = {for (final o in quizQuestions.firstWhere((x) => x.field == 'cuisines').options) o.label: o.emoji};
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in cuisines)
              ChoiceChipTile(
                key: Key('top-$c'),
                label: picks.contains(c) ? '$c  #${picks.indexOf(c) + 1}' : c,
                emoji: emoji[c] ?? '🍽️',
                selected: picks.contains(c),
                onTap: () => _toggle(q, c),
              ),
          ],
        );
      case QuizKind.text:
        return TextField(
          key: Key('quiz-text-${q.field}'),
          controller: _texts[q.field],
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: bakeField('Your answer', hint: q.hint),
          onChanged: (v) => _set(q.field, v, debounce: true),
        );
      case QuizKind.slider:
        final value = (_food[q.field] as num?)?.toDouble() ?? 5;
        return Column(
          children: [
            Text('${value.round()}/10', style: Theme.of(context).textTheme.headlineSmall),
            Slider(
              value: value,
              min: 0,
              max: 10,
              divisions: 10,
              activeColor: BakeColors.cherryRed,
              onChanged: (v) => _set(q.field, v.round(), debounce: true),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text('I order the same thing every time', style: TextStyle(color: BakeColors.muted))),
                SizedBox(width: 16),
                Flexible(child: Text("I'll try anything at least once", textAlign: TextAlign.end, style: TextStyle(color: BakeColors.muted))),
              ],
            ),
          ],
        );
      case QuizKind.prompts:
        return Column(
          children: [
            for (final p in profilePrompts.entries) ...[
              TextField(
                controller: _texts['prompt.${p.key}'],
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                decoration: bakeField(p.value),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
    }
  }
}

class _CherryPopIn extends StatelessWidget {
  const _CherryPopIn({required this.line, required this.pose});

  final String line;
  final MascotPose pose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Mascot(pose, size: 70, bob: false),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: BakeColors.softPink, borderRadius: BorderRadius.circular(16)),
              child: Text(line, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), curve: Curves.easeOutBack),
    );
  }
}
