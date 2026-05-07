//
//  HTTPClient.swift
//  JjingToDo
//

import Foundation

struct HTTPError: Error, LocalizedError {
    let status: Int
    let body: String?
    var errorDescription: String? { "HTTP \(status): \(body ?? "")" }
}

struct HTTPClient {
    static let shared = HTTPClient()
    private init() {}

    func get<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        let (data, resp) = try await URLSession.shared.data(from: url)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw HTTPError(status: http.statusCode, body: String(data: data, encoding: .utf8))
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
