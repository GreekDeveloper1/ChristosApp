import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingFailed
    case httpError(Int)
    case timeout
    case unauthorized
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "Invalid URL"
        case .noData:           return "No data received"
        case .decodingFailed:   return "Failed to decode response"
        case .httpError(let c): return "HTTP \(c)"
        case .timeout:          return "Request timed out"
        case .unauthorized:     return "Unauthorized — check device pairing"
        case .custom(let m):    return m
        }
    }
}

final class NetworkManager {
    static let shared = NetworkManager()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 8
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    // MARK: - Generic JSON Request

    func request<T: Decodable>(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        if body != nil {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Raw Request (returns Data)

    func rawRequest(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await session.data(for: req)
        try validate(response)
        return data
    }

    // MARK: - POST JSON helper

    func post(url: URL, jsonObject: Any, headers: [String: String] = [:]) async throws -> Data {
        let body = try JSONSerialization.data(withJSONObject: jsonObject)
        var allHeaders = headers
        allHeaders["Content-Type"] = "application/json"
        return try await rawRequest(url: url, method: "POST", headers: allHeaders, body: body)
    }

    // MARK: - Reachability

    func isReachable(host: String, port: Int, timeout: TimeInterval = 3) async -> Bool {
        await withCheckedContinuation { continuation in
            let task = URLSession.shared.dataTask(
                with: URLRequest(url: URL(string: "http://\(host):\(port)")!, timeoutInterval: timeout)
            ) { _, response, error in
                let reachable = error == nil || (response as? HTTPURLResponse) != nil
                continuation.resume(returning: reachable)
            }
            task.resume()
        }
    }

    // MARK: - Validation

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: break
        case 401, 403:  throw NetworkError.unauthorized
        default:        throw NetworkError.httpError(http.statusCode)
        }
    }
}
