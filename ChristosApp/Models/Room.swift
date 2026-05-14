import Foundation
import SwiftUI

struct Room: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var colorHex: String

    init(id: UUID = UUID(), name: String, icon: String = "house", colorHex: String = "#2196F3") {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    static let defaults: [Room] = [
        Room(id: UUID(), name: "Living Room",  icon: "sofa",         colorHex: "#2196F3"),
        Room(id: UUID(), name: "Bedroom",      icon: "bed.double",   colorHex: "#9C27B0"),
        Room(id: UUID(), name: "Kitchen",      icon: "fork.knife",   colorHex: "#FF9800"),
        Room(id: UUID(), name: "Office",       icon: "desktopcomputer", colorHex: "#4CAF50"),
    ]
}
