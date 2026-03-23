import SwiftUI

struct VisualizerView: View {
    @ObservedObject var model: VisualizerModel

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                if model.backgroundVisible {
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.02, blue: 0.09),
                            Color(red: 0.10, green: 0.03, blue: 0.20),
                            Color(red: 0.02, green: 0.02, blue: 0.09)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }

                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate

                    visualizerBody(size: size, time: time)
                    .frame(width: size.width, height: size.height)
                    .compositingGroup()
                }

                KeyCaptureView(model: model)
                    .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private func visualizerBody(size: CGSize, time: TimeInterval) -> some View {
        switch model.style {
        case .neonWave:
            NeonWaveVisualizer(bands: model.bands, time: time)
        case .prismBars:
            PrismBarsVisualizer(bands: model.bands)
        case .pulseLine:
            PulseLineVisualizer(bands: model.bands, time: time)
        case .horizonDots:
            HorizonDotsVisualizer(bands: model.bands, time: time)
        }
    }

    private func strandColor(index: Int) -> Color {
        let palette = [
            Color(red: 0.18, green: 0.88, blue: 1.0),
            Color(red: 0.46, green: 0.55, blue: 1.0),
            Color(red: 0.95, green: 0.36, blue: 0.92)
        ]
        return palette[index % palette.count]
    }
}

private struct NeonWaveVisualizer: View {
    let bands: [CGFloat]
    let time: TimeInterval

    var body: some View {
        ZStack {
            ForEach(0..<18, id: \.self) { strand in
                let strandProgress = CGFloat(strand) / 17.0
                let color = strandColor(index: strand)
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

            MirrorWaveShape(bands: bands, mirrored: false)
                .stroke(
                    Color(red: 1.0, green: 0.35, blue: 0.75).opacity(0.92),
                    style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
                )

            MirrorWaveShape(bands: bands, mirrored: true)
                .stroke(
                    Color(red: 0.15, green: 0.82, blue: 1.0).opacity(0.92),
                    style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
                )
        }
    }

    private func strandColor(index: Int) -> Color {
        let palette = [
            Color(red: 0.18, green: 0.88, blue: 1.0),
            Color(red: 0.46, green: 0.55, blue: 1.0),
            Color(red: 0.95, green: 0.36, blue: 0.92)
        ]
        return palette[index % palette.count]
    }
}

private struct PrismBarsVisualizer: View {
    let bands: [CGFloat]

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
                    let hue = Double(index) / Double(max(bands.count - 1, 1))
                    let color = Color(hue: 0.52 + (0.38 * hue), saturation: 0.72, brightness: 0.98)

                    Capsule(style: .continuous)
                        .fill(color.opacity(0.96))
                        .frame(width: barWidth, height: height)
                        .position(x: x, y: (size.height / 2) - (height / 2) - 6)

                    Capsule(style: .continuous)
                        .fill(color.opacity(0.4))
                        .frame(width: barWidth, height: height * 0.92)
                        .position(x: x, y: (size.height / 2) + (height * 0.46) + 6)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 1)
                    .offset(y: -0.5)
            }
        }
    }
}

private struct PulseLineVisualizer: View {
    let bands: [CGFloat]
    let time: TimeInterval

    var body: some View {
        ZStack {
            PulseShape(bands: bands, mirrored: false, time: time)
                .stroke(Color(red: 1.0, green: 0.42, blue: 0.82).opacity(0.92), style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round))

            PulseShape(bands: bands, mirrored: true, time: time)
                .stroke(Color(red: 0.18, green: 0.86, blue: 1.0).opacity(0.92), style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round))

            PulseCenterLine()
                .stroke(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
        }
    }
}

private struct HorizonDotsVisualizer: View {
    let bands: [CGFloat]
    let time: TimeInterval

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
                    let hue = Double(index) / Double(max(bands.count - 1, 1))
                    let color = Color(hue: 0.54 + (0.32 * hue), saturation: 0.62, brightness: 0.98)

                    Circle()
                        .fill(color.opacity(0.95))
                        .frame(width: maxRadius, height: maxRadius)
                        .position(x: x, y: (size.height / 2) - amplitude + CGFloat(wobble))

                    Circle()
                        .fill(color.opacity(0.45))
                        .frame(width: maxRadius * 0.8, height: maxRadius * 0.8)
                        .position(x: x, y: (size.height / 2) + amplitude - CGFloat(wobble))
                }
            }
        }
    }
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

    func path(in rect: CGRect) -> Path {
        let midY = rect.height / 2
        var path = Path()

        for index in bands.indices {
            let x = CGFloat(index) / CGFloat(max(bands.count - 1, 1)) * rect.width
            let energy = min(bands[index] * 1.28, 1.3)
            let yOffset = energy * rect.height * 0.24
            let y = mirrored ? midY + yOffset : midY - yOffset

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
            let y = mirrored ? midY + yOffset : midY - yOffset

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
