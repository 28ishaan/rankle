#!/usr/bin/env swift
import AppKit
import CoreGraphics
import CoreText

let sizes: [(String, Int)] = [
  ("Icon-120.png", 120),
  ("Icon-180.png", 180),
  ("Icon-152.png", 152),
  ("Icon-167.png", 167),
  ("Icon-1024.png", 1024)
]

// Sunset gradient colors
let sunsetTop = NSColor(calibratedRed: 255/255.0, green: 183/255.0, blue: 147/255.0, alpha: 1)
let sunsetBottom = NSColor(calibratedRed: 255/255.0, green: 218/255.0, blue: 185/255.0, alpha: 1)
let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  .appendingPathComponent("Rankle/Sources/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func drawIcon(size px: Int) -> Data {
  let colorSpace = CGColorSpaceCreateDeviceRGB()
  let bytesPerRow = px * 4
  guard let context = CGContext(data: nil,
                                width: px,
                                height: px,
                                bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("Failed to create CGContext")
  }

  // Draw sunset gradient background
  let gradient = CGGradient(colorsSpace: colorSpace,
                           colors: [sunsetTop.cgColor, sunsetBottom.cgColor] as CFArray,
                           locations: [0.0, 1.0])!
  context.drawLinearGradient(gradient,
                            start: CGPoint(x: 0, y: 0),
                            end: CGPoint(x: 0, y: CGFloat(px)),
                            options: [])

  // Draw centered 'R' using CoreText
  let fontSize = CGFloat(px) * 0.6
  let font = NSFont.systemFont(ofSize: fontSize, weight: .black)
  let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white
  ]
  let attributed = NSAttributedString(string: "R", attributes: attributes)
  let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)
  let bounds = CTLineGetBoundsWithOptions(line, [])
  let textWidth = bounds.width
  let textHeight = bounds.height

  context.saveGState()
  context.translateBy(x: CGFloat(px)/2 - textWidth/2, y: CGFloat(px)/2 - textHeight/2)
  let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
  NSGraphicsContext.current = nsContext
  attributed.draw(at: .zero)
  NSGraphicsContext.current = nil
  context.restoreGState()

  guard let cgImage = context.makeImage() else { fatalError("Failed to make image") }
  let rep = NSBitmapImageRep(cgImage: cgImage)
  guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("PNG encode failed") }
  return png
}

for (name, px) in sizes {
  let png = drawIcon(size: px)
  let outPath = outputDir.appendingPathComponent(name)
  try png.write(to: outPath)
  print("Wrote \(name) (\(px)x\(px))")
}
print("Done")
