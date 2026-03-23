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

                    ZStack {
                        ForEach(0..<18, id: \.self) { strand in
                            let strandProgress = CGFloat(strand) / 17.0
                            let color = strandColor(index: strand)
                            let opacity = 0.18 + (1.0 - abs(strandProgress - 0.5)) * 0.44

                            WaveStrandShape(
                                bands: model.bands,
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

                        MirrorWaveShape(bands: model.bands, mirrored: false)
                            .stroke(
                                Color(red: 1.0, green: 0.35, blue: 0.75).opacity(0.92),
                                style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
                            )

                        MirrorWaveShape(bands: model.bands, mirrored: true)
                            .stroke(
                                Color(red: 0.15, green: 0.82, blue: 1.0).opacity(0.92),
                                style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
                            )
                    }
                    .frame(width: size.width, height: size.height)
                    .compositingGroup()
                }

                KeyCaptureView(model: model)
                    .ignoresSafeArea()
            }
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
