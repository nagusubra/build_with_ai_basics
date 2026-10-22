import 'package:flutter/services.dart';

/// How far Android has to turn a raw camera frame clockwise to make it upright.
///
/// The camera plugin hands over image-stream frames in the sensor's own
/// orientation, so a frame is only upright once the sensor's mounting angle and
/// the way the phone is being held are added together. iOS frames are already
/// upright, so this returns 0 there.
int uprightRotation({
  required int sensorOrientation,
  required DeviceOrientation orientation,
  required bool android,
}) {
  if (!android) return 0;
  return (sensorOrientation + _heldDegrees[orientation]!) % 360;
}

/// Clockwise turn of the phone itself, from its natural portrait position.
const _heldDegrees = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeRight: 90,
  DeviceOrientation.portraitDown: 180,
  // The top of the phone points left, which is a quarter turn anticlockwise.
  DeviceOrientation.landscapeLeft: 270,
};
