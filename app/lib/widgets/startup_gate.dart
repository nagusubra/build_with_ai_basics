import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'mascot.dart';
import 'mascot_rive.dart';

/// Keeps one splash mounted until initialization and destination loading finish.
class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
    required this.initialize,
    required this.buildDestination,
  });

  final Future<void> Function() initialize;
  final Widget Function(VoidCallback onReady) buildDestination;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  Widget? _destination;
  bool _ready = false;
  bool _starting = true;
  bool _precacheStarted = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precacheStarted) return;
    _precacheStarted = true;
    final binding = WidgetsBinding.instance;
    binding.deferFirstFrame();
    precacheImage(
      const AssetImage(MascotMotion.welcomePosterAsset),
      context,
      onError: (error, stack) {
        debugPrint('Could not preload the splash poster: $error');
        debugPrintStack(stackTrace: stack);
      },
    ).whenComplete(binding.allowFirstFrame);
  }

  Future<void> _initialize() async {
    try {
      await widget.initialize();
      if (!mounted) return;
      setState(() {
        _starting = false;
        _destination = widget.buildDestination(_destinationReady);
      });
    } catch (error, stack) {
      debugPrint('BakeOut startup failed: $error');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = error;
      });
    }
  }

  void _destinationReady() {
    if (mounted && !_ready) setState(() => _ready = true);
  }

  void _retry() {
    setState(() {
      _starting = true;
      _error = null;
    });
    _initialize();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      _destination ?? const SizedBox.expand(),
      if (!_ready)
        Scaffold(
          key: const Key('startup-splash'),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AnimatedMascot(
                      key: Key('startup-mascot'),
                      MascotPose.duoWelcome,
                      size: 280,
                      bob: false,
                      animationAsset: MascotMotion.welcomeAsset,
                      posterAsset: MascotMotion.welcomePosterAsset,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'BakeOut',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      const Text(
                        "We couldn't start BakeOut. Check your connection and try again.",
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _starting ? null : _retry,
                        child: const Text('Try again'),
                      ),
                    ] else
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: BakeColors.cherryRed,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
