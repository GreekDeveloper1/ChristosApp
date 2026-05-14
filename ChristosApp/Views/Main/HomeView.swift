import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var discoveryVM:  DeviceDiscoveryViewModel
    @EnvironmentObject private var favoritesVM:  FavoritesViewModel
    @EnvironmentObject private var bluetoothMgr: BluetoothManager
    @EnvironmentObject private var historyMgr:   ConnectionHistoryManager

    @State private var showScanner = false
    @State private var selectedDevice: Device?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // Scan button / Radar
                        scanSection

                        // Turn off all
                        if discoveryVM.connectedCount > 0 {
                            turnOffAllButton
                        }

                        // Recent / Favorites quick row
                        if !favoritesVM.favoriteDevices.isEmpty {
                            favoritesRow
                        }

                        // Devices grouped by room
                        deviceList
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 110)
                }
            }
            .navigationDestination(item: $selectedDevice) { device in
                DeviceControlView(
                    viewModel: DeviceControlViewModel(device: device)
                )
                .environmentObject(historyMgr)
            }
        }
    }

    // MARK: - Sub-sections

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Christos App")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                Text("\(discoveryVM.devices.count) device\(discoveryVM.devices.count == 1 ? "" : "s") found")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
            }
            Spacer()
            // Bluetooth indicator
            Circle()
                .fill(bluetoothMgr.state == .poweredOn ? Color.appAccent : Color.appTextSecondary)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color.appAccent.opacity(0.4), lineWidth: 3)
                        .scaleEffect(bluetoothMgr.state == .poweredOn ? 1.8 : 1)
                        .opacity(bluetoothMgr.state == .poweredOn ? 0 : 0)
                )
        }
        .padding(.top, 16)
    }

    private var scanSection: some View {
        VStack(spacing: 16) {
            if discoveryVM.isScanning {
                RadarScanView()
                    .frame(height: 220)
                Button("Stop Scanning") {
                    discoveryVM.stopScan()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.appDanger)
                .padding(.vertical, 10)
                .padding(.horizontal, 28)
                .background(Color.appDanger.opacity(0.12))
                .clipShape(Capsule())
            } else {
                Button {
                    withAnimation(.smooth) {
                        discoveryVM.startScan(bluetoothManager: bluetoothMgr)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Scan for Devices")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(LinearGradient.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.appAccent.opacity(0.4), radius: 16, y: 6)
                }
                .haptic(.medium)
            }
        }
    }

    private var turnOffAllButton: some View {
        Button {
            discoveryVM.turnOffAll()
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "power")
                    .font(.system(size: 16, weight: .semibold))
                Text("Turn Off All (\(discoveryVM.connectedCount))")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.appDanger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.appDanger.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.appDanger.opacity(0.3), lineWidth: 1)
            )
        }
        .haptic(.heavy)
    }

    private var favoritesRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Favorites", systemImage: "heart.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appTextSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(favoritesVM.favoriteDevices) { device in
                        SmallDeviceCard(device: device)
                            .onTapGesture { selectedDevice = device }
                    }
                }
            }
        }
    }

    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 20) {
            if discoveryVM.devices.isEmpty {
                emptyState
            } else {
                // Unassigned
                if !discoveryVM.unassignedDevices.isEmpty {
                    DeviceSection(
                        title: "All Devices",
                        icon: "square.grid.2x2",
                        devices: discoveryVM.unassignedDevices,
                        onTap: { selectedDevice = $0 },
                        onFavorite: { favoritesVM.toggle($0) },
                        favoritesVM: favoritesVM
                    )
                }
                // By room
                ForEach(discoveryVM.rooms) { room in
                    let roomDevices = discoveryVM.devicesByRoom[room.id] ?? []
                    if !roomDevices.isEmpty {
                        DeviceSection(
                            title: room.name,
                            icon: room.icon,
                            devices: roomDevices,
                            onTap: { selectedDevice = $0 },
                            onFavorite: { favoritesVM.toggle($0) },
                            favoritesVM: favoritesVM
                        )
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundStyle(LinearGradient.accentGradient)
            Text("No devices found")
                .font(.title3.bold())
                .foregroundColor(.appTextPrimary)
            Text("Tap Scan to discover devices\non your local network")
                .font(.subheadline)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - DeviceSection
private struct DeviceSection: View {
    let title: String
    let icon: String
    let devices: [Device]
    let onTap: (Device) -> Void
    let onFavorite: (Device) -> Void
    let favoritesVM: FavoritesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appTextSecondary)

            ForEach(devices) { device in
                DeviceCardView(
                    device: device,
                    isFavorite: favoritesVM.isFavorite(device),
                    onTap: { onTap(device) },
                    onFavorite: { onFavorite(device) }
                )
            }
        }
    }
}

// MARK: - SmallDeviceCard
private struct SmallDeviceCard: View {
    let device: Device

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(device.type.accentColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: device.type.systemImage)
                    .font(.system(size: 22))
                    .foregroundColor(device.type.accentColor)
            }
            Text(device.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.appTextPrimary)
                .lineLimit(1)
                .frame(width: 70)
        }
        .padding(12)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
