import SwiftUI
import CoreBluetooth

struct BLEDeviceDetailView: View {
    let advertisement: BLEAdvertisement
    let bluetoothMgr: BluetoothManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {

                        // Title card
                        headerCard

                        // Signal
                        infoSection("SIGNAL") {
                            row("RSSI", value: "\(advertisement.rssi) dBm", color: rssiColor)
                            row("Level", value: advertisement.signalEmoji, color: .green)
                            if let tx = advertisement.txPowerLevel {
                                row("TX Power", value: "\(tx) dBm", color: .cyan)
                                row("Distance (est.)", value: estimatedDistance, color: .yellow)
                            }
                        }

                        // Identity
                        infoSection("IDENTITY") {
                            row("UUID", value: advertisement.id.uuidString, color: .green, mono: true, small: true)
                            if let company = advertisement.companyName {
                                row("Company", value: company, color: .cyan)
                            }
                            row("Connectable", value: advertisement.isConnectable ? "YES" : "NO",
                                color: advertisement.isConnectable ? .green : .red)
                            row("Packets seen", value: "\(advertisement.seenCount)", color: .white)
                        }

                        // Services
                        if !advertisement.serviceUUIDs.isEmpty {
                            infoSection("SERVICE UUIDs (\(advertisement.serviceUUIDs.count))") {
                                ForEach(advertisement.serviceUUIDs, id: \.uuidString) { uuid in
                                    row(serviceDescription(uuid), value: uuid.uuidString,
                                        color: .cyan, mono: true, small: true)
                                }
                            }
                        }

                        // Manufacturer data
                        if let hex = advertisement.manufacturerHex {
                            infoSection("MANUFACTURER DATA") {
                                if let company = advertisement.companyName {
                                    row("Company ID", value: company, color: .yellow)
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("RAW HEX")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(Color.green.opacity(0.5))
                                    Text(hex)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.green)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        // Service data
                        if !advertisement.serviceData.isEmpty {
                            infoSection("SERVICE DATA") {
                                ForEach(Array(advertisement.serviceData.keys), id: \.uuidString) { uuid in
                                    if let data = advertisement.serviceData[uuid] {
                                        let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
                                        row(uuid.uuidString, value: hex, color: .cyan, mono: true, small: true)
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(advertisement.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.green)
                        .font(.system(size: 14, design: .monospaced))
                }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.3), lineWidth: 1))
                Image(systemName: deviceIcon)
                    .font(.system(size: 26))
                    .foregroundColor(.green)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(advertisement.displayName)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                if let company = advertisement.companyName {
                    Text(company)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.green)
                }
                Text("\(advertisement.rssi) dBm · \(advertisement.signalLevel.label)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(rssiColor)
            }
        }
        .padding(14)
        .background(Color(white: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Helpers

    private func infoSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("── \(title) ──")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color.green.opacity(0.5))

            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(12)
            .background(Color(white: 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.15), lineWidth: 1))
        }
    }

    private func row(
        _ label: String,
        value: String,
        color: Color = .white,
        mono: Bool = false,
        small: Bool = false
    ) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: small ? 10 : 12, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.4))
                .frame(minWidth: 80, alignment: .leading)
            Text(value)
                .font(.system(size: small ? 10 : 12, weight: mono ? .regular : .medium, design: .monospaced))
                .foregroundColor(color)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private var rssiColor: Color {
        switch advertisement.rssi {
        case ..<(-80): return .red
        case -80 ..< -70: return .orange
        case -70 ..< -55: return .yellow
        default: return .green
        }
    }

    private var estimatedDistance: String {
        guard let tx = advertisement.txPowerLevel else { return "unknown" }
        let ratio = Double(advertisement.rssi) / Double(tx)
        let distance: Double
        if ratio < 1 {
            distance = pow(ratio, 10)
        } else {
            distance = 0.89976 * pow(ratio, 7.7095) + 0.111
        }
        if distance < 1 { return String(format: "~%.0f cm", distance * 100) }
        return String(format: "~%.1f m", distance)
    }

    private var deviceIcon: String {
        let name = advertisement.displayName.lowercased()
        let company = advertisement.companyName?.lowercased() ?? ""
        if name.contains("iphone") || company.contains("apple") { return "iphone" }
        if name.contains("watch") { return "applewatch" }
        if name.contains("macbook") || name.contains("mac") { return "laptopcomputer" }
        if name.contains("airpod") || name.contains("headphone") || name.contains("earphone") { return "airpodspro" }
        if name.contains("tv") { return "tv" }
        if name.contains("speaker") { return "hifispeaker.fill" }
        if name.contains("keyboard") { return "keyboard" }
        if name.contains("mouse") { return "computermouse" }
        if advertisement.isConnectable { return "wave.3.right.circle" }
        return "dot.radiowaves.left.and.right"
    }

    private func serviceDescription(_ uuid: CBUUID) -> String {
        let known: [String: String] = [
            "1800": "Generic Access",
            "1801": "Generic Attribute",
            "180A": "Device Information",
            "180F": "Battery",
            "1812": "HID (Remote/Keyboard)",
            "110B": "Audio Sink",
            "110A": "Audio Source",
            "1101": "Serial Port",
            "FE9F": "Google Cast",
            "FD6F": "COVID-19 Exposure",
            "181A": "Environmental Sensing",
            "1816": "Cycling Speed",
            "1818": "Cycling Power",
            "180D": "Heart Rate",
            "1814": "Running Speed",
        ]
        let short = uuid.uuidString.count == 36
            ? String(uuid.uuidString.prefix(8)).replacingOccurrences(of: "0000", with: "")
            : uuid.uuidString
        return known[short.uppercased()] ?? short
    }
}
