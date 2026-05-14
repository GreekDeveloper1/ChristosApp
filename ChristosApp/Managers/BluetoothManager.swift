import Foundation
import CoreBluetooth
import Combine

final class BluetoothManager: NSObject, ObservableObject {
    @Published var state: CBManagerState = .unknown
    @Published var advertisements: [UUID: BLEAdvertisement] = [:]
    @Published var sortedAdvertisements: [BLEAdvertisement] = []
    @Published var isScanning = false
    @Published var authorizationDenied = false
    @Published var totalSeen = 0

    // Legacy — still used by BLEDiscovery for device list
    var discoveredPeripherals: [CBPeripheral] { Array(peripheralMap.values) }
    var rssiMap: [UUID: Int] { advertisements.mapValues { $0.rssi } }

    private var centralManager: CBCentralManager!
    private var peripheralMap: [UUID: CBPeripheral] = [:]
    private var connectedPeripherals: [UUID: CBPeripheral] = [:]
    private var sortTimer: Timer?

    override init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: DispatchQueue(label: "com.christos.ble", qos: .userInitiated),
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
    }

    // MARK: - Scanning

    func startScanning() {
        guard centralManager.state == .poweredOn, !isScanning else { return }
        isScanning = true
        // Scan ALL devices, no service filter, allow duplicates for RSSI updates
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        startSortTimer()
    }

    func stopScanning() {
        guard isScanning else { return }
        isScanning = false
        centralManager.stopScan()
        sortTimer?.invalidate()
    }

    func clearResults() {
        advertisements.removeAll()
        peripheralMap.removeAll()
        sortedAdvertisements.removeAll()
        totalSeen = 0
    }

    func connect(to peripheral: CBPeripheral) {
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect(from peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }

    func rssi(for peripheral: CBPeripheral) -> Int {
        advertisements[peripheral.identifier]?.rssi ?? -100
    }

    // MARK: - Private

    private func startSortTimer() {
        sortTimer?.invalidate()
        sortTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.rebuildSorted()
        }
    }

    private func rebuildSorted() {
        DispatchQueue.main.async {
            self.sortedAdvertisements = self.advertisements.values
                .sorted { $0.rssi > $1.rssi }  // strongest signal first
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            self.state = central.state
            if central.state == .unauthorized { self.authorizationDenied = true }
            if central.state == .poweredOn && self.isScanning { self.startScanning() }
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let rssiValue = RSSI.intValue
        guard rssiValue > -100 && rssiValue < 0 else { return }

        let id = peripheral.identifier
        peripheralMap[id] = peripheral

        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let txPower = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let isConnectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? false
        let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] ?? [:]
        let overflow = advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? []

        DispatchQueue.main.async {
            if var existing = self.advertisements[id] {
                existing.rssi = rssiValue
                existing.lastSeen = Date()
                existing.seenCount += 1
                if let n = localName, !n.isEmpty { existing.localName = n }
                if !serviceUUIDs.isEmpty { existing.serviceUUIDs = serviceUUIDs }
                if let m = manufacturerData { existing.manufacturerData = m }
                if let t = txPower { existing.txPowerLevel = t }
                self.advertisements[id] = existing
            } else {
                let adv = BLEAdvertisement(
                    id: id,
                    name: peripheral.name ?? "Unknown",
                    rssi: rssiValue,
                    isConnectable: isConnectable,
                    serviceUUIDs: serviceUUIDs,
                    manufacturerData: manufacturerData,
                    manufacturerCompany: nil,
                    txPowerLevel: txPower,
                    localName: localName,
                    serviceData: serviceData,
                    overflowUUIDs: overflow,
                    lastSeen: Date(),
                    seenCount: 1
                )
                self.advertisements[id] = adv
                self.totalSeen += 1
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async { self.connectedPeripherals[peripheral.identifier] = peripheral }
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async { self.connectedPeripherals.removeValue(forKey: peripheral.identifier) }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {}
}
