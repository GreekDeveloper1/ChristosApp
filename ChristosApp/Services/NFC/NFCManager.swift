import Foundation
import CoreNFC

struct NFCTagRecord: Identifiable {
    let id = UUID()
    let uid: String           // hex UID/serial
    let type: String          // tag technology type
    let techDetails: String   // e.g. ISO 14443-4A, ISO 15693
    let ndefPayload: [String] // decoded NDEF records
    let rawBytes: String      // first bytes of tag UID in hex
    let scannedAt: Date
}

final class NFCManager: NSObject, ObservableObject {

    @Published var isScanning = false
    @Published var tags: [NFCTagRecord] = []
    @Published var lastError: String?

    static let shared = NFCManager()

    private var tagSession: NFCTagReaderSession?
    private var ndefSession: NFCNDEFReaderSession?

    // MARK: - Public

    var isAvailable: Bool { NFCTagReaderSession.readingAvailable }

    func startScan() {
        guard isAvailable else {
            lastError = "NFC not available — requires iPhone 7+ with NFC capability enabled in provisioning."
            return
        }
        lastError = nil
        isScanning = true

        // NDEF session for common smart tags / stickers
        ndefSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        ndefSession?.alertMessage = "Hold iPhone near an NFC tag."
        ndefSession?.begin()
    }

    func startRawScan() {
        guard isAvailable else {
            lastError = "NFC not available on this device."
            return
        }
        lastError = nil
        isScanning = true

        tagSession = NFCTagReaderSession(
            pollingOption: [.iso14443, .iso15693, .iso18092],
            delegate: self, queue: nil
        )
        tagSession?.alertMessage = "Hold iPhone near an NFC / RFID tag."
        tagSession?.begin()
    }

    func stopScan() {
        ndefSession?.invalidate()
        tagSession?.invalidate()
        ndefSession = nil
        tagSession = nil
        DispatchQueue.main.async { self.isScanning = false }
    }

    func clearTags() {
        tags.removeAll()
    }
}

// MARK: - NDEF Session Delegate

extension NFCManager: NFCNDEFReaderSessionDelegate {

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false
            let err = error as? NFCReaderError
            if err?.code != .readerSessionInvalidationErrorUserCanceled {
                self.lastError = error.localizedDescription
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        let payloads = messages.flatMap(\.records).compactMap { record -> String? in
            decodeNDEFRecord(record)
        }
        let record = NFCTagRecord(
            uid: "NDEF tag",
            type: "NDEF",
            techDetails: "\(messages.count) message(s), \(messages.flatMap(\.records).count) record(s)",
            ndefPayload: payloads,
            rawBytes: "",
            scannedAt: Date()
        )
        DispatchQueue.main.async { self.tags.insert(record, at: 0) }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else { return }
        session.connect(to: tag) { [weak self] error in
            guard error == nil else { return }
            tag.readNDEF { message, error in
                guard let message, error == nil else { return }
                let payloads = message.records.compactMap { self?.decodeNDEFRecord($0) }
                let record = NFCTagRecord(
                    uid: "NDEF tag",
                    type: "NDEF",
                    techDetails: "\(message.records.count) record(s)",
                    ndefPayload: payloads,
                    rawBytes: "",
                    scannedAt: Date()
                )
                DispatchQueue.main.async { self?.tags.insert(record, at: 0) }
            }
        }
    }

    private func decodeNDEFRecord(_ record: NFCNDEFPayload) -> String? {
        if let url = record.wellKnownTypeURIPayload() { return "URL: \(url.absoluteString)" }
        if let (text, _) = record.wellKnownTypeTextPayload() { return "Text: \(text)" }
        let hex = record.payload.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " ")
        return "Raw: \(hex)"
    }
}

// MARK: - Raw Tag Session Delegate

extension NFCManager: NFCTagReaderSessionDelegate {

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false
            let err = error as? NFCReaderError
            if err?.code != .readerSessionInvalidationErrorUserCanceled {
                self.lastError = error.localizedDescription
            }
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        session.connect(to: tag) { [weak self] error in
            guard error == nil else { return }
            let record = self?.buildRecord(from: tag) ?? NFCTagRecord(
                uid: "?", type: "Unknown", techDetails: "", ndefPayload: [], rawBytes: "", scannedAt: Date()
            )
            DispatchQueue.main.async { self?.tags.insert(record, at: 0) }
            session.alertMessage = "Tag detected!"
        }
    }

    private func buildRecord(from tag: NFCTag) -> NFCTagRecord {
        switch tag {
        case .iso7816(let t):
            let uid = t.identifier.hexString
            return NFCTagRecord(uid: uid, type: "ISO 7816-4", techDetails: "AID: \(t.initialSelectedAID)",
                                ndefPayload: [], rawBytes: uid, scannedAt: Date())
        case .feliCa(let t):
            let uid = t.currentIDm.hexString
            return NFCTagRecord(uid: uid, type: "FeliCa / NFC-F", techDetails: "IDm: \(uid)",
                                ndefPayload: [], rawBytes: uid, scannedAt: Date())
        case .iso15693(let t):
            let uid = t.identifier.hexString
            return NFCTagRecord(uid: uid, type: "ISO 15693 / NFC-V", techDetails: "UID: \(uid)",
                                ndefPayload: [], rawBytes: uid, scannedAt: Date())
        case .miFare(let t):
            let uid = t.identifier.hexString
            let family: String
            switch t.mifareFamily {
            case .ultralight: family = "MIFARE Ultralight"
            case .plus:       family = "MIFARE Plus"
            case .desfire:    family = "MIFARE DESFire"
            default:          family = "MIFARE"
            }
            return NFCTagRecord(uid: uid, type: family, techDetails: "UID: \(uid)",
                                ndefPayload: [], rawBytes: uid, scannedAt: Date())
        @unknown default:
            return NFCTagRecord(uid: "?", type: "Unknown", techDetails: "",
                                ndefPayload: [], rawBytes: "", scannedAt: Date())
        }
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
