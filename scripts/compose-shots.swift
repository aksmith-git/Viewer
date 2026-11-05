// Captioned App Store screenshots.
// swiftc -O scripts/compose-shots.swift -o build/compose && build/compose <raw dir> <out dir>
import AppKit

let captions: [(String, String, String)] = [
    ("1-web", "Web pages that\nactually run", "HTML, CSS and JavaScript, right from your files"),
    ("2-console", "A console\nin your pocket", "See logs and errors, run JavaScript"),
    ("3-markdown", "Markdown,\nbeautifully", "Rendered like a great README"),
    ("4-code", "Code in colour", "Nearly 200 languages, light and dark"),
    ("5-json", "Explore JSON", "Expand, collapse and copy any value"),
    ("6-csv", "Tables from CSV", "Pinned headers, numbers aligned"),
    ("7-pdf", "PDFs and\ndocuments", "Plus Word, Excel, Pages, Keynote and more"),
    ("8-home", "Everything you open,\none tap away", "Recent files and pins, on iPhone and iPad"),
]

let args = CommandLine.arguments
let rawDir = URL(fileURLWithPath: args[1]), outDir = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

for (name, title, subtitle) in captions {
    guard let shot = NSImage(contentsOf: rawDir.appendingPathComponent("\(name).png")),
          let rep = shot.representations.first else { continue }
    let W = CGFloat(rep.pixelsWide), H = CGFloat(rep.pixelsHigh)
    let ipad = W / H > 0.6
    let canvas = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8,
                                  samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)
    let ctx = NSGraphicsContext.current!.cgContext

    // background
    let gradient = NSGradient(colors: [NSColor(srgbRed: 0.24, green: 0.62, blue: 1.0, alpha: 1),
                                       NSColor(srgbRed: 0.13, green: 0.36, blue: 0.90, alpha: 1),
                                       NSColor(srgbRed: 0.27, green: 0.23, blue: 0.85, alpha: 1)])!
    gradient.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

    // captions (AppKit origin is bottom-left)
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    para.lineHeightMultiple = 0.95
    let titleFont = NSFont.systemFont(ofSize: W * (ipad ? 0.052 : 0.078), weight: .bold)
    let subFont = NSFont.systemFont(ofSize: W * (ipad ? 0.024 : 0.038), weight: .medium)
    let t = NSAttributedString(string: title, attributes: [.font: titleFont, .foregroundColor: NSColor.white, .paragraphStyle: para, .kern: -W * 0.0012])
    let s = NSAttributedString(string: subtitle, attributes: [.font: subFont, .foregroundColor: NSColor.white.withAlphaComponent(0.85), .paragraphStyle: para])
    let top = H * 0.045
    let tSize = t.boundingRect(with: NSSize(width: W * 0.9, height: H), options: [.usesLineFragmentOrigin])
    t.draw(with: NSRect(x: W * 0.05, y: H - top - tSize.height, width: W * 0.9, height: tSize.height), options: [.usesLineFragmentOrigin])
    let sSize = s.boundingRect(with: NSSize(width: W * 0.86, height: H), options: [.usesLineFragmentOrigin])
    let sY = H - top - tSize.height - H * 0.012 - sSize.height
    s.draw(with: NSRect(x: W * 0.07, y: sY, width: W * 0.86, height: sSize.height), options: [.usesLineFragmentOrigin])

    // screenshot, rounded, shadowed, running off the bottom
    let scale: CGFloat = ipad ? 0.80 : 0.84
    let sw = W * scale, sh = H * scale
    let x = (W - sw) / 2
    let yTop = sY - H * 0.035
    let rect = NSRect(x: x, y: yTop - sh, width: sw, height: sh)
    let radius = W * (ipad ? 0.03 : 0.07)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -W * 0.01), blur: W * 0.04, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.black.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    ctx.restoreGState()
    ctx.saveGState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    shot.draw(in: rect)
    ctx.restoreGState()
    NSColor.white.withAlphaComponent(0.25).setStroke()
    let border = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: radius, yRadius: radius)
    border.lineWidth = max(2, W * 0.002)
    border.stroke()

    NSGraphicsContext.restoreGraphicsState()
    // App Store wants no alpha channel
    let flat = NSImage(size: NSSize(width: W, height: H))
    flat.addRepresentation(canvas)
    let cg = canvas.cgImage!
    let rgb = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    rgb.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
    let out = NSBitmapImageRep(cgImage: rgb.makeImage()!)
    try out.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent("\(name).png"))
    print("wrote \(name).png \(Int(W))x\(Int(H))")
}
