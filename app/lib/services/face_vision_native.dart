import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'detected_face.dart';

const _channel = MethodChannel('bakeout/face_vision');

/// Apple Vision on iOS and Google ML Kit on Android, both reached over the
/// `bakeout/face_vision` method channel.
Future<List<DetectedFace>> detectInBytes(Uint8List bytes) async {
  final file = File('${Directory.systemTemp.path}/bakeout_face_${DateTime.now().microsecondsSinceEpoch}.jpg');
  await file.writeAsBytes(bytes);
  try {
    return await _detect('detectInFile', {'path': file.path});
  } finally {
    try {
      await file.delete();
    } catch (_) {
      // A leftover temp file is not worth failing the check over.
    }
  }
}

/// Expects a camera frame that is already upright.
///
/// iOS hands over BGRA; Android hands over NV21, so the format travels with the bytes.
Future<List<DetectedFace>> detectInFrame(CameraImage frame) {
  final plane = frame.planes.first;
  return _detect('detectInFrame', {
    'bytes': plane.bytes,
    'width': frame.width,
    'height': frame.height,
    'bytesPerRow': plane.bytesPerRow,
    'format': Platform.isAndroid ? 'nv21' : 'bgra',
  });
}

Future<List<DetectedFace>> _detect(String method, Map<String, Object> args) async {
  final faces = await _channel.invokeListMethod<Map<Object?, Object?>>(method, args) ?? const [];
  return faces.map(DetectedFace.fromChannel).toList();
}
