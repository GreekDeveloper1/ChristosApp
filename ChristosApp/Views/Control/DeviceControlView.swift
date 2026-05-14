import SwiftUI

struct DeviceControlView: View {
    @StateObject var viewModel: DeviceControlViewModel
    @EnvironmentObject private var historyMgr: ConnectionHistoryManager

    @State private var showAppLauncher = false
    @State private var selectedInput: String? = nil

    var body: some View {
        ZStack {
            LinearGradient.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Device header
                    deviceHeader

                    // Connection status / connect button
                    connectionSection

                    if viewModel.connectionStatus == .connected {
                        // Power + Volume row
                        powerVolumeRow

                        // Main remote control
                        TVControlView(viewModel: viewModel)

                        // Media controls
                        MediaControlView(viewModel: viewModel)

                        // Input selector
                        if viewModel.device.type.supportsInputSelection,
                           !viewModel.availableInputs.isEmpty {
                            inputSelector
                        }

                        // App Launcher
                        if viewModel.device.type.supportsAppLaunch {
                            appLauncherSection
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 110)
            }

            // Command feedback overlay
            if let feedback = viewModel.lastCommandFeedback {
                FeedbackToast(text: feedback)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.35), value: viewModel.lastCommandFeedback)
            }
        }
        .navigationTitle(viewModel.device.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if viewModel.connectionStatus != .connected {
                Task { await viewModel.connect(historyManager: historyMgr) }
            }
        }
        .sheet(isPresented: $showAppLauncher) {
            AppLauncherView(viewModel: viewModel)
        }
    }

    // MARK: - Sub-views

    private var deviceHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(viewModel.device.type.accentColor.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: viewModel.device.type.systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(viewModel.device.type.accentColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.device.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.appTextPrimary)
                Text("\(viewModel.device.brand.rawValue) · \(viewModel.device.type.rawValue)")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
                if let ip = viewModel.device.ipAddress {
                    Text(ip)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.appTextSecondary.opacity(0.7))
                }
            }
            Spacer()
            ConnectionBadge(status: viewModel.connectionStatus)
        }
        .padding(16)
        .cardStyle(padding: 0)
    }

    private var connectionSection: some View {
        VStack(spacing: 12) {
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.appWarning)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.appTextSecondary)
                    Spacer()
                }
                .padding(12)
                .background(Color.appWarning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if viewModel.connectionStatus != .connected {
                Button {
                    Task { await viewModel.connect(historyManager: historyMgr) }
                } label: {
                    HStack {
                        if viewModel.connectionStatus.isTransitioning {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "bolt.fill")
                        }
                        Text(viewModel.connectionStatus.isTransitioning ? "Connecting..." : "Connect")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(viewModel.connectionStatus.isTransitioning)
                .haptic(.medium)
            }
        }
    }

    private var powerVolumeRow: some View {
        HStack(spacing: 16) {
            // Power button
            RemoteButton(
                icon: "power",
                label: "Power",
                color: viewModel.isPoweredOn ? .appDanger : .appSuccess,
                size: .large
            ) {
                viewModel.send(.powerToggle)
            }

            // Volume section
            VStack(spacing: 8) {
                HStack(spacing: 20) {
                    RemoteButton(icon: "speaker.minus", label: "Vol -", color: .appAccent, size: .medium) {
                        viewModel.send(.volumeDown)
                    }
                    VStack(spacing: 2) {
                        Text("\(viewModel.volume)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.appTextPrimary)
                        Text("Volume")
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                    }
                    .frame(minWidth: 50)
                    RemoteButton(icon: "speaker.plus", label: "Vol +", color: .appAccent, size: .medium) {
                        viewModel.send(.volumeUp)
                    }
                }
                RemoteButton(icon: "speaker.slash", label: "Mute", color: .appTextSecondary, size: .small) {
                    viewModel.send(.muteToggle)
                }
                .opacity(viewModel.isMuted ? 1 : 0.6)
            }
        }
        .padding(16)
        .cardStyle(padding: 0)
    }

    private var inputSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Input Source", systemImage: "input.hdmi")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.appTextSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.availableInputs, id: \.self) { input in
                        Button {
                            selectedInput = input
                            viewModel.send(.setInput(input))
                        } label: {
                            Text(input)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(selectedInput == input ? Color.appAccent : Color.appSurfaceElevated)
                                .foregroundColor(selectedInput == input ? .white : .appTextSecondary)
                                .clipShape(Capsule())
                        }
                        .haptic(.soft)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var appLauncherSection: some View {
        Button {
            showAppLauncher = true
        } label: {
            HStack {
                Label("Launch App", systemImage: "app.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.appTextSecondary)
            }
        }
        .cardStyle()
        .haptic(.soft)
    }
}

// MARK: - Feedback Toast
private struct FeedbackToast: View {
    let text: String

    var body: some View {
        VStack {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.3), radius: 10)
            Spacer()
        }
        .padding(.top, 8)
    }
}
