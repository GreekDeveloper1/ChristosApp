import Foundation
import Combine

// Orchestrates all discovery channels and de-duplicates results
final class DeviceDiscoveryService {
    var onDeviceFound:   ((Device) -> Void)?
    var onDeviceUpdated: ((Device) -> Void)?

    private let bonjour: BonjourDiscovery
    private let ssdp:    SSDPDiscovery
    private let ble:     BLEDiscovery

    private var discoveredMap: [String: Device] = [:]  // keyed by de-dup identifier

    init(bluetoothManager: BluetoothManager) {
        bonjour = BonjourDiscovery()
        ssdp    = SSDPDiscovery()
        ble     = BLEDiscovery(bluetoothManager: bluetoothManager)

        bonjour.onDeviceFound = { [weak self] in self?.handle($0) }
        ssdp.onDeviceFound    = { [weak self] in self?.handle($0) }
        ble.onDeviceFound     = { [weak self] in self?.handle($0) }
    }

    func startScan() {
        discoveredMap.removeAll()
        bonjour.start()
        ssdp.start()
        ble.start()
    }

    func stopScan() {
        bonjour.stop()
        ssdp.stop()
        ble.stop()
    }

    // MARK: - De-duplication

    private func handle(_ device: Device) {
        let key = dedupKey(for: device)
        if let existing = discoveredMap[key] {
            // Update existing — merge better data
            var updated = existing
            if let ip = device.ipAddress      { updated.ipAddress = ip }
            if let p  = device.port           { updated.port = p }
            if device.signalStrength > existing.signalStrength { updated.signalStrength = device.signalStrength }
            if device.type != .unknown        { updated.type = device.type }
            if device.brand != .unknown       { updated.brand = device.brand }
            updated.name     = device.name.count > existing.name.count ? device.name : existing.name
            updated.lastSeen = Date()
            discoveredMap[key] = updated
            DispatchQueue.main.async { self.onDeviceUpdated?(updated) }
        } else {
            discoveredMap[key] = device
            DispatchQueue.main.async { self.onDeviceFound?(device) }
        }
    }

    private func dedupKey(for device: Device) -> String {
        if let ip = device.ipAddress { return ip }
        if let si = device.serviceIdentifier { return si }
        return device.id.uuidString
    }
}
