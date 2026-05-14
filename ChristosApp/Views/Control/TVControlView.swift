import SwiftUI

struct TVControlView: View {
    @ObservedObject var viewModel: DeviceControlViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Top row: Back / Home / Menu
            HStack(spacing: 24) {
                RemoteButton(icon: "arrow.uturn.left", label: "Back",  color: .appTextSecondary, size: .medium) {
                    viewModel.send(.back)
                }
                RemoteButton(icon: "house.fill",       label: "Home",  color: .appAccent,        size: .medium) {
                    viewModel.send(.home)
                }
                RemoteButton(icon: "list.bullet",      label: "Menu",  color: .appTextSecondary, size: .medium) {
                    viewModel.send(.menu)
                }
            }

            // D-Pad
            dPad

            // Number pad
            numberPad

            // Channel controls
            HStack(spacing: 32) {
                RemoteButton(icon: "chevron.up.square.fill",   label: "Ch +", color: .appAccentSecondary, size: .medium) {
                    viewModel.send(.channelUp)
                }
                RemoteButton(icon: "chevron.down.square.fill", label: "Ch -", color: .appAccentSecondary, size: .medium) {
                    viewModel.send(.channelDown)
                }
            }
        }
        .padding(20)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.appDivider, lineWidth: 0.5)
        )
    }

    // MARK: - D-Pad

    private var dPad: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.appSurfaceElevated)
                .frame(width: 180, height: 180)
                .overlay(Circle().stroke(Color.appDivider, lineWidth: 0.5))

            // Directional buttons
            VStack(spacing: 0) {
                dPadButton(command: .up,    icon: "chevron.up",   offset: CGSize(width: 0, height: -58))
                dPadButton(command: .down,  icon: "chevron.down", offset: CGSize(width: 0, height:  58))
            }
            HStack(spacing: 0) {
                dPadButton(command: .left,  icon: "chevron.left",  offset: CGSize(width: -58, height: 0))
                dPadButton(command: .right, icon: "chevron.right", offset: CGSize(width:  58, height: 0))
            }

            // Center / OK
            Button {
                viewModel.send(.select)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient.accentGradient)
                        .frame(width: 60, height: 60)
                    Text("OK")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(1)
        }
    }

    private func dPadButton(command: DeviceCommand, icon: String, offset: CGSize) -> some View {
        Button {
            viewModel.send(command)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.appTextPrimary)
                .frame(width: 50, height: 50)
        }
        .offset(offset)
        .frame(width: 50, height: 50)
    }

    // MARK: - Number Pad

    private var numberPad: some View {
        VStack(spacing: 0) {
            Label("Numbers", systemImage: "number")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.appTextSecondary.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(1...9, id: \.self) { n in
                    numButton(n)
                }
                numButton(-1, label: "")  // empty
                numButton(0)
                numButton(-2, label: "⌫")
            }
        }
    }

    private func numButton(_ n: Int, label: String? = nil) -> some View {
        Button {
            if n >= 0 { viewModel.send(.number(n)) }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.appSurfaceElevated)
                    .frame(height: 46)
                Text(label ?? "\(n)")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(n < 0 ? .appTextSecondary.opacity(0.3) : .appTextPrimary)
            }
        }
        .disabled(n < 0)
    }
}
