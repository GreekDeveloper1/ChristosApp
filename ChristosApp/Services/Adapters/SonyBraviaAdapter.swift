import Foundation

// Sony Bravia — HTTP JSON-RPC on port 80 (/sony/*), pre-shared key auth
final class SonyBraviaAdapter: DeviceAdapter {
    let device: Device
    private(set) var isConnected = false

    private var host: String { device.ipAddress ?? "" }
    private var psk:  String { device.metadata["sonyPSK"] ?? "0000" }

    private let services = (
        system:  "system",
        audio:   "audio",
        avContent: "avContent",
        appControl: "appControl"
    )

    init(device: Device) { self.device = device }

    func connect() async throws {
        let reachable = await NetworkManager.shared.isReachable(host: host, port: 80)
        guard reachable else { throw NetworkError.custom("Sony TV not reachable on \(host):80") }
        isConnected = true
    }

    func disconnect() { isConnected = false }

    func send(_ command: DeviceCommand) async throws {
        guard isConnected else { throw NetworkError.custom("Not connected") }

        switch command {
        case .powerOn:
            try await ircc("AAAAAQAAAAEAAAAuAw==")  // POWER ON
        case .powerOff, .powerToggle:
            try await ircc("AAAAAQAAAAEAAAAvAw==")  // POWER
        case .volumeUp:
            try await ircc("AAAAAQAAAAEAAAASAw==")
        case .volumeDown:
            try await ircc("AAAAAQAAAAEAAAATAw==")
        case .mute, .muteToggle:
            try await ircc("AAAAAQAAAAEAAAAUAw==")
        case .up:
            try await ircc("AAAAAQAAAAEAAAB0Aw==")
        case .down:
            try await ircc("AAAAAQAAAAEAAAB1Aw==")
        case .left:
            try await ircc("AAAAAQAAAAEAAAA0Aw==")
        case .right:
            try await ircc("AAAAAQAAAAEAAAAzAw==")
        case .select:
            try await ircc("AAAAAQAAAAEAAABlAw==")
        case .back:
            try await ircc("AAAAAgAAAJcAAAA2Aw==")
        case .home:
            try await ircc("AAAAAQAAAAEAAABgAw==")
        case .play:
            try await ircc("AAAAAgAAAJcAAAAaAw==")
        case .pause:
            try await ircc("AAAAAgAAAJcAAAAZAw==")
        case .stop:
            try await ircc("AAAAAgAAAJcAAAAYAw==")
        case .rewind:
            try await ircc("AAAAAgAAAJcAAAAbAw==")
        case .fastForward:
            try await ircc("AAAAAgAAAJcAAAAcAw==")
        case .channelUp:
            try await ircc("AAAAAQAAAAEAAAAQAw==")
        case .channelDown:
            try await ircc("AAAAAQAAAAEAAAARAw==")
        case .launchApp(let app):
            try await callRPC(service: services.appControl,
                              method: "setActiveApp",
                              params: [["uri": "localapp://webapi/?v=2.0&type=app&id=\(app.id)"]])
        default:
            break
        }
    }

    func getInstalledApps() async throws -> [AppInfo] {
        let result = try await callRPC(service: services.appControl,
                                       method: "getApplicationList",
                                       params: [])
        if let list = result["result"] as? [[Any]],
           let apps = list.first as? [[String: Any]] {
            return apps.compactMap { dict -> AppInfo? in
                guard let name = dict["title"] as? String,
                      let uri  = dict["uri"]   as? String
                else { return nil }
                let id = uri.components(separatedBy: "id=").last ?? uri
                return AppInfo(id: id, name: name, iconURL: nil, deepLink: uri)
            }
        }
        return AppInfo.presets
    }

    func getVolume() async throws -> Int {
        let result = try await callRPC(service: services.audio,
                                       method: "getVolumeInformation",
                                       params: [])
        if let list = result["result"] as? [[Any]],
           let items = list.first as? [[String: Any]],
           let speaker = items.first(where: { ($0["target"] as? String) == "speaker" }),
           let vol = speaker["volume"] as? Int {
            return vol
        }
        return 0
    }

    func getPowerState() async throws -> Bool { isConnected }

    func getAvailableInputs() async throws -> [String] {
        let result = try await callRPC(service: services.avContent,
                                       method: "getContentList",
                                       params: [["source": "extInput:hdmi"]])
        if let list = result["result"] as? [[Any]],
           let items = list.first as? [[String: Any]] {
            return items.compactMap { $0["title"] as? String }
        }
        return ["HDMI 1", "HDMI 2", "HDMI 3", "AV"]
    }

    // MARK: - Private

    @discardableResult
    private func callRPC(service: String, method: String, params: [[String: Any]]) async throws -> [String: Any] {
        guard let url = URL(string: "http://\(host)/sony/\(service)") else {
            throw NetworkError.invalidURL
        }
        let body: [String: Any] = ["method": method, "params": params, "id": 1, "version": "1.0"]
        let data = try await NetworkManager.shared.post(
            url: url,
            jsonObject: body,
            headers: ["X-Auth-PSK": psk]
        )
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func ircc(_ code: String) async throws {
        guard let url = URL(string: "http://\(host)/sony/IRCC") else {
            throw NetworkError.invalidURL
        }
        let soapBody = """
        <?xml version="1.0"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
            s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:X_SendIRCC xmlns:u="urn:schemas-sony-com:service:IRCC:1">
              <IRCCCode>\(code)</IRCCCode>
            </u:X_SendIRCC>
          </s:Body>
        </s:Envelope>
        """
        _ = try await NetworkManager.shared.rawRequest(
            url: url,
            method: "POST",
            headers: [
                "Content-Type": "text/xml; charset=UTF-8",
                "SOAPACTION": "\"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC\"",
                "X-Auth-PSK": psk
            ],
            body: soapBody.data(using: .utf8)
        )
    }
}
