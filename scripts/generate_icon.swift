import AppKit
import Foundation

struct IconGenerator {
    let outputDirectory: URL
    let fileManager = FileManager.default

    func run() throws {
        let iconsetURL = outputDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        try? fileManager.removeItem(at: iconsetURL)
        try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

        let variants: [(name: String, side: Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024)
        ]

        for variant in variants {
            try writeIcon(side: variant.side, to: iconsetURL.appendingPathComponent(variant.name))
        }
    }

    private func writeIcon(side: Int, to url: URL) throws {
        let rect = NSRect(x: 0, y: 0, width: side, height: side)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: side,
            pixelsHigh: side,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw NSError(domain: "IconGenerator", code: 1)
        }

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw NSError(domain: "IconGenerator", code: 1)
        }
        NSGraphicsContext.current = context
        defer { NSGraphicsContext.restoreGraphicsState() }

        let radius = CGFloat(side) * 0.225

        let outerPath = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(side) * 0.035, dy: CGFloat(side) * 0.035), xRadius: radius, yRadius: radius)
        outerPath.addClip()

        let background = NSGradient(colors: [
            NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.11, alpha: 1),
            NSColor(calibratedRed: 0.11, green: 0.03, blue: 0.20, alpha: 1),
            NSColor(calibratedRed: 0.03, green: 0.02, blue: 0.07, alpha: 1)
        ])!
        background.draw(in: outerPath, angle: -35)

        let glowRect = rect.insetBy(dx: CGFloat(side) * 0.14, dy: CGFloat(side) * 0.14)
        let glow = NSGradient(colors: [
            NSColor(calibratedRed: 0.98, green: 0.25, blue: 0.78, alpha: 0.95),
            NSColor(calibratedRed: 0.42, green: 0.40, blue: 1.0, alpha: 0.72),
            NSColor(calibratedRed: 0.16, green: 0.88, blue: 1.0, alpha: 0.85)
        ])!
        let glowPath = NSBezierPath(ovalIn: glowRect)
        glow.draw(in: glowPath, relativeCenterPosition: NSPoint(x: 0, y: 0))

        drawWaveLines(in: rect, side: CGFloat(side))

        let border = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(side) * 0.035, dy: CGFloat(side) * 0.035), xRadius: radius, yRadius: radius)
        NSColor.white.withAlphaComponent(0.12).setStroke()
        border.lineWidth = max(2, CGFloat(side) * 0.012)
        border.stroke()

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "IconGenerator", code: 1)
        }

        try pngData.write(to: url)
    }

    private func drawWaveLines(in rect: NSRect, side: CGFloat) {
        let lineCount = 18
        let inset = side * 0.14
        let width = rect.width - (inset * 2)
        let centerY = rect.midY
        let lineWidth = max(2.0, side * 0.018)
        let shadow = NSShadow()
        shadow.shadowBlurRadius = side * 0.03
        shadow.shadowColor = NSColor(calibratedRed: 0.95, green: 0.35, blue: 0.85, alpha: 0.65)
        shadow.set()

        for index in 0..<lineCount {
            let progress = CGFloat(index) / CGFloat(lineCount - 1)
            let yOffset = (progress - 0.5) * side * 0.34
            let path = NSBezierPath()
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            for step in 0...36 {
                let x = inset + (CGFloat(step) / 36.0) * width
                let ridge = sin((CGFloat(step) / 36.0) * .pi * 2.2 + progress * 2.1) * side * 0.08
                let ripple = sin((CGFloat(step) / 36.0) * .pi * 5.6 - progress) * side * 0.018
                let y = centerY + yOffset + ridge + ripple
                let point = NSPoint(x: x, y: y)
                if step == 0 {
                    path.move(to: point)
                } else {
                    path.line(to: point)
                }
            }

            let color = NSColor(
                calibratedHue: 0.52 + (0.34 * progress),
                saturation: 0.68,
                brightness: 1.0,
                alpha: 0.22 + (0.55 * (1 - abs(progress - 0.5) * 1.4))
            )
            color.setStroke()
            path.stroke()
        }

        let accentPath = NSBezierPath()
        accentPath.lineWidth = max(2.4, side * 0.024)
        accentPath.lineCapStyle = .round
        let baseY = centerY
        for step in 0...40 {
            let x = inset + (CGFloat(step) / 40.0) * width
            let wave = sin((CGFloat(step) / 40.0) * .pi * 4.0) * side * 0.11
            let point = NSPoint(x: x, y: baseY + wave)
            if step == 0 {
                accentPath.move(to: point)
            } else {
                accentPath.line(to: point)
            }
        }
        NSColor(calibratedRed: 0.98, green: 0.93, blue: 1.0, alpha: 0.92).setStroke()
        accentPath.stroke()
    }
}

let outputPath = CommandLine.arguments.dropFirst().first ?? "."
let generator = IconGenerator(outputDirectory: URL(fileURLWithPath: outputPath, isDirectory: true))
try generator.run()
