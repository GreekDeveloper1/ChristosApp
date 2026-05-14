import SwiftUI

struct RadarScanView: View {
    @EnvironmentObject private var discoveryVM: DeviceDiscoveryViewModel

    @State private var rotation: Double = 0
    @State private var pulseScale: [CGFloat] = [1, 1, 1]
    @State private var pulseOpacity: [Double] = [0.5, 0.35, 0.2]
    @State private var dotPositions: [CGPoint] = []

    private let ringCount = 4

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                // Background rings
                ForEach(1...ringCount, id: \.self) { i in
                    let fraction = CGFloat(i) / CGFloat(ringCount)
                    Circle()
                        .stroke(Color.appAccent.opacity(0.12), lineWidth: 1)
                        .frame(width: size * fraction, height: size * fraction)
                }

                // Pulse rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.appAccent.opacity(pulseOpacity[i]), lineWidth: 1.5)
                        .frame(width: size * 0.9 * pulseScale[i],
                               height: size * 0.9 * pulseScale[i])
                }

                // Sweep cone
                SweepCone(rotation: rotation, size: size)

                // Cross-hairs
                Path { p in
                    p.move(to: CGPoint(x: geo.size.width / 2, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height))
                    p.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(Color.appAccent.opacity(0.1), lineWidth: 0.5)

                // Discovered device dots
                ForEach(dotPositions.indices, id: \.self) { i in
                    let pos = dotPositions[i]
                    DeviceDot(index: i)
                        .position(x: center.x + pos.x * size * 0.45,
                                  y: center.y + pos.y * size * 0.45)
                }

                // Center dot
                ZStack {
                    Circle()
                        .fill(LinearGradient.accentGradient)
                        .frame(width: 16, height: 16)
                    Circle()
                        .stroke(Color.appAccent.opacity(0.3), lineWidth: 6)
                        .frame(width: 28, height: 28)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear(perform: startAnimations)
        .onChange(of: discoveryVM.devices.count) { _, count in
            updateDots(count: count)
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Sweep rotation
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        // Pulse rings
        for i in 0..<3 {
            withAnimation(
                .easeOut(duration: 2.5)
                .repeatForever(autoreverses: false)
                .delay(Double(i) * 0.7)
            ) {
                pulseScale[i] = 1.4
                pulseOpacity[i] = 0
            }
        }
    }

    private func updateDots(count: Int) {
        // Randomly place dots on the radar within unit circle
        while dotPositions.count < count {
            let angle = Double.random(in: 0..<360) * .pi / 180
            let radius = Double.random(in: 0.15...0.9)
            dotPositions.append(CGPoint(x: cos(angle) * radius, y: sin(angle) * radius))
        }
    }
}

// MARK: - Sweep Cone
private struct SweepCone: View {
    let rotation: Double
    let size: CGFloat

    var body: some View {
        ZStack {
            // Trailing gradient arc
            AngularGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.appAccent.opacity(0.0), location: 0.0),
                    .init(color: Color.appAccent.opacity(0.0), location: 0.65),
                    .init(color: Color.appAccent.opacity(0.3), location: 0.85),
                    .init(color: Color.appAccent.opacity(0.5), location: 1.0),
                ]),
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )
            .frame(width: size * 0.88, height: size * 0.88)
            .clipShape(Circle())

            // Sweep line
            Path { path in
                path.move(to: CGPoint(x: size / 2, y: size / 2))
                path.addLine(to: CGPoint(x: size / 2, y: 0))
            }
            .stroke(
                LinearGradient(
                    colors: [Color.appAccent.opacity(0), Color.appAccent],
                    startPoint: .top, endPoint: .bottom
                ),
                lineWidth: 2
            )
            .frame(width: size, height: size)
        }
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Device Dot
private struct DeviceDot: View {
    let index: Int
    @State private var appeared = false

    private let colors: [Color] = [.appAccent, .appAccentSecondary, .appSuccess, .appWarning]

    var body: some View {
        ZStack {
            Circle()
                .fill(colors[index % colors.count].opacity(0.3))
                .frame(width: 20, height: 20)
                .scaleEffect(appeared ? 1 : 0)

            Circle()
                .fill(colors[index % colors.count])
                .frame(width: 8, height: 8)
                .scaleEffect(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }
}
