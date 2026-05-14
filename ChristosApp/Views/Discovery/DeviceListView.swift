import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject private var discoveryVM: DeviceDiscoveryViewModel
    @EnvironmentObject private var favoritesVM: FavoritesViewModel
    @Binding var selectedDevice: Device?

    @State private var searchText = ""
    @State private var filterType: DeviceType? = nil

    private var filtered: [Device] {
        discoveryVM.devices.filter { device in
            let matchesSearch = searchText.isEmpty ||
                device.name.localizedCaseInsensitiveContains(searchText) ||
                (device.ipAddress?.contains(searchText) ?? false)
            let matchesFilter = filterType == nil || device.type == filterType
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search + filter
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.appTextSecondary)
                    TextField("Search devices...", text: $searchText)
                        .foregroundColor(.appTextPrimary)
                        .tint(.appAccent)
                }
                .padding(12)
                .background(Color.appSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(label: "All", isSelected: filterType == nil) {
                            filterType = nil
                        }
                        ForEach(DeviceType.allCases.filter { $0 != .unknown }, id: \.self) { type in
                            FilterChip(
                                label: type.rawValue,
                                icon: type.systemImage,
                                isSelected: filterType == type
                            ) {
                                filterType = filterType == type ? nil : type
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // List
            if filtered.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.appTextSecondary)
                    Text("No matching devices")
                        .foregroundColor(.appTextSecondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { device in
                            DeviceCardView(
                                device: device,
                                isFavorite: favoritesVM.isFavorite(device),
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
}

// MARK: - Filter Chip
private struct FilterChip: View {
    let label: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? Color.appAccent : Color.appSurfaceElevated)
            .foregroundColor(isSelected ? .white : .appTextSecondary)
            .clipShape(Capsule())
        }
        .haptic(.soft)
    }
}
