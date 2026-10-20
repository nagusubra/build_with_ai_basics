// Lifts the subject out of each mascot image using macOS Vision and saves a transparent PNG.
// Usage: swift design/cutout.swift <input.jpg> <output.png>
import CoreImage
import Foundation
import Vision

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: cutout.swift <input> <output.png>\n".data(using: .utf8)!)
    exit(2)
}

let input = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])

let request = VNGenerateForegroundInstanceMaskRequest()
let handler = VNImageRequestHandler(url: input)
try handler.perform([request])

guard let result = request.results?.first else {
    FileHandle.standardError.write("no subject found in \(input.lastPathComponent)\n".data(using: .utf8)!)
    exit(1)
}

let masked = try result.generateMaskedImage(
    ofInstances: result.allInstances,
    from: handler,
    croppedToInstancesExtent: false
)

let image = CIImage(cvPixelBuffer: masked)
let context = CIContext()
try context.writePNGRepresentation(
    of: image,
    to: output,
    format: .RGBA8,
    colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
)
print("wrote \(output.lastPathComponent)")
