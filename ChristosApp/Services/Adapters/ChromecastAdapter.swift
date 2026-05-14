import Foundation
import Network

// Chromecast — Cast Application Framework v2 (CASTV2)
// Communication: TLS over port 8009, Protocol Buffers framing
// This adapter implements the control channel handshake and media namespace commands.
final class ChromecastAdapter: DeviceAdapter {
    let device: Device
    private(set) var isConnected = false
    private var connection: NWConnection?

    private var host: String { device.ipAddress ?? "" }
    private let port: NWEndpoint.Port = 8009

    // Cast namespace constants
    private enum Namespace {
        static let connection = "urn:x-cast:com.google.cast.tp.connection"
        static let heartbeat  = "urn:x-cast:com.google.cast.tp.heartbeat"
        static let receiver   = "urn:x-cast:com.google.cast.receiver"
        static let media      = "urn:x-cast:com.google.cast.media"
    }

    private var heartbeatTimer: Timer?
    private var requestId = 1

    init(device: Device) { self.device = device }

    func connect() async throws {
        let params = NWParameters.tls
        let options = NWProtocolTLS.Options()
        // Chromecast uses a self-signed cert — disable hostname validation
        sec_protocol_options_set_verify_block(
            options.securityProtocolOptions,
            { _, _, completion in completion(true) },
            .main
        )
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: port
        )
        connection = NWConnection(to: endpoint, using: params)

        return try await withCheckedThrowingContinuation { continuation in
            connection?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.sendConnect()
                    self?.startHeartbeat()
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            connection?.start(queue: .global(qos: .userInitiated))
        }
    }

    func disconnect() {
        heartbeatTimer?.invalidate()
        sendClose()
        connection?.cancel()
        isConnected = false
    }

    func send(_ command: DeviceCommand) async throws {
        guard isConnected else { throw NetworkError.custom("Not connected to Chromecast") }
        switch command {
        case .play:
            try sendCastMessage(namespace: Namespace.media, payload: ["type": "PLAY"])
        case .pause, .playPause:
            try sendCastMessage(namespace: Namespace.media, payload: ["type": "PAUSE"])
        case .stop:
            try sendCastMessage(namespace: Namespace.media, payload: ["type": "STOP"])
        case .volumeUp:
            try sendCastMessage(namespace: Namespace.receiver, payload: [
                "type": "SET_VOLUME",
                "volume": ["stepInterval": 0.05, "increment": true]
            ])
        case .volumeDown:
            try sendCastMessage(namespace: Namespace.receiver, payload: [
                "type": "SET_VOLUME",
                "volume": ["stepInterval": 0.05, "increment": false]
            ])
        case .mute, .muteToggle:
            try sendCastMessage(namespace: Namespace.receiver, payload: [
                "type": "SET_VOLUME",
                "volume": ["muted": true]
            ])
        case .launchApp(let app):
            try sendCastMessage(namespace: Namespace.receiver, payload: [
                "type": "LAUNCH",
                "appId": app.id,
                "requestId": requestId
            ])
        default:
            break
        }
    }

    func getInstalledApps() async throws -> [AppInfo] {
        [
            AppInfo(id: "CC1AD845", name: "Default Media Receiver", iconURL: nil, deepLink: nil),
            AppInfo(id: "YouTube",   name: "YouTube",               iconURL: nil, deepLink: nil),
            AppInfo(id: "Netflix",   name: "Netflix",               iconURL: nil, deepLink: nil),
            AppInfo(id: "B3DCF968", name: "Disney+",                iconURL: nil, deepLink: nil),
        ]
    }

    func getVolume() async throws -> Int { 0 }
    func getPowerState() async throws -> Bool { isConnected }
    func getAvailableInputs() async throws -> [String] { [] }

    // MARK: - Private CASTV2

    private func sendConnect() {
        try? sendCastMessage(namespace: Namespace.connection, payload: [
            "type": "CONNECT",
            "userAgent": "ChristosApp/1.0 iOS"
        ])
    }

    private func sendClose() {
        try? sendCastMessage(namespace: Namespace.connection, payload: ["type": "CLOSE"])
    }

    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            try? self?.sendCastMessage(namespace: Namespace.heartbeat, payload: ["type": "PING"])
        }
    }

    private func sendCastMessage(namespace: String, payload: [String: Any]) throws {
        guard let connection else { return }
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload),
              let payloadStr  = String(data: payloadData, encoding: .utf8)
        else { throw NetworkError.custom("Failed to serialize Cast message") }

        // CASTV2 framing: 4-byte big-endian length + protobuf CastMessage
        // Simplified: build a minimal protobuf manually
        let msg = buildCastProto(
            namespace: namespace,
            payloadUtf8: payloadStr,
            sourceId: "sender-0",
            destinationId: "receiver-0"
        )
        let lengthHeader = withUnsafeBytes(of: UInt32(msg.count).bigEndian) { Data($0) }
        connection.send(content: lengthHeader + msg, completion: .idempotent)
        requestId += 1
    }

    // Minimal CastMessage proto encoder (field 1=sourceId, 2=destId, 3=namespace, 4=payload)
    private func buildCastProto(
        namespace: String,
        payloadUtf8: String,
        sourceId: String,
        destinationId: String
    ) -> Data {
        func encodeField(_ tag: Int, _ value: String) -> Data {
            let strData = Data(value.utf8)
            let fieldTag = Data([(UInt8(tag) << 3) | 0x02])
            return fieldTag + encodeVarint(UInt64(strData.count)) + strData
        }
        func encodeVarint(_ v: UInt64) -> Data {
            var value = v
            var result = Data()
            while value > 0x7F {
                result.append(UInt8(value & 0x7F) | 0x80)
                value >>= 7
            }
            result.append(UInt8(value))
            return result
        }
        // field 1: protocol_version (varint, = 0)
        var proto = Data([0x08, 0x00])
        proto += encodeField(2, sourceId)
        proto += encodeField(3, destinationId)
        proto += encodeField(4, namespace)
        // payload_type string = 5
        proto += encodeField(6, payloadUtf8)
        return proto
    }
}
