import SwiftUI

struct VisualizerView: View {
    @ObservedObject var model: VisualizerModel
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let theme = resolvedTheme
            let activeBands = reducedBands(from: model.bands, targetCount: settings.renderMode.targetBandCount)
            let frameInterval = resolvedFrameInterval

            ZStack {
                if model.blackoutMode {
                    Color.black
                        .ignoresSafeArea()
                } else if model.backgroundVisible {
                    LinearGradient(
                        colors: theme.backgroundGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .hueRotation(.degrees(model.backgroundHueRotation * 360))
                    .brightness(model.backgroundBrightness - 1.0)
                    .animation(.easeInOut(duration: 0.28), value: model.backgroundHueRotation)
                    .animation(.easeInOut(duration: 0.2), value: model.backgroundBrightness)
                    .ignoresSafeArea()
                }

                TimelineView(.animation(minimumInterval: frameInterval, paused: false)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate

                    visualizerBody(size: size, time: time, theme: theme, bands: activeBands)
                    .frame(width: size.width, height: size.height)
                    .hueRotation(.degrees(model.foregroundHueRotation * 360))
                    .brightness(model.foregroundBrightness - 1.0)
                    .animation(.easeInOut(duration: 0.28), value: model.foregroundHueRotation)
                    .animation(.easeInOut(duration: 0.2), value: model.foregroundBrightness)
                    .modifier(RenderPipelineModifier(useGPUCompositing: settings.renderMode.prefersGPUCompositing))
                }

                KeyCaptureView(model: model)
                    .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private func visualizerBody(size: CGSize, time: TimeInterval, theme: VisualTheme, bands: [CGFloat]) -> some View {
        switch model.style {
        case .neonWave:
            NeonWaveVisualizer(
                bands: bands,
                time: time,
                theme: theme,
                mirrored: settings.mirrorEnabled,
                strandCount: settings.renderMode.neonStrands
            )
        case .prismBars:
            PrismBarsVisualizer(bands: bands, theme: theme, mirrored: settings.mirrorEnabled)
        case .pulseLine:
            PulseLineVisualizer(bands: bands, time: time, theme: theme, mirrored: settings.mirrorEnabled)
        case .horizonDots:
            HorizonDotsVisualizer(bands: bands, time: time, theme: theme, mirrored: settings.mirrorEnabled)
        case .tidalWaves:
            TidalWavesVisualizer(
                bands: bands,
                time: time,
                theme: theme,
                mirrored: settings.mirrorEnabled,
                layerCount: settings.renderMode.tidalLayers
            )
        }
    }

    private var resolvedFrameInterval: TimeInterval {
        switch settings.frameRatePreset {
        case .adaptive:
            let lowEnergy = model.averageEnergy < 0.08
            let veryLowEnergy = model.averageEnergy < 0.035
            if veryLowEnergy { return 1.0 / 20.0 }
            if lowEnergy { return 1.0 / 30.0 }
            return 1.0 / 45.0
        default:
            return settings.frameRatePreset.interval
        }
    }

    private var resolvedTheme: VisualTheme {
        if model.blackoutMode {
            return .blackout
        }

        if let imported = settings.importedLUT {
            return VisualTheme(
                palette: imported.palette.map(\.color),
                accentTop: imported.palette.first?.color ?? .white,
                accentBottom: imported.palette.last?.color ?? .white,
                guide: imported.palette.dropFirst().first?.color ?? .white,
                backgroundGradient: imported.backgroundGradient.map(\.color)
            )
        }

        if model.followsSystemTheme {
            return colorScheme == .light ? .lightSynced : .darkSynced
        }
        return .manualNeon
    }

    private func reducedBands(from source: [CGFloat], targetCount: Int) -> [CGFloat] {
        guard source.count > targetCount else { return source }
        let chunkSize = max(source.count / targetCount, 1)
        var reduced: [CGFloat] = []
        reduced.reserveCapacity(targetCount)

        var index = 0
        while index < source.count {
            let end = min(index + chunkSize, source.count)
            let slice = source[index..<end]
            reduced.append(slice.reduce(0, +) / CGFloat(slice.count))
            index = end
        }

        return reduced
    }
}

private struct NeonWaveVisualizer: View {
    let bands: [CGFloat]
    let time: TimeInterval
    let theme: VisualTheme
    let mirrored: Bool
    let strandCount: Int

    var body: some View {
        ZStack {
            ForEach(0..<strandCount, id: \.self) { strand in
                let strandProgress = CGFloat(strand) / CGFloat(max(strandCount - 1, 1))
                let color = theme.palette[strand % theme.palette.count]
                let opacity = 0.18 + (1.0 - abs(strandProgress - 0.5)) * 0.44

                WaveStrandShape(
                    bands: bands,
                    strandProgress: strandProgress,
                    time: time
                )
                .stroke(
                    color.opacity(opacity),
                    style: StrokeStyle(
                        lineWidth: 1.5 + (1.0 - abs(strandProgress - 0.5)) * 2.8,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }

            if mirrored {
                MirrorWaveShape(bands: bands, mirrored: false, centered: false)
                    .stroke(
                        theme.accentTop.opacity(0.92),
                        style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
                    )

                MirrorWaveShape(bands: bands, mirrored: true, centered: false)
                    .stroke(
                        theme.accentBottom.opacity(0.92),
                        style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
                    )
            } else {
                MirrorWaveShape(bands: bands, mirrored: false, centered: true)
                    .stroke(
                        theme.accentTop.opacity(0.92),
                        style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
                    )
            }
        }
    }
}

private struct PrismBarsVisualizer: View {
    let bands: [CGFloat]
    let theme: VisualTheme
    let mirrored: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let spacing = size.width / CGFloat(max(bands.count, 1))
            let barWidth = max(spacing * 0.58, 2)
            let maxHeight = size.height * 0.34

            ZStack {
                ForEach(Array(bands.enumerated()), id: \.offset) { index, band in
                    let x = (CGFloat(index) + 0.5) * spacing
                    let height = max(8, min(band, 1.1) * maxHeight)
                    let color = theme.palette[index % theme.palette.count]

                    Capsule(style: .continuous)
                        .fill(color.opacity(0.96))
                        .frame(width: barWidth, height: height)
                        .position(x: x, y: mirrored ? (size.height / 2) - (height / 2) - 6 : size.height / 2)

                    if mirrored {
                        Capsule(style: .continuous)
                            .fill(color.opacity(0.4))
                            .frame(width: barWidth, height: height * 0.92)
                            .position(x: x, y: (size.height / 2) + (height * 0.46) + 6)
                    }
                }

                Rectangle()
                    .fill(theme.guide.opacity(0.14))
                    .frame(height: 1)
                    .offset(y: -0.5)
            }
        }
    }
}

private struct PulseLineVisualizer: View {
    let bands: [CGFloat]
    let time: TimeInterval
    let theme: VisualTheme
    let mirrored: Bool

    var body: some View {
        ZStack {
            PulseShape(bands: bands, mirrored: false, time: time, centered: !mirrored)
                .stroke(theme.accentTop.opacity(0.92), style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round))

            if mirrored {
                PulseShape(bands: bands, mirrored: true, time: time, centered: false)
                    .stroke(theme.accentBottom.opacity(0.92), style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round))
            }

            PulseCenterLine()
                .stroke(theme.guide.opacity(0.14), style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
        }
    }
}

private struct HorizonDotsVisualizer: View {
    let bands: [CGFloat]
    let time: TimeInterval
    let theme: VisualTheme
    let mirrored: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let spacing = size.width / CGFloat(max(bands.count, 1))
            let maxRadius = max(3, size.height * 0.026)

            ZStack {
                ForEach(Array(bands.enumerated()), id: \.offset) { index, band in
                    let x = (CGFloat(index) + 0.5) * spacing
                    let amplitude = min(band, 1.05) * size.height * 0.24
                    let wobble = sin(time * 1.8 + Double(index) * 0.23) * Double(size.height * 0.006)
                    let color = theme.palette[index % theme.palette.count]

                    Circle()
                        .fill(color.opacity(0.95))
                        .frame(width: maxRadius, height: maxRadius)
                        .position(x: x, y: mirrored ? (size.height / 2) - amplitude + CGFloat(wobble) : (size.height / 2) + CGFloat(wobble))

                    if mirrored {
                        Circle()
                            .fill(color.opacity(0.45))
                            .frame(width: maxRadius * 0.8, height: maxRadius * 0.8)
                            .position(x: x, y: (size.height / 2) + amplitude - CGFloat(wobble))
                    }
                }
            }
        }
    }
}

private struct TidalWavesVisualizer: View {
    let bands: [CGFloat]
    let time: TimeInterval
    let theme: VisualTheme
    let mirrored: Bool
    let layerCount: Int

    var body: some View {
        ZStack {
            ForEach(0..<layerCount, id: \.self) { layer in
                let progress = CGFloat(layer) / CGFloat(max(layerCount - 1, 1))
                WaveFieldShape(
                    bands: bands,
                    time: time + Double(layer) * 0.35,
                    verticalOffset: mirrored ? (progress - 0.5) * 140 : 0,
                    mirrored: mirrored
                )
                .stroke(
                    theme.palette[layer % theme.palette.count].opacity(0.22 + Double(progress) * 0.22),
                    style: StrokeStyle(lineWidth: 2.2 + (1.0 - progress) * 2.6, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}

private struct RenderPipelineModifier: ViewModifier {
    let useGPUCompositing: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if useGPUCompositing {
            content
                .drawingGroup(opaque: false, colorMode: .linear)
        } else {
            content
        }
    }
}

private struct VisualTheme {
    let palette: [Color]
    let accentTop: Color
    let accentBottom: Color
    let guide: Color
    let backgroundGradient: [Color]

    static let manualNeon = VisualTheme(
        palette: [
            Color(red: 0.18, green: 0.88, blue: 1.0),
            Color(red: 0.46, green: 0.55, blue: 1.0),
            Color(red: 0.95, green: 0.36, blue: 0.92)
        ],
        accentTop: Color(red: 1.0, green: 0.35, blue: 0.75),
        accentBottom: Color(red: 0.15, green: 0.82, blue: 1.0),
        guide: .white,
        backgroundGradient: [
            Color(red: 0.02, green: 0.02, blue: 0.09),
            Color(red: 0.10, green: 0.03, blue: 0.20),
            Color(red: 0.02, green: 0.02, blue: 0.09)
        ]
    )

    static let darkSynced = VisualTheme(
        palette: [
            Color(red: 0.32, green: 0.91, blue: 1.0),
            Color(red: 0.52, green: 0.65, blue: 1.0),
            Color(red: 0.98, green: 0.50, blue: 0.84)
        ],
        accentTop: Color(red: 1.0, green: 0.48, blue: 0.78),
        accentBottom: Color(red: 0.28, green: 0.87, blue: 1.0),
        guide: .white,
        backgroundGradient: [
            Color(red: 0.03, green: 0.03, blue: 0.08),
            Color(red: 0.07, green: 0.10, blue: 0.18),
            Color(red: 0.02, green: 0.03, blue: 0.07)
        ]
    )

    static let lightSynced = VisualTheme(
        palette: [
            Color(red: 0.15, green: 0.60, blue: 0.98),
            Color(red: 0.48, green: 0.44, blue: 0.98),
            Color(red: 0.96, green: 0.46, blue: 0.63)
        ],
        accentTop: Color(red: 0.96, green: 0.46, blue: 0.63),
        accentBottom: Color(red: 0.16, green: 0.67, blue: 0.96),
        guide: Color(red: 0.12, green: 0.16, blue: 0.24),
        backgroundGradient: [
            Color(red: 0.94, green: 0.97, blue: 1.0),
            Color(red: 0.88, green: 0.92, blue: 0.99),
            Color(red: 0.96, green: 0.94, blue: 0.99)
        ]
    )

    static let blackout = VisualTheme(
        palette: [
            .white,
            Color.white.opacity(0.92),
            Color.white.opacity(0.84)
        ],
        accentTop: .white,
        accentBottom: .white,
        guide: .white,
        backgroundGradient: [
            .black,
            .black,
            .black
        ]
    )
}

private struct WaveStrandShape: Shape {
    let bands: [CGFloat]
    let strandProgress: CGFloat
    let time: TimeInterval

    func path(in rect: CGRect) -> Path {
        let midY = rect.height / 2
        let verticalSpread = (strandProgress - 0.5) * rect.height * 0.52
        let amplitude = (0.14 + (1.0 - abs(strandProgress - 0.5)) * 0.72) * rect.height * 0.24
        let phase = CGFloat(time * 0.9) + strandProgress * 2.3

        var path = Path()
        for index in bands.indices {
            let x = CGFloat(index) / CGFloat(max(bands.count - 1, 1)) * rect.width
            let energy = bands[index]
            let drift = sin((x / rect.width * .pi * 3.4) + phase) * 0.18
            let ridge = sin((x / rect.width * .pi * 0.9) - phase * 0.4) * 0.08
            let y = midY + verticalSpread + (energy + drift + ridge) * amplitude

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

private struct MirrorWaveShape: Shape {
    let bands: [CGFloat]
    let mirrored: Bool
    let centered: Bool

    func path(in rect: CGRect) -> Path {
        let midY = rect.height / 2
        var path = Path()

        for index in bands.indices {
            let x = CGFloat(index) / CGFloat(max(bands.count - 1, 1)) * rect.width
            let energy = min(bands[index] * 1.28, 1.3)
            let yOffset = energy * rect.height * 0.24
            let y = centered ? midY - (yOffset * 0.5) : (mirrored ? midY + yOffset : midY - yOffset)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

private struct PulseShape: Shape {
    let bands: [CGFloat]
    let mirrored: Bool
    let time: TimeInterval
    let centered: Bool

    func path(in rect: CGRect) -> Path {
        let midY = rect.height / 2
        let usableWidth = rect.width * 0.84
        let startX = rect.midX - (usableWidth / 2)
        var path = Path()

        for index in bands.indices {
            let progress = CGFloat(index) / CGFloat(max(bands.count - 1, 1))
            let x = startX + (progress * usableWidth)
            let envelope = 1.0 - abs((progress - 0.5) * 1.75)
            let ripple = sin((progress * .pi * 10) + CGFloat(time * 2.4)) * 0.06
            let yOffset = min(bands[index] * 0.9 + ripple, 1.2) * rect.height * 0.22 * max(envelope, 0.2)
            let y = centered ? midY + ((ripple * rect.height * 0.08) - (yOffset * 0.15)) : (mirrored ? midY + yOffset : midY - yOffset)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

private struct WaveFieldShape: Shape {
    let bands: [CGFloat]
    let time: TimeInterval
    let verticalOffset: CGFloat
    let mirrored: Bool

    func path(in rect: CGRect) -> Path {
        let midY = rect.height / 2
        var path = Path()

        for index in bands.indices {
            let progress = CGFloat(index) / CGFloat(max(bands.count - 1, 1))
            let x = progress * rect.width
            let band = bands[index]
            let amplitude = rect.height * (mirrored ? 0.08 : 0.11)
            let primary = sin((progress * .pi * 4.5) + CGFloat(time * 1.4)) * amplitude
            let secondary = cos((progress * .pi * 9.0) - CGFloat(time * 0.9)) * amplitude * 0.24
            let reactive = band * rect.height * 0.12
            let y = midY + verticalOffset + primary + secondary + (mirrored ? reactive * (progress - 0.5) : reactive * 0.28)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

private struct PulseCenterLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.08, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width * 0.92, y: rect.midY))
        return path
    }
}
