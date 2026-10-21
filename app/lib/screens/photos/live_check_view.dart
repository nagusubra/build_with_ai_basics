import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../services/face_vision.dart';
import '../../services/liveness_tracker.dart';
import '../../theme/colors.dart';

/// Front-camera live check. When the person has blinked, turned, and looked back,
/// it takes one still and hands its path to [onCaptured]. The caller must delete it.
class LiveCheckView extends StatefulWidget {
  const LiveCheckView({super.key, required this.onCaptured, this.onCancel});

  final ValueChanged<String> onCaptured;
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
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
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

  Future<void> _onFrame(CameraImage frame) async {
    if (_busy || _capturing) return;
    _busy = true;
    try {
      final faces = await FaceVision.detectInFrame(frame);
      final face = faces.length == 1 ? faces.first : null;
      _tracker.update(FaceSnapshot(
        faceCount: faces.length,
        leftEyeOpen: face?.leftEyeOpen,
        rightEyeOpen: face?.rightEyeOpen,
        headYaw: face?.yaw,
      ));
      if (!mounted) return;
      setState(() {});
      if (_tracker.passed) await _capture();
    } finally {
      _busy = false;
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || _capturing) return;
    _capturing = true;
    await camera.stopImageStream();
    final still = await camera.takePicture();
    if (!mounted) {
      await File(still.path).delete();
      return;
    }
    widget.onCaptured(still.path);
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
          child: Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
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
