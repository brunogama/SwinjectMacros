// RetryMacroTests.swift - Tests for @Retry macro expansion
// Copyright © 2025 SwinJectMacros. All rights reserved.

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import SwinjectMacrosImplementation

final class RetryMacroTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "Retry": RetryMacro.self
    ]

    // MARK: - Basic Functionality Tests

    func disabled_testBasicRetryExpansion() throws {
        assertMacroExpansion(
            """
            @Retry
            func fetchData() throws -> String {
                return "data"
            }
            """,
            expandedSource: """
            func fetchData() throws -> String {
                return "data"
            }

            public func fetchDataRetry() async throws -> String {
                let methodKey = "\\(String(describing: type(of: self))).fetchData"
                var lastError: Error?

                for attempt in 1...3 {

                    do {
                        let result = try fetchData()

                        // Record successful call
                        RetryMetricsManager.recordResult(
                            for: methodKey,
                            succeeded: true,
                            attemptCount: attempt,
                            totalDelay: 0.0
                        )

                        return result
                    } catch {
                        lastError = error

                        // Check if this is the last attempt
                        if attempt == 3 {
                            // Record final failure
                            RetryMetricsManager.recordResult(
                                for: methodKey,
                                succeeded: false,
                                attemptCount: attempt,
                                totalDelay: 0.0,
                                finalError: error
                            )
                            throw error
                        }

                        // Calculate backoff delay
                        let baseDelay = 1.0 * pow(2.0, Double(attempt - 1))
                        let cappedDelay = min(baseDelay, 60.0)
                        let delay = cappedDelay

                        // Record retry attempt
                        let retryAttempt = RetryAttempt(
                            attemptNumber: attempt,
                            error: error,
                            delay: delay
                        )
                        RetryMetricsManager.recordAttempt(retryAttempt, for: methodKey)

                        // Wait before retry
                        if delay > 0 {
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                }

                // This should never be reached, but just in case
                throw lastError ?? RetryError.maxAttemptsExceeded(attempts: 3)
            }
            """,
            macros: testMacros
        )
    }

    func disabled_testRetryWithCustomMaxAttempts() throws {
        assertMacroExpansion(
            """
            @Retry(maxAttempts: 5)
            func uploadFile(data: Data) throws -> Bool {
                return true
            }
            """,
            expandedSource: """
            func uploadFile(data: Data) throws -> Bool {
                return true
            }

            public func uploadFileRetry(data: Data) async throws -> Bool {
                let methodKey = "\\(String(describing: type(of: self))).uploadFile"
                var lastError: Error?

                for attempt in 1...5 {

                    do {
                        let result = try uploadFile(data: data)

                        // Record successful call
                        RetryMetricsManager.recordResult(
                            for: methodKey,
                            succeeded: true,
                            attemptCount: attempt,
                            totalDelay: 0.0
                        )

                        return result
                    } catch {
                        lastError = error

                        // Check if this is the last attempt
                        if attempt == 5 {
                            // Record final failure
                            RetryMetricsManager.recordResult(
                                for: methodKey,
                                succeeded: false,
                                attemptCount: attempt,
                                totalDelay: 0.0,
                                finalError: error
                            )
                            throw error
                        }

                        // Calculate backoff delay
                        let baseDelay = 1.0 * pow(2.0, Double(attempt - 1))
                        let cappedDelay = min(baseDelay, 60.0)
                        let delay = cappedDelay

                        // Record retry attempt
                        let retryAttempt = RetryAttempt(
                            attemptNumber: attempt,
                            error: error,
                            delay: delay
                        )
                        RetryMetricsManager.recordAttempt(retryAttempt, for: methodKey)

                        // Wait before retry
                        if delay > 0 {
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                }

                // This should never be reached, but just in case
                throw lastError ?? RetryError.maxAttemptsExceeded(attempts: 5)
            }
            """,
            macros: testMacros
        )
    }

    func disabled_testRetryWithJitter() throws {
        assertMacroExpansion(
            """
            @Retry(maxAttempts: 3, jitter: true)
            func networkCall() throws -> Data {
                return Data()
            }
            """,
            expandedSource: """
            func networkCall() throws -> Data {
                return Data()
            }

            public func networkCallRetry() async throws -> Data {
                let methodKey = "\\(String(describing: type(of: self))).networkCall"
                var lastError: Error?

                for attempt in 1...3 {

                    do {
                        let result = try networkCall()

                        // Record successful call
                        RetryMetricsManager.recordResult(
                            for: methodKey,
                            succeeded: true,
                            attemptCount: attempt,
                            totalDelay: 0.0
                        )

                        return result
                    } catch {
                        lastError = error

                        // Check if this is the last attempt
                        if attempt == 3 {
                            // Record final failure
                            RetryMetricsManager.recordResult(
                                for: methodKey,
                                succeeded: false,
                                attemptCount: attempt,
                                totalDelay: 0.0,
                                finalError: error
                            )
                            throw error
                        }

                        // Calculate backoff delay
                        let baseDelay = 1.0 * pow(2.0, Double(attempt - 1))
                        let cappedDelay = min(baseDelay, 60.0)
                        let jitterRange = cappedDelay * 0.25
                        let randomJitter = Double.random(in: -jitterRange...jitterRange)
                        let delay = max(0, cappedDelay + randomJitter)

                        // Record retry attempt
                        let retryAttempt = RetryAttempt(
                            attemptNumber: attempt,
                            error: error,
                            delay: delay
                        )
                        RetryMetricsManager.recordAttempt(retryAttempt, for: methodKey)

                        // Wait before retry
                        if delay > 0 {
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                }

                // This should never be reached, but just in case
                throw lastError ?? RetryError.maxAttemptsExceeded(attempts: 3)
            }
            """,
            macros: testMacros
        )
    }

    func disabled_testRetryWithTimeout() throws {
        assertMacroExpansion(
            """
            @Retry(maxAttempts: 5, timeout: 30.0)
            func longRunningTask() throws -> String {
                return "result"
            }
            """,
            expandedSource: """
            func longRunningTask() throws -> String {
                return "result"
            }

            public func longRunningTaskRetry() async throws -> String {
                let methodKey = "\\(String(describing: type(of: self))).longRunningTask"
                var lastError: Error?
                let startTime = Date()
                let timeoutInterval: TimeInterval = 30.0

                for attempt in 1...5 {
                    // Check overall timeout
                    if Date().timeIntervalSince(startTime) >= timeoutInterval {
                        throw RetryError.timeoutExceeded(timeout: timeoutInterval)
                    }

                    do {
                        let result = try longRunningTask()

                        // Record successful call
                        RetryMetricsManager.recordResult(
                            for: methodKey,
                            succeeded: true,
                            attemptCount: attempt,
                            totalDelay: 0.0
                        )

                        return result
                    } catch {
                        lastError = error

                        // Check if this is the last attempt
                        if attempt == 5 {
                            // Record final failure
                            RetryMetricsManager.recordResult(
                                for: methodKey,
                                succeeded: false,
                                attemptCount: attempt,
                                totalDelay: 0.0,
                                finalError: error
                            )
                            throw error
                        }

                        // Calculate backoff delay
                        let baseDelay = 1.0 * pow(2.0, Double(attempt - 1))
                        let cappedDelay = min(baseDelay, 60.0)
                        let delay = cappedDelay

                        // Record retry attempt
                        let retryAttempt = RetryAttempt(
                            attemptNumber: attempt,
                            error: error,
                            delay: delay
                        )
                        RetryMetricsManager.recordAttempt(retryAttempt, for: methodKey)

                        // Wait before retry
                        if delay > 0 {
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                }

                // This should never be reached, but just in case
                throw lastError ?? RetryError.maxAttemptsExceeded(attempts: 5)
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Async Function Tests

    func disabled_testAsyncRetry() throws {
        assertMacroExpansion(
            """
            @Retry(maxAttempts: 3)
            func fetchDataAsync(from url: URL) async throws -> Data {
                return try await URLSession.shared.data(from: url).0
            }
            """,
            expandedSource: """
            func fetchDataAsync(from url: URL) async throws -> Data {
                return try await URLSession.shared.data(from: url).0
            }

            public func fetchDataAsyncRetry(from url: URL) async throws -> Data {
                let methodKey = "\\(String(describing: type(of: self))).fetchDataAsync"
                var lastError: Error?

                for attempt in 1...3 {

                    do {
                        let result = try await fetchDataAsync(from: url)

                        // Record successful call
                        RetryMetricsManager.recordResult(
                            for: methodKey,
                            succeeded: true,
                            attemptCount: attempt,
                            totalDelay: 0.0
                        )

                        return result
                    } catch {
                        lastError = error

                        // Check if this is the last attempt
                        if attempt == 3 {
                            // Record final failure
                            RetryMetricsManager.recordResult(
                                for: methodKey,
                                succeeded: false,
                                attemptCount: attempt,
                                totalDelay: 0.0,
                                finalError: error
                            )
                            throw error
                        }

                        // Calculate backoff delay
                        let baseDelay = 1.0 * pow(2.0, Double(attempt - 1))
                        let cappedDelay = min(baseDelay, 60.0)
                        let delay = cappedDelay

                        // Record retry attempt
                        let retryAttempt = RetryAttempt(
                            attemptNumber: attempt,
                            error: error,
                            delay: delay
                        )
                        RetryMetricsManager.recordAttempt(retryAttempt, for: methodKey)

                        // Wait before retry
                        if delay > 0 {
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                }

                // This should never be reached, but just in case
                throw lastError ?? RetryError.maxAttemptsExceeded(attempts: 3)
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Static Method Tests

    func disabled_testStaticMethodRetry() throws {
        assertMacroExpansion(
            """
            @Retry(maxAttempts: 2)
            static func validateInput(_ input: String) throws -> Bool {
                return !input.isEmpty
            }
            """,
            expandedSource: """
            static func validateInput(_ input: String) throws -> Bool {
                return !input.isEmpty
            }

            public static func validateInputRetry(_ input: String) async throws -> Bool {
                let methodKey = "\\(String(describing: type(of: self))).validateInput"
                var lastError: Error?

                for attempt in 1...2 {

                    do {
                        let result = try validateInput(input)

                        // Record successful call
                        RetryMetricsManager.recordResult(
                            for: methodKey,
                            succeeded: true,
                            attemptCount: attempt,
                            totalDelay: 0.0
                        )

                        return result
                    } catch {
                        lastError = error

                        // Check if this is the last attempt
                        if attempt == 2 {
                            // Record final failure
                            RetryMetricsManager.recordResult(
                                for: methodKey,
                                succeeded: false,
                                attemptCount: attempt,
                                totalDelay: 0.0,
                                finalError: error
                            )
                            throw error
                        }

                        // Calculate backoff delay
                        let baseDelay = 1.0 * pow(2.0, Double(attempt - 1))
                        let cappedDelay = min(baseDelay, 60.0)
                        let delay = cappedDelay

                        // Record retry attempt
                        let retryAttempt = RetryAttempt(
                            attemptNumber: attempt,
                            error: error,
                            delay: delay
                        )
                        RetryMetricsManager.recordAttempt(retryAttempt, for: methodKey)

                        // Wait before retry
                        if delay > 0 {
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                }

                // This should never be reached, but just in case
                throw lastError ?? RetryError.maxAttemptsExceeded(attempts: 2)
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Non-Throwing Method Tests

    func disabled_testNonThrowingMethodRetry() throws {
        assertMacroExpansion(
            """
            @Retry(maxAttempts: 3)
            func computeValue(input: Int) -> Int {
                return input * 2
            }
            """,
            expandedSource: """
            func computeValue(input: Int) -> Int {
                return input * 2
            }

            public func computeValueRetry(input: Int) async throws -> Int {
                let methodKey = "\\(String(describing: type(of: self))).computeValue"
                var lastError: Error?

                for attempt in 1...3 {

                    do {
                        let result = computeValue(input: input)

                        // Record successful call
                        RetryMetricsManager.recordResult(
                            for: methodKey,
                            succeeded: true,
                            attemptCount: attempt,
                            totalDelay: 0.0
                        )

                        return result
                    } catch {
                        lastError = error

                        // Check if this is the last attempt
                        if attempt == 3 {
                            // Record final failure
                            RetryMetricsManager.recordResult(
                                for: methodKey,
                                succeeded: false,
                                attemptCount: attempt,
                                totalDelay: 0.0,
                                finalError: error
                            )
                            throw error
                        }

                        // Calculate backoff delay
                        let baseDelay = 1.0 * pow(2.0, Double(attempt - 1))
                        let cappedDelay = min(baseDelay, 60.0)
                        let delay = cappedDelay

                        // Record retry attempt
                        let retryAttempt = RetryAttempt(
                            attemptNumber: attempt,
                            error: error,
                            delay: delay
                        )
                        RetryMetricsManager.recordAttempt(retryAttempt, for: methodKey)

                        // Wait before retry
                        if delay > 0 {
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                }

                // This should never be reached, but just in case
                throw lastError ?? RetryError.maxAttemptsExceeded(attempts: 3)
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Void Return Type Tests

    func disabled_testVoidReturnTypeRetry() throws {
        assertMacroExpansion(
            """
            @Retry(maxAttempts: 2)
            func performAction() throws {
                // Action implementation
            }
            """,
            expandedSource: """
            func performAction() throws {
                // Action implementation
            }

            public func performActionRetry() async throws {
                let methodKey = "\\(String(describing: type(of: self))).performAction"
                var lastError: Error?

                for attempt in 1...2 {

                    do {
                        let result = try performAction()

                        // Record successful call
                        RetryMetricsManager.recordResult(
                            for: methodKey,
                            succeeded: true,
                            attemptCount: attempt,
                            totalDelay: 0.0
                        )

                    } catch {
                        lastError = error

                        // Check if this is the last attempt
                        if attempt == 2 {
                            // Record final failure
                            RetryMetricsManager.recordResult(
                                for: methodKey,
                                succeeded: false,
                                attemptCount: attempt,
                                totalDelay: 0.0,
                                finalError: error
                            )
                            throw error
                        }

                        // Calculate backoff delay
                        let baseDelay = 1.0 * pow(2.0, Double(attempt - 1))
                        let cappedDelay = min(baseDelay, 60.0)
                        let delay = cappedDelay

                        // Record retry attempt
                        let retryAttempt = RetryAttempt(
                            attemptNumber: attempt,
                            error: error,
                            delay: delay
                        )
                        RetryMetricsManager.recordAttempt(retryAttempt, for: methodKey)

                        // Wait before retry
                        if delay > 0 {
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                }

                // This should never be reached, but just in case
                throw lastError ?? RetryError.maxAttemptsExceeded(attempts: 2)
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Error Cases

    func disabled_testRetryOnNonFunction() throws {
        assertMacroExpansion(
            """
            @Retry
            struct TestStruct {
                let value: String
            }
            """,
            expandedSource: """
            struct TestStruct {
                let value: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Retry can only be applied to functions and methods", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    // MARK: - Complex Parameter Tests

    func disabled_testRetryWithComplexParameters() throws {
        assertMacroExpansion(
            """
            @Retry(maxAttempts: 3)
            func processRequest(from url: URL, with headers: [String: String] = [:], timeout: TimeInterval = 30.0) async throws -> Response {
                return Response()
            }
            """,
            expandedSource: """
            func processRequest(from url: URL, with headers: [String: String] = [:], timeout: TimeInterval = 30.0) async throws -> Response {
                return Response()
            }

            public func processRequestRetry(from url: URL, with headers: [String: String] = [:], timeout: TimeInterval = 30.0) async throws -> Response {
                let methodKey = "\\(String(describing: type(of: self))).processRequest"
                var lastError: Error?

                for attempt in 1...3 {

                    do {
                        let result = try await processRequest(from: url, with: headers, timeout: timeout)

                        // Record successful call
                        RetryMetricsManager.recordResult(
                            for: methodKey,
                            succeeded: true,
                            attemptCount: attempt,
                            totalDelay: 0.0
                        )

                        return result
                    } catch {
                        lastError = error

                        // Check if this is the last attempt
                        if attempt == 3 {
                            // Record final failure
                            RetryMetricsManager.recordResult(
                                for: methodKey,
                                succeeded: false,
                                attemptCount: attempt,
                                totalDelay: 0.0,
                                finalError: error
                            )
                            throw error
                        }

                        // Calculate backoff delay
                        let baseDelay = 1.0 * pow(2.0, Double(attempt - 1))
                        let cappedDelay = min(baseDelay, 60.0)
                        let delay = cappedDelay

                        // Record retry attempt
                        let retryAttempt = RetryAttempt(
                            attemptNumber: attempt,
                            error: error,
                            delay: delay
                        )
                        RetryMetricsManager.recordAttempt(retryAttempt, for: methodKey)

                        // Wait before retry
                        if delay > 0 {
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                }

                // This should never be reached, but just in case
                throw lastError ?? RetryError.maxAttemptsExceeded(attempts: 3)
            }
            """,
            macros: testMacros
        )
    }
}
