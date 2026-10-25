import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/colors.dart';
import 'mascot.dart';

/// One stop on the tour: what to highlight (or nothing, for a centred card) and what to say.
class TourStep {
  const TourStep({
    required this.title,
    required this.body,
    required this.pose,
    this.target,
    this.part,
  });

  final String title;
  final String body;
  final MascotPose pose;
  final GlobalKey? target;

  /// Narrows the highlight to a slice of the target, e.g. one tab of the navigation bar.
  final Rect Function(Rect)? part;
}

/// A first-time walkthrough: the screen dims, the current area is lit, and the person's own
/// Jack or Jill explains it. "Skip tour" is always there.
class GuidedTour extends StatefulWidget {
  const GuidedTour({super.key, required this.steps, required this.onDone});

  final List<TourStep> steps;

  /// Called once, with whether the person skipped.
  final void Function(bool skipped) onDone;

  @override
  State<GuidedTour> createState() => _GuidedTourState();
}

class _GuidedTourState extends State<GuidedTour> {
  int _index = 0;
  bool _done = false;
  Rect? _hole;

  /// Measured after layout, so the highlight follows the real position of each area.
  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hole = _targetRect(widget.steps[_index]);
      final old = _hole;
      final moved =
          (hole == null) != (old == null) ||
          (hole != null &&
              old != null &&
              (hole.left - old.left).abs() +
                      (hole.top - old.top).abs() +
                      (hole.width - old.width).abs() +
                      (hole.height - old.height).abs() >
                  0.5);
      if (moved) setState(() => _hole = hole);
    });
  }

  void _finish(bool skipped) {
    if (_done) return;
    _done = true;
    widget.onDone(skipped);
  }

  void _next() {
    if (_index == widget.steps.length - 1) return _finish(false);
    setState(() => _index++);
  }

  Rect? _targetRect(TourStep step) {
    final target = step.target?.currentContext?.findRenderObject();
    final self = context.findRenderObject();
    if (target is! RenderBox ||
        self is! RenderBox ||
        !target.hasSize ||
        !target.attached) {
      return null;
    }
    final rect =
        target.localToGlobal(Offset.zero, ancestor: self) & target.size;
    return (step.part?.call(rect) ?? rect).inflate(6);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final last = _index == widget.steps.length - 1;
    _measure();
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final hole = step.target == null ? null : _hole;
        final centre = Rect.fromCenter(
          center: size.center(Offset.zero),
          width: 0,
          height: 0,
        );
        // Put the card on the roomier side of the highlight; if neither side fits it,
        // lay it over the bottom of the highlight. Never under the status bar or home indicator.
        final safe = MediaQuery.paddingOf(context);
        const needed = 200.0;
        double? top;
        double? bottom;
        if (hole != null) {
          final above = hole.top - safe.top;
          final below = size.height - safe.bottom - hole.bottom;
          if (below >= needed && below >= above) {
            top = hole.bottom + 14;
          } else if (above >= needed) {
            bottom = size.height - hole.top + 14;
          } else {
            bottom = safe.bottom + 16;
          }
        }
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.enter): _next,
            const SingleActivator(LogicalKeyboardKey.space): _next,
            const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                _finish(true),
          },
          child: Focus(
            autofocus: true,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: TweenAnimationBuilder<Rect?>(
                      tween: RectTween(end: hole ?? centre),
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                      builder: (context, rect, _) =>
                          CustomPaint(painter: _Spotlight(rect ?? centre)),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  left: 16,
                  right: 16,
                  top: top,
                  bottom: bottom,
                  child: hole == null
                      ? SizedBox(
                          height: size.height,
                          child: Center(child: _card(step, last)),
                        )
                      : _card(step, last),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card(TourStep step, bool last) {
    final text = Theme.of(context).textTheme;
    return Material(
          key: ValueKey(_index),
          color: Colors.white,
          elevation: 10,
          shadowColor: BakeColors.deepCherry.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Mascot(step.pose, size: 64, bob: false),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step.title, style: text.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            step.body,
                            style: text.bodyLarge?.copyWith(
                              color: BakeColors.charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < widget.steps.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 5),
                        width: i == _index ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? BakeColors.cherryRed
                              : BakeColors.line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    const Spacer(),
                    if (!last)
                      TextButton(
                        key: const Key('tour-skip'),
                        onPressed: () => _finish(true),
                        child: const Text('Skip tour'),
                      ),
                    const SizedBox(width: 4),
                    FilledButton(
                      key: const Key('tour-next'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      onPressed: _next,
                      child: Text(
                        last
                            ? 'Start exploring'
                            : (_index == 0 ? 'Show me' : 'Next'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .animate(key: ValueKey('card-$_index'))
        .fadeIn(duration: 250.ms)
        .moveY(begin: 8, end: 0);
  }
}

class _Spotlight extends CustomPainter {
  _Spotlight(this.hole);

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Path()..addRect(Offset.zero & size);
    final cut = Path()
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(18)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, dim, cut),
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );
    if (!hole.isEmpty) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(hole, const Radius.circular(18)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_Spotlight old) => old.hole != hole;
}
