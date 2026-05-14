import SwiftUI

struct NFCScannerView: View {
    @StateObject private var nfc = NFCManager.shared
    @State private var showRawScan = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    terminalHeader
                    scanControls
                    tagList
                }
            }
            .navigationTitle("NFC Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !nfc.tags.isEmpty {
                        Button("Clear") { nfc.clearTags() }
                            .foregroundColor(.green)
                            .font(.system(size: 13, design: .monospaced))
                    }
                }
            }
        }
    }

    // MARK: - Terminal Header

    private var terminalHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                Text("NFC / RFID — 13.56 MHz")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.green)
                Spacer()
                if nfc.isScanning {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                            .symbolEffect(.pulse)
                        Text("ACTIVE")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.green)
                    }
                } else {
                    Text("READY")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.green.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(white: 0.05))

            Rectangle().frame(height: 0.5).foregroundColor(Color.green.opacity(0.2))
        }
    }

    // MARK: - Scan Controls

    private var scanControls: some View {
        VStack(spacing: 12) {
            if !nfc.isAvailable {
                unavailableNotice
            } else {
                HStack(spacing: 12) {
                    scanButton(
                        title: "NDEF Scan",
                        subtitle: "Smart tags, stickers",
                        icon: "tag.fill",
                        active: nfc.isScanning
                    ) {
                        if nfc.isScanning { nfc.stopScan() }
                        else { nfc.startScan() }
                    }

                    scanButton(
                        title: "Raw Scan",
                        subtitle: "ISO 14443 / 15693",
                        icon: "cpu.fill",
                        active: false
                    ) {
                        if nfc.isScanning { nfc.stopScan() }
                        else { nfc.startRawScan() }
                    }
                }

                if let error = nfc.lastError {
                    Text(error)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .padding(16)
    }

    private func scanButton(
        title: String,
        subtitle: String,
        icon: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); action() }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(active ? .black : .green)
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(active ? .black : .white)
                Text(subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(active ? .black.opacity(0.6) : .white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(active ? Color.green : Color(white: 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.3), lineWidth: 1))
        }
    }

    private var unavailableNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("NFC Not Available")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.yellow)
                Text("Requires iPhone 7+ with NFC entitlement in signed build.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(14)
        .background(Color.yellow.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Tag List

    @ViewBuilder
    private var tagList: some View {
        if nfc.tags.isEmpty {
            Spacer()
            emptyState
            Spacer()
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(nfc.tags) { tag in
                        tagCard(tag)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wave.3.forward.circle")
                .font(.system(size: 48))
                .foregroundColor(Color.green.opacity(0.3))
            Text("No tags scanned")
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.3))
            Text("Tap a scan button, then hold\nyour iPhone near an NFC tag or card.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.2))
                .multilineTextAlignment(.center)
        }
    }

    private func tagCard(_ tag: NFCTagRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Tag header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 36, height: 36)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.3), lineWidth: 1))
                    Image(systemName: tagIcon(for: tag.type))
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(tag.type)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(tag.uid)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green)
                        .textSelection(.enabled)
                }
                Spacer()
                Text(tag.scannedAt, style: .time)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.3))
            }

            if !tag.techDetails.isEmpty {
                termRow("TECH", tag.techDetails)
            }

            if !tag.rawBytes.isEmpty {
                termRow("UID", tag.rawBytes)
            }

            if !tag.ndefPayload.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PAYLOAD")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color.green.opacity(0.4))
                    ForEach(tag.ndefPayload, id: \.self) { payload in
                        Text(payload)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.cyan)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(white: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.15), lineWidth: 1))
    }

    private func termRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color.green.opacity(0.4))
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.6))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tagIcon(for type: String) -> String {
        let t = type.lowercased()
        if t.contains("ndef")     { return "tag.fill" }
        if t.contains("mifare")   { return "creditcard.fill" }
        if t.contains("felica")   { return "wave.3.right" }
        if t.contains("15693")    { return "cpu" }
        if t.contains("7816")     { return "creditcard.and.123" }
        return "wave.3.forward"
    }
}
