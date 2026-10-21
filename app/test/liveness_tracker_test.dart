import 'package:bakeout/services/liveness_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

const _open = FaceSnapshot(faceCount: 1, leftEyeOpen: 0.95, rightEyeOpen: 0.93, headYaw: 2);
const _closed = FaceSnapshot(faceCount: 1, leftEyeOpen: 0.05, rightEyeOpen: 0.08, headYaw: 1);
const _turned = FaceSnapshot(faceCount: 1, leftEyeOpen: 0.9, rightEyeOpen: 0.9, headYaw: -28);

void _feed(LivenessTracker t, FaceSnapshot f, [int times = 1]) {
  for (var i = 0; i < times; i++) {
    t.update(f);
  }
}

void main() {
  test('passes after facing, blinking, turning, and looking back in order', () {
    final t = LivenessTracker();
    _feed(t, _open, 3);
    expect(t.step, LivenessStep.blink);
    _feed(t, _closed);
    _feed(t, _open);
    expect(t.step, LivenessStep.turn);
    _feed(t, _turned);
    expect(t.step, LivenessStep.lookBack);
    _feed(t, _open);
    expect(t.passed, isTrue);
  });

  test('a still photo never passes: open eyes without a blink stay on the blink step', () {
    final t = LivenessTracker();
    _feed(t, _open, 50);
    expect(t.step, LivenessStep.blink);
    expect(t.passed, isFalse);
  });

  test('turning before blinking does not skip the blink', () {
    final t = LivenessTracker();
    _feed(t, _open, 3);
    _feed(t, _turned, 5);
    expect(t.step, LivenessStep.blink);
  });

  test('a second face resets progress and warns', () {
    final t = LivenessTracker();
    _feed(t, _open, 3);
    _feed(t, _closed);
    _feed(t, _open);
    expect(t.step, LivenessStep.turn);
    t.update(const FaceSnapshot(faceCount: 2));
    expect(t.step, LivenessStep.findFace);
    expect(t.warning, isNotNull);
  });

  test('losing the face warns without losing progress', () {
    final t = LivenessTracker();
    _feed(t, _open, 3);
    t.update(const FaceSnapshot(faceCount: 0));
    expect(t.step, LivenessStep.blink);
    expect(t.warning, isNotNull);
  });

  test('needs a few steady frontal frames before starting', () {
    final t = LivenessTracker();
    _feed(t, _open, 2);
    expect(t.step, LivenessStep.findFace);
    _feed(t, _turned);
    _feed(t, _open, 2);
    expect(t.step, LivenessStep.findFace);
    _feed(t, _open);
    expect(t.step, LivenessStep.blink);
  });
}
