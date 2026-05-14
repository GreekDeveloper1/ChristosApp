import Foundation
import Combine

@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published var favoriteDevices: [Device] = []
    @Published var favoriteIds: Set<UUID> = []

    private let persistence = PersistenceManager.shared

    init() {
        favoriteIds = persistence.loadFavoriteIDs()
    }

    func sync(with allDevices: [Device]) {
        favoriteDevices = allDevices.filter { favoriteIds.contains($0.id) }
    }

    func toggle(_ device: Device) {
        if favoriteIds.contains(device.id) {
            favoriteIds.remove(device.id)
            favoriteDevices.removeAll { $0.id == device.id }
        } else {
            favoriteIds.insert(device.id)
            if !favoriteDevices.contains(device) {
                favoriteDevices.append(device)
            }
        }
        persistence.saveFavoriteIDs(favoriteIds)
    }

    func isFavorite(_ device: Device) -> Bool {
        favoriteIds.contains(device.id)
    }
}
