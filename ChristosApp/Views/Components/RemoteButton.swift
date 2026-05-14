import SwiftUI

enum RemoteButtonSize {
    case small, medium, large

    var dimension: CGFloat {
        switch self {
        case .small:  return 40
        case .medium: return 52
        case .large:  return 64
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .small:  return 16
        case .medium: return 20
        case .large:  return 26
        }
    }
}

struct RemoteButton: View {
    let icon: String
    let label: String
    let color: Color
    let size: RemoteButtonSize
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: { action(); UIImpactFeedbackGenerator(style: .light).impactOccurred() }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(pressed ? 0.3 : 0.12))
                        .frame(width: size.dimension, height: size.dimension)
                        .overlay(Circle().stroke(color.opacity(0.25), lineWidth: 1))

                    Image(systemName: icon)
                        .font(.system(size: size.fontSize, weight: .semibold))
                        .foregroundColor(color)
                }

                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                }
            }
            .scaleEffect(pressed ? 0.9 : 1)
            .animation(.snappy, value: pressed)
        }
        .buttonStyle(PressButtonStyle(pressed: $pressed))
    }
}
