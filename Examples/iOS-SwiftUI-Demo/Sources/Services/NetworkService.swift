// NetworkService.swift - Network service demonstrating @Injectable and @PerformanceTracked
// Copyright © 2025 SwinjectMacros Demo. All rights reserved.

import Foundation
import Swinject
import SwinjectMacros

// MARK: - Network Protocol

protocol NetworkServiceProtocol {
    func fetchData<T: Codable>(from endpoint: String, type: T.Type) async throws -> T
    func postData(_ data: some Codable, to endpoint: String) async throws -> Bool
    func uploadImage(_ imageData: Data, to endpoint: String) async throws -> String
}

// MARK: - Network Service Implementation

@Injectable
@PerformanceTracked(
    trackExecutionTime: true,
    trackMemoryUsage: true,
    logSlowOperations: true,
    slowOperationThreshold: 2.0
)
class NetworkService: NetworkServiceProtocol {

    // Dependencies injected automatically
    private let logger: LoggerServiceProtocol
    private let configuration: ConfigurationServiceProtocol

    // URLSession configured with timeouts
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        return URLSession(configuration: config)
    }()

    init(
        logger: LoggerServiceProtocol,
        configuration: ConfigurationServiceProtocol
    ) {
        self.logger = logger
        self.configuration = configuration

        logger.info("🌐 NetworkService initialized")
    }

    // MARK: - NetworkServiceProtocol Implementation

    func fetchData<T: Codable>(from endpoint: String, type: T.Type) async throws -> T {
        logger.info("📥 Fetching data from: \(endpoint)")

        let url = try buildURL(for: endpoint)
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(configuration.apiKey, forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            logger.error("❌ HTTP Error: \(httpResponse.statusCode)")
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        do {
            let decodedData = try JSONDecoder().decode(type, from: data)
            logger.info("✅ Successfully fetched \(String(describing: type))")
            return decodedData
        } catch {
            logger.error("❌ Decoding error: \(error)")
            throw NetworkError.decodingError(error)
        }
    }

    func postData(_ data: some Codable, to endpoint: String) async throws -> Bool {
        logger.info("📤 Posting data to: \(endpoint)")

        let url = try buildURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(configuration.apiKey, forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONEncoder().encode(data)
        } catch {
            logger.error("❌ Encoding error: \(error)")
            throw NetworkError.encodingError(error)
        }

        let (_, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        let success = 200...299 ~= httpResponse.statusCode
        if success {
            logger.info("✅ Successfully posted data")
        } else {
            logger.error("❌ POST failed with status: \(httpResponse.statusCode)")
        }

        return success
    }

    func uploadImage(_ imageData: Data, to endpoint: String) async throws -> String {
        logger.info("📸 Uploading image to: \(endpoint) (size: \(imageData.count) bytes)")

        let url = try buildURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.addValue(configuration.apiKey, forHTTPHeaderField: "Authorization")
        request.httpBody = imageData

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            logger.error("❌ Image upload failed: \(httpResponse.statusCode)")
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        let responseString = String(data: data, encoding: .utf8) ?? ""
        logger.info("✅ Image uploaded successfully")
        return responseString
    }

    // MARK: - Helper Methods

    private func buildURL(for endpoint: String) throws -> URL {
        let baseURL = configuration.baseURL
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL(baseURL + endpoint)
        }
        return url
    }
}

// MARK: - Network Errors

enum NetworkError: Error, LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case httpError(Int)
    case encodingError(Error)
    case decodingError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            "Invalid URL: \(url)"
        case .invalidResponse:
            "Invalid server response"
        case .httpError(let code):
            "HTTP error: \(code)"
        case .encodingError(let error):
            "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            "Decoding error: \(error.localizedDescription)"
        case .noData:
            "No data received"
        }
    }
}

// MARK: - Supporting Services

protocol LoggerServiceProtocol {
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

@Injectable
class LoggerService: LoggerServiceProtocol {

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    func info(_ message: String) {
        log(level: "INFO", message: message)
    }

    func warning(_ message: String) {
        log(level: "WARN", message: message)
    }

    func error(_ message: String) {
        log(level: "ERROR", message: message)
    }

    private func log(level: String, message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] [\(level)] \(message)")
    }
}

protocol ConfigurationServiceProtocol {
    var baseURL: String { get }
    var apiKey: String { get }
    var timeout: TimeInterval { get }
}

@Injectable
@ScopedService(.container)
class ConfigurationService: ConfigurationServiceProtocol {

    let baseURL: String
    let apiKey: String
    let timeout: TimeInterval

    init() {
        // In a real app, these would come from environment variables or config files
        baseURL = "https://api.demo.com/"
        apiKey = "demo_api_key_12345"
        timeout = 30.0
    }
}
