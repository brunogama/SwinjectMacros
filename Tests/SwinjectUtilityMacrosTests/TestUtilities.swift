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

/// Simple test service protocol
public protocol TestServiceProtocol {
    func performAction() -> String
}

/// Test service implementation
public class TestService: TestServiceProtocol {
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
    public static func recordResult(for key: String, succeeded: Bool, attemptCount: Int, totalDelay: TimeInterval, finalError: Error? = nil) {}
    public static func recordAttempt(_ attempt: RetryAttempt, for key: String) {}
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

        container.register(TestServiceProtocol.self) { resolver in
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
