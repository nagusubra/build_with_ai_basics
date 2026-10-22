import 'package:bakeout/services/face_vision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('eye openness maps the closed and open ratios to 0 and 1, clamped', () {
    expect(eyeOpenness(closedEyeRatio), 0);
    expect(eyeOpenness(openEyeRatio), 1);
    expect(eyeOpenness(0.02), 0);
    expect(eyeOpenness(0.5), 1);
    expect(eyeOpenness((closedEyeRatio + openEyeRatio) / 2), closeTo(0.5, 1e-9));
  });

  test('channel maps become faces with a top-left box and eye openness', () {
    final face = DetectedFace.fromChannel({
      'x': 10.0,
      'y': 20.0,
      'width': 100.0,
      'height': 120.0,
      'yaw': -25.0,
      'leftEyeRatio': openEyeRatio,
      'rightEyeRatio': closedEyeRatio,
    });
    expect(face.box.left, 10);
    expect(face.box.top, 20);
    expect(face.box.width, 100);
    expect(face.yaw, -25);
    expect(face.leftEyeOpen, 1);
    expect(face.rightEyeOpen, 0);
  });

  test('missing landmarks leave eye openness unknown', () {
    final face = DetectedFace.fromChannel({'x': 0, 'y': 0, 'width': 1, 'height': 1});
    expect(face.leftEyeOpen, isNull);
    expect(face.yaw, isNull);
  });

  test('an openness the backend measured itself wins over the raw ratio', () {
    final face = DetectedFace.fromChannel({
      'x': 0.0,
      'y': 0.0,
      'width': 1.0,
      'height': 1.0,
      'leftEyeOpen': 0.9,
      'rightEyeOpen': 0.1,
      'leftEyeRatio': openEyeRatio,
      'rightEyeRatio': closedEyeRatio,
    });
    expect(face.leftEyeOpen, 0.9);
    expect(face.rightEyeOpen, 0.1);
  });
}
