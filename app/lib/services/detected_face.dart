import 'dart:ui';

/// Eye height-to-width ratio at which we call an eye fully closed or fully open.
/// Tune on device if blinks are missed or false-triggered.
const double closedEyeRatio = 0.12;
const double openEyeRatio = 0.24;

/// Maps an eye's height-to-width ratio onto 0 (closed) … 1 (open).
double eyeOpenness(double ratio) =>
    ((ratio - closedEyeRatio) / (openEyeRatio - closedEyeRatio)).clamp(0.0, 1.0);

/// One face found in a photo or camera frame, in pixel coordinates of that image.
class DetectedFace {
  const DetectedFace({
    required this.box,
    this.yaw,
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.leftEye,
    this.rightEye,
  });

  /// Builds a face from the flat map the native channel (or the web bridge) sends.
  ///
  /// A backend may send the eye's openness directly (`leftEyeOpen`), or the
  /// raw height-to-width ratio it measured (`leftEyeRatio`), which is mapped here.
  factory DetectedFace.fromChannel(Map<Object?, Object?> m) {
    double? n(String key) => (m[key] as num?)?.toDouble();
    Offset? point(String prefix) {
      final x = n('${prefix}X'), y = n('${prefix}Y');
      return x == null || y == null ? null : Offset(x, y);
    }

    final leftRatio = n('leftEyeRatio');
    final rightRatio = n('rightEyeRatio');
    final leftOpen = n('leftEyeOpen');
    final rightOpen = n('rightEyeOpen');
    return DetectedFace(
      box: Rect.fromLTWH(n('x')!, n('y')!, n('width')!, n('height')!),
      yaw: n('yaw'),
      leftEyeOpen: leftOpen ?? (leftRatio == null ? null : eyeOpenness(leftRatio)),
      rightEyeOpen: rightOpen ?? (rightRatio == null ? null : eyeOpenness(rightRatio)),
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
