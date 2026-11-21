import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "macos/Resources"
let fileManager = FileManager.default
let iconset = "\(output)/ZapretMac.iconset"
try fileManager.createDirectory(atPath: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func writePNG(_ image: NSImage, to path: String) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Cannot encode \(path)")
    }
    try data.write(to: URL(fileURLWithPath: path))
}

func appIcon(_ side: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()
    let scale = side / 1024
    let rect = NSRect(x: 32 * scale, y: 32 * scale, width: 960 * scale, height: 960 * scale)
    let background = NSBezierPath(roundedRect: rect, xRadius: 220 * scale, yRadius: 220 * scale)
    NSGradient(colors: [color(0x8b5cf6), color(0x2563eb)])!.draw(in: background, angle: -58)
    color(0xffffff, alpha: 0.18).setStroke()
    background.lineWidth = 5 * scale
    background.stroke()

    let z = NSBezierPath()
    z.move(to: NSPoint(x: 312 * scale, y: 714 * scale))
    z.line(to: NSPoint(x: 716 * scale, y: 714 * scale))
    z.line(to: NSPoint(x: 312 * scale, y: 310 * scale))
    z.line(to: NSPoint(x: 716 * scale, y: 310 * scale))
    z.lineWidth = 104 * scale
    z.lineCapStyle = .round
    z.lineJoinStyle = .round
    color(0xffffff).setStroke()
    z.stroke()
    image.unlockFocus()
    return image
}

func installerBackground() -> NSImage {
    let image = NSImage(size: NSSize(width: 900, height: 600))
    image.lockFocus()
    NSGradient(colors: [color(0xffffff), color(0xeef2ff)])!.draw(
        in: NSBezierPath(rect: NSRect(x: 0, y: 0, width: 900, height: 600)),
        angle: 90
    )

    color(0x8b5cf6, alpha: 0.07).setFill()
    NSBezierPath(ovalIn: NSRect(x: 690, y: 390, width: 300, height: 300)).fill()
    color(0x2563eb, alpha: 0.05).setFill()
    NSBezierPath(ovalIn: NSRect(x: -130, y: -150, width: 330, height: 330)).fill()

    NSString(string: "ZapretMac").draw(
        at: NSPoint(x: 50, y: 510),
        withAttributes: [
            .font: NSFont.boldSystemFont(ofSize: 42),
            .foregroundColor: color(0x172033)
        ]
    )
    NSString(string: "Discord и YouTube без VPN").draw(
        at: NSPoint(x: 52, y: 472),
        withAttributes: [
            .font: NSFont.systemFont(ofSize: 20),
            .foregroundColor: color(0x667085)
        ]
    )

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 397, y: 300))
    arrow.line(to: NSPoint(x: 497, y: 300))
    arrow.move(to: NSPoint(x: 471, y: 326))
    arrow.line(to: NSPoint(x: 497, y: 300))
    arrow.line(to: NSPoint(x: 471, y: 274))
    arrow.lineWidth = 8
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    color(0x8b5cf6).setStroke()
    arrow.stroke()

    NSString(string: "Перетащите ZapretMac в Applications").draw(
        at: NSPoint(x: 242, y: 92),
        withAttributes: [
            .font: NSFont.systemFont(ofSize: 22, weight: .medium),
            .foregroundColor: color(0x344054)
        ]
    )
    image.unlockFocus()
    return image
}

let sizes = [16, 16, 32, 32, 128, 128, 256, 256, 512, 512]
let scales = [1, 2, 1, 2, 1, 2, 1, 2, 1, 2]
for (size, scale) in zip(sizes, scales) {
    let suffix = scale == 2 ? "@2x" : ""
    try writePNG(appIcon(CGFloat(size * scale)), to: "\(iconset)/icon_\(size)x\(size)\(suffix).png")
}
try writePNG(appIcon(512), to: "\(output)/ZapretMac.png")
try writePNG(installerBackground(), to: "\(output)/dmg-background.png")

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset, "-o", "\(output)/ZapretMac.icns"]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { fatalError("iconutil failed") }
try fileManager.removeItem(atPath: iconset)
