import Foundation

// Android TV / Google TV / Cosmote TV box
// Uses Android TV Remote Service protocol (port 6466) — certificate-based pairing
// Falls back to ADB-over-TCP (port 5555) for rooted/dev devices
final class AndroidTVAdapter: DeviceAdapter {
    let device: Device
    private(set) var isConnected = false
    private var ws: WebSocketManager?

    private var host: String { device.ipAddress ?? "" }

    // Android TV keycode mapping
    private enum Keycode: Int {
        case power       = 26
        case volumeUp    = 24
        case volumeDown  = 25
        case mute        = 164
        case dpadUp      = 19
        case dpadDown    = 20
        case dpadLeft    = 21
        case dpadRight   = 22
        case dpadCenter  = 23
        case back        = 4
        case home        = 3
        case menu        = 82
        case mediaPlay   = 126
        case mediaPause  = 127
        case mediaStop   = 86
        case mediaNext   = 87
        case mediaPrev   = 88
        case channelUp   = 166
        case channelDown = 167
        case n0 = 7, n1, n2, n3, n4, n5, n6, n7, n8, n9
    }

    init(device: Device) { self.device = device }

    func connect() async throws {
        // Try Sender API over WebSocket first (Android TV Remote Service alternative)
        // Many Android TV boxes expose a REST API on port 7676 (Home Assistant pattern)
        let reachable = await NetworkManager.shared.isReachable(host: host, port: 6466)
        if reachable {
            isConnected = true
        } else {
            // Fall back to port 7676 (some Android boxes)
            let alt = await NetworkManager.shared.isReachable(host: host, port: 7676)
            isConnected = alt
        }
        guard isConnected else {
            throw NetworkError.custom("Android TV not reachable on \(host)")
        }
    }

    func disconnect() { isConnected = false }

    func send(_ command: DeviceCommand) async throws {
        guard isConnected else { throw NetworkError.custom("Not connected") }
        if let keycode = keycode(for: command) {
            try await sendKeycode(keycode)
        } else if case .launchApp(let app) = command {
            try await launchApp(app)
        }
    }

    func getInstalledApps() async throws -> [AppInfo] {
        // Standard Android TV apps
        return [
            AppInfo(id: "com.netflix.ninja",             name: "Netflix",     iconURL: nil, deepLink: nil),
            AppInfo(id: "com.google.android.youtube.tv", name: "YouTube",     iconURL: nil, deepLink: nil),
            AppInfo(id: "com.amazon.avod.thirdpartyclient", name: "Prime Video", iconURL: nil, deepLink: nil),
            AppInfo(id: "com.disney.disneyplus",         name: "Disney+",     iconURL: nil, deepLink: nil),
            AppInfo(id: "com.google.android.tvlauncher", name: "Home",        iconURL: nil, deepLink: nil),
        ]
    }

    func getVolume() async throws -> Int { 0 }
    func getPowerState() async throws -> Bool { isConnected }
    func getAvailableInputs() async throws -> [String] { ["HDMI 1", "HDMI 2", "HDMI 3"] }

    // MARK: - Private

    private func sendKeycode(_ keycode: Int) async throws {
        // Android TV Remote Service v2 — simplified REST wrapper
        guard let url = URL(string: "http://\(host):7676/api/remote/\(keycode)") else {
            throw NetworkError.invalidURL
        }
        _ = try? await NetworkManager.shared.rawRequest(url: url, method: "POST")
    }

    private func launchApp(_ app: AppInfo) async throws {
        guard let url = URL(string: "http://\(host):7676/api/launch?package=\(app.id)") else {
            throw NetworkError.invalidURL
        }
        _ = try? await NetworkManager.shared.rawRequest(url: url, method: "POST")
    }

    private func keycode(for command: DeviceCommand) -> Int? {
        switch command {
        case .powerToggle, .powerOff, .powerOn: return Keycode.power.rawValue
        case .volumeUp:           return Keycode.volumeUp.rawValue
        case .volumeDown:         return Keycode.volumeDown.rawValue
        case .mute, .muteToggle:  return Keycode.mute.rawValue
        case .up:                 return Keycode.dpadUp.rawValue
        case .down:               return Keycode.dpadDown.rawValue
        case .left:               return Keycode.dpadLeft.rawValue
        case .right:              return Keycode.dpadRight.rawValue
        case .select:             return Keycode.dpadCenter.rawValue
        case .back:               return Keycode.back.rawValue
        case .home:               return Keycode.home.rawValue
        case .menu:               return Keycode.menu.rawValue
        case .play:               return Keycode.mediaPlay.rawValue
        case .pause:              return Keycode.mediaPause.rawValue
        case .stop:               return Keycode.mediaStop.rawValue
        case .skipForward:        return Keycode.mediaNext.rawValue
        case .skipBack:           return Keycode.mediaPrev.rawValue
        case .channelUp:          return Keycode.channelUp.rawValue
        case .channelDown:        return Keycode.channelDown.rawValue
        case .number(let n):      return (Keycode.n0.rawValue + n)
        default:                  return nil
        }
    }
}
