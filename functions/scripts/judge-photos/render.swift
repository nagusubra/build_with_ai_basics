// HACKATHON DEMO — draws a portrait card (gradient, signature-dish emoji, name) for each demo
// profile, so Discover has photos without using anyone's face. A real <id>.jpg in this folder
// is never overwritten.
//
//   node -e "import('../judge-demo.mjs').then(m => console.log(JSON.stringify(m.everyone.map(p => ({ id: p.id, name: p.name, ...p.photo })))))" | swift render.swift
import AppKit

struct Spec: Decodable {
  let id: String
  let name: String
  let emoji: String
  let colors: [String]
}

func color(_ hex: String) -> NSColor {
  var value: UInt64 = 0
  Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
  return NSColor(
    srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
    green: CGFloat((value >> 8) & 0xFF) / 255,
    blue: CGFloat(value & 0xFF) / 255,
    alpha: 1)
}

func centered(_ text: String, font: NSFont, color: NSColor, y: CGFloat, width: CGFloat) {
  let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
  let size = (text as NSString).size(withAttributes: attrs)
  (text as NSString).draw(at: NSPoint(x: (width - size.width) / 2, y: y), withAttributes: attrs)
}

let folder = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let specs = try JSONDecoder().decode([Spec].self, from: FileHandle.standardInput.readDataToEndOfFile())
let size = NSSize(width: 1080, height: 1350)

for spec in specs {
  let out = folder.appendingPathComponent("\(spec.id).jpg")
  if FileManager.default.fileExists(atPath: out.path) { continue }

  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

  NSGradient(colors: spec.colors.map(color))!.draw(in: NSRect(origin: .zero, size: size), angle: -60)
  NSColor.white.withAlphaComponent(0.35).setFill()
  // Discover crops the middle band of the photo, so the dish sits dead centre.
  NSBezierPath(ovalIn: NSRect(x: 190, y: 325, width: 700, height: 700)).fill()

  centered(spec.emoji, font: NSFont(name: "Apple Color Emoji", size: 440)!, color: .black, y: 400, width: size.width)
  let rounded = NSFont.systemFont(ofSize: 110, weight: .black).fontDescriptor.withDesign(.rounded)!
  centered(spec.name, font: NSFont(descriptor: rounded, size: 110)!, color: color("#7A1230"), y: 150, width: size.width)
  centered("BakeOut demo profile", font: .systemFont(ofSize: 40, weight: .semibold),
           color: color("#7A1230").withAlphaComponent(0.6), y: 80, width: size.width)

  NSGraphicsContext.restoreGraphicsState()
  try rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])!.write(to: out)
  print("drew \(out.lastPathComponent)")
}
