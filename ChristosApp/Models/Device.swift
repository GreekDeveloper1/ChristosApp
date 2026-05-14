import Foundation

struct Device: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var type: DeviceType
    var brand: DeviceBrand
    var connectionType: ConnectionType
    var ipAddress: String?
    var port: Int?
    var macAddress: String?
    var signalStrength: Int          // dBm (RSSI)
    var connectionStatus: ConnectionStatus
    var roomId: UUID?
    var isFavorite: Bool
    var lastSeen: Date
    var serviceIdentifier: String?   // mDNS name, UPnP USN, BLE peripheral UUID
    var metadata: [String: String]   // brand-specific key-value pairs

    init(
        id: UUID = UUID(),
        name: String,
        type: DeviceType,
        brand: DeviceBrand = .unknown,
        connectionType: ConnectionType,
        ipAddress: String? = nil,
        port: Int? = nil,
        macAddress: String? = nil,
        signalStrength: Int = -70,
        connectionStatus: ConnectionStatus = .disconnected,
        roomId: UUID? = nil,
        isFavorite: Bool = false,
        lastSeen: Date = Date(),
        serviceIdentifier: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.brand = brand
        self.connectionType = connectionType
        self.ipAddress = ipAddress
        self.port = port
        self.macAddress = macAddress
        self.signalStrength = signalStrength
        self.connectionStatus = connectionStatus
        self.roomId = roomId
        self.isFavorite = isFavorite
        self.lastSeen = lastSeen
        self.serviceIdentifier = serviceIdentifier
        self.metadata = metadata
    }

    var signalLevel: SignalLevel {
        switch signalStrength {
        case ..<(-80): return .poor
        case -80 ..< -70: return .fair
        case -70 ..< -55: return .good
        default: return .excellent
        }
    }

    var displayAddress: String {
        ipAddress ?? serviceIdentifier ?? "Unknown"
    }

    static func == (lhs: Device, rhs: Device) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum ConnectionType: String, Codable, CaseIterable {
    case wifi       = "Wi-Fi"
    case bluetooth  = "Bluetooth"
    case bonjour    = "Bonjour/mDNS"
    case ssdp       = "SSDP/UPnP"
    case chromecast = "Chromecast"
    case airplay    = "AirPlay"

    var systemImage: String {
        switch self {
        case .wifi:       return "wifi"
        case .bluetooth:  return "wave.3.right"
        case .bonjour:    return "network"
        case .ssdp:       return "server.rack"
        case .chromecast: return "dot.radiowaves.left.and.right"
        case .airplay:    return "airplayvideo"
        }
    }
}

enum SignalLevel: Int, Comparable {
    case poor = 1, fair, good, excellent

    static func < (lhs: SignalLevel, rhs: SignalLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .poor:      return "Poor"
        case .fair:      return "Fair"
        case .good:      return "Good"
        case .excellent: return "Excellent"
        }
    }
}

struct ConnectionHistory: Identifiable, Codable {
    let id: UUID
    let deviceId: UUID
    let deviceName: String
    let connectedAt: Date
    var disconnectedAt: Date?

    init(device: Device) {
        self.id = UUID()
        self.deviceId = device.id
        self.deviceName = device.name
        self.connectedAt = Date()
    }
}
