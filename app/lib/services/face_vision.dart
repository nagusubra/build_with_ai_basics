import 'dart:typed_data';

import 'package:camera/camera.dart';

import 'detected_face.dart';
import 'face_vision_native.dart' if (dart.library.js_interop) 'face_vision_web.dart' as backend;

export 'detected_face.dart';

/// Finds faces in photos and camera frames, on the device only.
///
/// iOS uses Apple Vision (through `AppDelegate.swift`), Android uses Google ML Kit
/// (through `FaceVisionChannel.kt`), and the web uses MediaPipe in the browser.
/// All three answer with the same [DetectedFace] shape.
abstract final class FaceVision {
  /// Detects faces in an encoded image (JPEG or PNG bytes).
  static Future<List<DetectedFace>> detectInBytes(Uint8List bytes) =>
      backend.detectInBytes(bytes);

  /// Detects faces in a live camera frame.
  ///
  /// Not available on the web, where frames come from the browser camera instead.
  /// Android hands over frames in the sensor's own orientation, so [rotationDegrees]
  /// says how far to turn the frame upright. iOS frames already are.
  static Future<List<DetectedFace>> detectInFrame(CameraImage frame, {int rotationDegrees = 0}) =>
      backend.detectInFrame(frame, rotationDegrees: rotationDegrees);
}
