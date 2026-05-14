import SwiftUI

enum DeviceType: String, Codable, CaseIterable {
    case smartTV      = "Smart TV"
    case appleTV      = "Apple TV"
    case androidTV    = "Android TV"
    case chromecast   = "Chromecast"
    case projector    = "Projector"
    case streamingBox = "Streaming Box"
    case smartSpeaker = "Smart Speaker"
    case iotDevice    = "IoT Device"
    case unknown      = "Unknown"

    var systemImage: String {
        switch self {
        case .smartTV:      return "tv"
        case .appleTV:      return "appletv"
        case .androidTV:    return "tv.and.hifispeaker.fill"
        case .chromecast:   return "dot.radiowaves.left.and.right"
        case .projector:    return "videoprojector"
        case .streamingBox: return "tv.fill"
        case .smartSpeaker: return "hifispeaker.fill"
        case .iotDevice:    return "homekit"
        case .unknown:      return "questionmark.circle"
        }
    }

    var accentColor: Color {
        switch self {
        case .smartTV:      return .blue
        case .appleTV:      return Color(white: 0.75)
        case .androidTV:    return .green
        case .chromecast:   return Color(red: 0.93, green: 0.26, blue: 0.21)
        case .projector:    return .purple
        case .streamingBox: return .orange
        case .smartSpeaker: return .cyan
        case .iotDevice:    return .yellow
        case .unknown:      return .secondary
        }
    }

    var supportsAppLaunch: Bool {
        switch self {
        case .smartTV, .appleTV, .androidTV, .chromecast, .streamingBox: return true
        default: return false
        }
    }

    var supportsInputSelection: Bool {
        switch self {
        case .smartTV, .projector, .streamingBox: return true
        default: return false
        }
    }
}

enum DeviceBrand: String, Codable, CaseIterable {
    case samsung    = "Samsung"
    case lg         = "LG"
    case sony       = "Sony"
    case google     = "Google"
    case apple      = "Apple"
    case epson      = "Epson"
    case benq       = "BenQ"
    case cosmote    = "Cosmote"
    case generic    = "Generic"
    case unknown    = "Unknown"

    var adapterType: AdapterType {
        switch self {
        case .samsung:  return .samsung
        case .lg:       return .lgWebOS
        case .sony:     return .sonyBravia
        case .google:   return .androidTV
        case .apple:    return .appleTV
        case .epson, .benq: return .generic
        case .cosmote:  return .androidTV
        case .generic, .unknown: return .generic
        }
    }
}

enum AdapterType: Equatable {
    case samsung
    case lgWebOS
    case sonyBravia
    case androidTV
    case appleTV
    case chromecast
    case generic
}
