import Foundation
import Combine

final class ConnectionHistoryManager: ObservableObject {
    @Published private(set) var history: [ConnectionHistory] = []

    private let maxEntries = 100
    private let key = "connection_history"

    init() {
        load()
    }

    func recordConnection(for device: Device) {
        let entry = ConnectionHistory(device: device)
        history.insert(entry, at: 0)
        trim()
        save()
    }

    func recordDisconnection(deviceId: UUID) {
        if let idx = history.firstIndex(where: {
            $0.deviceId == deviceId && $0.disconnectedAt == nil
        }) {
            history[idx].disconnectedAt = Date()
            save()
        }
    }

    func clearHistory() {
        history.removeAll()
        save()
    }

    func recentDevices(limit: Int = 5) -> [ConnectionHistory] {
        Array(history.prefix(limit))
    }

    // MARK: - Private

    private func trim() {
        if history.count > maxEntries {
            history = Array(history.prefix(maxEntries))
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([ConnectionHistory].self, from: data)
        else { return }
        history = entries
    }
}
