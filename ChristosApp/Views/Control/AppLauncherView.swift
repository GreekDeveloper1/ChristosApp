import SwiftUI

struct AppLauncherView: View {
    @ObservedObject var viewModel: DeviceControlViewModel
    @Environment(\.dismiss) private var dismiss

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    private let appColors: [String: Color] = [
        "netflix": .red,
        "youtube": .red,
        "prime":   Color(red: 0.1, green: 0.5, blue: 0.9),
        "disney":  Color(red: 0.1, green: 0.1, blue: 0.6),
        "spotify": .green,
        "twitch":  .purple,
        "hbomax":  .purple,
        "appletv+": .gray,
    ]

    private let appIcons: [String: String] = [
        "netflix":  "play.rectangle.fill",
        "youtube":  "play.circle.fill",
        "prime":    "shippingbox.fill",
        "disney":   "wand.and.stars",
        "spotify":  "music.note.list",
        "twitch":   "gamecontroller.fill",
        "hbomax":   "tv.fill",
        "appletv+": "appletv.fill",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Preset apps
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Popular Apps")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.appTextSecondary)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(AppInfo.presets) { app in
                                    AppIconButton(
                                        app: app,
                                        color: appColors[app.id] ?? .appAccent,
                                        icon: appIcons[app.id] ?? "app.fill"
                                    ) {
                                        viewModel.send(.launchApp(app))
                                        dismiss()
                                    }
                                }
                            }
                        }

                        // Device-specific installed apps
                        if !viewModel.installedApps.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Installed on Device")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.appTextSecondary)

                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(viewModel.installedApps) { app in
                                        AppIconButton(
                                            app: app,
                                            color: .appAccent,
                                            icon: "app.fill"
                                        ) {
                                            viewModel.send(.launchApp(app))
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Launch App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
        }
        .task {
            await viewModel.loadDeviceState()
        }
    }
}

// MARK: - App Icon Button
private struct AppIconButton: View {
    let app: AppInfo
    let color: Color
    let icon: String
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 60, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(color.opacity(0.3), lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 26))
                        .foregroundColor(color)
                }

                Text(app.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .scaleEffect(pressed ? 0.94 : 1)
        }
        .buttonStyle(PressButtonStyle(pressed: $pressed))
        .haptic(.soft)
    }
}
