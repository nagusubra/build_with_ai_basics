import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:rive/rive.dart'
    show
        ArtboardNamed,
        Factory,
        FileLoader,
        Fit,
        RiveFailed,
        RiveLoaded,
        RiveLoading,
        RiveNative,
        RiveWidget,
        RiveWidgetBuilder;

import 'mascot.dart';

/// Loads the shared mascot Rive file and falls back to the PNG when anything
/// is unavailable: web, a failed native init, reduced motion, or a bad artboard.
abstract final class MascotMotion {
  static const asset = 'assets/mascots/rive/cherry_mascots.riv';
  static const _enabled = bool.fromEnvironment('MASCOT_RIVE', defaultValue: true);

  static bool _initialised = false;
  static bool _nativeReady = false;

  static bool get available =>
      _enabled && !kIsWeb && _initialised && _nativeReady;

  static Future<void> init() async {
    if (!_enabled || kIsWeb) return;
    try {
      _nativeReady = await RiveNative.init();
    } catch (_) {
      _nativeReady = false;
    }
    _initialised = true;
  }

  static final FileLoader loader = FileLoader.fromAsset(
    asset,
    riveFactory: _nativeReady ? Factory.rive : Factory.flutter,
  );
}

/// A hero mascot: Rive idle motion when possible, the existing PNG otherwise.
class AnimatedMascot extends StatelessWidget {
  const AnimatedMascot(
    this.pose, {
    super.key,
    this.size = 220,
    this.bob = true,
  });

  final MascotPose pose;
  final double size;
  final bool bob;

  @override
  Widget build(BuildContext context) {
    final artboard = pose.riveArtboard;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (artboard == null || reduceMotion || !MascotMotion.available) {
      return Mascot(pose, size: size, bob: bob);
    }

    return SizedBox(
      width: size,
      height: size,
      child: RiveWidgetBuilder(
        fileLoader: MascotMotion.loader,
        artboardSelector: ArtboardNamed(artboard),
        builder: (context, state) => switch (state) {
          RiveLoaded(:final controller) => RepaintBoundary(
              child: RiveWidget(controller: controller, fit: Fit.contain),
            ),
          RiveFailed() => Mascot(pose, size: size, bob: bob),
          RiveLoading() => Mascot(pose, size: size, bob: false),
        },
      ),
    );
  }
}
