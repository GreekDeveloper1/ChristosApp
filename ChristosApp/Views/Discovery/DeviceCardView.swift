import SwiftUI

struct DeviceCardView: View {
    let device: Device
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavorite: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Device icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(device.type.accentColor.opacity(0.15))
                        .frame(width: 54, height: 54)
                    Image(systemName: device.type.systemImage)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(device.type.accentColor)
                }

                // Info
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(device.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                            .lineLimit(1)

                        if device.connectionStatus == .connected {
                            Circle()
                                .fill(Color.appSuccess)
                                .frame(width: 7, height: 7)
                        }
                    }

                    HStack(spacing: 8) {
                        Label(device.type.rawValue, systemImage: device.type.systemImage)
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary)

                        if let ip = device.ipAddress {
                            Text("·")
                                .foregroundColor(.appTextSecondary)
                            Text(ip)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.appTextSecondary)
                        }
                    }

                    HStack(spacing: 8) {
                        // Connection type
                        Label(device.connectionType.rawValue, systemImage: device.connectionType.systemImage)
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary.opacity(0.7))

                        // Signal strength
                        SignalStrengthView(level: device.signalLevel)
                    }
                }

                Spacer(minLength: 0)

                // Actions
                VStack(spacing: 12) {
                    Button(action: onFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(isFavorite ? .appDanger : .appTextSecondary)
                    }
                    .haptic(.soft)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appTextSecondary.opacity(0.5))
                }
            }
            .padding(16)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        device.connectionStatus == .connected
                            ? Color.appSuccess.opacity(0.3)
                            : Color.appDivider,
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(PressButtonStyle(pressed: $pressed))
    }
}

// MARK: - Press Animation
struct PressButtonStyle: ButtonStyle {
    @Binding var pressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, val in
                withAnimation(.snappy) { pressed = val }
            }
    }
}
