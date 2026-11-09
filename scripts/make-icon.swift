import AppKit

let directory = CommandLine.arguments[1]
let iconset = URL(fileURLWithPath: directory).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let p = CGFloat(pixels)
        let rect = NSRect(x: p * 0.08, y: p * 0.08, width: p * 0.84, height: p * 0.84)
        let path = NSBezierPath(roundedRect: rect, xRadius: p * 0.19, yRadius: p * 0.19)
        NSGradient(starting: NSColor(srgbRed: 0.22, green: 0.48, blue: 0.36, alpha: 1), ending: NSColor(srgbRed: 0.11, green: 0.29, blue: 0.22, alpha: 1))!.draw(in: path, angle: -90)
        if let symbol = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: p * 0.43, weight: .medium)) {
            let tinted = NSImage(size: symbol.size)
            tinted.lockFocus(); NSColor(srgbRed: 0.91, green: 0.95, blue: 0.89, alpha: 1).set(); NSRect(origin: .zero, size: symbol.size).fill(); symbol.draw(at: .zero, from: .zero, operation: .destinationIn, fraction: 1); tinted.unlockFocus()
            let context = NSGraphicsContext.current!.cgContext
            context.saveGState(); context.translateBy(x: p / 2, y: p / 2); context.rotate(by: -.pi / 2)
            tinted.draw(in: NSRect(x: -p * 0.23, y: -p * 0.25, width: p * 0.46, height: p * 0.5)); context.restoreGState()
        }
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil"); task.arguments = ["-c", "icns", iconset.path, "-o", URL(fileURLWithPath: directory).appendingPathComponent("AppIcon.icns").path]; try task.run(); task.waitUntilExit()
guard task.terminationStatus == 0 else { exit(1) }
