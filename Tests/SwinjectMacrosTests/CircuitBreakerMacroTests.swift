// CircuitBreakerMacroTests.swift - Tests for @CircuitBreaker macro expansion
// Copyright © 2025 SwinJectMacros. All rights reserved.

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import SwinjectMacrosImplementation

final class CircuitBreakerMacroTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "CircuitBreaker": CircuitBreakerMacro.self
    ]

    // MARK: - Basic Functionality Tests

    func testBasicCircuitBreakerExpansion() throws {
        assertMacroExpansion(
            """
            @CircuitBreaker
            func callExternalService() throws -> String {
                return "service response"
            }
            """,
            expandedSource: """
            func callExternalService() throws -> String {
                return "service response"
            }

            public func callExternalServiceCircuitBreaker() throws -> String {
                let circuitKey = "\\(String(describing: type(of: self))).callExternalService"

                // Get or create circuit breaker instance
                let circuitBreaker = CircuitBreakerRegistry.getCircuitBreaker(
                    for: circuitKey,
                    failureThreshold: 5,
                    timeout: 60.0,
                    successThreshold: 3,
                    monitoringWindow: 60.0
                )

                // Check if call should be allowed
                guard circuitBreaker.shouldAllowCall() else {
                    // Circuit is open, record blocked call and handle fallback
                    let blockedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: true,
                        responseTime: 0.0,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(blockedCall, for: circuitKey)

                    throw CircuitBreakerError.circuitOpen(circuitName: circuitKey, lastFailureTime: circuitBreaker.lastOpenedTime)
                }

                // Execute the method with circuit breaker protection
                let startTime = CFAbsoluteTimeGetCurrent()
                var wasSuccessful = false
                var callError: Error?

                do {
                    let result = try callExternalService()
                    wasSuccessful = true

                    // Record successful call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let successfulCall = CircuitBreakerCall(
                        wasSuccessful: true,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(successfulCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: true)

                    return result
                } catch {
                    wasSuccessful = false
                    callError = error

                    // Record failed call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000

                    let failedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState,
                        error: error
                    )
                    CircuitBreakerRegistry.recordCall(failedCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: false)

                    // Re-throw the error
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }

    func testCircuitBreakerWithCustomThresholds() throws {
        assertMacroExpansion(
            """
            @CircuitBreaker(failureThreshold: 3, timeout: 30.0, successThreshold: 2)
            func unstableService() throws -> Bool {
                return true
            }
            """,
            expandedSource: """
            func unstableService() throws -> Bool {
                return true
            }

            public func unstableServiceCircuitBreaker() throws -> Bool {
                let circuitKey = "\\(String(describing: type(of: self))).unstableService"

                // Get or create circuit breaker instance
                let circuitBreaker = CircuitBreakerRegistry.getCircuitBreaker(
                    for: circuitKey,
                    failureThreshold: 3,
                    timeout: 30.0,
                    successThreshold: 2,
                    monitoringWindow: 60.0
                )

                // Check if call should be allowed
                guard circuitBreaker.shouldAllowCall() else {
                    // Circuit is open, record blocked call and handle fallback
                    let blockedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: true,
                        responseTime: 0.0,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(blockedCall, for: circuitKey)

                    throw CircuitBreakerError.circuitOpen(circuitName: circuitKey, lastFailureTime: circuitBreaker.lastOpenedTime)
                }

                // Execute the method with circuit breaker protection
                let startTime = CFAbsoluteTimeGetCurrent()
                var wasSuccessful = false
                var callError: Error?

                do {
                    let result = try unstableService()
                    wasSuccessful = true

                    // Record successful call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let successfulCall = CircuitBreakerCall(
                        wasSuccessful: true,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(successfulCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: true)

                    return result
                } catch {
                    wasSuccessful = false
                    callError = error

                    // Record failed call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000

                    let failedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState,
                        error: error
                    )
                    CircuitBreakerRegistry.recordCall(failedCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: false)

                    // Re-throw the error
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }

    func testCircuitBreakerWithFallbackValue() throws {
        assertMacroExpansion(
            """
            @CircuitBreaker(fallbackValue: "Service Unavailable")
            func getStatusMessage() throws -> String {
                return "All systems operational"
            }
            """,
            expandedSource: """
            func getStatusMessage() throws -> String {
                return "All systems operational"
            }

            public func getStatusMessageCircuitBreaker() throws -> String {
                let circuitKey = "\\(String(describing: type(of: self))).getStatusMessage"

                // Get or create circuit breaker instance
                let circuitBreaker = CircuitBreakerRegistry.getCircuitBreaker(
                    for: circuitKey,
                    failureThreshold: 5,
                    timeout: 60.0,
                    successThreshold: 3,
                    monitoringWindow: 60.0
                )

                // Check if call should be allowed
                guard circuitBreaker.shouldAllowCall() else {
                    // Circuit is open, record blocked call and handle fallback
                    let blockedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: true,
                        responseTime: 0.0,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(blockedCall, for: circuitKey)

                    return "Service Unavailable" as! String // Fallback value
                }

                // Execute the method with circuit breaker protection
                let startTime = CFAbsoluteTimeGetCurrent()
                var wasSuccessful = false
                var callError: Error?

                do {
                    let result = try getStatusMessage()
                    wasSuccessful = true

                    // Record successful call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let successfulCall = CircuitBreakerCall(
                        wasSuccessful: true,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(successfulCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: true)

                    return result
                } catch {
                    wasSuccessful = false
                    callError = error

                    // Record failed call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000

                    let failedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState,
                        error: error
                    )
                    CircuitBreakerRegistry.recordCall(failedCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: false)

                    // Re-throw the error
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Async Function Tests

    func testAsyncCircuitBreaker() throws {
        assertMacroExpansion(
            """
            @CircuitBreaker(failureThreshold: 3)
            func fetchDataAsync(from url: URL) async throws -> Data {
                return try await URLSession.shared.data(from: url).0
            }
            """,
            expandedSource: """
            func fetchDataAsync(from url: URL) async throws -> Data {
                return try await URLSession.shared.data(from: url).0
            }

            public func fetchDataAsyncCircuitBreaker(from url: URL) async throws -> Data {
                let circuitKey = "\\(String(describing: type(of: self))).fetchDataAsync"

                // Get or create circuit breaker instance
                let circuitBreaker = CircuitBreakerRegistry.getCircuitBreaker(
                    for: circuitKey,
                    failureThreshold: 3,
                    timeout: 60.0,
                    successThreshold: 3,
                    monitoringWindow: 60.0
                )

                // Check if call should be allowed
                guard circuitBreaker.shouldAllowCall() else {
                    // Circuit is open, record blocked call and handle fallback
                    let blockedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: true,
                        responseTime: 0.0,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(blockedCall, for: circuitKey)

                    throw CircuitBreakerError.circuitOpen(circuitName: circuitKey, lastFailureTime: circuitBreaker.lastOpenedTime)
                }

                // Execute the method with circuit breaker protection
                let startTime = CFAbsoluteTimeGetCurrent()
                var wasSuccessful = false
                var callError: Error?

                do {
                    let result = try await fetchDataAsync(from: url)
                    wasSuccessful = true

                    // Record successful call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let successfulCall = CircuitBreakerCall(
                        wasSuccessful: true,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(successfulCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: true)

                    return result
                } catch {
                    wasSuccessful = false
                    callError = error

                    // Record failed call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000

                    let failedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState,
                        error: error
                    )
                    CircuitBreakerRegistry.recordCall(failedCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: false)

                    // Re-throw the error
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Static Method Tests

    func testStaticMethodCircuitBreaker() throws {
        assertMacroExpansion(
            """
            @CircuitBreaker(failureThreshold: 2, timeout: 15.0)
            static func validateConfiguration(_ config: String) throws -> Bool {
                return !config.isEmpty
            }
            """,
            expandedSource: """
            static func validateConfiguration(_ config: String) throws -> Bool {
                return !config.isEmpty
            }

            public static func validateConfigurationCircuitBreaker(_ config: String) throws -> Bool {
                let circuitKey = "\\(String(describing: type(of: self))).validateConfiguration"

                // Get or create circuit breaker instance
                let circuitBreaker = CircuitBreakerRegistry.getCircuitBreaker(
                    for: circuitKey,
                    failureThreshold: 2,
                    timeout: 15.0,
                    successThreshold: 3,
                    monitoringWindow: 60.0
                )

                // Check if call should be allowed
                guard circuitBreaker.shouldAllowCall() else {
                    // Circuit is open, record blocked call and handle fallback
                    let blockedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: true,
                        responseTime: 0.0,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(blockedCall, for: circuitKey)

                    throw CircuitBreakerError.circuitOpen(circuitName: circuitKey, lastFailureTime: circuitBreaker.lastOpenedTime)
                }

                // Execute the method with circuit breaker protection
                let startTime = CFAbsoluteTimeGetCurrent()
                var wasSuccessful = false
                var callError: Error?

                do {
                    let result = try validateConfiguration(config)
                    wasSuccessful = true

                    // Record successful call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let successfulCall = CircuitBreakerCall(
                        wasSuccessful: true,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(successfulCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: true)

                    return result
                } catch {
                    wasSuccessful = false
                    callError = error

                    // Record failed call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000

                    let failedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState,
                        error: error
                    )
                    CircuitBreakerRegistry.recordCall(failedCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: false)

                    // Re-throw the error
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Non-Throwing Method Tests

    func testNonThrowingMethodCircuitBreaker() throws {
        assertMacroExpansion(
            """
            @CircuitBreaker(failureThreshold: 3)
            func computeValue(input: Int) -> Int {
                return input * 2
            }
            """,
            expandedSource: """
            func computeValue(input: Int) -> Int {
                return input * 2
            }

            public func computeValueCircuitBreaker(input: Int) throws -> Int {
                let circuitKey = "\\(String(describing: type(of: self))).computeValue"

                // Get or create circuit breaker instance
                let circuitBreaker = CircuitBreakerRegistry.getCircuitBreaker(
                    for: circuitKey,
                    failureThreshold: 3,
                    timeout: 60.0,
                    successThreshold: 3,
                    monitoringWindow: 60.0
                )

                // Check if call should be allowed
                guard circuitBreaker.shouldAllowCall() else {
                    // Circuit is open, record blocked call and handle fallback
                    let blockedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: true,
                        responseTime: 0.0,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(blockedCall, for: circuitKey)

                    throw CircuitBreakerError.circuitOpen(circuitName: circuitKey, lastFailureTime: circuitBreaker.lastOpenedTime)
                }

                // Execute the method with circuit breaker protection
                let startTime = CFAbsoluteTimeGetCurrent()
                var wasSuccessful = false
                var callError: Error?

                do {
                    let result = computeValue(input: input)
                    wasSuccessful = true

                    // Record successful call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let successfulCall = CircuitBreakerCall(
                        wasSuccessful: true,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(successfulCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: true)

                    return result
                } catch {
                    wasSuccessful = false
                    callError = error

                    // Record failed call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000

                    let failedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState,
                        error: error
                    )
                    CircuitBreakerRegistry.recordCall(failedCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: false)

                    // Re-throw the error
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Void Return Type Tests

    func testVoidReturnTypeCircuitBreaker() throws {
        assertMacroExpansion(
            """
            @CircuitBreaker(failureThreshold: 2, fallbackValue: "NoOp")
            func performAction() throws {
                // Action implementation
            }
            """,
            expandedSource: """
            func performAction() throws {
                // Action implementation
            }

            public func performActionCircuitBreaker() throws {
                let circuitKey = "\\(String(describing: type(of: self))).performAction"

                // Get or create circuit breaker instance
                let circuitBreaker = CircuitBreakerRegistry.getCircuitBreaker(
                    for: circuitKey,
                    failureThreshold: 2,
                    timeout: 60.0,
                    successThreshold: 3,
                    monitoringWindow: 60.0
                )

                // Check if call should be allowed
                guard circuitBreaker.shouldAllowCall() else {
                    // Circuit is open, record blocked call and handle fallback
                    let blockedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: true,
                        responseTime: 0.0,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(blockedCall, for: circuitKey)

                    return // Circuit is open, no operation performed
                }

                // Execute the method with circuit breaker protection
                let startTime = CFAbsoluteTimeGetCurrent()
                var wasSuccessful = false
                var callError: Error?

                do {
                    let result = try performAction()
                    wasSuccessful = true

                    // Record successful call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let successfulCall = CircuitBreakerCall(
                        wasSuccessful: true,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(successfulCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: true)


                } catch {
                    wasSuccessful = false
                    callError = error

                    // Record failed call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000

                    let failedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState,
                        error: error
                    )
                    CircuitBreakerRegistry.recordCall(failedCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: false)

                    // Re-throw the error
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Error Cases

    func testCircuitBreakerOnNonFunction() throws {
        assertMacroExpansion(
            """
            @CircuitBreaker
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
                DiagnosticSpec(
                    message: "@CircuitBreaker can only be applied to functions and methods",
                    line: 1,
                    column: 1
                )
            ],
            macros: testMacros
        )
    }

    // MARK: - Complex Parameter Tests

    func testCircuitBreakerWithComplexParameters() throws {
        assertMacroExpansion(
            """
            @CircuitBreaker(failureThreshold: 3, timeout: 45.0)
            func processRequest(from url: URL, with headers: [String: String] = [:], timeout: TimeInterval = 30.0) async throws -> Response {
                return Response()
            }
            """,
            expandedSource: """
            func processRequest(from url: URL, with headers: [String: String] = [:], timeout: TimeInterval = 30.0) async throws -> Response {
                return Response()
            }

            public func processRequestCircuitBreaker(from url: URL, with headers: [String: String] = [:], timeout: TimeInterval = 30.0) async throws -> Response {
                let circuitKey = "\\(String(describing: type(of: self))).processRequest"

                // Get or create circuit breaker instance
                let circuitBreaker = CircuitBreakerRegistry.getCircuitBreaker(
                    for: circuitKey,
                    failureThreshold: 3,
                    timeout: 45.0,
                    successThreshold: 3,
                    monitoringWindow: 60.0
                )

                // Check if call should be allowed
                guard circuitBreaker.shouldAllowCall() else {
                    // Circuit is open, record blocked call and handle fallback
                    let blockedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: true,
                        responseTime: 0.0,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(blockedCall, for: circuitKey)

                    throw CircuitBreakerError.circuitOpen(circuitName: circuitKey, lastFailureTime: circuitBreaker.lastOpenedTime)
                }

                // Execute the method with circuit breaker protection
                let startTime = CFAbsoluteTimeGetCurrent()
                var wasSuccessful = false
                var callError: Error?

                do {
                    let result = try await processRequest(from: url, with: headers, timeout: timeout)
                    wasSuccessful = true

                    // Record successful call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let successfulCall = CircuitBreakerCall(
                        wasSuccessful: true,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(successfulCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: true)

                    return result
                } catch {
                    wasSuccessful = false
                    callError = error

                    // Record failed call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000

                    let failedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState,
                        error: error
                    )
                    CircuitBreakerRegistry.recordCall(failedCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: false)

                    // Re-throw the error
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
}
