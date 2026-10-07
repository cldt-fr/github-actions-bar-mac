// Turns a square icon render (squircle on a light background) into a transparent
// 1024×1024 PNG following Apple's icon grid (824 px squircle, 100 px margin).
// Usage: swift scripts/make-icon.swift <input.png> <output.png>
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count == 3,
      let source = NSImage(contentsOfFile: args[1])?.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    print("usage: make-icon.swift <input.png> <output.png>")
    exit(1)
}

// Read pixels to find the bounding box of the dark squircle body.
let width = source.width, height = source.height
var pixels = [UInt8](repeating: 0, count: width * height * 4)
let readContext = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
readContext.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

var minX = width, minY = height, maxX = 0, maxY = 0
for y in 0..<height {
    for x in 0..<width {
        let i = (y * width + x) * 4
        let luminance = 0.299 * Double(pixels[i]) + 0.587 * Double(pixels[i + 1]) + 0.114 * Double(pixels[i + 2])
        if luminance < 140 {
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
    }
}
// Trim a little to drop the light anti-aliased rim.
let trim = Int(Double(maxX - minX) * 0.006)
// The squircle is square; its light top rim can escape the threshold, so derive the
// height from the width and anchor on the (reliably dark) bottom edge.
let side = maxX - minX - 2 * trim
let crop = CGRect(x: minX + trim, y: maxY - trim - side, width: side, height: side)
print("squircle bounds: \(crop)")
let body = source.cropping(to: crop)!

// Apple-style continuous squircle (superellipse) mask.
func squircle(in rect: CGRect, exponent n: Double = 5) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    for step in 0...720 {
        let t = Double(step) / 720 * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = a * copysign(pow(abs(c), 2 / n), c)
        let y = b * copysign(pow(abs(s), 2 / n), s)
        let point = CGPoint(x: rect.midX + x, y: rect.midY + y)
        step == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

let size = 1024, inset: CGFloat = 100
let output = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
output.interpolationQuality = .high
let iconRect = CGRect(x: inset, y: inset, width: CGFloat(size) - 2 * inset, height: CGFloat(size) - 2 * inset)

// Soft drop shadow, as in Apple's template.
output.saveGState()
output.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.35).cgColor)
output.addPath(squircle(in: iconRect))
output.setFillColor(NSColor.black.cgColor)
output.fillPath()
output.restoreGState()

output.addPath(squircle(in: iconRect))
output.clip()
output.draw(body, in: iconRect)

let rep = NSBitmapImageRep(cgImage: output.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("wrote \(args[2])")
