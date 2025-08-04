// ErrorRecoveryTests.swift - Tests for error recovery and resilience scenarios
// Copyright © 2025 SwinJectMacros. All rights reserved.

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
@testable import SwinjectUtilityMacros
@testable import SwinjectUtilityMacrosImplementation
import XCTest

final class ErrorRecoveryTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "Injectable": InjectableMacro.self,
        "AutoFactory": AutoFactoryMacro.self,
        "LazyInject": LazyInjectMacro.self,
        "WeakInject": WeakInjectMacro.self,
        "Retry": RetryMacro.self,
        "CircuitBreaker": CircuitBreakerMacro.self,
        "Cache": CacheMacro.self,
        "TestContainer": TestContainerMacro.self
    ]

    // MARK: - Malformed Syntax Recovery

    func testInjectableWithMalformedInitializer() {
        assertMacroExpansion("""
        @Injectable
        class MalformedService {
            init( {
                // Malformed initializer
            }
        }
        """, expandedSource: """
        class MalformedService {
            init( {
                // Malformed initializer
            }
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @Injectable requires a class or struct with at least one initializer.

            ✅ Correct usage with dependencies:
            @Injectable
            class UserService {
                init(repository: UserRepository, logger: LoggerProtocol) {
                    // Dependency injection initializer
                }
            }

            ✅ Correct usage without dependencies:
            @Injectable
            class ConfigService {
                init() {
                    // Default initializer
                }
            }

            ❌ Invalid usage:
            @Injectable
            class BadService {
                // Missing initializer - add init() method
            }

            💡 Tip: Make your initializer public for better dependency injection control.
            """, line: 1, column: 1, severity: .error)
        ], macros: testMacros)
    }

    func testInjectableWithInvalidParameterTypes() {
        assertMacroExpansion("""
        @Injectable
        class InvalidParamService {
            init(param: ) {
                // Invalid parameter type
            }
        }
        """, expandedSource: """
        class InvalidParamService {
            init(param: ) {
                // Invalid parameter type
            }
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @Injectable requires a class or struct with at least one initializer.

            ✅ Correct usage with dependencies:
            @Injectable
            class UserService {
                init(repository: UserRepository, logger: LoggerProtocol) {
                    // Dependency injection initializer
                }
            }

            ✅ Correct usage without dependencies:
            @Injectable
            class ConfigService {
                init() {
                    // Default initializer
                }
            }

            ❌ Invalid usage:
            @Injectable
            class BadService {
                // Missing initializer - add init() method
            }

            💡 Tip: Make your initializer public for better dependency injection control.
            """, line: 1, column: 1, severity: .error)
        ], macros: testMacros)
    }

    func testInjectableWithGenericConstraintErrors() {
        assertMacroExpansion("""
        @Injectable
        class GenericService<T: NonExistentProtocol> {
            init(dependency: T) {
                // Generic with invalid constraint
            }
        }
        """, expandedSource: """
        class GenericService<T: NonExistentProtocol> {
            init(dependency: T) {
                // Generic with invalid constraint
            }

            static func register(in container: Container) {
                container.register(GenericService.self) { resolver in
                    GenericService(
                        dependency: resolver.resolve(T.self)!
                    )
                }.inObjectScope(.graph)
            }
        }

        extension GenericService: Injectable {
        }
        """, macros: testMacros)
        // Note: Should still generate code but compiler will catch constraint errors later
    }

    // MARK: - Runtime Error Recovery

    func testRetryMacroWithInvalidConfiguration() {
        assertMacroExpansion("""
        @Retry(maxAttempts: -5, timeout: "invalid")
        func invalidRetryConfig() throws {
            throw TestError.networkFailure
        }
        """, expandedSource: """
        func invalidRetryConfig() throws {
            throw TestError.networkFailure
        }

        public func invalidRetryConfigRetry() throws {
            let methodKey = "\\(String(describing: type(of: self))).invalidRetryConfig"
            var lastError: Error?
            var totalDelay: TimeInterval = 0.0

            // Handle invalid maxAttempts by using default
            let maxAttempts = max(-5, 1) // Ensure at least 1 attempt

            for attempt in 1...maxAttempts {
                do {
                    let result = invalidRetryConfig()

                    // Record successful call
                    RetryMetricsManager.recordResult(
                        for: methodKey,
                        succeeded: true,
                        attemptCount: attempt,
                        totalDelay: totalDelay
                    )

                } catch {
                    lastError = error

                    // Check if this is the last attempt
                    if attempt == maxAttempts {
                        // Record final failure
                        RetryMetricsManager.recordResult(
                            for: methodKey,
                            succeeded: false,
                            attemptCount: attempt,
                            totalDelay: totalDelay,
                            finalError: error
                        )
                        throw error
                    }

                    // Calculate backoff delay with safe defaults
                    let baseDelay = 1.0 * pow(2.0, Double(attempt - 1))
                    let cappedDelay = min(baseDelay, 60.0) // Cap at 60 seconds
                    let delay = cappedDelay

                    // Add to total delay tracking
                    totalDelay += delay

                    // Record retry attempt
                    let retryAttempt = RetryAttempt(
                        attemptNumber: attempt,
                        error: error,
                        delay: delay
                    )
                    RetryMetricsManager.recordAttempt(retryAttempt, for: methodKey)

                    // Wait before retry
                    if delay > 0 {
                        Thread.sleep(forTimeInterval: delay)
                    }
                }
            }

            // This should never be reached, but just in case
            throw lastError ?? RetryError.maxAttemptsExceeded(attempts: maxAttempts)
        }
        """, macros: testMacros)
    }

    func testCircuitBreakerWithInvalidThresholds() {
        assertMacroExpansion("""
        @CircuitBreaker(failureThreshold: -1, successThreshold: 0)
        func invalidCircuitConfig() throws -> String {
            return "success"
        }
        """, expandedSource: """
        func invalidCircuitConfig() throws -> String {
            return "success"
        }

        public func invalidCircuitConfigCircuitBreaker() throws -> String {
            let circuitKey = "\\(String(describing: type(of: self))).invalidCircuitConfig"

            // Get or create circuit breaker instance with safe defaults
            let circuitBreaker = CircuitBreakerRegistry.getCircuitBreaker(
                for: circuitKey,
                failureThreshold: max(-1, 1), // Ensure positive threshold
                timeout: 60.0,
                successThreshold: max(0, 1), // Ensure positive threshold
                monitoringWindow: 60.0
            )

            // Check if call should be allowed
            guard circuitBreaker.shouldAllowCall() else {
                // Circuit is open, record blocked call
                let blockedCall = CircuitBreakerCall(
                    wasSuccessful: false,
                    wasBlocked: true,
                    responseTime: 0.0,
                    circuitState: circuitBreaker.currentState
                )
                CircuitBreakerRegistry.recordCall(blockedCall, for: circuitKey)

                throw CircuitBreakerError.circuitOpen(circuitName: circuitKey)
            }

            // Execute the method with circuit breaker protection
            let startTime = CFAbsoluteTimeGetCurrent()
            var wasSuccessful = false
            var callError: Error?

            do {
                let result = invalidCircuitConfig()
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
        """, macros: testMacros)
    }

    // MARK: - Memory Management Edge Cases

    func testWeakInjectWithValueTypes() {
        assertMacroExpansion("""
        class TestService {
            @WeakInject var count: Int?
        }
        """, expandedSource: """
        class TestService {
            @WeakInject var count: Int?

            private weak var _countWeakBacking: Int?
            private var _countOnceToken: Bool = false
            private let _countOnceTokenLock = NSLock()

            private func _countWeakAccessor() -> Int? {
                func resolveWeakReference() {
                    // Register property for metrics tracking
                    let pendingInfo = WeakPropertyInfo(
                        propertyName: "count",
                        propertyType: "Int",
                        containerName: "default",
                        serviceName: nil,
                        autoResolve: true,
                        state: .pending,
                        initialResolutionTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    WeakInjectionMetrics.recordAccess(pendingInfo)

                    do {
                        // Resolve dependency as weak reference (will fail at runtime for value types)
                        if let resolved = Container.shared.resolve(Int.self) {
                            _countWeakBacking = resolved

                            // Record successful resolution
                            let resolvedInfo = WeakPropertyInfo(
                                propertyName: "count",
                                propertyType: "Int",
                                containerName: "default",
                                serviceName: nil,
                                autoResolve: true,
                                state: .resolved,
                                initialResolutionTime: Date(),
                                lastAccessTime: Date(),
                                resolutionCount: 1,
                                threadInfo: ThreadInfo()
                            )
                            WeakInjectionMetrics.recordAccess(resolvedInfo)
                        } else {
                            // Service not found - record failure
                            let error = WeakInjectionError.serviceNotRegistered(serviceName: nil, type: "Int")

                            let failedInfo = WeakPropertyInfo(
                                propertyName: "count",
                                propertyType: "Int",
                                containerName: "default",
                                serviceName: nil,
                                autoResolve: true,
                                state: .failed,
                                initialResolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            WeakInjectionMetrics.recordAccess(failedInfo)
                        }
                    } catch {
                        // Record failed resolution
                        let failedInfo = WeakPropertyInfo(
                            propertyName: "count",
                            propertyType: "Int",
                            containerName: "default",
                            serviceName: nil,
                            autoResolve: true,
                            state: .failed,
                            initialResolutionTime: Date(),
                            resolutionError: error,
                            threadInfo: ThreadInfo()
                        )
                        WeakInjectionMetrics.recordAccess(failedInfo)
                    }
                }

                // Auto-resolve if reference is nil and auto-resolve is enabled
                if _countWeakBacking == nil {
                    _countOnceTokenLock.lock()
                    if !_countOnceToken {
                        _countOnceToken = true
                        _countOnceTokenLock.unlock()
                        resolveWeakReference()
                    } else {
                        _countOnceTokenLock.unlock()
                    }
                }

                return _countWeakBacking
            }
        }
        """, macros: testMacros)
        // Note: This will generate code but fail at runtime - that's expected behavior
    }

    // MARK: - Container State Recovery

    func testLazyInjectWithMissingContainer() {
        assertMacroExpansion("""
        class TestService {
            @LazyInject var dependency: MissingDependency?
        }
        """, expandedSource: """
        class TestService {
            @LazyInject var dependency: MissingDependency?

            private var _dependencyBacking: MissingDependency?
            private var _dependencyOnceToken: Bool = false
            private let _dependencyOnceTokenLock = NSLock()

            var dependency: MissingDependency? {
                get {
                    _dependencyOnceTokenLock.lock()
                    if !_dependencyOnceToken {
                        _dependencyOnceToken = true
                        _dependencyOnceTokenLock.unlock()

                        // Register property for metrics tracking
                        let pendingInfo = LazyPropertyInfo(
                            propertyName: "dependency",
                            propertyType: "MissingDependency",
                            containerName: "default",
                            serviceName: nil,
                            isOptional: true,
                            state: .pending,
                            initialResolutionTime: Date(),
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordAccess(pendingInfo)

                        do {
                            _dependencyBacking = Container.shared.resolve(MissingDependency.self)

                            // Record resolution attempt
                            let resolvedInfo = LazyPropertyInfo(
                                propertyName: "dependency",
                                propertyType: "MissingDependency",
                                containerName: "default",
                                serviceName: nil,
                                isOptional: true,
                                state: _dependencyBacking != nil ? .resolved : .failed,
                                initialResolutionTime: Date(),
                                lastAccessTime: Date(),
                                resolutionCount: 1,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordAccess(resolvedInfo)
                        } catch {
                            // Record failed resolution
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "dependency",
                                propertyType: "MissingDependency",
                                containerName: "default",
                                serviceName: nil,
                                isOptional: true,
                                state: .failed,
                                initialResolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordAccess(failedInfo)
                        }
                    } else {
                        _dependencyOnceTokenLock.unlock()
                    }

                    return _dependencyBacking
                }
                set {
                    _dependencyOnceTokenLock.lock()
                    _dependencyBacking = newValue
                    _dependencyOnceToken = true
                    _dependencyOnceTokenLock.unlock()
                }
            }
        }
        """, macros: testMacros)
    }

    // MARK: - Thread Safety Edge Cases

    func testLazyInjectConcurrentAccess() {
        // This tests the generated code handles concurrent access
        assertMacroExpansion("""
        class ConcurrentService {
            @LazyInject var sharedResource: ExpensiveResource

            func accessConcurrently() async {
                // Multiple concurrent accesses should be thread-safe
                async let resource1 = sharedResource
                async let resource2 = sharedResource
                async let resource3 = sharedResource

                let (r1, r2, r3) = await (resource1, resource2, resource3)
                // All should be the same instance due to lazy loading
            }
        }
        """, expandedSource: """
        class ConcurrentService {
            @LazyInject var sharedResource: ExpensiveResource

            func accessConcurrently() async {
                // Multiple concurrent accesses should be thread-safe
                async let resource1 = sharedResource
                async let resource2 = sharedResource
                async let resource3 = sharedResource

                let (r1, r2, r3) = await (resource1, resource2, resource3)
                // All should be the same instance due to lazy loading
            }

            private var _sharedResourceBacking: ExpensiveResource?
            private var _sharedResourceOnceToken: Bool = false
            private let _sharedResourceOnceTokenLock = NSLock()

            var sharedResource: ExpensiveResource {
                get {
                    _sharedResourceOnceTokenLock.lock()
                    if !_sharedResourceOnceToken {
                        _sharedResourceOnceToken = true
                        _sharedResourceOnceTokenLock.unlock()

                        // Register property for metrics tracking
                        let pendingInfo = LazyPropertyInfo(
                            propertyName: "sharedResource",
                            propertyType: "ExpensiveResource",
                            containerName: "default",
                            serviceName: nil,
                            isOptional: false,
                            state: .pending,
                            initialResolutionTime: Date(),
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordAccess(pendingInfo)

                        do {
                            _sharedResourceBacking = Container.shared.resolve(ExpensiveResource.self)

                            // Record resolution attempt
                            let resolvedInfo = LazyPropertyInfo(
                                propertyName: "sharedResource",
                                propertyType: "ExpensiveResource",
                                containerName: "default",
                                serviceName: nil,
                                isOptional: false,
                                state: _sharedResourceBacking != nil ? .resolved : .failed,
                                initialResolutionTime: Date(),
                                lastAccessTime: Date(),
                                resolutionCount: 1,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordAccess(resolvedInfo)
                        } catch {
                            // Record failed resolution
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "sharedResource",
                                propertyType: "ExpensiveResource",
                                containerName: "default",
                                serviceName: nil,
                                isOptional: false,
                                state: .failed,
                                initialResolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordAccess(failedInfo)
                        }
                    } else {
                        _sharedResourceOnceTokenLock.unlock()
                    }

                    return _sharedResourceBacking!
                }
                set {
                    _sharedResourceOnceTokenLock.lock()
                    _sharedResourceBacking = newValue
                    _sharedResourceOnceToken = true
                    _sharedResourceOnceTokenLock.unlock()
                }
            }
        }
        """, macros: testMacros)
    }

    // MARK: - Cache Error Recovery

    func testCacheWithInvalidKeyGeneration() {
        assertMacroExpansion("""
        @Cache(keyGenerator: "invalidFunction")
        func cachedOperation(param1: String, param2: Int) -> String {
            return "result: \\(param1)-\\(param2)"
        }
        """, expandedSource: """
        func cachedOperation(param1: String, param2: Int) -> String {
            return "result: \\(param1)-\\(param2)"
        }

        public func cachedOperationCached(param1: String, param2: Int) -> String {
            let methodKey = "\\(String(describing: type(of: self))).cachedOperation"

            // Generate cache key with fallback to default if custom generator fails
            let cacheKey: String
            do {
                // Try custom key generator if available
                if let keyGenerator = invalidFunction as? (String, Int) -> String {
                    cacheKey = keyGenerator(param1, param2)
                } else {
                    // Fallback to default key generation
                    cacheKey = "\\(methodKey)_\\(param1)_\\(param2)"
                }
            } catch {
                // Fallback to default key generation on error
                cacheKey = "\\(methodKey)_\\(param1)_\\(param2)"
            }

            // Check cache first
            if let cachedResult = CacheManager.shared.get(key: cacheKey, type: String.self) {
                // Record cache hit
                CacheMetrics.recordHit(for: methodKey, key: cacheKey)
                return cachedResult
            }

            // Execute method and cache result
            let result = cachedOperation(param1: param1, param2: param2)

            // Store in cache with error handling
            do {
                CacheManager.shared.set(key: cacheKey, value: result, ttl: 300.0)
                CacheMetrics.recordMiss(for: methodKey, key: cacheKey)
            } catch {
                // Log cache storage error but don't fail the operation
                CacheMetrics.recordError(for: methodKey, key: cacheKey, error: error)
            }

            return result
        }
        """, macros: testMacros)
    }
}

// MARK: - Test Support Types
// Note: Common test types are now imported from TestUtilities.swift

// MARK: - Mock Implementations for Generated Code

// CircuitBreakerCall is imported from SwinjectUtilityMacros

// CircuitBreakerState is imported from SwinjectUtilityMacros

public enum CircuitBreakerError: Error {
    case circuitOpen(circuitName: String)
    case noFallbackAvailable(circuitName: String)
}

public class MockCircuitBreaker {
    public let currentState: CircuitBreakerState = .closed

    public init() {}

    public func shouldAllowCall() -> Bool {
        currentState != .open
    }

    public func recordCall(wasSuccessful: Bool) {
        // Mock implementation
    }
}

// CircuitBreakerRegistry is now imported from TestUtilities.swift

// LazyPropertyInfo is imported from SwinjectUtilityMacros
// LazyPropertyState is imported from SwinjectUtilityMacros

// WeakPropertyInfo is imported from SwinjectUtilityMacros

// WeakPropertyState is imported from SwinjectUtilityMacros as WeakReferenceState
// WeakInjectionError is imported from SwinjectUtilityMacros
// ThreadInfo is imported from SwinjectUtilityMacros
// LazyInjectionMetrics is imported from SwinjectUtilityMacros
// WeakInjectionMetrics is imported from SwinjectUtilityMacros

// CacheManager is now imported from TestUtilities.swift

class CacheMetrics {
    static func recordHit(for methodKey: String, key: String) {
        // Mock implementation
    }

    static func recordMiss(for methodKey: String, key: String) {
        // Mock implementation
    }

    static func recordError(for methodKey: String, key: String, error: Error) {
        // Mock implementation
    }
}
