import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Same-person cutoff for MobileFaceNet cosine similarity on eye-aligned faces.
/// Public-domain portrait pairs scored ~0.70–0.72 for the same person and ≤0.25 for
/// different people; tune against real selfies before relying on it.
const double faceMatchThreshold = 0.5;

Float32List l2Normalize(List<double> v) {
  var sum = 0.0;
  for (final x in v) {
    sum += x * x;
  }
  final norm = math.sqrt(sum);
  final out = Float32List(v.length);
  if (norm == 0) return out;
  for (var i = 0; i < v.length; i++) {
    out[i] = v[i] / norm;
  }
  return out;
}

double cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length) {
    throw ArgumentError('Embeddings differ in length: ${a.length} vs ${b.length}');
  }
  final na = l2Normalize(a);
  final nb = l2Normalize(b);
  var dot = 0.0;
  for (var i = 0; i < na.length; i++) {
    dot += na[i] * nb[i];
  }
  return dot;
}

bool isSamePerson(double similarity) => similarity >= faceMatchThreshold;

/// Where MobileFaceNet's (ArcFace-style) 112×112 training crops place the eye centres.
const templateLeftEye = Offset(38.2946, 51.6963);
const templateRightEye = Offset(73.5318, 51.5014);

/// Where Vision's eye landmarks sit inside its face box, measured on frontal portraits.
const _boxEyeLeftX = 0.325, _boxEyeRightX = 0.675, _boxEyeY = 0.275;

/// Eye centres estimated from the face box alone, for when landmarks are missing.
(Offset, Offset) estimatedEyes(Rect box) => (
      Offset(box.left + _boxEyeLeftX * box.width, box.top + _boxEyeY * box.height),
      Offset(box.left + _boxEyeRightX * box.width, box.top + _boxEyeY * box.height),
    );

/// Whether landmark eyes look like real eyes for this face box: a sensible distance
/// apart and in the upper part of the face.
bool plausibleEyes(Rect box, Offset left, Offset right) {
  final gap = (right - left).distance / box.width;
  bool upper(Offset e) => box.contains(e) && e.dy < box.top + 0.55 * box.height;
  return gap > 0.2 && gap < 0.6 && upper(left) && upper(right);
}

/// Rotation + scale + shift that puts a photo's eyes on the template eyes.
/// [sourceFor] answers "which photo pixel feeds this model-input pixel?".
class EyeAlignment {
  factory EyeAlignment(Offset eyeA, Offset eyeB) {
    final (left, right) = eyeA.dx <= eyeB.dx ? (eyeA, eyeB) : (eyeB, eyeA);
    final template = templateRightEye - templateLeftEye;
    final source = right - left;
    final scale = source.distance / template.distance;
    final angle = source.direction - template.direction;
    return EyeAlignment._(left, scale, math.cos(angle), math.sin(angle));
  }

  const EyeAlignment._(this._sourceLeftEye, this.scale, this._cos, this._sin);

  final Offset _sourceLeftEye;

  /// Source pixels per model-input pixel.
  final double scale;
  final double _cos;
  final double _sin;

  Offset sourceFor(double x, double y) {
    final dx = x - templateLeftEye.dx;
    final dy = y - templateLeftEye.dy;
    return Offset(
      _sourceLeftEye.dx + scale * (_cos * dx - _sin * dy),
      _sourceLeftEye.dy + scale * (_sin * dx + _cos * dy),
    );
  }
}
