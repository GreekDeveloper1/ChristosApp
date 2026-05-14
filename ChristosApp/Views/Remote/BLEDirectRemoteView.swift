import SwiftUI

struct BLEDirectRemoteView: View {

    @StateObject private var remote = BLERemotePeripheral()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        statusCard
                        pairingInstructions
                        if case .paired = remote.state { remoteGrid }
                        Spacer(minLength: 60)
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("BLE Direct Remote")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { remote.stopAdvertising() }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Label("Bluetooth HID Remote", systemImage: "wave.3.right")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.green)
            Spacer()
            if let feedback = remote.lastKeyFeedback {
                Text(feedback)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.green.opacity(0.7))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(white: 0.05))
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(Color.green.opacity(0.2)), alignment: .bottom)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(statusColor.opacity(0.4), lineWidth: 1.5))
                Image(systemName: statusIcon)
                    .font(.system(size: 32))
                    .foregroundColor(statusColor)
                    .symbolEffect(.pulse, isActive: remote.state == .advertising)
            }

            VStack(spacing: 4) {
                Text(statusTitle)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(statusSubtitle)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }

            if case .error(let msg) = remote.state {
                Text(msg)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            // Main action button
            switch remote.state {
            case .idle:
                actionButton("Start Advertising", color: .green) {
                    remote.startAdvertising()
                }
            case .error:
                actionButton("Retry", color: .green) {
                    remote.startAdvertising()
                }
            case .advertising:
                actionButton("Stop", color: .red) {
                    remote.stopAdvertising()
                }
            case .paired:
                actionButton("Disconnect", color: .orange) {
                    remote.stopAdvertising()
                }
            case .powering:
                ProgressView().tint(.green)
            }
        }
        .padding(20)
        .background(Color(white: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(statusColor.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Pairing Instructions

    @ViewBuilder
    private var pairingInstructions: some View {
        if remote.state == .advertising || remote.state == .idle {
            VStack(alignment: .leading, spacing: 12) {
                Text("── HOW TO PAIR ──")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.green.opacity(0.5))

                ForEach(Array(pairingSteps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(i + 1)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.green)
                            .frame(width: 16)
                        Text(step)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(14)
            .background(Color(white: 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.15), lineWidth: 1))
        }
    }

    private let pairingSteps = [
        "Tap \"Start Advertising\" — the phone broadcasts as \"ChristosRemote\" over Bluetooth.",
        "On your TV: Settings → Remote & Accessories → Add Accessory (or Bluetooth → Scan).",
        "Select \"ChristosRemote\" on the TV. Accept any pairing prompt on the phone.",
        "Once paired, the remote controls below become active.",
    ]

    // MARK: - Remote Grid

    private var remoteGrid: some View {
        VStack(spacing: 20) {

            // Media row
            sectionLabel("MEDIA")
            HStack(spacing: 14) {
                remoteBtn("backward.fill",  "Prev")   { remote.send(.previous,  label: "Prev") }
                remoteBtn("play.fill",      "Play")   { remote.send(.playPause,  label: "Play/Pause") }
                remoteBtn("forward.fill",   "Next")   { remote.send(.next,       label: "Next") }
            }

            // Volume row
            sectionLabel("VOLUME")
            HStack(spacing: 14) {
                remoteBtn("speaker.minus.fill", "Vol−") { remote.send(.volumeDown, label: "Vol −") }
                remoteBtn("speaker.slash.fill", "Mute") { remote.send(.mute,       label: "Mute") }
                remoteBtn("speaker.plus.fill",  "Vol+") { remote.send(.volumeUp,   label: "Vol +") }
            }

            // D-Pad
            sectionLabel("NAVIGATION")
            VStack(spacing: 8) {
                // Up
                HStack {
                    Spacer()
                    navBtn("chevron.up", "Up")     { remote.send(.up,     label: "Up") }
                    Spacer()
                }
                // Left / OK / Right
                HStack(spacing: 8) {
                    navBtn("chevron.left",  "Left")   { remote.send(.left,   label: "Left") }
                    navBtn("circle.fill",   "OK",  size: 56, accent: true) {
                        remote.send(.select, label: "OK")
                    }
                    navBtn("chevron.right", "Right")  { remote.send(.right,  label: "Right") }
                }
                // Down
                HStack {
                    Spacer()
                    navBtn("chevron.down", "Down")  { remote.send(.down,   label: "Down") }
                    Spacer()
                }
            }

            // System row
            sectionLabel("SYSTEM")
            HStack(spacing: 14) {
                remoteBtn("chevron.backward", "Back")  { remote.send(.back,     label: "Back") }
                remoteBtn("house.fill",       "Home")  { remote.send(.home,     label: "Home") }
                remoteBtn("line.3.horizontal","Menu")  { remote.send(.menu,     label: "Menu") }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text("── \(text) ──")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(Color.green.opacity(0.4))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func remoteBtn(
        _ icon: String,
        _ label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); action() }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color(white: 0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.15), lineWidth: 1))
        }
    }

    private func navBtn(
        _ icon: String,
        _ label: String,
        size: CGFloat = 48,
        accent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); action() }) {
            Image(systemName: icon)
                .font(.system(size: accent ? 20 : 18, weight: .semibold))
                .foregroundColor(accent ? .black : .white)
                .frame(width: size, height: size)
                .background(accent ? Color.green : Color(white: 0.12))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.green.opacity(accent ? 0 : 0.2), lineWidth: 1))
        }
    }

    private func actionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: { UIImpactFeedbackGenerator(style: .heavy).impactOccurred(); action() }) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
        }
    }

    // MARK: - Status Helpers

    private var statusColor: Color {
        switch remote.state {
        case .idle:        return .green.opacity(0.5)
        case .powering:    return .yellow
        case .advertising: return .yellow
        case .paired:      return .green
        case .error:       return .red
        }
    }

    private var statusIcon: String {
        switch remote.state {
        case .idle:        return "wave.3.right"
        case .powering:    return "antenna.radiowaves.left.and.right"
        case .advertising: return "antenna.radiowaves.left.and.right"
        case .paired:      return "checkmark.shield.fill"
        case .error:       return "exclamationmark.triangle.fill"
        }
    }

    private var statusTitle: String {
        switch remote.state {
        case .idle:        return "Ready"
        case .powering:    return "Starting Bluetooth…"
        case .advertising: return "Advertising"
        case .paired:      return "Paired & Ready"
        case .error:       return "Error"
        }
    }

    private var statusSubtitle: String {
        switch remote.state {
        case .idle:        return "Tap Start to broadcast as a Bluetooth remote"
        case .powering:    return "Waiting for Bluetooth…"
        case .advertising: return "Broadcasting as \"ChristosRemote\"\nGo to TV → Settings → Bluetooth → Add"
        case .paired:      return "TV connected — use the remote below"
        case .error:       return ""
        }
    }
}
