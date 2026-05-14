import SwiftUI

extension Color {
    // MARK: - App Theme
    static let appBackground      = Color(hex: "#0A0A0F")!
    static let appSurface         = Color(hex: "#141420")!
    static let appSurfaceElevated = Color(hex: "#1E1E2E")!
    static let appAccent          = Color(hex: "#6C63FF")!
    static let appAccentSecondary = Color(hex: "#00D4FF")!
    static let appDanger          = Color(hex: "#FF4B55")!
    static let appSuccess         = Color(hex: "#00E676")!
    static let appWarning         = Color(hex: "#FFB74D")!
    static let appTextPrimary     = Color.white
    static let appTextSecondary   = Color(white: 0.65)
    static let appDivider         = Color(white: 0.15)

    // MARK: - Hex Initialiser
    init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let value = UInt64(str, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8)  & 0xFF) / 255
        let b = Double(value          & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Gradient Helpers
extension LinearGradient {
    static let appBackground = LinearGradient(
        colors: [Color(hex: "#0A0A0F")!, Color(hex: "#0D0D1A")!],
        startPoint: .top, endPoint: .bottom
    )

    static let accentGradient = LinearGradient(
        colors: [Color.appAccent, Color.appAccentSecondary],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let dangerGradient = LinearGradient(
        colors: [Color(hex: "#FF4B55")!, Color(hex: "#FF6B35")!],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [Color.appSurface, Color.appSurfaceElevated],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
