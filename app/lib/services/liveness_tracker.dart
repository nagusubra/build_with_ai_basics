/// What one camera frame told us about the faces in it.
class FaceSnapshot {
  const FaceSnapshot({
    required this.faceCount,
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.headYaw,
  });

  final int faceCount;
  final double? leftEyeOpen;
  final double? rightEyeOpen;

  /// Degrees; positive and negative are left and right turns.
  final double? headYaw;
}

enum LivenessStep { findFace, blink, turn, lookBack, done }

/// Walks a person through: face the camera → blink → turn your head → look back.
/// A photo held up to the camera can't blink, and a video can't follow the order on cue.
class LivenessTracker {
  static const _eyesOpen = 0.6;
  static const _eyesClosed = 0.25;
  static const _frontalYaw = 10.0;
  static const _turnedYaw = 20.0;
  static const _steadyFramesNeeded = 3;

  LivenessStep _step = LivenessStep.findFace;
  int _steadyFrames = 0;
  bool _sawEyesClosed = false;
  String? _warning;

  LivenessStep get step => _step;
  bool get passed => _step == LivenessStep.done;
  String? get warning => _warning;

  String get prompt => switch (_step) {
        LivenessStep.findFace => 'Look straight at the camera',
        LivenessStep.blink => 'Now blink slowly',
        LivenessStep.turn => 'Turn your head to one side',
        LivenessStep.lookBack => 'And look back at the camera',
        LivenessStep.done => 'All done!',
      };

  double get progress => _step.index / LivenessStep.done.index;

  void reset() {
    _step = LivenessStep.findFace;
    _steadyFrames = 0;
    _sawEyesClosed = false;
    _warning = null;
  }

  void update(FaceSnapshot frame) {
    if (passed) return;

    if (frame.faceCount > 1) {
      reset();
      _warning = 'Only one face in the frame, please';
      return;
    }
    if (frame.faceCount == 0) {
      _warning = "We can't see your face";
      _steadyFrames = 0;
      return;
    }
    _warning = null;

    final yaw = (frame.headYaw ?? 0).abs();
    final left = frame.leftEyeOpen;
    final right = frame.rightEyeOpen;
    final eyesOpen = left != null && right != null && left > _eyesOpen && right > _eyesOpen;
    final eyesClosed = left != null && right != null && left < _eyesClosed && right < _eyesClosed;

    switch (_step) {
      case LivenessStep.findFace:
        _steadyFrames = (yaw < _frontalYaw && eyesOpen) ? _steadyFrames + 1 : 0;
        if (_steadyFrames >= _steadyFramesNeeded) _step = LivenessStep.blink;
      case LivenessStep.blink:
        if (eyesClosed) _sawEyesClosed = true;
        if (_sawEyesClosed && eyesOpen) _step = LivenessStep.turn;
      case LivenessStep.turn:
        if (yaw > _turnedYaw) _step = LivenessStep.lookBack;
      case LivenessStep.lookBack:
        if (yaw < _frontalYaw && eyesOpen) _step = LivenessStep.done;
      case LivenessStep.done:
        break;
    }
  }
}
