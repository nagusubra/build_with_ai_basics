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
/// is unavailable: a failed or slow runtime init, reduced motion, or a bad artboard.
abstract final class MascotMotion {
  static const asset = 'assets/mascots/rive/cherry_mascots.riv';
  static const welcomeAsset = 'assets/mascots/rive/cherry_duo_welcome.riv';
  static const welcomePosterAsset =
      'assets/mascots/cherry_duo_welcome_rest.png';
  static const jackAsset = 'assets/mascots/rive/jack_wingman.riv';
  static const jillAsset = 'assets/mascots/rive/jill_wingwoman.riv';
  static const _enabled = bool.fromEnvironment(
    'MASCOT_RIVE',
    defaultValue: true,
  );

  /// On the web the runtime is a WASM download from a CDN; startup never waits longer than this.
  static const _webInitTimeout = Duration(seconds: 6);

  static final _changes = _MotionChanges();

  /// Notifies when [available] may have changed.
  static Listenable get changes => _changes;
  static bool _initialized = false;
  static bool _nativeReady = false;
  static Future<void>? _initialization;
  static final Map<String, FileLoader> _loaders = {};

  static bool get available => _enabled && _initialized && _nativeReady;

  static Future<void> init() => _initialization ??= _init();

  static Future<void> _init() async {
    if (_enabled) {
      try {
        final runtime = RiveNative.init();
        _nativeReady = kIsWeb
            ? await runtime.timeout(_webInitTimeout, onTimeout: () {
                runtime.then(_lateWebRuntime, onError: (_) {});
                return false;
              })
            : await runtime;
        if (!_nativeReady) {
          debugPrint('Rive initialization unavailable; showing mascot posters.');
        }
      } catch (error, stack) {
        debugPrint('Rive initialization failed: $error');
        debugPrintStack(stackTrace: stack);
        _nativeReady = false;
      }
    }
    _initialized = true;
    _changes.notify();
  }

  /// A slow network finished the WASM download after startup gave up: animate from now on.
  static void _lateWebRuntime(bool ready) {
    if (!ready || _nativeReady) return;
    _nativeReady = true;
    _changes.notify();
  }

  static FileLoader loaderFor(String asset) => _loaders.putIfAbsent(
    asset,
      () => FileLoader.fromAsset(
        asset,
        // The layered rigs (duo welcome, the Jack/Jill wingmen) need no
        // Rive-only effects. Paint them directly into Flutter's canvas to
        // avoid blank Android texture handoffs.
        riveFactory: asset == welcomeAsset ||
                asset == jackAsset ||
                asset == jillAsset ||
                !_nativeReady
            ? Factory.flutter
            : Factory.rive,
      ),
  );
}

class _MotionChanges extends ChangeNotifier {
  void notify() => notifyListeners();
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: MascotMotion.changes,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final artboard = pose.riveArtboard;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (artboard == null || reduceMotion || !MascotMotion.available) {
      final asset = posterAsset;
      if (asset == null) {
        return Mascot(pose, size: size, bob: bob && !reduceMotion);
      }
      return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
    }
    return ArtboardMascot(
      animationAsset: animationAsset,
      artboard: artboard,
      size: size,
      posterAsset: posterAsset,
      fallback: Mascot(pose, size: size, bob: bob),
    );
  }
}

/// A wingman rig clip (`Wingman.rig`): the animated Jack/Jill artboard when
/// possible, its matching static rest poster otherwise.
class AnimatedWingman extends StatelessWidget {
  const AnimatedWingman(this.pose, {super.key, this.size = 220, this.bob = true});

  final WingmanPose pose;
  final double size;
  final bool bob;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: MascotMotion.changes,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion || !MascotMotion.available) {
      return Image.asset(pose.posterAsset,
          width: size, height: size, fit: BoxFit.contain);
    }
    return ArtboardMascot(
      animationAsset: pose.animationAsset,
      artboard: pose.artboard,
      size: size,
      posterAsset: pose.posterAsset,
      fallback: Image.asset(pose.posterAsset,
          width: size, height: size, fit: BoxFit.contain),
    );
  }
}

/// One artboard of one .riv asset, with [fallback] shown while loading or when
/// the artboard fails to load. Native availability and reduced motion are
/// checked before constructing this.
class ArtboardMascot extends StatelessWidget {
  const ArtboardMascot({
    super.key,
    required this.animationAsset,
    required this.artboard,
    required this.size,
    required this.fallback,
    this.posterAsset,
  });

  final String animationAsset;
  final String artboard;
  final double size;
  final Widget fallback;

  /// Shown while the asset is still loading; [fallback] covers load failures.
  final String? posterAsset;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: MascotMotion.changes,
    builder: (context, _) => SizedBox(
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
          RiveFailed() => fallback,
          RiveLoading() => posterAsset != null
              ? Image.asset(
                  posterAsset!,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                )
              : fallback,
        },
      ),
    ),
  );
}
