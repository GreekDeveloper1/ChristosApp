import Foundation
import CoreBluetooth

// BLE discovery adapter that wraps BluetoothManager
// and converts CBPeripheral objects into Device models
final class BLEDiscovery {
    var onDeviceFound: ((Device) -> Void)?

    private weak var bluetoothManager: BluetoothManager?
    private var observationTask: Task<Void, Never>?

    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
    }

    func start() {
        bluetoothManager?.startScanning()
        observePeripherals()
    }

    func stop() {
        bluetoothManager?.stopScanning()
        observationTask?.cancel()
    }

    // MARK: - Private

    private func observePeripherals() {
        observationTask = Task {
            var knownIds = Set<UUID>()
            while !Task.isCancelled {
                guard let manager = bluetoothManager else { break }
                let newPeripherals = manager.discoveredPeripherals.filter {
                    !knownIds.contains($0.identifier)
                }
                for p in newPeripherals {
                    knownIds.insert(p.identifier)
                    let rssi = manager.rssi(for: p)
                    let device = buildDevice(from: p, rssi: rssi)
                    onDeviceFound?(device)
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func buildDevice(from peripheral: CBPeripheral, rssi: Int) -> Device {
        let name = peripheral.name ?? "BLE Device"
        let type = guessType(from: name)
        let brand = guessBrand(from: name)
        return Device(
            name: name,
            type: type,
            brand: brand,
            connectionType: .bluetooth,
            ipAddress: nil,
            port: nil,
            macAddress: nil,
            signalStrength: rssi,
            connectionStatus: .disconnected,
            serviceIdentifier: peripheral.identifier.uuidString,
            metadata: ["bleUUID": peripheral.identifier.uuidString]
        )
    }

    private func guessType(from name: String) -> DeviceType {
        let lower = name.lowercased()
        if lower.contains("tv") || lower.contains("bravia") || lower.contains("smart") { return .smartTV }
        if lower.contains("speaker") || lower.contains("soundbar") { return .smartSpeaker }
        if lower.contains("projector") { return .projector }
        if lower.contains("remote") { return .streamingBox }
        return .iotDevice
    }

    private func guessBrand(from name: String) -> DeviceBrand {
        let lower = name.lowercased()
        if lower.contains("samsung") { return .samsung }
        if lower.contains("lg")     { return .lg }
        if lower.contains("sony")   { return .sony }
        if lower.contains("apple")  { return .apple }
        if lower.contains("google") { return .google }
        return .unknown
    }
}
