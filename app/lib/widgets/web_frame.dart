import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// On a wide browser window, BakeOut runs inside an iPhone (body, Dynamic Island, status bar,
/// home indicator) on a soft cherry backdrop, with a short introduction beside it when there's
/// room. Phones and narrow windows get the app full-bleed.
class WebFrame extends StatelessWidget {
  const WebFrame({super.key, required this.child});

  final Widget child;

  /// iPhone 15 Pro's screen in points, and the safe areas the app keeps clear.
  static const screen = Size(393, 852);
  static const _topInset = 54.0;
  static const _bottomInset = 34.0;
  static const _bezel = 12.0;
  static const _device = Size(393 + 2 * _bezel, 852 + 2 * _bezel);
  static const _minWideWidth = 600.0;
  static const _brandPanelWidth = 1020.0;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < _minWideWidth) return child;
        final media = MediaQuery.of(context);
        final phone = MediaQuery(
          data: media.copyWith(
            size: screen,
            padding: const EdgeInsets.only(
              top: _topInset,
              bottom: _bottomInset,
            ),
            viewPadding: const EdgeInsets.only(
              top: _topInset,
              bottom: _bottomInset,
            ),
          ),
          child: SizedBox.fromSize(size: screen, child: child),
        );
        // Shrink the whole phone, never crop it, when the window is short.
        final height = math.min(box.maxHeight - 40, _device.height);
        final width = height * _device.width / _device.height;
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
                  const Material(type: MaterialType.transparency, child: _BrandPanel()),
                  const SizedBox(width: 72),
                ],
                SizedBox(
                  key: const Key('web-phone-frame'),
                  width: width,
                  height: height,
                  child: FittedBox(
                    child: SizedBox.fromSize(
                      size: _device,
                      child: _IPhone(
                        bezel: _bezel,
                        topInset: _topInset,
                        child: phone,
                      ),
                    ),
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

/// An iPhone 15 Pro-style body around [child]: titanium edge, side buttons, Dynamic Island,
/// status bar, and home indicator. The status bar and island sit over the app's top safe area.
class _IPhone extends StatelessWidget {
  const _IPhone({
    required this.bezel,
    required this.topInset,
    required this.child,
  });

  final double bezel;
  final double topInset;
  final Widget child;

  static const _body = Color(0xFF1B1B1D);
  static const _edge = Color(0xFF4A4A4F);

  Widget _button(double height) => Container(
    width: 4,
    height: height,
    decoration: BoxDecoration(
      color: _edge,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(left: -3, top: 130, child: _button(30)),
        Positioned(left: -3, top: 185, child: _button(58)),
        Positioned(left: -3, top: 255, child: _button(58)),
        Positioned(right: -3, top: 215, child: _button(90)),
        Positioned.fill(
          child: Container(
            padding: EdgeInsets.all(bezel - 2.5),
            decoration: BoxDecoration(
              color: _body,
              borderRadius: BorderRadius.circular(66),
              border: Border.all(color: _edge, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: BakeColors.deepCherry.withValues(alpha: 0.18),
                  blurRadius: 70,
                  offset: const Offset(0, 30),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(54),
              child: Stack(
                children: [
                  Positioned.fill(child: child),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: topInset,
                    child: const IgnorePointer(
                      child: Material(
                        type: MaterialType.transparency,
                        child: _StatusBar(),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 11,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 124,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 134,
                          height: 5,
                          decoration: BoxDecoration(
                            color: BakeColors.charcoal.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 9:41, signal, Wi-Fi, and battery, the way every iPhone promo shows it.
class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    const ink = BakeColors.charcoal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(44, 16, 30, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '9:41',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ink,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Row(
              children: [
                Icon(Icons.signal_cellular_alt_rounded, size: 17, color: ink),
                SizedBox(width: 4),
                Icon(Icons.wifi_rounded, size: 17, color: ink),
                SizedBox(width: 5),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                Container(
                  width: 25,
                  height: 12,
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: ink.withValues(alpha: 0.45),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(3.5),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Container(
                  width: 1.5,
                  height: 4,
                  margin: const EdgeInsets.only(left: 1),
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget point(String emoji, String title, String line) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleMedium?.copyWith(color: BakeColors.charcoal),
                ),
                Text(
                  line,
                  style: text.bodyMedium?.copyWith(color: BakeColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    Widget platform(IconData icon, String name) => Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BakeColors.charcoal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
    return SizedBox(
      width: 400,
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
          point(
            '🍳',
            'Food-first profiles',
            'Your cooking style, favourite cuisines, and signature dish.',
          ),
          point(
            '🍒',
            'Jack & Jill, your wingmen',
            'They break the ice and keep the conversation going.',
          ),
          point(
            '📅',
            'A real cooking date',
            'Dish, day, time, a recipe and a song — then they leave you to it.',
          ),
          point(
            '✅',
            'Genuine people',
            'A quick selfie check, done right on your device.',
          ),
          const SizedBox(height: 24),
          Text(
            'Available on',
            style: text.labelLarge?.copyWith(
              color: BakeColors.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              platform(Icons.apple, 'iPhone'),
              platform(Icons.android, 'Android'),
              platform(Icons.language_rounded, 'Web'),
            ],
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
