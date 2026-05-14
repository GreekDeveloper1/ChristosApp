import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var discoveryVM: DeviceDiscoveryViewModel
    @EnvironmentObject private var historyMgr: ConnectionHistoryManager
    @State private var showRoomManager = false
    @State private var showHistory = false
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.appBackground.ignoresSafeArea()

                List {
                    // App Credit
                    Section {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(LinearGradient.accentGradient)
                                    .frame(width: 52, height: 52)
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Christos App")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.appTextPrimary)
                                Text("Universal Remote Hub")
                                    .font(.subheadline)
                                    .foregroundColor(.appAccentSecondary)
                                Text("Made by Christos Papavas")
                                    .font(.caption)
                                    .foregroundColor(.appTextSecondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.appSurface)
                    }

                    // Rooms
                    Section("Organization") {
                        Button {
                            showRoomManager = true
                        } label: {
                            Label("Manage Rooms", systemImage: "house.fill")
                                .foregroundColor(.appTextPrimary)
                        }
                        .listRowBackground(Color.appSurface)
                    }

                    // History
                    Section("Activity") {
                        Button {
                            showHistory = true
                        } label: {
                            Label("Connection History", systemImage: "clock.arrow.circlepath")
                                .foregroundColor(.appTextPrimary)
                        }
                        .listRowBackground(Color.appSurface)

                        HStack {
                            Label("Devices Found", systemImage: "network")
                                .foregroundColor(.appTextPrimary)
                            Spacer()
                            Text("\(discoveryVM.devices.count)")
                                .foregroundColor(.appTextSecondary)
                        }
                        .listRowBackground(Color.appSurface)

                        HStack {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.appTextPrimary)
                            Spacer()
                            Text("\(discoveryVM.connectedCount)")
                                .foregroundColor(.appSuccess)
                        }
                        .listRowBackground(Color.appSurface)
                    }

                    // Danger zone
                    Section("Data") {
                        Button(role: .destructive) {
                            historyMgr.clearHistory()
                        } label: {
                            Label("Clear History", systemImage: "trash")
                        }
                        .listRowBackground(Color.appSurface)

                        Button(role: .destructive) {
                            discoveryVM.devices.removeAll()
                            PersistenceManager.shared.saveDevices([])
                        } label: {
                            Label("Remove All Devices", systemImage: "xmark.circle")
                        }
                        .listRowBackground(Color.appSurface)
                    }

                    // About
                    Section("About") {
                        HStack {
                            Label("Version", systemImage: "info.circle")
                                .foregroundColor(.appTextPrimary)
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.appTextSecondary)
                        }
                        .listRowBackground(Color.appSurface)

                        HStack {
                            Label("Developer", systemImage: "person.fill")
                                .foregroundColor(.appTextPrimary)
                            Spacer()
                            Text("Christos Papavas")
                                .foregroundColor(.appTextSecondary)
                        }
                        .listRowBackground(Color.appSurface)

                        HStack {
                            Label("Protocols", systemImage: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.appTextPrimary)
                            Spacer()
                            Text("Wi-Fi · BLE · mDNS · SSDP")
                                .font(.caption)
                                .foregroundColor(.appTextSecondary)
                        }
                        .listRowBackground(Color.appSurface)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showRoomManager) {
                RoomManagerView()
                    .environmentObject(discoveryVM)
            }
            .sheet(isPresented: $showHistory) {
                HistoryView()
                    .environmentObject(historyMgr)
            }
        }
    }
}
