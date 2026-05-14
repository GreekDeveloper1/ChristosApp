import Foundation
import CoreBluetooth

struct BLEAdvertisement: Identifiable, Equatable {
    let id: UUID                         // CBPeripheral.identifier
    var name: String
    var rssi: Int
    var isConnectable: Bool
    var serviceUUIDs: [CBUUID]
    var manufacturerData: Data?
    var manufacturerCompany: String?
    var txPowerLevel: Int?
    var localName: String?
    var serviceData: [CBUUID: Data]
    var overflowUUIDs: [CBUUID]
    var lastSeen: Date
    var seenCount: Int                   // how many advertisement packets received

    var displayName: String {
        if let n = localName, !n.isEmpty { return n }
        if name != "Unknown" { return name }
        return "Unknown Device"
    }

    var manufacturerHex: String? {
        guard let data = manufacturerData else { return nil }
        return data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    var companyName: String? {
        guard let data = manufacturerData, data.count >= 2 else { return nil }
        let companyId = UInt16(data[0]) | (UInt16(data[1]) << 8)
        return BluetoothCompanies.name(for: companyId)
    }

    var signalLevel: SignalLevel {
        switch rssi {
        case ..<(-80): return .poor
        case -80 ..< -70: return .fair
        case -70 ..< -55: return .good
        default: return .excellent
        }
    }

    var signalEmoji: String {
        switch rssi {
        case ..<(-80): return "▂___"
        case -80 ..< -70: return "▂▄__"
        case -70 ..< -55: return "▂▄▆_"
        default: return "▂▄▆█"
        }
    }

    static func == (lhs: BLEAdvertisement, rhs: BLEAdvertisement) -> Bool {
        lhs.id == rhs.id
    }
}

// Partial Bluetooth company ID lookup (most common ones)
enum BluetoothCompanies {
    static func name(for id: UInt16) -> String? {
        let table: [UInt16: String] = [
            0x004C: "Apple",
            0x0006: "Microsoft",
            0x0075: "Samsung",
            0x00E0: "Google",
            0x0499: "Ruuvi Innovations",
            0x0157: "Polar Electro",
            0x0059: "Nordic Semiconductor",
            0x0171: "Amazon",
            0x02E5: "Ableton",
            0x008C: "Garmin",
            0x0078: "Bose",
            0x001D: "Qualcomm",
            0x0010: "Broadcom",
            0x038F: "Tile",
            0x0087: "Xiaomi",
        ]
        return table[id]
    }
}
