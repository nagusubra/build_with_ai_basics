import 'package:bakeout/services/frame_rotation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a portrait phone needs only the sensor angle', () {
    expect(
      uprightRotation(sensorOrientation: 270, orientation: DeviceOrientation.portraitUp, android: true),
      270,
    );
    expect(
      uprightRotation(sensorOrientation: 90, orientation: DeviceOrientation.portraitUp, android: true),
      90,
    );
  });

  test('holding the phone sideways takes a quarter turn off the sensor angle', () {
    expect(
      uprightRotation(sensorOrientation: 90, orientation: DeviceOrientation.landscapeLeft, android: true),
      0,
    );
    expect(
      uprightRotation(sensorOrientation: 90, orientation: DeviceOrientation.landscapeRight, android: true),
      180,
    );
  });

  test('upside down adds half a turn and wraps around', () {
    expect(
      uprightRotation(sensorOrientation: 90, orientation: DeviceOrientation.portraitDown, android: true),
      270,
    );
    expect(
      uprightRotation(sensorOrientation: 270, orientation: DeviceOrientation.portraitDown, android: true),
      90,
    );
  });

  test('iOS frames arrive upright, whatever the sensor angle', () {
    expect(
      uprightRotation(sensorOrientation: 270, orientation: DeviceOrientation.landscapeRight, android: false),
      0,
    );
  });
}
