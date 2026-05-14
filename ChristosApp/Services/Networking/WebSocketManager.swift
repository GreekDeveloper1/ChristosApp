import Foundation
import Combine

enum WebSocketState {
    case idle, connecting, connected, disconnected, error(Error)
}

final class WebSocketManager: NSObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private var pingTimer: Timer?

    var onMessage: ((String) -> Void)?
    var onData:    ((Data) -> Void)?
    var onState:   ((WebSocketState) -> Void)?

    private(set) var state: WebSocketState = .idle {
        didSet { onState?(state) }
    }

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }

    // MARK: - Connection

    func connect(to url: URL, headers: [String: String] = [:]) {
        disconnect()
        var request = URLRequest(url: url)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        webSocketTask = session.webSocketTask(with: request)
        state = .connecting
        webSocketTask?.resume()
        startReceiving()
        startPing()
    }

    func disconnect() {
        stopPing()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        state = .disconnected
    }

    // MARK: - Send

    func send(text: String) async throws {
        try await webSocketTask?.send(.string(text))
    }

    func send(data: Data) async throws {
        try await webSocketTask?.send(.data(data))
    }

    func sendJSON(_ object: Any) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        let text = String(data: data, encoding: .utf8) ?? ""
        try await send(text: text)
    }

    // MARK: - Private

    private func startReceiving() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.onMessage?(text)
                case .data(let data):
                    self?.onData?(data)
                @unknown default:
                    break
                }
                self?.startReceiving()  // keep listening
            case .failure:
                self?.state = .disconnected
            }
        }
    }

    private func startPing() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.webSocketTask?.sendPing { error in
                if error != nil {
                    self?.state = .disconnected
                }
            }
        }
    }

    private func stopPing() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
}

// MARK: - URLSessionWebSocketDelegate
extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol proto: String?
    ) {
        state = .connected
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        state = .disconnected
    }
}
