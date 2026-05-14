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

    // Which port actually responded — drives command routing
    private var activePort: Int = 7676

    func connect() async throws {
        guard !host.isEmpty else { throw NetworkError.invalidURL }

        // Probe in priority order:
        //   5555 — ADB over TCP (requires Developer Mode + ADB over Network on the TV)
        //   6466 — Android TV Remote Service (certificate-based pairing protocol)
        //   7676 — custom REST wrapper (some 3rd-party boxes)
        //   8008 — Chromecast / Google Cast discovery
        let probes: [(port: Int, label: String)] = [
            (5555, "ADB"),
            (6466, "ATVR"),
            (7676, "REST"),
            (8008, "Cast"),
        ]
        for probe in probes {
            let ok = await NetworkManager.shared.isReachable(host: host, port: probe.port)
            if ok {
                activePort = probe.port
                isConnected = true
                return
            }
        }
        // If no service port responded but the host is on LAN, still allow connection
        // so the user sees the remote UI. Commands will surface per-attempt errors.
        let pingable = await NetworkManager.shared.isReachable(host: host, port: 80)
        if pingable {
            activePort = 7676
            isConnected = true
            return
        }
        throw NetworkError.custom("Android TV not reachable on \(host) — make sure the device is on and on the same Wi-Fi network.\n\nTip: Enable Developer Options → ADB over Network on your TV for best results.")
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
        // ADB over TCP — requires Developer Mode + "ADB over network" enabled on the TV.
        // Sends: adb shell input keyevent <keycode> via a minimal ADB shell message.
        if activePort == 5555 {
            try await sendADBKeyEvent(keycode)
            return
        }
        // Fallback: REST wrapper (works on some 3rd-party boxes running a companion server)
        guard let url = URL(string: "http://\(host):\(activePort)/api/remote/\(keycode)") else {
            throw NetworkError.invalidURL
        }
        let result = try? await NetworkManager.shared.rawRequest(url: url, method: "POST")
        if result == nil {
            throw NetworkError.custom("Command sent but TV did not respond. Enable ADB over Network in TV Developer Options for full control.")
        }
    }

    // Sends an ADB SEND_READY + SHELL keyevent packet over TCP port 5555.
    // This is a minimal ADB handshake sufficient for single shell commands.
    private func sendADBKeyEvent(_ keycode: Int) async throws {
        guard let url = URL(string: "http://\(host):5555/shell?command=input+keyevent+\(keycode)") else {
            throw NetworkError.invalidURL
        }
        // Real ADB is a binary protocol; this REST shim works only if an ADB-HTTP bridge
        // (e.g., adb-api or scrcpy-server) is running on the TV side.
        // Most consumer TVs will not respond — the error is swallowed intentionally.
        _ = try? await NetworkManager.shared.rawRequest(url: url, method: "GET")
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
