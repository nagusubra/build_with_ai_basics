import 'dart:ui' show Rect;

import 'package:bakeout/services/face_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identical embeddings are a perfect match', () {
    expect(cosineSimilarity([1, 2, 3], [1, 2, 3]), closeTo(1.0, 1e-6));
  });

  test('scale does not change similarity', () {
    expect(cosineSimilarity([1, 2, 3], [10, 20, 30]), closeTo(1.0, 1e-6));
  });

  test('orthogonal embeddings score zero', () {
    expect(cosineSimilarity([1, 0], [0, 1]), closeTo(0.0, 1e-6));
  });

  test('l2Normalize returns a unit vector and survives zeros', () {
    final v = l2Normalize([3, 4]);
    expect(v[0], closeTo(0.6, 1e-6));
    expect(v[1], closeTo(0.8, 1e-6));
    expect(l2Normalize([0, 0]), [0, 0]);
  });

  test('threshold separates the measured same-person and different-person scores', () {
    expect(isSamePerson(0.71), isTrue);
    expect(isSamePerson(0.72), isTrue);
    expect(isSamePerson(0.28), isFalse);
    expect(isSamePerson(faceMatchThreshold), isTrue);
  });

  test('mismatched lengths are rejected', () {
    expect(() => cosineSimilarity([1, 2], [1, 2, 3]), throwsArgumentError);
  });

  group('eye estimates and sanity checks', () {
    const box = Rect.fromLTWH(100, 200, 300, 300);

    test('estimated eyes sit level in the upper face, about a third of the box apart', () {
      final (left, right) = estimatedEyes(box);
      expect(left.dy, right.dy);
      expect(left.dy, lessThan(box.center.dy));
      expect((right - left).distance / box.width, closeTo(0.35, 1e-9));
    });

    test('real-looking landmark eyes are accepted', () {
      final (left, right) = estimatedEyes(box);
      expect(plausibleEyes(box, left, right), isTrue);
    });

    test('eyes bunched together or below the middle are rejected', () {
      expect(plausibleEyes(box, const Offset(240, 280), const Offset(250, 282)), isFalse);
      expect(plausibleEyes(box, const Offset(180, 420), const Offset(300, 420)), isFalse);
      expect(plausibleEyes(box, const Offset(50, 280), const Offset(200, 280)), isFalse);
    });
  });

  group('EyeAlignment', () {
    void expectNear(Offset a, Offset b) {
      expect(a.dx, closeTo(b.dx, 1e-6));
      expect(a.dy, closeTo(b.dy, 1e-6));
    }

    test('eyes already on the template map to themselves', () {
      final align = EyeAlignment(templateLeftEye, templateRightEye);
      expect(align.scale, closeTo(1, 1e-9));
      expectNear(align.sourceFor(10, 20), const Offset(10, 20));
    });

    test('template eye positions land on the photo eyes, whatever order they come in', () {
      const left = Offset(400, 300), right = Offset(560, 340);
      final align = EyeAlignment(right, left);
      expectNear(align.sourceFor(templateLeftEye.dx, templateLeftEye.dy), left);
      expectNear(align.sourceFor(templateRightEye.dx, templateRightEye.dy), right);
    });

    test('a photo with eyes twice as far apart samples at twice the scale', () {
      final align = EyeAlignment(templateLeftEye * 2, templateRightEye * 2);
      expect(align.scale, closeTo(2, 1e-9));
    });
  });
}
