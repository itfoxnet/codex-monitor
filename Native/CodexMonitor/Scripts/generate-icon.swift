import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
  fputs("Usage: swift generate-icon.swift OUTPUT_ICONSET\n", stderr)
  exit(2)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
  ("icon_16x16.png", 16),
  ("icon_16x16@2x.png", 32),
  ("icon_32x32.png", 32),
  ("icon_32x32@2x.png", 64),
  ("icon_128x128.png", 128),
  ("icon_128x128@2x.png", 256),
  ("icon_256x256.png", 256),
  ("icon_256x256@2x.png", 512),
  ("icon_512x512.png", 512),
  ("icon_512x512@2x.png", 1024),
]

func drawIcon(size: CGFloat) -> NSImage {
  let image = NSImage(size: NSSize(width: size, height: size))
  image.lockFocus()
  defer { image.unlockFocus() }

  let scale = size / 1024
  let canvas = NSRect(x: 0, y: 0, width: size, height: size)
  NSColor(calibratedRed: 0.949, green: 0.937, blue: 0.902, alpha: 1).setFill()
  NSBezierPath(roundedRect: canvas.insetBy(dx: 18 * scale, dy: 18 * scale), xRadius: 220 * scale, yRadius: 220 * scale).fill()

  let hall = NSRect(x: 170 * scale, y: 170 * scale, width: 684 * scale, height: 684 * scale)
  NSColor(calibratedRed: 0.114, green: 0.129, blue: 0.118, alpha: 1).setFill()
  NSBezierPath(roundedRect: hall, xRadius: 120 * scale, yRadius: 120 * scale).fill()

  let counter = NSRect(x: 270 * scale, y: 330 * scale, width: 484 * scale, height: 92 * scale)
  NSColor(calibratedRed: 0.988, green: 0.984, blue: 0.969, alpha: 1).setFill()
  NSBezierPath(roundedRect: counter, xRadius: 24 * scale, yRadius: 24 * scale).fill()

  let personCenters: [CGFloat] = [350, 512, 674]
  for x in personCenters {
    let head = NSRect(x: (x - 42) * scale, y: 580 * scale, width: 84 * scale, height: 84 * scale)
    NSBezierPath(ovalIn: head).fill()
    let body = NSRect(x: (x - 55) * scale, y: 455 * scale, width: 110 * scale, height: 98 * scale)
    NSBezierPath(roundedRect: body, xRadius: 34 * scale, yRadius: 34 * scale).fill()
  }

  NSColor(calibratedRed: 0.843, green: 0.478, blue: 0.071, alpha: 1).setFill()
  let raised = NSRect(x: 621 * scale, y: 686 * scale, width: 106 * scale, height: 38 * scale)
  let bar = NSBezierPath(roundedRect: raised, xRadius: 19 * scale, yRadius: 19 * scale)
  var transform = AffineTransform()
  transform.translate(x: 674 * scale, y: 705 * scale)
  transform.rotate(byDegrees: 58)
  transform.translate(x: -674 * scale, y: -705 * scale)
  bar.transform(using: transform)
  bar.fill()

  return image
}

for (name, pixels) in variants {
  let image = drawIcon(size: CGFloat(pixels))
  guard let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:]) else {
    throw CocoaError(.fileWriteUnknown)
  }
  try png.write(to: output.appendingPathComponent(name), options: .atomic)
}
