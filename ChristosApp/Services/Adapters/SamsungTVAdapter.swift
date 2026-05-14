import Foundation

// Samsung Smart TV — WebSocket API (Tizen OS, port 8002 SSL / 8001 plain)
final class SamsungTVAdapter: DeviceAdapter {
    let device: Device
    private let ws = WebSocketManager()
    private(set) var isConnected = false

    private var host: String { device.ipAddress ?? "" }
    private var port: Int    { device.port ?? 8002 }

    // App name shown on TV pairing screen
    private let appName = "Christos App"
    private var encodedAppName: String {
        Data(appName.utf8).base64EncodedString()
    }

    init(device: Device) {
        self.device = device
        ws.onState = { [weak self] state in
            if case .connected = state    { self?.isConnected = true }
            if case .disconnected = state { self?.isConnected = false }
        }
    }

    // MARK: - Connection

    func connect() async throws {
        let urlStr = "wss://\(host):\(port)/api/v2/channels/samsung.remote.control?name=\(encodedAppName)"
        guard let url = URL(string: urlStr) else { throw NetworkError.invalidURL }
        ws.connect(to: url)
        // Wait up to 5s for connection
        try await waitForConnection(timeout: 5)
    }

    func disconnect() {
        ws.disconnect()
        isConnected = false
    }

    // MARK: - Commands

    func send(_ command: DeviceCommand) async throws {
        guard isConnected else { throw NetworkError.custom("Not connected") }
        let key = samsungKey(for: command)
        let payload: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": "Click",
                "DataOfCmd": key,
                "Option": "false",
                "TypeOfRemote": "SendRemoteKey"
            ]
        ]
        try await ws.sendJSON(payload)
    }

    func getInstalledApps() async throws -> [AppInfo] {
        guard let url = URL(string: "http://\(host):8001/api/v2/applications") else {
            throw NetworkError.invalidURL
        }
        struct AppListResponse: Decodable {
            struct TVApp: Decodable {
                let name: String
                let appId: String
            }
            let data: [TVApp]
        }
        let response: AppListResponse = try await NetworkManager.shared.request(url: url)
        return response.data.map { AppInfo(id: $0.appId, name: $0.name, iconURL: nil, deepLink: nil) }
    }

    func getVolume() async throws -> Int { 0 }    // requires DLNA
    func getPowerState() async throws -> Bool { isConnected }
    func getAvailableInputs() async throws -> [String] {
        ["HDMI 1", "HDMI 2", "HDMI 3", "AV", "Component", "Screen Mirroring"]
    }

    // MARK: - Key Mapping

    private func samsungKey(for command: DeviceCommand) -> String {
        switch command {
        case .powerToggle, .powerOff: return "KEY_POWER"
        case .powerOn:                return "KEY_POWERON"
        case .volumeUp:               return "KEY_VOLUP"
        case .volumeDown:             return "KEY_VOLDOWN"
        case .mute, .muteToggle:      return "KEY_MUTE"
        case .up:                     return "KEY_UP"
        case .down:                   return "KEY_DOWN"
        case .left:                   return "KEY_LEFT"
        case .right:                  return "KEY_RIGHT"
        case .select:                 return "KEY_ENTER"
        case .back:                   return "KEY_RETURN"
        case .home:                   return "KEY_HOME"
        case .menu:                   return "KEY_MENU"
        case .play:                   return "KEY_PLAY"
        case .pause:                  return "KEY_PAUSE"
        case .playPause:              return "KEY_PLAYPAUSE"
        case .stop:                   return "KEY_STOP"
        case .rewind:                 return "KEY_REWIND"
        case .fastForward:            return "KEY_FF"
        case .skipBack:               return "KEY_REWIND"
        case .skipForward:            return "KEY_FF"
        case .channelUp:              return "KEY_CHUP"
        case .channelDown:            return "KEY_CHDOWN"
        case .number(let n):          return "KEY_\(n)"
        case .nextInput:              return "KEY_SOURCE"
        case .raw(let k):             return k
        default:                      return "KEY_ENTER"
        }
    }

    // MARK: - Helpers

    private func waitForConnection(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !isConnected && Date() < deadline {
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        if !isConnected { throw NetworkError.custom("Samsung TV connection timed out") }
    }
}
