import 'package:flutter/material.dart';

import '../models/chat_match.dart';
import '../models/message.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import 'mascot.dart';
import 'mascot_rive.dart';

/// Shared frame for Cherry's cards in the chat.
class _CherryCard extends StatelessWidget {
  const _CherryCard({required this.child, this.color = Colors.white, this.faded = false});

  final Widget child;
  final Color color;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: faded ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.fromLTRB(46, 4, 8, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(BakeShapes.cardRadius),
          border: Border.all(color: const Color(0xFFF7D3D9)),
          boxShadow: BakeShapes.softShadow,
        ),
        child: child,
      ),
    );
  }
}

/// The cooking-date card: dish, day, time, who has confirmed, and my Confirm button.
class DateCardView extends StatelessWidget {
  const DateCardView({
    super.key,
    required this.message,
    required this.plan,
    required this.myUid,
    required this.otherUid,
    required this.otherName,
    required this.planningPose,
    required this.onConfirm,
  });

  final ChatMessage message;
  final DatePlan plan;
  final String myUid;
  final String otherUid;
  final String otherName;
  final WingmanPose planningPose;

  final Future<void> Function(int version) onConfirm;

  int get _version => (message.payload['version'] as num?)?.toInt() ?? 0;
  bool get _current => _version == plan.version;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = message.payload;
    final confirmedHere = _current && plan.confirmed;
    final canConfirm = _current && plan.status == 'proposed' && !plan.confirmedByUser(myUid);

    return _CherryCard(
      color: BakeColors.softPink,
      faded: !_current,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedWingman(planningPose, size: 54, bob: false),
              const SizedBox(width: 8),
              Expanded(child: Text('Your cooking date', style: text.titleMedium?.copyWith(color: BakeColors.deepCherry))),
            ],
          ),
          const SizedBox(height: 8),
          Text('${p['dish'] ?? ''}', style: text.titleLarge?.copyWith(color: BakeColors.charcoal)),
          if ((p['dishWhy'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text('${p['dishWhy']}', style: text.bodyMedium?.copyWith(color: BakeColors.muted)),
          ],
          const SizedBox(height: 10),
          Text('📅 ${p['day'] ?? ''}   ·   🕖 ${p['time'] ?? ''}', style: text.bodyLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              _Tick(label: 'You', done: _current && plan.confirmedByUser(myUid)),
              const SizedBox(width: 14),
              _Tick(label: otherName, done: _current && plan.confirmedByUser(otherUid)),
            ],
          ),
          const SizedBox(height: 12),
          if (!_current)
            Text('This plan was updated — see the newer card below.', style: text.bodyMedium?.copyWith(color: BakeColors.muted))
          else if (confirmedHere)
            Text("It's a date! 🎉", style: text.titleMedium?.copyWith(color: BakeColors.leafGreen))
          else if (canConfirm)
            FilledButton(
              key: Key('confirm-date-$_version'),
              onPressed: () => onConfirm(_version),
              child: const Text('Confirm 🍒'),
            )
          else
            Text('Waiting for $otherName to confirm…', style: text.bodyMedium?.copyWith(color: BakeColors.muted)),
        ],
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 20, color: done ? BakeColors.leafGreen : BakeColors.muted),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class RecipeCardView extends StatelessWidget {
  const RecipeCardView({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = message.payload;
    final ingredients = List<String>.from(p['ingredients'] as List? ?? const []);
    final steps = List<String>.from(p['steps'] as List? ?? const []);
    return _CherryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('👩‍🍳 ${p['title'] ?? 'Recipe'}', style: text.titleLarge?.copyWith(color: BakeColors.deepCherry)),
          if (p['minutes'] != null) Text('⏱ ${p['minutes']} minutes', style: text.bodyMedium?.copyWith(color: BakeColors.muted)),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Material(
              color: Colors.transparent,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('See the full recipe', style: text.titleMedium),
                children: [
                  Align(alignment: Alignment.centerLeft, child: Text('Ingredients', style: text.titleMedium)),
                  for (final i in ingredients)
                    Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 3), child: Text('• $i'))),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: Text('Steps', style: text.titleMedium)),
                  for (var s = 0; s < steps.length; s++)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(padding: const EdgeInsets.only(top: 4), child: Text('${s + 1}. ${steps[s]}')),
                    ),
                ],
              ),
            ),
          ),
          if ((p['allergyNote'] as String?)?.isNotEmpty ?? false)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: BakeColors.softPink, borderRadius: BorderRadius.circular(12)),
              child: Text('⚠️ ${p['allergyNote']}', style: text.bodyMedium),
            ),
        ],
      ),
    );
  }
}

class SongCardView extends StatelessWidget {
  const SongCardView({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = message.payload;
    return _CherryCard(
      child: Row(
        children: [
          const Text('🎶', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p['title'] ?? ''}', style: text.titleMedium),
                Text('${p['artist'] ?? ''}', style: text.bodyMedium?.copyWith(color: BakeColors.deepCherry)),
                if ((p['why'] as String?)?.isNotEmpty ?? false)
                  Text('${p['why']}', style: text.bodyMedium?.copyWith(color: BakeColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The wingman's last words, then the chat belongs to the two of them.
class CherryGoodbyeView extends StatelessWidget {
  const CherryGoodbyeView({super.key, required this.message, required this.goodbyePose, this.name = 'Your wingman'});

  final ChatMessage message;
  final MascotPose goodbyePose;
  final String name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Mascot(goodbyePose, size: 110),
          const SizedBox(height: 6),
          Text(message.text, textAlign: TextAlign.center, style: text.titleMedium?.copyWith(color: BakeColors.deepCherry)),
          const SizedBox(height: 10),
          Text("$name has left the chat — it's just you two now 💛",
              style: text.bodyMedium?.copyWith(color: BakeColors.muted)),
        ],
      ),
    );
  }
}
