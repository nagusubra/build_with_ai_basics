import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';

import 'detected_face.dart';

@JS('bakeoutVision.init')
external JSPromise<JSAny?> _visionInit();

@JS('bakeoutVision.detectImageBytes')
external JSPromise<JSString?> _visionDetect(String base64);

bool _ready = false;

/// MediaPipe's eye aspect ratio for a wide-open eye, and for a closed one.
/// Measured against public-domain portraits: about 0.20 open, under 0.08 closed.
const double _openEar = 0.20;
const double _closedEar = 0.06;

/// Loads the browser-side MediaPipe detector. Safe to call more than once.
Future<void> ensureVisionReady() async {
  if (_ready) return;
  await _visionInit().toDart;
  _ready = true;
}

/// Detects faces in an encoded image using MediaPipe in the browser.
Future<List<DetectedFace>> detectInBytes(Uint8List bytes) async {
  await ensureVisionReady();
  final json = (await _visionDetect(base64Encode(bytes)).toDart)!;
  final decoded = jsonDecode(json.toDart) as List<dynamic>;
  return decoded
      .map((e) => _face((e as Map<dynamic, dynamic>).cast<Object?, Object?>()))
      .toList();
}

/// The browser reads camera frames itself, so there is no Dart-side frame to pass.
Future<List<DetectedFace>> detectInFrame(CameraImage frame) =>
    throw UnsupportedError('Live frames on the web come from the browser camera bridge.');

/// MediaPipe measures the eye opening on its own scale, so it is mapped onto the
/// 0 (closed) to 1 (open) the liveness check works with.
double _openness(double ear) =>
    ((ear - _closedEar) / (_openEar - _closedEar)).clamp(0.0, 1.0);

DetectedFace _face(Map<Object?, Object?> m) {
  double? n(String key) => (m[key] as num?)?.toDouble();
  Offset? point(String prefix) {
    final x = n('${prefix}X'), y = n('${prefix}Y');
    return x == null || y == null ? null : Offset(x, y);
  }

  final leftEar = n('leftEyeEar');
  final rightEar = n('rightEyeEar');
  return DetectedFace(
    box: Rect.fromLTWH(n('x')!, n('y')!, n('width')!, n('height')!),
    yaw: n('yaw'),
    leftEyeOpen: leftEar == null ? null : _openness(leftEar),
    rightEyeOpen: rightEar == null ? null : _openness(rightEar),
    leftEye: point('leftEye'),
    rightEye: point('rightEye'),
  );
}
