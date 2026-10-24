import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/profile.dart';
import '../../services/camera_support.dart';
import '../../services/profile_service.dart';
import '../../services/verification_service.dart';
import '../../theme/colors.dart';
import '../../widgets/mascot.dart';
import '../../widgets/mascot_rive.dart';
import '../../widgets/onboarding.dart';
import 'live_check_view.dart';
import 'photos_screen.dart';

enum _Stage { intro, camera, checking, passed, failed }

/// Live selfie check against the main profile photo, entirely on the phone
/// (`prd.md > Photos and Verification`). The selfie is deleted right after comparing.
class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key, required this.profile, required this.profiles, this.onVerified});

  final UserProfile profile;
  final ProfileService profiles;

  /// Re-verifying from My profile: called once verified (onboarding moves on by itself).
  final VoidCallback? onVerified;

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _verifier = VerificationService();
  _Stage _stage = _Stage.intro;
  String? _reason;
  bool _hasCamera = true;

  @override
  void initState() {
    super.initState();
    cameraAvailable().then((ok) {
      if (mounted) setState(() => _hasCamera = ok);
    }).catchError((_) {
      if (mounted) setState(() => _hasCamera = false);
    });
  }

  @override
  void dispose() {
    _verifier.dispose();
    super.dispose();
  }

  MascotPose get _tryAgainPose => Wingman(widget.profile.cherryAvatar).tryAgain;
  MascotPose get _cheerPose => Wingman(widget.profile.cherryAvatar).cheer;

  Future<void> _onSelfie(Uint8List selfie) async {
    setState(() => _stage = _Stage.checking);
    try {
      final main = await widget.profiles.downloadPhoto(widget.profile.photos.first);
      final result = await _verifier.compare(profilePhotoBytes: main, selfieBytes: selfie);
      if (result.matched) {
        setState(() => _stage = _Stage.passed);
        HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 1600));
        await widget.profiles.markVerified(widget.profile.uid);
        widget.onVerified?.call();
      } else {
        setState(() {
          _stage = _Stage.failed;
          _reason = switch (result.problem) {
            FaceProblem.noFaceInPhoto => "We couldn't find a clear face in your main photo.",
            FaceProblem.noFaceInSelfie => "We couldn't see one clear face in the selfie.",
            FaceProblem.severalFacesInSelfie => 'There was more than one face in the selfie.',
            FaceProblem.unreadableImage => "That photo couldn't be read.",
            null => "The selfie didn't match your main photo.",
          };
        });
      }
    } catch (_) {
      setState(() {
        _stage = _Stage.failed;
        _reason = 'Something went wrong while checking. Please try again.';
      });
    }
  }

  /// Onboarding moves on without the badge; from My profile it just closes.
  Future<void> _skip() async {
    final reverifying = widget.onVerified != null;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip the selfie check?'),
        content: Text(
          reverifying
              ? 'You can verify any time from My profile.'
              : "You'll still appear in Discover, just without the verified badge — and some people only look at verified profiles. "
                  'You can verify any time from My profile.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Verify now')),
          TextButton(key: const Key('verify-skip-confirm'), onPressed: () => Navigator.pop(context, true), child: const Text('Skip for now')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    if (reverifying) {
      Navigator.of(context).pop();
      return;
    }
    try {
      await widget.profiles.skipVerification(widget.profile.uid);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't save that just now — please try again.")));
      }
    }
  }

  Future<void> _changePhotos() => Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => PhotosScreen(
          profile: widget.profile,
          profiles: widget.profiles,
          onDone: () => Navigator.pop(context),
        ),
      ));

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.camera:
        return Scaffold(
          appBar: AppBar(title: const Text('Selfie check')),
          body: LiveCheckView(onCaptured: _onSelfie, onCancel: () => setState(() => _stage = _Stage.intro)),
        );
      case _Stage.checking:
        return const Scaffold(body: CherryLoading(caption: 'Comparing with your photo…'));
      case _Stage.passed:
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedMascot(_cheerPose, size: 200),
                Text("You're verified ✓", style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: BakeColors.leafGreen)),
              ],
            ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
          ),
        );
      case _Stage.failed:
        return OnboardingPage(
          title: "Let's try that again",
          subtitle: '$_reason\n\nTips: face the light, take off sunglasses or a hat, and use a main photo where your face is clear.',
          top: Center(child: Mascot(_tryAgainPose, size: 170)),
          action: FilledButton(onPressed: () => setState(() => _stage = _Stage.camera), child: const Text('Try again')),
          secondaryAction: Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(onPressed: _changePhotos, child: const Text('Change my photos')),
              TextButton(key: const Key('verify-skip-after-fail'), onPressed: _skip, child: const Text('Skip for now')),
            ],
          ),
          child: const SizedBox.shrink(),
        );
      case _Stage.intro:
        return OnboardingPage(
          title: 'Quick selfie check',
          subtitle:
              "So everyone on BakeOut knows they're talking to a genuine person. You'll blink, turn your head, and look back — that's it.\n\n"
              'Your selfie stays on your phone: it’s compared with your main photo right here, then deleted. It’s never uploaded or shown to anyone.',
          progress: widget.onVerified == null ? 0.85 : null,
          onBack: widget.onVerified == null ? null : () => Navigator.pop(context),
          top: const Center(child: Mascot(MascotPose.duoVerify, size: 200)),
          action: FilledButton(
            key: const Key('verify-start'),
            onPressed: _hasCamera ? () => setState(() => _stage = _Stage.camera) : null,
            child: Text(_hasCamera ? "I'm ready" : 'No camera found'),
          ),
          secondaryAction: Column(
            children: [
              TextButton(key: const Key('verify-skip'), onPressed: _skip, child: const Text('Skip for now')),
              if (kDebugMode)
                TextButton(
                  key: const Key('verify-dev-skip'),
                  onPressed: () async {
                    await widget.profiles.markVerified(widget.profile.uid);
                    widget.onVerified?.call();
                  },
                  child: const Text('DEV ONLY: mark verified'),
                ),
            ],
          ),
          child: const SizedBox.shrink(),
        );
    }
  }
}
