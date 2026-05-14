import Foundation
import Network

// SSDP (Simple Service Discovery Protocol) — UDP multicast M-SEARCH
final class SSDPDiscovery {
    var onDeviceFound: ((Device) -> Void)?

    private let multicastAddress = "239.255.255.250"
    private let multicastPort: UInt16 = 1900
    private var connection: NWConnection?
    private var receiveTimer: Timer?

    private let searchTargets = [
        "ssdp:all",
        "urn:dial-multiscreen-org:service:dial:1",          // DIAL (Netflix, YouTube apps)
        "urn:schemas-upnp-org:device:MediaRenderer:1",
        "urn:schemas-upnp-org:device:Basic:1",
        "urn:samsung.com:device:RemoteControlReceiver:1",   // Samsung TV
    ]

    func start() {
        for target in searchTargets {
            sendSearch(target: target)
        }
    }

    func stop() {
        receiveTimer?.invalidate()
        connection?.cancel()
    }

    // MARK: - M-SEARCH

    private func sendSearch(target: String) {
        let message = """
        M-SEARCH * HTTP/1.1\r
        HOST: \(multicastAddress):\(multicastPort)\r
        MAN: "ssdp:discover"\r
        MX: 3\r
        ST: \(target)\r
        USER-AGENT: iOS/16 UPnP/1.1 ChristosApp/1.0\r
        \r

        """
        guard let data = message.data(using: .utf8) else { return }

        let host = NWEndpoint.Host(multicastAddress)
        let port = NWEndpoint.Port(rawValue: multicastPort)!
        let endpoint = NWEndpoint.hostPort(host: host, port: port)
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        let conn = NWConnection(to: endpoint, using: params)
        conn.stateUpdateHandler = { state in
            if case .ready = state {
                conn.send(content: data, completion: .idempotent)
            }
        }
        conn.receiveMessage { [weak self] content, _, _, _ in
            if let data = content, let text = String(data: data, encoding: .utf8) {
                self?.parseResponse(text)
            }
        }
        conn.start(queue: .global(qos: .utility))

        // Keep connection alive to receive responses for 5s
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            conn.cancel()
        }
    }

    // MARK: - Response Parsing

    private func parseResponse(_ response: String) {
        var headers: [String: String] = [:]
        for line in response.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                headers[parts[0].uppercased()] = parts[1]
            }
        }

        guard let location = headers["LOCATION"] ?? headers["AL"],
              let url = URL(string: location),
              let host = url.host
        else { return }

        let server = headers["SERVER"] ?? ""
        let st     = headers["ST"] ?? ""
        let usn    = headers["USN"] ?? ""

        let device = buildDevice(ip: host, server: server, st: st, usn: usn, location: location)
        DispatchQueue.main.async {
            self.onDeviceFound?(device)
        }

        // Fetch device description XML for more details
        Task { [weak self] in
            await self?.fetchDescription(from: location, baseDevice: device)
        }
    }

    private func buildDevice(ip: String, server: String, st: String, usn: String, location: String) -> Device {
        let lower = server.lowercased() + st.lowercased()
        let type: DeviceType
        let brand: DeviceBrand

        if lower.contains("samsung") {
            type = .smartTV; brand = .samsung
        } else if lower.contains("lg") || lower.contains("webos") {
            type = .smartTV; brand = .lg
        } else if lower.contains("sony") || lower.contains("bravia") {
            type = .smartTV; brand = .sony
        } else if lower.contains("dial") || lower.contains("androidtv") {
            type = .androidTV; brand = .google
        } else if lower.contains("renderer") {
            type = .streamingBox; brand = .unknown
        } else {
            type = .unknown; brand = .unknown
        }

        return Device(
            name: ip,
            type: type,
            brand: brand,
            connectionType: .ssdp,
            ipAddress: ip,
            port: nil,
            signalStrength: -65,
            connectionStatus: .disconnected,
            serviceIdentifier: usn,
            metadata: ["server": server, "st": st, "location": location]
        )
    }

    private func fetchDescription(from location: String, baseDevice: Device) async {
        guard let url = URL(string: location) else { return }
        guard let data = try? await NetworkManager.shared.rawRequest(url: url) else { return }
        guard let xml = String(data: data, encoding: .utf8) else { return }

        var updated = baseDevice
        if let name = extractXML(tag: "friendlyName", from: xml) { updated.name = name }

        DispatchQueue.main.async {
            self.onDeviceFound?(updated)
        }
    }

    private func extractXML(tag: String, from xml: String) -> String? {
        let open  = "<\(tag)>"
        let close = "</\(tag)>"
        guard let start = xml.range(of: open),
              let end   = xml.range(of: close, range: start.upperBound..<xml.endIndex)
        else { return nil }
        return String(xml[start.upperBound..<end.lowerBound])
    }
}
