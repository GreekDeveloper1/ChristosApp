import Foundation
import CoreBluetooth

// Bitmask for Report 1 — Consumer Control (1 byte)
struct ConsumerKey: OptionSet {
    let rawValue: UInt8
    static let volumeUp   = ConsumerKey(rawValue: 1 << 0)
    static let volumeDown = ConsumerKey(rawValue: 1 << 1)
    static let mute       = ConsumerKey(rawValue: 1 << 2)
    static let playPause  = ConsumerKey(rawValue: 1 << 3)
    static let next       = ConsumerKey(rawValue: 1 << 4)
    static let previous   = ConsumerKey(rawValue: 1 << 5)
    static let home       = ConsumerKey(rawValue: 1 << 6)
    static let back       = ConsumerKey(rawValue: 1 << 7)
}

// Keyboard HID scancodes for Report 2 — Navigation
enum NavKey: UInt8 {
    case none   = 0x00
    case up     = 0x52
    case down   = 0x51
    case left   = 0x50
    case right  = 0x4F
    case select = 0x28  // Enter
    case esc    = 0x29  // Back / Escape
    case menu   = 0x76  // F1 — maps to Menu on Android TV
}

// iPhone acts as a BLE HID peripheral (like a Bluetooth remote).
// The TV connects to the phone from its own Settings → Bluetooth → Add remote.
// No Wi-Fi required — pure Bluetooth direct control.
final class BLERemotePeripheral: NSObject, ObservableObject {

    enum State: Equatable {
        case idle
        case powering
        case advertising
        case paired
        case error(String)
    }

    @Published var state: State = .idle
    @Published var pairedDeviceName: String?
    @Published var lastKeyFeedback: String?

    private var manager: CBPeripheralManager!
    private var consumerReport: CBMutableCharacteristic?
    private var navReport: CBMutableCharacteristic?
    private var subscribedCentrals = Set<CBCentral>()
    private var feedbackTask: Task<Void, Never>?

    override init() {
        super.init()
        manager = CBPeripheralManager(
            delegate: self,
            queue: DispatchQueue(label: "com.christos.ble.peripheral", qos: .userInitiated),
            options: [CBPeripheralManagerOptionShowPowerAlertKey: true]
        )
        state = .powering
    }

    // MARK: - Public API

    func startAdvertising() {
        guard manager.state == .poweredOn else { return }
        buildAndAddServices()
        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: "1812")],
            CBAdvertisementDataLocalNameKey: "ChristosRemote",
        ])
        DispatchQueue.main.async { self.state = .advertising }
    }

    func stopAdvertising() {
        manager.stopAdvertising()
        manager.removeAllServices()
        subscribedCentrals.removeAll()
        DispatchQueue.main.async {
            self.state = .idle
            self.pairedDeviceName = nil
        }
    }

    // One-shot: press then release after 100 ms
    func send(_ key: ConsumerKey, label: String) {
        sendConsumer(key.rawValue)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            self?.sendConsumer(0x00)
        }
        showFeedback(label)
    }

    func send(_ key: NavKey, label: String) {
        sendNav(key.rawValue)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            self?.sendNav(0x00)
        }
        showFeedback(label)
    }

    // MARK: - GATT Setup

    private func buildAndAddServices() {
        manager.removeAllServices()

        // ── Device Information (0x180A) ───────────────────────────────────
        let devInfoSvc = CBMutableService(type: .devInfo, primary: true)
        devInfoSvc.characteristics = [
            fixed(.mfrName, value: "Christos"),
            fixed(.modelNumber, value: "TV Remote 1.0"),
        ]

        // ── Battery (0x180F) — required by some TVs ───────────────────────
        let batterySvc = CBMutableService(type: .battery, primary: true)
        batterySvc.characteristics = [
            fixed(.battLevel, value: Data([100])),  // 100 %
        ]

        // ── HID (0x1812) ──────────────────────────────────────────────────
        let hidSvc = CBMutableService(type: .hid, primary: true)

        let hidInfo = fixed(.hidInfo, value: Data([
            0x11, 0x01,  // HID version 1.11
            0x00,        // country code: not localized
            0x03,        // flags: remote-wake | normally-connectable
        ]))

        let reportMap = fixed(.reportMap, value: Data(HIDDescriptor.bytes))

        let controlPoint = CBMutableCharacteristic(
            type: .controlPoint,
            properties: .writeWithoutResponse,
            value: nil, permissions: .writeable
        )

        let protoMode = CBMutableCharacteristic(
            type: .protoMode,
            properties: [.read, .writeWithoutResponse],
            value: Data([0x01]),   // Report Protocol Mode
            permissions: [.readable, .writeable]
        )

        // Report 1 — Consumer (volume, play, home, back)
        let cr = CBMutableCharacteristic(
            type: .report,
            properties: [.read, .notify],
            value: nil, permissions: .readable
        )
        cr.descriptors = [
            CBMutableDescriptor(type: CBUUID(string: "2908"), value: Data([0x01, 0x01])),  // ID=1, Input
        ]

        // Report 2 — Navigation (D-pad, select, esc, menu)
        let nr = CBMutableCharacteristic(
            type: .report,
            properties: [.read, .notify],
            value: nil, permissions: .readable
        )
        nr.descriptors = [
            CBMutableDescriptor(type: CBUUID(string: "2908"), value: Data([0x02, 0x01])),  // ID=2, Input
        ]

        consumerReport = cr
        navReport = nr

        hidSvc.characteristics = [hidInfo, reportMap, controlPoint, protoMode, cr, nr]

        manager.add(devInfoSvc)
        manager.add(batterySvc)
        manager.add(hidSvc)
    }

    // MARK: - Sending Reports

    private func sendConsumer(_ value: UInt8) {
        guard let cr = consumerReport, !subscribedCentrals.isEmpty else { return }
        manager.updateValue(Data([value]), for: cr, onSubscribedCentrals: nil)
    }

    private func sendNav(_ value: UInt8) {
        guard let nr = navReport, !subscribedCentrals.isEmpty else { return }
        manager.updateValue(Data([value]), for: nr, onSubscribedCentrals: nil)
    }

    private func showFeedback(_ text: String) {
        feedbackTask?.cancel()
        DispatchQueue.main.async { self.lastKeyFeedback = text }
        feedbackTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run { self.lastKeyFeedback = nil }
        }
    }

    // Helper: static value characteristic
    private func fixed(_ uuid: CBUUID, value: String) -> CBMutableCharacteristic {
        fixed(uuid, value: Data(value.utf8))
    }

    private func fixed(_ uuid: CBUUID, value: Data) -> CBMutableCharacteristic {
        CBMutableCharacteristic(type: uuid, properties: .read, value: value, permissions: .readable)
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLERemotePeripheral: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        DispatchQueue.main.async {
            switch peripheral.state {
            case .poweredOn:  self.state = .idle
            case .poweredOff: self.state = .error("Bluetooth is off")
            case .unauthorized: self.state = .error("Bluetooth permission denied")
            default: break
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {}

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            DispatchQueue.main.async { self.state = .error(error.localizedDescription) }
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        subscribedCentrals.insert(central)
        DispatchQueue.main.async {
            self.state = .paired
            self.pairedDeviceName = central.identifier.uuidString
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        subscribedCentrals.remove(central)
        if subscribedCentrals.isEmpty {
            DispatchQueue.main.async {
                self.state = .advertising
                self.pairedDeviceName = nil
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == .report {
            request.value = Data([0x00])
        }
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for r in requests { peripheral.respond(to: r, withResult: .success) }
    }
}

// MARK: - Well-known UUIDs

private extension CBUUID {
    // Services
    static let devInfo  = CBUUID(string: "180A")
    static let battery  = CBUUID(string: "180F")
    static let hid      = CBUUID(string: "1812")
    // Characteristics
    static let mfrName     = CBUUID(string: "2A29")
    static let modelNumber = CBUUID(string: "2A24")
    static let battLevel   = CBUUID(string: "2A19")
    static let hidInfo     = CBUUID(string: "2A4A")
    static let reportMap   = CBUUID(string: "2A4B")
    static let controlPoint = CBUUID(string: "2A4C")
    static let protoMode   = CBUUID(string: "2A4E")
    static let report      = CBUUID(string: "2A4D")
}

// MARK: - HID Report Descriptor

enum HIDDescriptor {
    // Report 1 (1 byte): Consumer Control bitmask
    //   bit 0 = Volume Up, 1 = Volume Down, 2 = Mute, 3 = Play/Pause,
    //   bit 4 = Next,       5 = Previous,   6 = AC Home, 7 = AC Back
    //
    // Report 2 (1 byte): Keyboard scancode
    //   0x00 = no key, 0x52 = Up, 0x51 = Down, 0x50 = Left, 0x4F = Right,
    //   0x28 = Enter,  0x29 = Esc/Back, 0x76 = F1/Menu
    static let bytes: [UInt8] = [
        // === Report 1: Consumer Control ===
        0x05, 0x0C,        // Usage Page (Consumer)
        0x09, 0x01,        // Usage (Consumer Control)
        0xA1, 0x01,        // Collection (Application)
        0x85, 0x01,        //   Report ID 1
        0x15, 0x00,        //   Logical Minimum 0
        0x25, 0x01,        //   Logical Maximum 1
        0x75, 0x01,        //   Report Size 1 bit
        0x95, 0x08,        //   Report Count 8
        0x09, 0xE9,        //   Volume Increment
        0x09, 0xEA,        //   Volume Decrement
        0x09, 0xE2,        //   Mute
        0x09, 0xCD,        //   Play/Pause
        0x09, 0xB5,        //   Scan Next Track
        0x09, 0xB6,        //   Scan Previous Track
        0x0A, 0x23, 0x02,  //   AC Home (0x0223)
        0x0A, 0x24, 0x02,  //   AC Back (0x0224)
        0x81, 0x02,        //   Input (Data, Variable, Absolute)
        0xC0,              // End Collection

        // === Report 2: Navigation / Keyboard ===
        0x05, 0x01,        // Usage Page (Generic Desktop)
        0x09, 0x06,        // Usage (Keyboard)
        0xA1, 0x01,        // Collection (Application)
        0x85, 0x02,        //   Report ID 2
        0x05, 0x07,        //   Usage Page (Key Codes)
        0x19, 0x00,        //   Usage Minimum 0
        0x29, 0x73,        //   Usage Maximum 115
        0x15, 0x00,        //   Logical Minimum 0
        0x25, 0x73,        //   Logical Maximum 115
        0x75, 0x08,        //   Report Size 8 bits
        0x95, 0x01,        //   Report Count 1 (one key at a time)
        0x81, 0x00,        //   Input (Array)
        0xC0,              // End Collection
    ]
}
