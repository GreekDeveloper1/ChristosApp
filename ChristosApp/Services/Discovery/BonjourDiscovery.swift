import Foundation
import Network
import Combine

final class BonjourDiscovery: NSObject {
    var onDeviceFound: ((Device) -> Void)?

    // Services we're interested in
    private let serviceTypes = [
        "_airplay._tcp",       // Apple TV, AirPlay receivers
        "_googlecast._tcp",    // Chromecast / Cast devices
        "_androidtvremote._tcp", // Android TV remote protocol
        "_androidtvremote2._tcp",
        "_samsung-tv._tcp",    // Samsung Smart TV
        "_webostv._tcp",       // LG webOS
        "_sony-adcp._tcp",     // Sony Bravia
        "_epsonProjector._tcp",
        "_printer._tcp",       // printers
        "_http._tcp",          // generic fallback
    ]

    private var browsers: [String: NWBrowser] = [:]
    private var resolvers: [String: NetService] = [:]
    private var legacyBrowsers: [NetServiceBrowser] = []

    func start() {
        for type in serviceTypes {
            startBrowsing(serviceType: type)
        }
    }

    func stop() {
        browsers.values.forEach { $0.cancel() }
        browsers.removeAll()
        legacyBrowsers.forEach { $0.stop() }
        legacyBrowsers.removeAll()
    }

    // MARK: - Private

    private func startBrowsing(serviceType: String) {
        let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: "local.")
        let params = NWParameters()
        params.includePeerToPeer = false
        let browser = NWBrowser(for: descriptor, using: params)

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            for change in changes {
                if case .added(let result) = change {
                    self?.handleResult(result, serviceType: serviceType)
                }
            }
        }
        browser.start(queue: .global(qos: .utility))
        browsers[serviceType] = browser
    }

    private func handleResult(_ result: NWBrowser.Result, serviceType: String) {
        guard case .service(let name, let type, let domain, _) = result.endpoint else { return }
        resolveService(name: name, type: type, domain: domain)
    }

    private func resolveService(name: String, type: String, domain: String) {
        let service = NetService(domain: domain, type: type, name: name)
        service.delegate = self
        service.resolve(withTimeout: 5)
        resolvers[name] = service
    }

    private func buildDevice(from service: NetService, ip: String) -> Device {
        let type = deviceType(from: service.type)
        let brand = deviceBrand(from: service.name + " " + service.type)
        return Device(
            name: service.name,
            type: type,
            brand: brand,
            connectionType: .bonjour,
            ipAddress: ip,
            port: service.port > 0 ? service.port : nil,
            signalStrength: -60,
            connectionStatus: .disconnected,
            serviceIdentifier: "\(service.name).\(service.type)\(service.domain)",
            metadata: parseTextRecord(service.txtRecordData())
        )
    }

    private func parseTextRecord(_ data: Data?) -> [String: String] {
        guard let data else { return [:] }
        let dict = NetService.dictionary(fromTXTRecord: data)
        return dict.compactMapValues { String(data: $0, encoding: .utf8) }
    }

    private func deviceType(from serviceType: String) -> DeviceType {
        if serviceType.contains("airplay")       { return .appleTV }
        if serviceType.contains("googlecast")    { return .chromecast }
        if serviceType.contains("androidtv")     { return .androidTV }
        if serviceType.contains("samsung")       { return .smartTV }
        if serviceType.contains("webostv")       { return .smartTV }
        if serviceType.contains("sony")          { return .smartTV }
        if serviceType.contains("projector")     { return .projector }
        return .unknown
    }

    private func deviceBrand(from hint: String) -> DeviceBrand {
        let lower = hint.lowercased()
        if lower.contains("samsung") { return .samsung }
        if lower.contains("lg") || lower.contains("webos") { return .lg }
        if lower.contains("sony") || lower.contains("bravia") { return .sony }
        if lower.contains("apple") || lower.contains("airplay") { return .apple }
        if lower.contains("google") || lower.contains("cast") { return .google }
        if lower.contains("epson") { return .epson }
        if lower.contains("benq")  { return .benq }
        return .unknown
    }
}

// MARK: - NetServiceDelegate
extension BonjourDiscovery: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses else { return }
        for data in addresses {
            if let ip = extractIP(from: data) {
                let device = buildDevice(from: sender, ip: ip)
                DispatchQueue.main.async {
                    self.onDeviceFound?(device)
                }
                break
            }
        }
        resolvers.removeValue(forKey: sender.name)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        resolvers.removeValue(forKey: sender.name)
    }

    private func extractIP(from data: Data) -> String? {
        data.withUnsafeBytes { ptr -> String? in
            let sa = ptr.bindMemory(to: sockaddr.self).baseAddress!
            if sa.pointee.sa_family == AF_INET {
                let sa4 = ptr.bindMemory(to: sockaddr_in.self).baseAddress!
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                var addr = sa4.pointee.sin_addr
                inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN))
                return String(cString: buffer)
            }
            return nil
        }
    }
}
