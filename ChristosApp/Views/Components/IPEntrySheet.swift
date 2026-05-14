import SwiftUI

struct IPEntrySheet: View {
    let deviceName: String
    @Binding var ipAddress: String
    let onConnect: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var port = ""
    @FocusState private var ipFocused: Bool

    private var isValid: Bool {
        let parts = ipAddress.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { Int($0) != nil }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.appBackground.ignoresSafeArea()

                VStack(spacing: 28) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.appAccent.opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: "network")
                            .font(.system(size: 30))
                            .foregroundColor(.appAccent)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 8) {
                        Text("Enter IP Address")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.appTextPrimary)
                        Text("Could not auto-detect IP for\n\(deviceName)")
                            .font(.subheadline)
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // IP field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("IP ADDRESS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.appTextSecondary)
                            .tracking(1.5)

                        TextField("192.168.1.100", text: $ipAddress)
                            .font(.system(size: 20, design: .monospaced))
                            .foregroundColor(.appTextPrimary)
                            .keyboardType(.decimalPad)
                            .focused($ipFocused)
                            .padding(14)
                            .background(Color.appSurfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isValid ? Color.appAccent.opacity(0.5) : Color.appDivider, lineWidth: 1)
                            )

                        Text("Find it on your device: Settings → Network → Wi-Fi → tap your network")
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary.opacity(0.7))
                    }
                    .padding(.horizontal, 24)

                    // Common IPs hint
                    VStack(alignment: .leading, spacing: 8) {
                        Text("QUICK SELECT")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.appTextSecondary)
                            .tracking(1.5)
                            .padding(.horizontal, 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(["192.168.1.", "192.168.0.", "10.0.0.", "172.16.0."], id: \.self) { prefix in
                                    Button {
                                        ipAddress = prefix
                                        ipFocused = true
                                    } label: {
                                        Text(prefix + "...")
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundColor(.appAccent)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Color.appAccent.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }

                    Spacer()

                    // Connect button
                    Button {
                        onConnect()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.fill")
                            Text("Connect")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(isValid ? LinearGradient.accentGradient : LinearGradient(colors: [Color.appTextSecondary.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .disabled(!isValid)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.appTextSecondary)
                }
            }
        }
        .onAppear { ipFocused = true }
    }
}
