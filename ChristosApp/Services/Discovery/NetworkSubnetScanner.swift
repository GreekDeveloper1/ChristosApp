import Foundation
import Network

// Scans every IP on the local /24 subnet and probes known device ports
final class NetworkSubnetScanner {
    var onDeviceFound: ((Device) -> Void)?
    var onProgress:    ((Double) -> Void)?

    // Ordered by likelihood — first match per host wins
    private let probePorts: [(port: UInt16, type: DeviceType, brand: DeviceBrand)] = [
        (8002, .smartTV,    .samsung),   // Samsung Tizen WS
        (8001, .smartTV,    .samsung),   // Samsung legacy
        (3000, .smartTV,    .lg),        // LG webOS
        (8009, .chromecast, .google),    // Chromecast Cast TLS
        (8008, .chromecast, .google),    // Chromecast HTTP
        (7676, .androidTV,  .google),    // Android TV REST
        (6466, .androidTV,  .google),    // Android TV Remote
        (5555, .androidTV,  .google),    // ADB TCP
        ( 443, .smartTV,    .unknown),   // Generic HTTPS
        (  80, .smartTV,    .unknown),   // Generic HTTP / Sony
    ]

    private var isCancelled = false

    func cancel() { isCancelled = true }

    func scan() async {
        isCancelled = false
        guard let localIP = localIPAddress() else { return }

        let parts = localIP.split(separator: ".").map(String.init)
        guard parts.count == 4 else { return }
        let prefix = parts.prefix(3).joined(separator: ".")

        // Scan 1–254 concurrently, max 50 at a time
        let total = 254.0
        var done  = 0.0

        await withTaskGroup(of: Void.self) { group in
            var active = 0
            for i in 1...254 {
                if isCancelled { break }
                let ip = "\(prefix).\(i)"

                // Throttle to 50 concurrent connections
                if active >= 50 {
                    await group.next()
                    active -= 1
                }
                active += 1

                group.addTask { [weak self] in
                    guard let self, !self.isCancelled else { return }
                    await self.probeHost(ip: ip)
                    done += 1
                    await MainActor.run {
                        self.onProgress?(done / total)
                    }
                }
            }
            await group.waitForAll()
        }
    }

    // MARK: - Per-host probe

    private func probeHost(ip: String) async {
        for probe in probePorts {
            guard !isCancelled else { return }
            if await isPortOpen(host: ip, port: probe.port, timeout: 0.8) {
                var device = Device(
                    name: "\(probe.brand.rawValue) Device",
                    type: probe.type,
                    brand: probe.brand,
                    connectionType: .wifi,
                    ipAddress: ip,
                    port: Int(probe.port),
                    signalStrength: -60,
                    connectionStatus: .disconnected
                )
                // Try to get the real name
                if let name = await fetchDeviceName(ip: ip, port: probe.port) {
                    device.name = name
                } else {
                    device.name = friendlyName(ip: ip, brand: probe.brand, port: probe.port)
                }
                await MainActor.run {
                    self.onDeviceFound?(device)
                }
                return  // one device per IP
            }
        }
    }

    // MARK: - TCP port check

    private func isPortOpen(host: String, port: UInt16, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.hostPort(
                host:      NWEndpoint.Host(host),
                port:      NWEndpoint.Port(rawValue: port)!
            )
            let conn = NWConnection(to: endpoint, using: .tcp)
            var done = false

            conn.stateUpdateHandler = { state in
                guard !done else { return }
                switch state {
                case .ready:
                    done = true
                    conn.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled, .waiting:
                    if !done {
                        done = true
                        conn.cancel()
                        continuation.resume(returning: false)
                    }
                default: break
                }
            }
            conn.start(queue: .global(qos: .utility))

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                guard !done else { return }
                done = true
                conn.cancel()
                continuation.resume(returning: false)
            }
        }
    }

    // MARK: - Device Name Fetch

    private func fetchDeviceName(ip: String, port: UInt16) async -> String? {
        // Try SSDP device description on port 80
        guard port == 80 || port == 8001 else { return nil }
        guard let url = URL(string: "http://\(ip):\(port)/") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 1.5)
        req.httpMethod = "GET"
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let body = String(data: data, encoding: .utf8)
        else { return nil }

        // Try to extract <friendlyName> or <title> from XML/HTML
        for tag in ["friendlyName", "title", "modelName"] {
            if let name = extract(tag: tag, from: body), !name.isEmpty {
                return name
            }
        }
        return nil
    }

    private func extract(tag: String, from text: String) -> String? {
        let open  = "<\(tag)>"
        let close = "</\(tag)>"
        guard let s = text.range(of: open),
              let e = text.range(of: close, range: s.upperBound..<text.endIndex)
        else { return nil }
        return String(text[s.upperBound..<e.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private func friendlyName(ip: String, brand: DeviceBrand, port: UInt16) -> String {
        let last = ip.split(separator: ".").last.map(String.init) ?? ip
        switch port {
        case 8001, 8002: return "Samsung TV (\(ip))"
        case 3000:       return "LG TV (\(ip))"
        case 8008, 8009: return "Chromecast (\(ip))"
        case 7676, 6466, 5555: return "Android TV (\(ip))"
        default:         return "\(brand.rawValue) Device .\(last)"
        }
    }

    // MARK: - Get local WiFi IP (en0)

    func localIPAddress() -> String? {
        var addr: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            let iface = ptr!.pointee
            if iface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: iface.ifa_name)
                if name == "en0" {
                    var sa = iface.ifa_addr.pointee
                    var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    getnameinfo(&sa, socklen_t(MemoryLayout<sockaddr_in>.size),
                                &buf, socklen_t(buf.count), nil, 0, NI_NUMERICHOST)
                    addr = String(cString: buf)
                }
            }
            ptr = ptr!.pointee.ifa_next
        }
        return addr
    }
}
