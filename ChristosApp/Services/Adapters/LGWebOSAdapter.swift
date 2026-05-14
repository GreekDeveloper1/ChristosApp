import Foundation

// LG webOS Smart TV — WebSocket on port 3000 (SSAP protocol)
final class LGWebOSAdapter: DeviceAdapter {
    let device: Device
    private let ws = WebSocketManager()
    private(set) var isConnected = false
    private var clientKey: String?
    private var commandId = 0

    private var host: String { device.ipAddress ?? "" }

    private let handshake: [String: Any] = [
        "type": "register",
        "id": "reg0",
        "payload": [
            "forcePairing": false,
            "pairingType": "PROMPT",
            "manifest": [
                "manifestVersion": 1,
                "appVersion": "1.1",
                "signed": [
                    "created": "20250101",
                    "appId": "com.christos.remoteapp",
                    "vendorId": "com.christos",
                    "localizedAppNames": ["": "Christos App"],
                    "localizedVendorNames": ["": "Christos Papavas"],
                    "permissions": [
                        "LAUNCH", "LAUNCH_WEBAPP",
                        "APP_TO_APP",
                        "CONTROL_AUDIO",
                        "CONTROL_DISPLAY",
                        "CONTROL_INPUT_JOYSTICK",
                        "CONTROL_INPUT_MEDIA_PLAYBACK",
                        "CONTROL_INPUT_MEDIA_RECORDING",
                        "CONTROL_INPUT_TEXT",
                        "CONTROL_INPUT_TV",
                        "CONTROL_POWER",
                        "READ_INSTALLED_APPS",
                        "READ_NOTIFICATIONS",
                        "SEARCH",
                        "WRITE_NOTIFICATION_TOAST",
                        "WRITE_SETTINGS"
                    ],
                    "serial": "2f930e2d2cfe083771f68e4fe7bb07"
                ],
                "permissions": [
                    "LAUNCH",
                    "LAUNCH_WEBAPP",
                    "APP_TO_APP",
                    "CLOSE",
                    "TEST_SECURE",
                    "CONTROL_AUDIO",
                    "CONTROL_DISPLAY",
                    "CONTROL_INPUT_JOYSTICK",
                    "CONTROL_INPUT_MEDIA_PLAYBACK",
                    "CONTROL_INPUT_MEDIA_RECORDING",
                    "CONTROL_INPUT_TEXT",
                    "CONTROL_INPUT_TV",
                    "CONTROL_POWER",
                    "READ_INSTALLED_APPS",
                    "READ_NOTIFICATIONS",
                    "SEARCH",
                    "WRITE_NOTIFICATION_TOAST",
                    "WRITE_SETTINGS"
                ]
            ]
        ]
    ]

    init(device: Device) {
        self.device = device
        clientKey = device.metadata["lgClientKey"]
        ws.onMessage = { [weak self] text in
            self?.handleMessage(text)
        }
        ws.onState = { [weak self] state in
            if case .disconnected = state { self?.isConnected = false }
        }
    }

    func connect() async throws {
        let urlStr = "ws://\(host):3000"
        guard let url = URL(string: urlStr) else { throw NetworkError.invalidURL }
        ws.connect(to: url)
        try await Task.sleep(nanoseconds: 500_000_000)  // wait for socket open
        var payload = handshake
        if let key = clientKey,
           var inner = (payload["payload"] as? [String: Any]) {
            inner["client-key"] = key
            payload["payload"] = inner
        }
        try await ws.sendJSON(payload)
        try await waitForConnection(timeout: 8)
    }

    func disconnect() {
        ws.disconnect()
        isConnected = false
    }

    func send(_ command: DeviceCommand) async throws {
        guard isConnected else { throw NetworkError.custom("Not connected to LG TV") }

        switch command {
        case .volumeUp:
            try await ssap("ssap://audio/volumeUp")
        case .volumeDown:
            try await ssap("ssap://audio/volumeDown")
        case .mute, .muteToggle:
            try await ssap("ssap://audio/setMute", payload: ["mute": true])
        case .powerOff, .powerToggle:
            try await ssap("ssap://system/turnOff")
        case .up:
            try await sendKey("UP")
        case .down:
            try await sendKey("DOWN")
        case .left:
            try await sendKey("LEFT")
        case .right:
            try await sendKey("RIGHT")
        case .select:
            try await sendKey("ENTER")
        case .back:
            try await sendKey("BACK")
        case .home:
            try await ssap("ssap://system.launcher/launch", payload: ["id": "com.webos.app.home"])
        case .play:
            try await ssap("ssap://media.controls/play")
        case .pause:
            try await ssap("ssap://media.controls/pause")
        case .stop:
            try await ssap("ssap://media.controls/stop")
        case .rewind:
            try await ssap("ssap://media.controls/rewind")
        case .fastForward:
            try await ssap("ssap://media.controls/fastForward")
        case .launchApp(let app):
            try await ssap("ssap://system.launcher/launch", payload: ["id": app.id])
        case .setInput(let src):
            try await ssap("ssap://tv/switchInput", payload: ["inputId": src])
        default:
            break
        }
    }

    func getInstalledApps() async throws -> [AppInfo] {
        // Returned via subscription; simplified here
        return AppInfo.presets
    }

    func getVolume() async throws -> Int {
        // Full implementation subscribes to ssap://audio/getVolume
        return 0
    }

    func getPowerState() async throws -> Bool { isConnected }

    func getAvailableInputs() async throws -> [String] {
        ["HDMI 1", "HDMI 2", "HDMI 3", "Component", "AV", "USB"]
    }

    // MARK: - SSAP Helpers

    private func ssap(_ uri: String, payload: [String: Any]? = nil) async throws {
        commandId += 1
        var msg: [String: Any] = ["type": "request", "id": "cmd\(commandId)", "uri": uri]
        if let p = payload { msg["payload"] = p }
        try await ws.sendJSON(msg)
    }

    private func sendKey(_ key: String) async throws {
        try await ssap("ssap://com.webos.service.ime/sendKeyAction", payload: [
            "name": key, "type": "CLICK"
        ])
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        if let type = json["type"] as? String, type == "registered",
           let payload = json["payload"] as? [String: Any],
           let key = payload["client-key"] as? String {
            clientKey = key
            isConnected = true
        }
    }

    private func waitForConnection(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !isConnected && Date() < deadline {
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        if !isConnected { throw NetworkError.custom("LG TV: pairing timed out — accept prompt on TV") }
    }
}
