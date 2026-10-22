import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../services/detected_face.dart';
import '../../services/liveness_tracker.dart';
import '../../theme/colors.dart';

@JS('bakeoutVision.startCamera')
external JSPromise<JSAny?> _visionStartCamera(web.HTMLVideoElement video, JSFunction onFrame);

@JS('bakeoutVision.stopCamera')
external void _visionStopCamera();

@JS('bakeoutVision.captureStill')
external JSPromise<JSString?> _visionCaptureStill();

const _viewType = 'bakeout/selfie-camera';

web.HTMLVideoElement? _videoElement;
bool _registered = false;

/// The browser owns the camera on the web, so the preview is a plain video element
/// that MediaPipe reads frames from.
web.HTMLVideoElement _video() {
  final existing = _videoElement;
  if (existing != null) return existing;
  final video = web.HTMLVideoElement()
    ..autoplay = true
    ..muted = true
    ..setAttribute('playsinline', '');
  video.style
    ..objectFit = 'cover'
    ..width = '100%'
    ..height = '100%';
  _videoElement = video;
  if (!_registered) {
    _registered = true;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => video);
  }
  return video;
}

/// Front-camera live check in the browser. When the person has blinked, turned,
/// and looked back, it takes one still and hands its bytes to [onCaptured].
///
/// The selfie never leaves the device: it is compared in the browser and then dropped.
class LiveCheckView extends StatefulWidget {
  const LiveCheckView({super.key, required this.onCaptured, this.onCancel});

  final ValueChanged<Uint8List> onCaptured;
  final VoidCallback? onCancel;

  @override
  State<LiveCheckView> createState() => _LiveCheckViewState();
}

class _LiveCheckViewState extends State<LiveCheckView> {
  final _tracker = LivenessTracker();
  bool _busy = false;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      await _visionStartCamera(_video(), _onFrame.toJS).toDart;
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'We could not open the camera. Check that this site is allowed to use it.');
      }
    }
  }

  void _onFrame(JSString payload) {
    if (_busy || _capturing || !mounted) return;
    _busy = true;
    try {
      final decoded = jsonDecode(payload.toDart) as List<dynamic>;
      final faces = decoded
          .map((e) => DetectedFace.fromChannel((e as Map<dynamic, dynamic>).cast<Object?, Object?>()))
          .toList();
      final face = faces.length == 1 ? faces.first : null;
      _tracker.update(FaceSnapshot(
        faceCount: faces.length,
        leftEyeOpen: face?.leftEyeOpen,
        rightEyeOpen: face?.rightEyeOpen,
        headYaw: face?.yaw,
      ));
      setState(() {});
      if (_tracker.passed) _capture();
    } finally {
      _busy = false;
    }
  }

  Future<void> _capture() async {
    if (_capturing) return;
    _capturing = true;
    try {
      final base64 = (await _visionCaptureStill().toDart)!;
      widget.onCaptured(base64Decode(base64.toDart));
    } catch (e) {
      if (mounted) setState(() => _error = 'That photo could not be taken. Please try again.');
    }
  }

  @override
  void dispose() {
    _visionStopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ),
      );
    }

    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const HtmlElementView(viewType: _viewType),
                  if (_capturing)
                    Container(
                      color: Colors.white54,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(color: BakeColors.cherryRed),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Column(
            children: [
              Text(_tracker.prompt, style: text.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              SizedBox(
                height: 22,
                child: Text(
                  _tracker.warning ?? '',
                  style: text.bodyMedium?.copyWith(color: BakeColors.deepCherry),
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _tracker.progress,
                  minHeight: 8,
                  color: BakeColors.leafGreen,
                  backgroundColor: BakeColors.softPink,
                ),
              ),
              if (widget.onCancel != null) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
