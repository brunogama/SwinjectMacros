// TestUtilities.swift - Shared test types and utilities
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import Swinject
@testable import SwinjectUtilityMacros
import XCTest

// MARK: - Common Test Types

/// Basic test dependency used across multiple test files
public class TestDependency {
    public let id = UUID()

    public init() {}

    public func transform(_ input: String) -> String {
        input.reversed().description
    }
}

/// Test service implementation
public class TestService {
    public let dependency: TestDependency?

    public init(dependency: TestDependency? = nil) {
        self.dependency = dependency
    }

    public func performAction() -> String {
        "Action performed"
    }
}

// MARK: - Mock Types for Circuit Breaker Tests
// Note: These types are also defined in ErrorRecoveryTests.swift with additional fields

// MARK: - Mock Types for Retry Tests

public struct RetryAttempt {
    public let attemptNumber: Int
    public let error: Error
    public let delay: TimeInterval

    public init(attemptNumber: Int, error: Error, delay: TimeInterval = 0) {
        self.attemptNumber = attemptNumber
        self.error = error
        self.delay = delay
    }
}

public struct RetryMetricsManager {
    public static func recordResult(for key: String, succeeded: Bool, attemptCount: Int, totalDelay: TimeInterval, finalError: Error? = nil) {
        // Implementation placeholder
    }

    public static func recordAttempt(_ attempt: RetryAttempt, for key: String) {
        // Implementation placeholder
    }
}

// CircuitBreakerRegistry is defined in ErrorRecoveryTests.swift

// MARK: - Mock Types for Cache Tests

public class CacheManager {
    private static var storage: [String: Any] = [:]

    public static func get(_ key: String) -> Any? {
        storage[key]
    }

    public static func set(_ key: String, value: Any, ttl: TimeInterval? = nil) {
        storage[key] = value
    }

    public static func invalidate(_ key: String) {
        storage.removeValue(forKey: key)
    }

    public static func clear() {
        storage.removeAll()
    }
}

// MARK: - Mock Types for Performance Tests

public struct PerformanceMetrics {
    public let executionTime: TimeInterval
    public let memoryUsage: Int

    public init(executionTime: TimeInterval, memoryUsage: Int = 0) {
        self.executionTime = executionTime
        self.memoryUsage = memoryUsage
    }
}

// MARK: - Test Container Utilities

public class TestContainer {
    public let container: Container

    public init() {
        self.container = Container()
        registerBasicServices()
    }

    private func registerBasicServices() {
        container.register(TestDependency.self) { _ in
            TestDependency()
        }

        container.register(TestService.self) { resolver in
            TestService(dependency: resolver.resolve(TestDependency.self))
        }
    }

    public func resolve<T>(_ type: T.Type) -> T? {
        container.resolve(type)
    }
}

// MARK: - Error Types

public enum TestError: Error {
    case generic
    case timeout
    case invalidInput
    case networkError
    case networkFailure
    case parseError
    case unknownError
}

public enum RetryError: Error {
    case maxAttemptsExceeded(attempts: Int)
    case timeoutExceeded(timeout: TimeInterval)
}

// MARK: - Generic Mock Types for Testing

public struct Repository<T> {
    public init() {}
    public func save(_ item: T) {}
    public func fetch() -> T? { nil }
}

public struct Cache<Key, Value> {
    public init() {}
    public func get(_ key: Key) -> Value? { nil }
    public func set(_ key: Key, _ value: Value) {}
}

public struct Processor<T> {
    public init() {}
    public func process(_ item: T) -> T { item }
}

public struct DataProvider<Input, Output> {
    public init() {}
    public func provide(_ input: Input) -> Output {
        fatalError("Mock implementation")
    }
}

public struct ValidationResult<T> {
    public let isValid: Bool
    public let value: T?
    public let errors: [String]

    public init(isValid: Bool, value: T? = nil, errors: [String] = []) {
        self.isValid = isValid
        self.value = value
        self.errors = errors
    }
}

public enum NetworkError: Error {
    case connectionFailed
    case timeout
    case serverError
    case authenticationFailed
}

public struct DataTransformer<Input, Output> {
    public init() {}
    public func transform(_ input: Input) -> Output {
        fatalError("Mock implementation")
    }
}

public struct Tree<Node> {
    public let root: Node?
    public init(root: Node? = nil) { self.root = root }
}

public struct TreeNode<T> {
    public let value: T
    public let children: [TreeNode<T>]
    public init(value: T, children: [TreeNode<T>] = []) {
        self.value = value
        self.children = children
    }
}

public struct RecursiveData<T, U> {
    public let primary: T
    public let secondary: U
    public init(primary: T, secondary: U) {
        self.primary = primary
        self.secondary = secondary
    }
}

public struct CacheKey<T> {
    public let value: T
    public init(_ value: T) { self.value = value }
}

public struct CachedValue<T> {
    public let value: T
    public let timestamp: Date
    public init(_ value: T) {
        self.value = value
        self.timestamp = Date()
    }
}

public struct ValidationContext<T> {
    public let target: T
    public let rules: [String]
    public init(target: T, rules: [String] = []) {
        self.target = target
        self.rules = rules
    }
}

// MARK: - Common Mock Protocol Definitions

public protocol APIClientProtocol {
    func request(_ endpoint: String) async throws -> Data
    func get(_ url: String) async throws -> Any
    func post(_ url: String, body: Any) async throws -> Any
}

public protocol DatabaseProtocol {
    func save(_ entity: Any) async throws
    func fetch(id: String) async throws -> Any?
    func delete(id: String) async throws
    func query(_ predicate: String) async throws -> [Any]
}

public protocol LoggerProtocol {
    func log(_ message: String, level: LogLevel)
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

public enum LogLevel: String {
    case debug, info, warning, error
}

public protocol RepositoryProtocol {
    associatedtype Entity
    func save(_ entity: Entity) async throws
    func findById(_ id: String) async throws -> Entity?
    func findAll() async throws -> [Entity]
    func delete(_ id: String) async throws
}

// MARK: - Mock Implementations

public class MockAPIClient: APIClientProtocol {
    public var requestCalled = false
    public var lastEndpoint: String?
    public var mockResponse: Data?
    public var shouldThrow: Error?

    public init() {}

    public func request(_ endpoint: String) async throws -> Data {
        requestCalled = true
        lastEndpoint = endpoint
        if let error = shouldThrow { throw error }
        return mockResponse ?? Data()
    }

    public func get(_ url: String) async throws -> Any {
        try await request(url)
    }

    public func post(_ url: String, body: Any) async throws -> Any {
        try await request(url)
    }
}

public class MockDatabase: DatabaseProtocol {
    private var storage: [String: Any] = [:]
    public var shouldThrow: Error?

    public init() {}

    public func save(_ entity: Any) async throws {
        if let error = shouldThrow { throw error }
        if let identifiable = entity as? Identifiable {
            storage[identifiable.id] = entity
        }
    }

    public func fetch(id: String) async throws -> Any? {
        if let error = shouldThrow { throw error }
        return storage[id]
    }

    public func delete(id: String) async throws {
        if let error = shouldThrow { throw error }
        storage.removeValue(forKey: id)
    }

    public func query(_ predicate: String) async throws -> [Any] {
        if let error = shouldThrow { throw error }
        return Array(storage.values)
    }
}

public protocol Identifiable {
    var id: String { get }
}

public class MockLogger: LoggerProtocol {
    public var messages: [(message: String, level: LogLevel)] = []

    public init() {}

    public func log(_ message: String, level: LogLevel) {
        messages.append((message, level))
    }

    public func debug(_ message: String) {
        log(message, level: .debug)
    }

    public func info(_ message: String) {
        log(message, level: .info)
    }

    public func warning(_ message: String) {
        log(message, level: .warning)
    }

    public func error(_ message: String) {
        log(message, level: .error)
    }
}

public class MockRepository<T>: RepositoryProtocol {
    public typealias Entity = T
    private var storage: [String: T] = [:]
    public var shouldThrow: Error?

    public init() {}

    public func save(_ entity: T) async throws {
        if let error = shouldThrow { throw error }
        if let identifiable = entity as? Identifiable {
            storage[identifiable.id] = entity
        }
    }

    public func findById(_ id: String) async throws -> T? {
        if let error = shouldThrow { throw error }
        return storage[id]
    }

    public func findAll() async throws -> [T] {
        if let error = shouldThrow { throw error }
        return Array(storage.values)
    }

    public func delete(_ id: String) async throws {
        if let error = shouldThrow { throw error }
        storage.removeValue(forKey: id)
    }
}

// MARK: - Performance Testing Mock Types

public protocol PerformanceMockProtocol {
    var operationCount: Int { get }
    func reset()
}

public class FastMockAPIClient: APIClientProtocol, PerformanceMockProtocol {
    public private(set) var operationCount = 0

    public init() {}

    public func request(_ endpoint: String) async throws -> Data {
        operationCount += 1
        return Data()
    }

    public func get(_ url: String) async throws -> Any {
        operationCount += 1
        return Data()
    }

    public func post(_ url: String, body: Any) async throws -> Any {
        operationCount += 1
        return Data()
    }

    public func reset() {
        operationCount = 0
    }
}

public class FastMockLogger: LoggerProtocol, PerformanceMockProtocol {
    public private(set) var operationCount = 0

    public init() {}

    public func log(_ message: String, level: LogLevel) {
        operationCount += 1
    }

    public func debug(_ message: String) {
        operationCount += 1
    }

    public func info(_ message: String) {
        operationCount += 1
    }

    public func warning(_ message: String) {
        operationCount += 1
    }

    public func error(_ message: String) {
        operationCount += 1
    }

    public func reset() {
        operationCount = 0
    }
}

// MARK: - SwiftUI Testing Mock Types

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public class SwiftUIMockAPIClient: MockAPIClient, ObservableObject {
    @Published public var isLoading = false
    @Published public var lastResult: Any?

    override public func request(_ endpoint: String) async throws -> Data {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        let result = try await super.request(endpoint)
        await MainActor.run { lastResult = result }
        return result
    }
}

// MARK: - Common Test Service Types

public class UserService {
    public let apiClient: APIClientProtocol
    public let database: DatabaseProtocol
    public let logger: LoggerProtocol

    public init(apiClient: APIClientProtocol, database: DatabaseProtocol, logger: LoggerProtocol) {
        self.apiClient = apiClient
        self.database = database
        self.logger = logger
    }

    public func fetchUser(id: String) async throws -> Any? {
        logger.info("Fetching user \(id)")
        if let cached = try await database.fetch(id: id) {
            logger.debug("User found in cache")
            return cached
        }

        let data = try await apiClient.get("/users/\(id)")
        try await database.save(data)
        logger.info("User fetched from API and cached")
        return data
    }
}

public class AnalyticsService {
    public let logger: LoggerProtocol

    public init(logger: LoggerProtocol) {
        self.logger = logger
    }

    public func track(event: String, properties: [String: Any] = [:]) {
        logger.info("Analytics event: \(event)")
    }
}

// MARK: - Test Helpers

public func measureTime<T>(block: () throws -> T) rethrows -> (result: T, time: TimeInterval) {
    let start = CFAbsoluteTimeGetCurrent()
    let result = try block()
    let time = CFAbsoluteTimeGetCurrent() - start
    return (result, time)
}

public func assertNoThrow<T>(_ expression: @autoclosure () throws -> T, message: String = "Expression threw unexpectedly", file: StaticString = #file, line: UInt = #line) -> T? {
    do {
        return try expression()
    } catch {
        XCTFail("\(message): \(error)", file: file, line: line)
        return nil
    }
}
