import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var discoveryVM:  DeviceDiscoveryViewModel
    @EnvironmentObject private var favoritesVM:  FavoritesViewModel
    @EnvironmentObject private var historyMgr:   ConnectionHistoryManager

    @State private var selectedDevice: Device?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.appBackground.ignoresSafeArea()

                Group {
                    if favoritesVM.favoriteDevices.isEmpty {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(favoritesVM.favoriteDevices) { device in
                                    DeviceCardView(
                                        device: device,
                                        isFavorite: true,
                                        onTap: { selectedDevice = device },
                                        onFavorite: { favoritesVM.toggle(device) }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 110)
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $selectedDevice) { device in
                DeviceControlView(viewModel: DeviceControlViewModel(device: device))
                    .environmentObject(historyMgr)
            }
            .onChange(of: discoveryVM.devices) { _, devices in
                favoritesVM.sync(with: devices)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48))
                .foregroundStyle(LinearGradient.accentGradient)
            Text("No favorites yet")
                .font(.title3.bold())
                .foregroundColor(.appTextPrimary)
            Text("Tap the heart icon on any device\nto add it here.")
                .font(.subheadline)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
