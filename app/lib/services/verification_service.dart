import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;

import 'face_math.dart';
import 'face_vision.dart';

enum FaceProblem { noFaceInPhoto, noFaceInSelfie, severalFacesInSelfie, unreadableImage }

class FaceMatchResult {
  const FaceMatchResult.scored(double this.similarity)
      : problem = null,
        matched = similarity >= faceMatchThreshold;

  const FaceMatchResult.failed(FaceProblem this.problem)
      : similarity = null,
        matched = false;

  final double? similarity;
  final FaceProblem? problem;
  final bool matched;
}

/// Compares a selfie with a profile photo entirely on the phone.
/// Nothing here uploads or keeps the selfie.
class VerificationService {
  static const _modelAsset = 'assets/models/mobile_facenet.tflite';
  static const _inputSize = 112;
  static const _embeddingSize = 128;
  static final _alignedEyeGap = 2 * (templateRightEye - templateLeftEye).distance;

  Interpreter? _interpreter;

  Future<Interpreter> _model() async {
    if (_interpreter != null) return _interpreter!;
    // A no-op on iOS and Android; loads the self-hosted TFLite.js runtime in the browser.
    await initializeWeb(
      tfJsScriptUrl: 'tflite/tf-core.js',
      tfBackendScriptUrls: ['tflite/tf-backend-cpu.js'],
      tfliteScriptUrl: 'tflite/tf-tflite.min.js',
    );
    return _interpreter = await Interpreter.fromAsset(_modelAsset);
  }

  Future<FaceMatchResult> compare({
    required Uint8List profilePhotoBytes,
    required Uint8List selfieBytes,
  }) async {
    final photo = await _faceTensor(profilePhotoBytes, requireSingleFace: false);
    if (photo.problem != null) {
      return FaceMatchResult.failed(
        photo.problem == FaceProblem.unreadableImage ? FaceProblem.unreadableImage : FaceProblem.noFaceInPhoto,
      );
    }
    final selfie = await _faceTensor(selfieBytes, requireSingleFace: true);
    if (selfie.problem != null) {
      return FaceMatchResult.failed(
        selfie.problem == FaceProblem.noFaceInPhoto ? FaceProblem.noFaceInSelfie : selfie.problem!,
      );
    }

    final model = await _model();
    final output = Float32List(2 * _embeddingSize);
    model.runForMultipleInputs(
      [photo.tensor!.buffer.asUint8List(), selfie.tensor!.buffer.asUint8List()],
      {0: output.buffer},
    );
    final similarity = cosineSimilarity(
      output.sublist(0, _embeddingSize),
      output.sublist(_embeddingSize),
    );
    return FaceMatchResult.scored(similarity);
  }

  /// Finds the face, aligns it by the eyes, and packs it as the model expects:
  /// channels-first RGB, 112×112, values 0–1.
  Future<({Float32List? tensor, FaceProblem? problem})> _faceTensor(
    Uint8List bytes, {
    required bool requireSingleFace,
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return (tensor: null, problem: FaceProblem.unreadableImage);
    final upright = img.bakeOrientation(decoded);

    // Detect on the upright copy so face coordinates and pixels agree.
    final uprightBytes = img.encodeJpg(upright, quality: 92);
    final faces = await FaceVision.detectInBytes(uprightBytes);

    if (faces.isEmpty) return (tensor: null, problem: FaceProblem.noFaceInPhoto);
    if (requireSingleFace && faces.length > 1) {
      return (tensor: null, problem: FaceProblem.severalFacesInSelfie);
    }

    final detected = faces.reduce((a, b) => a.box.width * a.box.height >= b.box.width * b.box.height ? a : b);
    final landmarkLeft = detected.leftEye, landmarkRight = detected.rightEye;
    final (leftEye, rightEye) =
        landmarkLeft != null && landmarkRight != null && plausibleEyes(detected.box, landmarkLeft, landmarkRight)
            ? (landmarkLeft, landmarkRight)
            : estimatedEyes(detected.box);
    final face = _alignedFace(upright, leftEye, rightEye);

    const plane = _inputSize * _inputSize;
    final tensor = Float32List(3 * plane);
    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        final p = face.getPixel(x, y);
        final i = y * _inputSize + x;
        tensor[i] = p.r / 255.0;
        tensor[plane + i] = p.g / 255.0;
        tensor[2 * plane + i] = p.b / 255.0;
      }
    }
    return (tensor: tensor, problem: null);
  }

  /// Warps the face so its eyes sit where the model's training crops put them.
  img.Image _alignedFace(img.Image upright, Offset leftEye, Offset rightEye) {
    // Shrink big photos first so each model pixel samples only a couple of source pixels.
    final eyeGap = (rightEye - leftEye).distance;
    final shrink = math.min(1.0, _alignedEyeGap / eyeGap);
    final source = shrink < 1
        ? img.copyResize(upright, width: (upright.width * shrink).round(), interpolation: img.Interpolation.average)
        : upright;

    final align = EyeAlignment(leftEye * shrink, rightEye * shrink);
    final out = img.Image(width: _inputSize, height: _inputSize);
    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        final s = align.sourceFor(x.toDouble(), y.toDouble());
        out.setPixel(x, y, source.getPixelInterpolate(s.dx, s.dy, interpolation: img.Interpolation.linear));
      }
    }
    return out;
  }
  void dispose() => _interpreter?.close();
}
