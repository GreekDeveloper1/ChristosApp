import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var discoveryVM:  DeviceDiscoveryViewModel
    @EnvironmentObject private var favoritesVM:  FavoritesViewModel
    @EnvironmentObject private var bluetoothMgr: BluetoothManager
    @EnvironmentObject private var historyMgr:   ConnectionHistoryManager

    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient.appBackground
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)

                BLEScannerView()
                    .tag(1)

                NFCScannerView()
                    .tag(2)

                FavoritesView()
                    .tag(3)

                SettingsView()
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            CustomTabBar(selectedTab: $selectedTab)
        }
        .onAppear {
            discoveryVM.loadSaved()
            favoritesVM.sync(with: discoveryVM.devices)
        }
    }
}

// MARK: - Custom Tab Bar
private struct CustomTabBar: View {
    @Binding var selectedTab: Int

    private let items: [(icon: String, label: String)] = [
        ("dot.radiowaves.left.and.right", "Discover"),
        ("wave.3.right",                  "BLE"),
        ("wave.3.forward.circle",         "NFC"),
        ("heart.fill",                    "Favorites"),
        ("gearshape.fill",                "Settings"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { idx in
                Button {
                    withAnimation(.snappy) { selectedTab = idx }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: items[idx].icon)
                            .font(.system(size: 20, weight: selectedTab == idx ? .semibold : .regular))
                            .foregroundStyle(
                                selectedTab == idx
                                    ? (idx == 1 || idx == 2
                                        ? LinearGradient(colors: [.green], startPoint: .top, endPoint: .bottom)
                                        : LinearGradient.accentGradient)
                                    : LinearGradient(colors: [.appTextSecondary], startPoint: .top, endPoint: .bottom)
                            )
                            .scaleEffect(selectedTab == idx ? 1.15 : 1)

                        Text(items[idx].label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(
                                selectedTab == idx
                                    ? (idx == 1 || idx == 2 ? .green : .appAccent)
                                    : .appTextSecondary
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .animation(.snappy, value: selectedTab)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 24, y: -4)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}
