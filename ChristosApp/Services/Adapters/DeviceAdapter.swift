import Foundation

// MARK: - Protocol all adapters must conform to
protocol DeviceAdapter: AnyObject {
    var device: Device { get }
    var isConnected: Bool { get }

    func connect() async throws
    func disconnect()
    func send(_ command: DeviceCommand) async throws
    func getInstalledApps() async throws -> [AppInfo]
    func getVolume() async throws -> Int
    func getPowerState() async throws -> Bool
    func getAvailableInputs() async throws -> [String]
}

// MARK: - Factory
enum AdapterFactory {
    static func make(for device: Device) -> DeviceAdapter {
        switch device.brand.adapterType {
        case .samsung:    return SamsungTVAdapter(device: device)
        case .lgWebOS:    return LGWebOSAdapter(device: device)
        case .sonyBravia: return SonyBraviaAdapter(device: device)
        case .androidTV:  return AndroidTVAdapter(device: device)
        case .appleTV:    return AppleTVAdapter(device: device)
        case .chromecast: return ChromecastAdapter(device: device)
        case .generic:    return GenericAdapter(device: device)
        }
    }
}

// MARK: - Generic / Fallback adapter
final class GenericAdapter: DeviceAdapter {
    let device: Device
    private(set) var isConnected = false

    init(device: Device) { self.device = device }

    func connect() async throws {
        // Attempt a simple TCP reachability check
        guard let ip = device.ipAddress else {
            throw NetworkError.invalidURL
        }
        let reachable = await NetworkManager.shared.isReachable(
            host: ip, port: device.port ?? 80
        )
        isConnected = reachable
    }

    func disconnect() { isConnected = false }

    func send(_ command: DeviceCommand) async throws {
        // Generic devices: no protocol defined
        throw NetworkError.custom("Generic adapter: command not supported")
    }

    func getInstalledApps()  async throws -> [AppInfo]  { [] }
    func getVolume()         async throws -> Int         { 0 }
    func getPowerState()     async throws -> Bool        { false }
    func getAvailableInputs() async throws -> [String]  { [] }
}
