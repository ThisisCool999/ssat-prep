import AppKit

// Renders the app icon — a happy little flashcard (kawaii face, rosy cheeks,
// "Aa" on its forehead) with two pastel cards peeking behind, on a soft
// periwinkle tile. Regenerate with:
//   swift Scripts/make_icon.swift && iconutil -c icns AppIcon.iconset -o Scripts/AppIcon.icns && rm -rf AppIcon.iconset

let sizes: [(pixels: Int, name: String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]

let skyTop = NSColor(srgbRed: 0.760, green: 0.830, blue: 0.985, alpha: 1)
let skyBottom = NSColor(srgbRed: 0.555, green: 0.665, blue: 0.960, alpha: 1)
let cream = NSColor(srgbRed: 1.00, green: 0.985, blue: 0.955, alpha: 1)
let peachBack = NSColor(srgbRed: 1.00, green: 0.870, blue: 0.740, alpha: 1)
let mintBack = NSColor(srgbRed: 0.780, green: 0.920, blue: 0.845, alpha: 1)
let ink = NSColor(srgbRed: 0.235, green: 0.270, blue: 0.400, alpha: 1)
let cheek = NSColor(srgbRed: 0.985, green: 0.660, blue: 0.690, alpha: 0.85)

func roundedFont(_ size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let desc = base.fontDescriptor.withDesign(.rounded),
       let font = NSFont(descriptor: desc, size: size) {
        return font
    }
    return base
}

func render(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let side = CGFloat(pixels)
    let inset = side * 0.085
    let tileRect = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let tile = NSBezierPath(roundedRect: tileRect, xRadius: tileRect.width * 0.222, yRadius: tileRect.width * 0.222)
    NSGradient(starting: skyTop, ending: skyBottom)?.draw(in: tile, angle: -90)
    tile.setClip()

    // Two soft clouds drifting in the corners.
    func cloud(cx: CGFloat, cy: CGFloat, s: CGFloat) {
        NSColor.white.withAlphaComponent(0.55).setFill()
        for (dx, dy, r) in [(-0.9, 0.0, 0.55), (0.0, 0.28, 0.72), (0.9, 0.0, 0.58)] {
            let rr = s * r
            NSBezierPath(ovalIn: NSRect(x: cx + s * dx - rr, y: cy + s * dy - rr,
                                        width: rr * 2, height: rr * 2)).fill()
        }
        NSBezierPath(rect: NSRect(x: cx - s * 1.4, y: cy - s * 0.55,
                                  width: s * 2.8, height: s * 0.55)).fill()
    }
    cloud(cx: tileRect.minX + tileRect.width * 0.16, cy: tileRect.maxY - tileRect.height * 0.15, s: tileRect.width * 0.075)
    cloud(cx: tileRect.maxX - tileRect.width * 0.13, cy: tileRect.maxY - tileRect.height * 0.30, s: tileRect.width * 0.055)

    // Card geometry (front card straight; two pastel friends peek behind).
    let cardW = tileRect.width * 0.52
    let cardH = tileRect.height * 0.62
    let cardRect = NSRect(x: tileRect.midX - cardW / 2,
                          y: tileRect.midY - cardH * 0.52,
                          width: cardW, height: cardH)
    let corner = cardW * 0.16

    func drawCard(rotationDegrees: CGFloat, offset: NSPoint, fill: NSColor, shadowAlpha: CGFloat) {
        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(srgbRed: 0.20, green: 0.28, blue: 0.55, alpha: shadowAlpha)
        shadow.shadowBlurRadius = side * 0.030
        shadow.shadowOffset = NSSize(width: 0, height: -side * 0.014)
        shadow.set()
        let r = cardRect.offsetBy(dx: offset.x, dy: offset.y)
        let transform = NSAffineTransform()
        transform.translateX(by: r.midX, yBy: r.midY)
        transform.rotate(byDegrees: rotationDegrees)
        transform.translateX(by: -r.midX, yBy: -r.midY)
        let path = NSBezierPath(roundedRect: r, xRadius: corner, yRadius: corner)
        path.transform(using: transform as AffineTransform)
        fill.setFill()
        path.fill()
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    drawCard(rotationDegrees: -12,
             offset: NSPoint(x: -cardW * 0.33, y: cardH * 0.045),
             fill: mintBack, shadowAlpha: 0.28)
    drawCard(rotationDegrees: 12,
             offset: NSPoint(x: cardW * 0.33, y: cardH * 0.045),
             fill: peachBack, shadowAlpha: 0.28)
    drawCard(rotationDegrees: 0, offset: .zero, fill: cream, shadowAlpha: 0.40)

    // "Aa" on the card's forehead.
    let word = "Aa" as NSString
    let font = roundedFont(cardH * 0.30, weight: .heavy)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
    let textSize = word.size(withAttributes: attrs)
    word.draw(at: NSPoint(x: cardRect.midX - textSize.width / 2,
                          y: cardRect.maxY - cardH * 0.185 - textSize.height / 2),
              withAttributes: attrs)

    // Face: round eyes with highlights, rosy cheeks, a little smile.
    let eyeY = cardRect.minY + cardH * 0.385
    let eyeDX = cardW * 0.185
    let eyeR = cardW * 0.062
    ink.setFill()
    for sideSign in [CGFloat(-1), 1] {
        let cx = cardRect.midX + eyeDX * sideSign
        NSBezierPath(ovalIn: NSRect(x: cx - eyeR, y: eyeY - eyeR,
                                    width: eyeR * 2, height: eyeR * 2)).fill()
    }
    NSColor.white.setFill()
    for sideSign in [CGFloat(-1), 1] {
        let cx = cardRect.midX + eyeDX * sideSign
        let hr = eyeR * 0.34
        NSBezierPath(ovalIn: NSRect(x: cx - hr + eyeR * 0.28, y: eyeY - hr + eyeR * 0.30,
                                    width: hr * 2, height: hr * 2)).fill()
    }

    cheek.setFill()
    let cheekW = cardW * 0.115
    let cheekH = cheekW * 0.62
    for sideSign in [CGFloat(-1), 1] {
        let cx = cardRect.midX + (eyeDX + cardW * 0.135) * sideSign
        NSBezierPath(ovalIn: NSRect(x: cx - cheekW / 2, y: eyeY - eyeR * 1.9 - cheekH / 2,
                                    width: cheekW, height: cheekH)).fill()
    }

    let smile = NSBezierPath()
    let smileR = cardW * 0.105
    smile.appendArc(withCenter: NSPoint(x: cardRect.midX, y: eyeY - eyeR * 0.8),
                    radius: smileR, startAngle: 205, endAngle: 335, clockwise: false)
    smile.lineWidth = max(1, cardW * 0.035)
    smile.lineCapStyle = .round
    ink.setStroke()
    smile.stroke()

    // A tiny sparkle so it feels alive.
    func sparkle(cx: CGFloat, cy: CGFloat, r: CGFloat, color: NSColor) {
        color.setFill()
        let arm = r * 0.36
        let vertical = NSBezierPath(roundedRect: NSRect(x: cx - arm / 2, y: cy - r, width: arm, height: r * 2),
                                    xRadius: arm / 2, yRadius: arm / 2)
        vertical.fill()
        let horizontal = NSBezierPath(roundedRect: NSRect(x: cx - r, y: cy - arm / 2, width: r * 2, height: arm),
                                      xRadius: arm / 2, yRadius: arm / 2)
        horizontal.fill()
    }
    sparkle(cx: tileRect.maxX - tileRect.width * 0.155, cy: tileRect.minY + tileRect.height * 0.175,
            r: tileRect.width * 0.045, color: NSColor.white.withAlphaComponent(0.9))
    sparkle(cx: tileRect.minX + tileRect.width * 0.145, cy: tileRect.minY + tileRect.height * 0.235,
            r: tileRect.width * 0.028, color: NSColor.white.withAlphaComponent(0.7))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconset = "AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

for (pixels, name) in sizes {
    let rep = render(pixels: pixels)
    let png = rep.representation(using: .png, properties: [:])!
    try png.write(to: URL(fileURLWithPath: "\(iconset)/\(name).png"))
}
print("Wrote \(sizes.count) images to \(iconset)")
