import SwiftUI

struct MediaControlView: View {
    @ObservedObject var viewModel: DeviceControlViewModel

    var body: some View {
        VStack(spacing: 16) {
            Label("Media Controls", systemImage: "play.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.appTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Seek row
            HStack(spacing: 0) {
                mediaButton(icon: "backward.end.fill",  command: .skipBack,     color: .appTextSecondary)
                mediaButton(icon: "backward.fill",       command: .rewind,       color: .appTextSecondary)
                mediaButton(icon: "playpause.fill",      command: .playPause,    color: .appAccent, big: true)
                mediaButton(icon: "forward.fill",        command: .fastForward,  color: .appTextSecondary)
                mediaButton(icon: "forward.end.fill",    command: .skipForward,  color: .appTextSecondary)
            }
            .padding(.vertical, 8)
            .background(Color.appSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            // Stop / Record
            HStack(spacing: 16) {
                mediaButton(icon: "stop.fill",      command: .stop,   color: .appDanger,   label: "Stop")
                mediaButton(icon: "record.circle",  command: .record, color: .appDanger,   label: "Record")
            }
        }
        .padding(16)
        .cardStyle(padding: 0)
    }

    @ViewBuilder
    private func mediaButton(
        icon: String,
        command: DeviceCommand,
        color: Color,
        big: Bool = false,
        label: String? = nil
    ) -> some View {
        Button {
            viewModel.send(command)
            UIImpactFeedbackGenerator(style: big ? .medium : .light).impactOccurred()
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if big {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 56, height: 56)
                    }
                    Image(systemName: icon)
                        .font(.system(size: big ? 26 : 20, weight: .semibold))
                        .foregroundColor(color)
                }
                if let label {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, big ? 4 : 10)
        }
    }
}
