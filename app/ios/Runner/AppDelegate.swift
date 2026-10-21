import CoreImage
import CoreML
import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FaceVisionChannel") {
      FaceVisionChannel.register(with: registrar.messenger())
    }
  }
}

/// Face detection for the selfie check, using Apple's on-device Vision framework.
/// Returns, per face: a top-left-origin pixel box, head yaw in degrees, and each eye's
/// height-to-width ratio (small when the eye is closed).
enum FaceVisionChannel {
  private static let queue = DispatchQueue(label: "bakeout.face_vision", qos: .userInitiated)

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "bakeout/face_vision", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      queue.async {
        let reply: Any
        do {
          reply = try handle(call)
        } catch {
          reply = FlutterError(code: "vision_failed", message: error.localizedDescription, details: nil)
        }
        DispatchQueue.main.async { result(reply) }
      }
    }
  }

  private enum VisionInputError: LocalizedError {
    case badArguments, unreadableImage
    var errorDescription: String? {
      switch self {
      case .badArguments: return "Missing or invalid arguments"
      case .unreadableImage: return "The image could not be read"
      }
    }
  }

  private static func handle(_ call: FlutterMethodCall) throws -> Any {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "detectInFile":
      guard let path = args["path"] as? String else { throw VisionInputError.badArguments }
      guard let image = UIImage(contentsOfFile: path)?.cgImage else { throw VisionInputError.unreadableImage }
      let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
      return try detect(handler, width: image.width, height: image.height)

    case "detectInFrame":
      guard
        let bytes = args["bytes"] as? FlutterStandardTypedData,
        let width = args["width"] as? Int,
        let height = args["height"] as? Int,
        let bytesPerRow = args["bytesPerRow"] as? Int
      else { throw VisionInputError.badArguments }
      let frame = CIImage(
        bitmapData: bytes.data,
        bytesPerRow: bytesPerRow,
        size: CGSize(width: width, height: height),
        format: .BGRA8,
        colorSpace: CGColorSpaceCreateDeviceRGB())
      let handler = VNImageRequestHandler(ciImage: frame, orientation: .up)
      return try detect(handler, width: width, height: height)

    default:
      return FlutterMethodNotImplemented
    }
  }

  private static func detect(_ handler: VNImageRequestHandler, width: Int, height: Int) throws -> [[String: Any]] {
    let rectangles = VNDetectFaceRectanglesRequest()
    runOnCPUInSimulator(rectangles)
    try handler.perform([rectangles])
    let found = rectangles.results ?? []
    if found.isEmpty { return [] }

    // Landmarks are computed on the faces already found, so each observation keeps its yaw.
    let landmarks = VNDetectFaceLandmarksRequest()
    landmarks.inputFaceObservations = found
    runOnCPUInSimulator(landmarks)
    try handler.perform([landmarks])

    return (landmarks.results ?? found).map { face in
      let box = face.boundingBox
      var out: [String: Any] = [
        "x": box.minX * Double(width),
        "y": (1 - box.maxY) * Double(height),
        "width": box.width * Double(width),
        "height": box.height * Double(height),
      ]
      if let yaw = face.yaw?.doubleValue { out["yaw"] = yaw * 180 / .pi }
      if let eye = face.landmarks?.leftEye { out["leftEyeRatio"] = aspectRatio(eye) }
      if let eye = face.landmarks?.rightEye { out["rightEyeRatio"] = aspectRatio(eye) }
      let size = CGSize(width: width, height: height)
      if let center = eyeCenter(face.landmarks?.leftEye, face: box, in: size) {
        out["leftEyeX"] = center.x
        out["leftEyeY"] = center.y
      }
      if let center = eyeCenter(face.landmarks?.rightEye, face: box, in: size) {
        out["rightEyeX"] = center.x
        out["rightEyeY"] = center.y
      }
      return out
    }
  }

  /// Mean of the eye outline, in top-left-origin pixel coordinates.
  /// Landmark points are normalized to the face box, whose own origin is bottom-left.
  private static func eyeCenter(_ region: VNFaceLandmarkRegion2D?, face: CGRect, in size: CGSize) -> CGPoint? {
    guard let points = region?.normalizedPoints, !points.isEmpty else { return nil }
    let nx = points.map(\.x).reduce(0, +) / CGFloat(points.count)
    let ny = points.map(\.y).reduce(0, +) / CGFloat(points.count)
    let x = (face.minX + nx * face.width) * size.width
    let y = (1 - (face.minY + ny * face.height)) * size.height
    return CGPoint(x: x, y: y)
  }

  /// The simulator has no GPU/Neural Engine for Vision, which fails with
  /// "Could not create inference context" unless pinned to the CPU.
  /// Landmarks computed this way are unreliable; Dart falls back to box-estimated eyes.
  private static func runOnCPUInSimulator(_ request: VNRequest) {
    #if targetEnvironment(simulator)
      if #available(iOS 17.0, *) {
        let cpu = MLComputeDevice.allComputeDevices.first {
          if case .cpu = $0 { return true }
          return false
        }
        for stage in (try? request.supportedComputeStageDevices.keys).map(Array.init) ?? [] {
          request.setComputeDevice(cpu, for: stage)
        }
      } else {
        request.usesCPUOnly = true
      }
    #endif
  }

  private static func aspectRatio(_ eye: VNFaceLandmarkRegion2D) -> Double {
    let points = eye.normalizedPoints
    guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
      let minY = points.map(\.y).min(), let maxY = points.map(\.y).max(), maxX > minX
    else { return 0 }
    return Double((maxY - minY) / (maxX - minX))
  }
}
