import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// On a wide browser window, BakeOut sits in a phone-sized card on a soft cherry backdrop
/// (with a short introduction beside it when there's room), so it looks and feels like the
/// iPhone app instead of stretching edge to edge. Phones and narrow windows get the app full-bleed.
class WebFrame extends StatelessWidget {
  const WebFrame({super.key, required this.child});

  final Widget child;

  static const phoneWidth = 430.0;
  static const _maxPhoneHeight = 932.0;
  static const _minWideWidth = 600.0;
  static const _brandPanelWidth = 1020.0;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < _minWideWidth) return child;
        final roomy = box.maxHeight >= 700;
        final height = roomy
            ? math.min(box.maxHeight - 48, _maxPhoneHeight)
            : box.maxHeight;
        final media = MediaQuery.of(context);
        final phone = MediaQuery(
          data: media.copyWith(
            size: Size(phoneWidth, height),
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
          ),
          child: SizedBox(width: phoneWidth, height: height, child: child),
        );
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.8, -0.9),
              radius: 1.4,
              colors: [
                Color(0xFFFFE3E8),
                BakeColors.warmCream,
                Color(0xFFF5F8EE),
              ],
              stops: [0, 0.55, 1],
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (box.maxWidth >= _brandPanelWidth) ...[
                  const _BrandPanel(),
                  const SizedBox(width: 72),
                ],
                Container(
                  key: const Key('web-phone-frame'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(roomy ? 36 : 0),
                    border: roomy
                        ? Border.all(color: BakeColors.line, width: 1.5)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: BakeColors.deepCherry.withValues(alpha: 0.14),
                        blurRadius: 60,
                        offset: const Offset(0, 24),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(roomy ? 35 : 0),
                    child: phone,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget point(String emoji, String line) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BakeColors.line),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              line,
              style: text.titleMedium?.copyWith(color: BakeColors.charcoal),
            ),
          ),
        ],
      ),
    );
    return SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/mascots/cherry_duo_welcome_rest.png',
            height: 170,
          ),
          const SizedBox(height: 12),
          Text('BakeOut', style: text.displaySmall?.copyWith(fontSize: 44)),
          const SizedBox(height: 6),
          Text(
            'Love might just be one recipe away.',
            style: text.headlineSmall?.copyWith(color: BakeColors.charcoal),
          ),
          const SizedBox(height: 10),
          point('🍳', 'Profiles built around how you cook and eat'),
          point('🍒', 'Jack & Jill break the ice for you'),
          point('📅', 'Plan a virtual cooking date together'),
          const SizedBox(height: 22),
          Text(
            'Made for iPhone — this is the web version.',
            style: text.bodyMedium?.copyWith(color: BakeColors.muted),
          ),
        ],
      ),
    );
  }
}

/// iPhone-like scrolling everywhere: drag with a mouse or trackpad too, and no desktop scrollbars.
class BakeScrollBehavior extends MaterialScrollBehavior {
  const BakeScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
