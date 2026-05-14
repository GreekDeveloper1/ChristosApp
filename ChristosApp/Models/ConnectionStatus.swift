import SwiftUI

enum ConnectionStatus: String, Codable {
    case disconnected  = "Disconnected"
    case scanning      = "Scanning"
    case connecting    = "Connecting"
    case connected     = "Connected"
    case pairing       = "Pairing"
    case error         = "Error"

    var color: Color {
        switch self {
        case .disconnected: return .gray
        case .scanning:     return .yellow
        case .connecting:   return .orange
        case .connected:    return .green
        case .pairing:      return .blue
        case .error:        return .red
        }
    }

    var systemImage: String {
        switch self {
        case .disconnected: return "circle"
        case .scanning:     return "magnifyingglass.circle"
        case .connecting:   return "arrow.triangle.2.circlepath"
        case .connected:    return "checkmark.circle.fill"
        case .pairing:      return "lock.open.rotation"
        case .error:        return "exclamationmark.circle.fill"
        }
    }

    var isActive: Bool {
        self == .connected
    }

    var isTransitioning: Bool {
        self == .connecting || self == .scanning || self == .pairing
    }
}
