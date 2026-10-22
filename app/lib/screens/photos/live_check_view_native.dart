import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/face_vision.dart';
import '../../services/frame_rotation.dart';
import '../../services/liveness_tracker.dart';
import '../../theme/colors.dart';

/// Front-camera live check on iOS and Android. When the person has blinked, turned,
/// and looked back, it takes one still and hands its bytes to [onCaptured].
///
/// The selfie never leaves the device: it is compared on the phone and then dropped.
class LiveCheckView extends StatefulWidget {
  const LiveCheckView({super.key, required this.onCaptured, this.onCancel});

  final ValueChanged<Uint8List> onCaptured;
  final VoidCallback? onCancel;

  @override
  State<LiveCheckView> createState() => _LiveCheckViewState();
}

class _LiveCheckViewState extends State<LiveCheckView> {
  final _tracker = LivenessTracker();
  CameraController? _camera;
  bool _busy = false;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera found on this device');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        // Apple Vision wants BGRA; ML Kit takes NV21, which CameraX hands over as one plane.
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
      await controller.startImageStream(_onFrame);
    } on CameraException catch (e) {
      setState(() => _error = e.description ?? 'Camera unavailable');
    } on StateError {
      setState(() => _error = 'No camera found on this device');
    }
  }

  /// How far Android has to turn the raw frame to make it upright.
  int _frameRotation(CameraController controller) => uprightRotation(
        sensorOrientation: controller.description.sensorOrientation,
        orientation: controller.value.deviceOrientation,
        android: Platform.isAndroid,
      );

  Future<void> _onFrame(CameraImage frame) async {
    // Frames keep arriving while one is being read, so late ones are skipped.
    if (_busy || _capturing) return;
    _busy = true;
    try {
      final camera = _camera;
      if (camera == null) return;
      final before = _visibleState;
      final faces = await FaceVision.detectInFrame(frame, rotationDegrees: _frameRotation(camera));
      final face = faces.length == 1 ? faces.first : null;
      _tracker.update(FaceSnapshot(
        faceCount: faces.length,
        leftEyeOpen: face?.leftEyeOpen,
        rightEyeOpen: face?.rightEyeOpen,
        headYaw: face?.yaw,
      ));
      if (!mounted) return;
      // Frames arrive many times a second, so only rebuild when the screen changes.
      if (_visibleState != before) setState(() {});
      if (_tracker.passed) await _capture();
    } finally {
      _busy = false;
    }
  }

  String get _visibleState => '${_tracker.prompt}|${_tracker.warning}|${_tracker.progress}|$_capturing';

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      await camera.stopImageStream();
      final still = await camera.takePicture();
      final bytes = await still.readAsBytes();
      // The selfie is compared in memory, so the temp file goes right away.
      try {
        await File(still.path).delete();
      } catch (_) {
        // A leftover temp file is not worth failing the check over.
      }
      if (!mounted) return;
      widget.onCaptured(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = 'That photo could not be taken. Please try again.';
      });
    }
  }

  Future<void> _retry() async {
    final old = _camera;
    _camera = null;
    _tracker.reset();
    setState(() {
      _error = null;
      _capturing = false;
    });
    await old?.dispose();
    await _start();
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              FilledButton(onPressed: _retry, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: BakeColors.cherryRed));
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
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: camera.value.previewSize?.height ?? 1,
                      height: camera.value.previewSize?.width ?? 1,
                      child: CameraPreview(camera),
                    ),
                  ),
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
