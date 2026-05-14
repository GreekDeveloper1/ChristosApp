import Foundation
import Combine

final class PersistenceManager {
    static let shared = PersistenceManager()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let devices  = "saved_devices"
        static let rooms    = "saved_rooms"
        static let favorites = "saved_favorites"
    }

    private init() {}

    // MARK: - Devices

    func saveDevices(_ devices: [Device]) {
        if let data = try? JSONEncoder().encode(devices) {
            defaults.set(data, forKey: Keys.devices)
        }
    }

    func loadDevices() -> [Device] {
        guard let data = defaults.data(forKey: Keys.devices),
              let devices = try? JSONDecoder().decode([Device].self, from: data)
        else { return [] }
        return devices
    }

    // MARK: - Rooms

    func saveRooms(_ rooms: [Room]) {
        if let data = try? JSONEncoder().encode(rooms) {
            defaults.set(data, forKey: Keys.rooms)
        }
    }

    func loadRooms() -> [Room] {
        guard let data = defaults.data(forKey: Keys.rooms),
              let rooms = try? JSONDecoder().decode([Room].self, from: data)
        else { return Room.defaults }
        return rooms
    }

    // MARK: - Favorites

    func saveFavoriteIDs(_ ids: Set<UUID>) {
        let strings = ids.map { $0.uuidString }
        defaults.set(strings, forKey: Keys.favorites)
    }

    func loadFavoriteIDs() -> Set<UUID> {
        let strings = defaults.stringArray(forKey: Keys.favorites) ?? []
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }
}
