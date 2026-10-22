package com.bakeout.bakeout

import android.graphics.BitmapFactory
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceContour
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import kotlin.math.max
import kotlin.math.min

/**
 * Face detection for the selfie check, using Google's on-device ML Kit.
 *
 * Answers on the `bakeout/face_vision` method channel with the same shape the
 * iOS channel sends: per face a top-left-origin pixel box, head yaw in degrees,
 * and each eye's height-to-width ratio (small when the eye is closed).
 */
class FaceVisionChannel(messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)

    private val detector = FaceDetection.getClient(
        FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
            .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
            .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
            .setContourMode(FaceDetectorOptions.CONTOUR_MODE_ALL)
            .setMinFaceSize(0.2f)
            .build()
    )

    fun start() = channel.setMethodCallHandler(this)

    fun dispose() {
        channel.setMethodCallHandler(null)
        detector.close()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "detectInFile" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_arguments", "Missing path", null)
                    return
                }
                val bitmap = BitmapFactory.decodeFile(path)
                if (bitmap == null) {
                    result.error("unreadable_image", "The image could not be read", null)
                    return
                }
                detect(InputImage.fromBitmap(bitmap, 0), result)
            }

            "detectInFrame" -> {
                val bytes = call.argument<ByteArray>("bytes")
                val width = call.argument<Int>("width")
                val height = call.argument<Int>("height")
                val rotation = call.argument<Int>("rotationDegrees") ?: 0
                if (bytes == null || width == null || height == null) {
                    result.error("bad_arguments", "Missing frame data", null)
                    return
                }
                // The camera plugin hands over a single tightly packed NV21 plane on
                // Android, still in the sensor's orientation, so the frame is turned
                // upright by the rotation the Dart side worked out.
                val image = InputImage.fromByteBuffer(
                    ByteBuffer.wrap(bytes),
                    width,
                    height,
                    rotation,
                    InputImage.IMAGE_FORMAT_NV21
                )
                detect(image, result)
            }

            else -> result.notImplemented()
        }
    }

    private fun detect(image: InputImage, result: MethodChannel.Result) {
        detector.process(image)
            .addOnSuccessListener { faces -> result.success(faces.map { it.toChannelMap() }) }
            .addOnFailureListener { error ->
                result.error("vision_failed", error.message ?: "Face detection failed", null)
            }
    }

    companion object {
        private const val CHANNEL = "bakeout/face_vision"
    }
}

/** Eye height-to-width ratio plus the eye centre, in image pixels. */
private data class EyeMetrics(val ratio: Double, val centerX: Double, val centerY: Double)

private fun Face.toChannelMap(): Map<String, Any> {
    val box = boundingBox
    val out = mutableMapOf<String, Any>(
        "x" to box.left.toDouble(),
        "y" to box.top.toDouble(),
        "width" to box.width().toDouble(),
        "height" to box.height().toDouble(),
        "yaw" to headEulerAngleY.toDouble(),
    )

    // ML Kit's eye-open probability is a trained signal, so it separates a blink
    // from an open eye far better than the shape of the eye outline does.
    leftEyeOpenProbability?.let { out["leftEyeOpen"] = it.toDouble() }
    rightEyeOpenProbability?.let { out["rightEyeOpen"] = it.toDouble() }

    eyeMetrics(this, FaceContour.LEFT_EYE)?.let { eye ->
        out["leftEyeRatio"] = eye.ratio
        out["leftEyeX"] = eye.centerX
        out["leftEyeY"] = eye.centerY
    }
    eyeMetrics(this, FaceContour.RIGHT_EYE)?.let { eye ->
        out["rightEyeRatio"] = eye.ratio
        out["rightEyeX"] = eye.centerX
        out["rightEyeY"] = eye.centerY
    }
    return out
}

/** The eye outline, the same shape the iOS channel measures. */
private fun eyeMetrics(face: Face, contourType: Int): EyeMetrics? {
    val contour: FaceContour = face.getContour(contourType) ?: return null
    val points = contour.points
    if (points.isEmpty()) return null

    var minX = Float.MAX_VALUE
    var maxX = -Float.MAX_VALUE
    var minY = Float.MAX_VALUE
    var maxY = -Float.MAX_VALUE
    var sumX = 0f
    var sumY = 0f
    for (point in points) {
        minX = min(minX, point.x)
        maxX = max(maxX, point.x)
        minY = min(minY, point.y)
        maxY = max(maxY, point.y)
        sumX += point.x
        sumY += point.y
    }

    val width = maxX - minX
    val ratio: Double = if (width > 0f) ((maxY - minY) / width).toDouble() else 0.0
    val count = points.size
    return EyeMetrics(ratio, (sumX / count).toDouble(), (sumY / count).toDouble())
}
