import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

/// Eye height-to-width ratio at which we call an eye fully closed or fully open.
/// Tune on device if blinks are missed or false-triggered.
const double closedEyeRatio = 0.12;
const double openEyeRatio = 0.24;

/// Maps an eye's height-to-width ratio onto 0 (closed) … 1 (open).
double eyeOpenness(double ratio) =>
    ((ratio - closedEyeRatio) / (openEyeRatio - closedEyeRatio)).clamp(0.0, 1.0);

class DetectedFace {
  const DetectedFace({
    required this.box,
    this.yaw,
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.leftEye,
    this.rightEye,
  });

  factory DetectedFace.fromChannel(Map<Object?, Object?> m) {
    double? n(String key) => (m[key] as num?)?.toDouble();
    Offset? point(String prefix) {
      final x = n('${prefix}X'), y = n('${prefix}Y');
      return x == null || y == null ? null : Offset(x, y);
    }

    final left = n('leftEyeRatio');
    final right = n('rightEyeRatio');
    return DetectedFace(
      box: Rect.fromLTWH(n('x')!, n('y')!, n('width')!, n('height')!),
      yaw: n('yaw'),
      leftEyeOpen: left == null ? null : eyeOpenness(left),
      rightEyeOpen: right == null ? null : eyeOpenness(right),
      leftEye: point('leftEye'),
      rightEye: point('rightEye'),
    );
  }

  /// Pixel box, top-left origin, in the upright image.
  final Rect box;
  final double? yaw;
  final double? leftEyeOpen;
  final double? rightEyeOpen;

  /// Eye centres in the same pixel space as [box].
  final Offset? leftEye;
  final Offset? rightEye;
}

/// Apple Vision face detection through `AppDelegate.swift`. Runs on the phone only.
abstract final class FaceVision {
  static const _channel = MethodChannel('bakeout/face_vision');

  static Future<List<DetectedFace>> detectInFile(String uprightImagePath) =>
      _detect('detectInFile', {'path': uprightImagePath});

  /// Expects a BGRA camera frame, already upright.
  static Future<List<DetectedFace>> detectInFrame(CameraImage frame) {
    final plane = frame.planes.first;
    return _detect('detectInFrame', {
      'bytes': plane.bytes,
      'width': frame.width,
      'height': frame.height,
      'bytesPerRow': plane.bytesPerRow,
    });
  }

  static Future<List<DetectedFace>> _detect(String method, Map<String, Object> args) async {
    final faces = await _channel.invokeListMethod<Map<Object?, Object?>>(method, args) ?? const [];
    return faces.map(DetectedFace.fromChannel).toList();
  }
}
