import Foundation
import CoreBluetooth
import Combine

final class BluetoothManager: NSObject, ObservableObject {
    @Published var state: CBManagerState = .unknown
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var rssiMap: [UUID: Int] = [:]
    @Published var isScanning = false
    @Published var authorizationDenied = false

    private var centralManager: CBCentralManager!
    private var connectedPeripherals: [UUID: CBPeripheral] = [:]
    private var rssiTimers: [UUID: Timer] = [:]

    // Known BLE service UUIDs for remotes and media devices
    private let targetServiceUUIDs: [CBUUID] = [
        CBUUID(string: "180A"),  // Device Information
        CBUUID(string: "1812"),  // HID (keyboards, remotes)
        CBUUID(string: "180F"),  // Battery
        CBUUID(string: "FE9F"),  // Google Cast
    ]

    override init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: DispatchQueue(label: "com.christos.ble", qos: .userInitiated),
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        guard !isScanning else { return }
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        // Auto-stop after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.stopScanning()
        }
    }

    func stopScanning() {
        guard isScanning else { return }
        isScanning = false
        centralManager.stopScan()
    }

    func connect(to peripheral: CBPeripheral) {
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect(from peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }

    func rssi(for peripheral: CBPeripheral) -> Int {
        rssiMap[peripheral.identifier] ?? -100
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            self.state = central.state
            if central.state == .unauthorized {
                self.authorizationDenied = true
            }
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let rssiValue = RSSI.intValue
        guard rssiValue > -100 else { return }  // filter out unreachable devices

        DispatchQueue.main.async {
            let id = peripheral.identifier
            self.rssiMap[id] = rssiValue
            if !self.discoveredPeripherals.contains(where: { $0.identifier == id }) {
                self.discoveredPeripherals.append(peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.connectedPeripherals[peripheral.identifier] = peripheral
        }
        peripheral.discoverServices(targetServiceUUIDs)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.connectedPeripherals.removeValue(forKey: peripheral.identifier)
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.connectedPeripherals.removeValue(forKey: peripheral.identifier)
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        // Service/characteristic discovery logged for debugging
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else { return }
        DispatchQueue.main.async {
            self.rssiMap[peripheral.identifier] = RSSI.intValue
        }
    }
}
