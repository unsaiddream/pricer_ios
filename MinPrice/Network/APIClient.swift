import Foundation

final class APIClient {
    static let shared = APIClient()

    private let baseURL = "https://backend.minprice.kz/api"
    private let session: URLSession
    private let guestUUIDKey = "guest_uuid"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    // MARK: - Guest UUID

    var guestUUID: String? {
        UserDefaults.standard.string(forKey: guestUUIDKey)
    }

    // Инициализирует сессию через /session/init/ как веб-клиент
    func initSession() async {
        if UserDefaults.standard.string(forKey: guestUUIDKey) != nil { return }
        do {
            struct SessionResponse: Decodable { let guestUuid: String }
            let response = try await fetch(SessionResponse.self, path: "/session/init/")
            UserDefaults.standard.set(response.guestUuid, forKey: guestUUIDKey)
        } catch {
            print("⚠️ Session init failed: \(error)")
        }
    }

    // MARK: - Request builder

    func request(path: String, queryItems: [URLQueryItem] = []) -> URLRequest {
        var components = URLComponents(string: baseURL + path)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        var req = URLRequest(url: components.url!)
        if let uuid = guestUUID {
            req.setValue(uuid, forHTTPHeaderField: "X-Guest-UUID")
        }
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }

    // MARK: - Fetch

    func fetch<T: Decodable>(_ type: T.Type, path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        let req = request(path: path, queryItems: queryItems)
        let (data, response) = try await session.data(for: req)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("❌ HTTP \(code) for \(path)")
            throw APIError.httpError(statusCode: code)
        }

        return try decode(T.self, from: data)
    }

    func postVoid<B: Encodable>(path: String, body: B) async throws {
        var req = request(path: path)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        req.httpBody = try encoder.encode(body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let raw = String(data: data.prefix(500), encoding: .utf8) ?? "?"
            print("❌ HTTP \(code) for POST \(path): \(raw)")
            throw APIError.httpError(statusCode: code)
        }
    }

    func post<T: Decodable, B: Encodable>(_ type: T.Type, path: String, body: B) async throws -> T {
        var req = request(path: path)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        req.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let raw = String(data: data.prefix(500), encoding: .utf8) ?? "?"
            print("❌ HTTP \(code) for POST \(path): \(raw)")
            throw APIError.httpError(statusCode: code)
        }

        return try decode(T.self, from: data)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let raw = String(data: data.prefix(3000), encoding: .utf8) ?? "?"
            print("❌ Decode \(T.self): \(error)")
            print("📄 JSON: \(raw)")
            throw error
        }
    }
}

enum APIError: LocalizedError {
    case httpError(statusCode: Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "Ошибка сервера: \(code)"
        case .decodingError(let msg): return "Ошибка данных: \(msg)"
        }
    }
}
