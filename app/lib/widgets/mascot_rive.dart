import 'package:flutter/foundation.dart' show kIsWeb, ValueListenable;
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
  static const welcomeAsset = 'assets/mascots/rive/cherry_duo_welcome.riv';
  static const welcomePosterAsset =
      'assets/mascots/cherry_duo_welcome_rest.png';
  static const _enabled = bool.fromEnvironment(
    'MASCOT_RIVE',
    defaultValue: true,
  );

  static final _initialized = ValueNotifier(false);
  static ValueListenable<bool> get initialized => _initialized;
  static bool _nativeReady = false;
  static Future<void>? _initialization;
  static final Map<String, FileLoader> _loaders = {};

  static bool get available =>
      _enabled && !kIsWeb && _initialized.value && _nativeReady;

  static Future<void> init() => _initialization ??= _init();

  static Future<void> _init() async {
    if (!_enabled || kIsWeb) {
      _initialized.value = true;
      return;
    }
    try {
      _nativeReady = await RiveNative.init();
      if (!_nativeReady) {
        debugPrint('Rive initialization unavailable; showing mascot posters.');
      }
    } catch (error, stack) {
      debugPrint('Rive initialization failed: $error');
      debugPrintStack(stackTrace: stack);
      _nativeReady = false;
    }
    _initialized.value = true;
  }

  static FileLoader loaderFor(String asset) => _loaders.putIfAbsent(
    asset,
    () => FileLoader.fromAsset(
      asset,
      // The layered duo needs no Rive-only effects. Paint it directly into
      // Flutter's canvas to avoid blank Android texture handoffs.
      riveFactory: asset == welcomeAsset || !_nativeReady
          ? Factory.flutter
          : Factory.rive,
    ),
  );
}

/// A hero mascot: Rive idle motion when possible, the existing PNG otherwise.
class AnimatedMascot extends StatelessWidget {
  const AnimatedMascot(
    this.pose, {
    super.key,
    this.size = 220,
    this.bob = true,
    this.animationAsset = MascotMotion.asset,
    this.posterAsset,
  });

  final MascotPose pose;
  final double size;
  final bool bob;
  final String animationAsset;
  final String? posterAsset;

  Widget _poster({required bool bob}) {
    final asset = posterAsset;
    if (asset == null) return Mascot(pose, size: size, bob: bob);
    return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: MascotMotion.initialized,
    builder: (context, _, _) => _buildMascot(context),
  );

  Widget _buildMascot(BuildContext context) {
    final artboard = pose.riveArtboard;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (artboard == null || reduceMotion || !MascotMotion.available) {
      return _poster(bob: bob && !reduceMotion);
    }

    return SizedBox(
      width: size,
      height: size,
      child: RiveWidgetBuilder(
        fileLoader: MascotMotion.loaderFor(animationAsset),
        artboardSelector: ArtboardNamed(artboard),
        onFailed: (error, stack) {
          debugPrint('Could not load mascot animation $animationAsset: $error');
          debugPrintStack(stackTrace: stack);
        },
        builder: (context, state) => switch (state) {
          RiveLoaded(:final controller) => RepaintBoundary(
            child: RiveWidget(controller: controller, fit: Fit.contain),
          ),
          RiveFailed() => _poster(bob: bob),
          RiveLoading() => _poster(bob: false),
        },
      ),
    );
  }
}
