// Renders the Brainwave app icon from the baked brain render:
//   App/Assets.xcassets/AppIcon.appiconset/icon.png      1024 px (iOS, Mac 2x)
//   App/Assets.xcassets/AppIcon.appiconset/icon-512.png  512 px  (Mac 1x)
//   App/Assets.xcassets/BrandMark.imageset/brand-mark.png 512 px  (in-app logo)
//   swift tools/make_icon.swift
import AppKit

let size: CGFloat = 1024
let brain = NSImage(contentsOfFile: "App/Assets.xcassets/BrainTop.imageset/brain-top.png")!
let outDir = "App/Assets.xcassets/AppIcon.appiconset/"

/// Draws the icon in a 1024-point square, then scales it to `side` pixels.
func drawIcon(_ ctx: CGContext, side: CGFloat) {
    ctx.saveGState()
    ctx.scaleBy(x: side / size, y: side / size)

    NSGradient(colors: [NSColor(red: 0.10, green: 0.14, blue: 0.28, alpha: 1), NSColor(red: 0.03, green: 0.04, blue: 0.08, alpha: 1)])!
        .draw(in: NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)), relativeCenterPosition: .zero)

    let h = size * 0.74, w = h * brain.size.width / brain.size.height
    ctx.setShadow(offset: .zero, blur: 40, color: NSColor.black.withAlphaComponent(0.6).cgColor)
    brain.draw(in: NSRect(x: (size - w) / 2, y: (size - h) / 2, width: w, height: h), from: .zero, operation: .sourceOver, fraction: 0.92)
    ctx.setShadow(offset: .zero, blur: 0)

    // The waveform: one rhythm that swells in the middle and fades at both ends.
    let left: CGFloat = 150, right: CGFloat = size - 150, mid = size / 2
    let path = CGMutablePath()
    for i in 0...200 {
        let t = CGFloat(i) / 200
        let envelope = sin(.pi * t)
        let x = left + (right - left) * t
        let y = mid + 150 * envelope * sin(2 * .pi * 2.5 * t)
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    let stroke: CGFloat = 30
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // Soft glow in the first colour, then the line filled with the scale: cyan → amber → crimson.
    ctx.setShadow(offset: .zero, blur: 50, color: NSColor(red: 0.35, green: 0.9, blue: 1, alpha: 0.9).cgColor)
    ctx.setStrokeColor(NSColor(red: 0.35, green: 0.9, blue: 1, alpha: 1).cgColor)
    ctx.setLineWidth(stroke)
    ctx.addPath(path)
    ctx.strokePath()
    ctx.setShadow(offset: .zero, blur: 0)

    ctx.saveGState()
    ctx.addPath(path)
    ctx.setLineWidth(stroke)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    let colours: [CGColor] = [
        NSColor(red: 0.35, green: 0.9, blue: 1.0, alpha: 1).cgColor,
        NSColor(red: 1.0, green: 0.80, blue: 0.25, alpha: 1).cgColor,
        NSColor(red: 0.95, green: 0.12, blue: 0.30, alpha: 1).cgColor,
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours as CFArray, locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: left, y: 0), end: CGPoint(x: right, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    ctx.restoreGState()
}

/// Writes a `side`×`side` opaque PNG (App Store icons must have no transparency).
func writePNG(side: Int, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(NSGraphicsContext.current!.cgContext, side: CGFloat(side))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

writePNG(side: 1024, to: outDir + "icon.png")
writePNG(side: 512, to: outDir + "icon-512.png")
writePNG(side: 512, to: "App/Assets.xcassets/BrandMark.imageset/brand-mark.png")  // in-app logo
print("icons written")
