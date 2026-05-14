import Foundation
import Combine

@MainActor
final class DeviceDiscoveryViewModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var errorMessage: String?
    @Published var rooms: [Room] = []

    private var discoveryService: DeviceDiscoveryService?
    private var scanTimer: Timer?
    private var progressTimer: Timer?

    var devicesByRoom: [UUID?: [Device]] {
        Dictionary(grouping: devices, by: { $0.roomId })
    }

    var unassignedDevices: [Device] {
        devices.filter { $0.roomId == nil }
    }

    var connectedCount: Int {
        devices.filter { $0.connectionStatus == .connected }.count
    }

    // MARK: - Scanning

    func startScan(bluetoothManager: BluetoothManager) {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0
        errorMessage = nil

        discoveryService = DeviceDiscoveryService(bluetoothManager: bluetoothManager)
        discoveryService?.onDeviceFound   = { [weak self] device in self?.addOrUpdate(device) }
        discoveryService?.onDeviceUpdated = { [weak self] device in self?.addOrUpdate(device) }
        discoveryService?.startScan()

        startProgressAnimation()

        // Auto-stop after 30 seconds
        scanTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            Task { await self?.stopScan() }
        }
    }

    func stopScan() {
        discoveryService?.stopScan()
        isScanning = false
        scanProgress = 1.0
        scanTimer?.invalidate()
        progressTimer?.invalidate()
        persist()
    }

    // MARK: - Device Management

    func toggleFavorite(_ device: Device) {
        update(device.id) { $0.isFavorite.toggle() }
    }

    func assignRoom(_ roomId: UUID?, to deviceId: UUID) {
        update(deviceId) { $0.roomId = roomId }
        persist()
    }

    func removeDevice(_ device: Device) {
        devices.removeAll { $0.id == device.id }
        persist()
    }

    func turnOffAll() {
        let paired = devices.filter { $0.connectionStatus == .connected }
        for device in paired {
            Task {
                let adapter = AdapterFactory.make(for: device)
                try? await adapter.send(.powerOff)
            }
        }
    }

    // MARK: - Rooms

    func addRoom(_ room: Room) {
        rooms.append(room)
        PersistenceManager.shared.saveRooms(rooms)
    }

    func deleteRoom(_ room: Room) {
        devices.indices.forEach { idx in
            if devices[idx].roomId == room.id {
                devices[idx].roomId = nil
            }
        }
        rooms.removeAll { $0.id == room.id }
        PersistenceManager.shared.saveRooms(rooms)
    }

    func loadSaved() {
        devices = PersistenceManager.shared.loadDevices()
        rooms   = PersistenceManager.shared.loadRooms()
    }

    // MARK: - Private

    private func addOrUpdate(_ device: Device) {
        if let idx = devices.firstIndex(where: {
            $0.id == device.id ||
            ($0.ipAddress != nil && $0.ipAddress == device.ipAddress) ||
            ($0.serviceIdentifier != nil && $0.serviceIdentifier == device.serviceIdentifier)
        }) {
            var current = devices[idx]
            current.lastSeen = Date()
            if let ip = device.ipAddress      { current.ipAddress = ip }
            if device.type != .unknown        { current.type = device.type }
            if device.brand != .unknown       { current.brand = device.brand }
            if device.signalStrength > current.signalStrength { current.signalStrength = device.signalStrength }
            devices[idx] = current
        } else {
            devices.append(device)
        }
    }

    private func update(_ id: UUID, mutation: (inout Device) -> Void) {
        if let idx = devices.firstIndex(where: { $0.id == id }) {
            mutation(&devices[idx])
        }
    }

    private func startProgressAnimation() {
        var elapsed: Double = 0
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] t in
            elapsed += 0.3
            self?.scanProgress = min(elapsed / 30, 0.95)
            if elapsed >= 30 { t.invalidate() }
        }
    }

    private func persist() {
        PersistenceManager.shared.saveDevices(devices)
    }
}
