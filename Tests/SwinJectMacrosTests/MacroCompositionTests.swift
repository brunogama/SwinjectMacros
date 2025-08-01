// MacroCompositionTests.swift - Tests for multiple macro composition scenarios

import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import SwinJectMacrosImplementation

final class MacroCompositionTests: XCTestCase {
    
    // MARK: - Multiple AOP Macros on Same Method
    
    func testRetryCircuitBreakerComposition() {
        assertMacroExpansion("""
        class CompositeService {
            @Retry(maxAttempts: 3)
            @CircuitBreaker(failureThreshold: 5)
            func complexNetworkCall() async throws -> NetworkData {
                return try await networkClient.fetchData()
            }
        }
        """, expandedSource: """
        class CompositeService {
            @Retry(maxAttempts: 3)
            @CircuitBreaker(failureThreshold: 5)
            func complexNetworkCall() async throws -> NetworkData {
                return try await networkClient.fetchData()
            }
            
            public func complexNetworkCallRetry() async throws -> NetworkData {
                let methodKey = "\\(String(describing: type(of: self))).complexNetworkCall"
                var lastError: Error?
                var totalDelay: TimeInterval = 0.0
                
                for attempt in 1...3 {
                    
                    do {
                        let result = try await complexNetworkCall()
                        
                        // Record successful call
                        RetryMetricsManager.recordResult(
                            for: methodKey,
                            succeeded: true,
                            attemptCount: attempt,
                            totalDelay: totalDelay
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
                                totalDelay: totalDelay,
                                finalError: error
                            )
                            throw error
                        }
                        
                        // Calculate backoff delay
                        let baseDelay = 1.0 * pow(2.0, Double(attempt - 1))
                        let cappedDelay = min(baseDelay, 60.0)
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
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                }
                
                // This should never be reached, but just in case
                throw lastError ?? RetryError.maxAttemptsExceeded(attempts: 3)
            }
            
            public func complexNetworkCallCircuitBreaker() async throws -> NetworkData {
                let circuitKey = "\\(String(describing: type(of: self))).complexNetworkCall"
                
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
                    let result = try await complexNetworkCall()
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
        }
        """, macros: testMacros)
    }
    
    func testTripleAOPComposition() {
        assertMacroExpansion("""
        class PowerService {
            @Retry(maxAttempts: 2)
            @CircuitBreaker(failureThreshold: 3)
            @Cache(ttl: 300)
            func expensiveComputation(_ input: String) async throws -> String {
                // Heavy computation
                return input.uppercased()
            }
        }
        """, expandedSource: """
        class PowerService {
            @Retry(maxAttempts: 2)
            @CircuitBreaker(failureThreshold: 3)
            @Cache(ttl: 300)
            func expensiveComputation(_ input: String) async throws -> String {
                // Heavy computation
                return input.uppercased()
            }
            
            public func expensiveComputationRetry(_ input: String) async throws -> String {
                let methodKey = "\\(String(describing: type(of: self))).expensiveComputation"
                var lastError: Error?
                var totalDelay: TimeInterval = 0.0
                
                for attempt in 1...2 {
                    
                    do {
                        let result = try await expensiveComputation(input)
                        
                        // Record successful call
                        RetryMetricsManager.recordResult(
                            for: methodKey,
                            succeeded: true,
                            attemptCount: attempt,
                            totalDelay: totalDelay
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
                                totalDelay: totalDelay,
                                finalError: error
                            )
                            throw error
                        }
                        
                        // Calculate backoff delay
                        let baseDelay = 1.0 * pow(2.0, Double(attempt - 1))
                        let cappedDelay = min(baseDelay, 60.0)
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
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                }
                
                // This should never be reached, but just in case
                throw lastError ?? RetryError.maxAttemptsExceeded(attempts: 2)
            }
            
            public func expensiveComputationCircuitBreaker(_ input: String) async throws -> String {
                let circuitKey = "\\(String(describing: type(of: self))).expensiveComputation"
                
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
                    let result = try await expensiveComputation(input)
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
            
            public func expensiveComputationCache(_ input: String) async throws -> String {
                let cacheKey = "\\(String(describing: type(of: self))).expensiveComputation_\\(input)"
                
                // Get or create cache instance
                let cache = CacheRegistry.getCache(
                    for: cacheKey,
                    maxSize: 100,
                    ttl: 300,
                    evictionPolicy: .lru
                )
                
                // Check cache first
                if let cachedResult = cache.get(cacheKey) as? String {
                    // Record cache hit
                    let cacheHit = CacheAccess(
                        key: cacheKey,
                        wasHit: true,
                        accessTime: Date(),
                        computationTime: 0.0
                    )
                    CacheRegistry.recordAccess(cacheHit, for: cacheKey)
                    
                    return cachedResult
                }
                
                // Cache miss - compute result
                let startTime = CFAbsoluteTimeGetCurrent()
                
                do {
                    let result = try await expensiveComputation(input)
                    
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let computationTime = (endTime - startTime) * 1000 // Convert to milliseconds
                    
                    // Store in cache
                    cache.set(cacheKey, value: result)
                    
                    // Record cache miss and computation
                    let cacheMiss = CacheAccess(
                        key: cacheKey,
                        wasHit: false,
                        accessTime: Date(),
                        computationTime: computationTime
                    )
                    CacheRegistry.recordAccess(cacheMiss, for: cacheKey)
                    
                    return result
                } catch {
                    // Record failed computation
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let computationTime = (endTime - startTime) * 1000
                    
                    let failedAccess = CacheAccess(
                        key: cacheKey,
                        wasHit: false,
                        accessTime: Date(),
                        computationTime: computationTime,
                        error: error
                    )
                    CacheRegistry.recordAccess(failedAccess, for: cacheKey)
                    
                    throw error
                }
            }
        }
        """, macros: testMacros)
    }
    
    // MARK: - Injectable + AOP Combination
    
    func testInjectableWithRetryMethod() {
        assertMacroExpansion("""
        @Injectable
        class RobustService {
            init(client: HTTPClient, logger: Logger) {
                self.client = client
                self.logger = logger
            }
            
            let client: HTTPClient
            let logger: Logger
            
            @Retry(maxAttempts: 5)
            func fetchData() async throws -> Data {
                return try await client.get("/data")
            }
        }
        """, expandedSource: """
        class RobustService {
            init(client: HTTPClient, logger: Logger) {
                self.client = client
                self.logger = logger
            }
            
            let client: HTTPClient
            let logger: Logger
            
            @Retry(maxAttempts: 5)
            func fetchData() async throws -> Data {
                return try await client.get("/data")
            }
            
            static func register(in container: Container) {
                container.register(RobustService.self) { resolver in
                    RobustService(
                        client: resolver.synchronizedResolve(HTTPClient.self)!,
                        logger: resolver.synchronizedResolve(Logger.self)!
                    )
                }.inObjectScope(.graph)
            }
            
            public func fetchDataRetry() async throws -> Data {
                let methodKey = "\\(String(describing: type(of: self))).fetchData"
                var lastError: Error?
                var totalDelay: TimeInterval = 0.0
                
                for attempt in 1...5 {
                    
                    do {
                        let result = try await fetchData()
                        
                        // Record successful call
                        RetryMetricsManager.recordResult(
                            for: methodKey,
                            succeeded: true,
                            attemptCount: attempt,
                            totalDelay: totalDelay
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
                                totalDelay: totalDelay,
                                finalError: error
                            )
                            throw error
                        }
                        
                        // Calculate backoff delay
                        let baseDelay = 1.0 * pow(2.0, Double(attempt - 1))
                        let cappedDelay = min(baseDelay, 60.0)
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
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                }
                
                // This should never be reached, but just in case
                throw lastError ?? RetryError.maxAttemptsExceeded(attempts: 5)
            }
        }

        extension RobustService: Injectable {
        }
        """, macros: testMacros)
    }
    
    // MARK: - Dependency Injection + Testing Macros
    
    func testInjectableWithSpyMethod() {
        assertMacroExpansion("""
        @Injectable
        class TestableService {
            init(dependency: TestDependency) {
                self.dependency = dependency
            }
            
            let dependency: TestDependency
            
            @Spy
            func processData(_ input: String) -> String {
                return dependency.transform(input)
            }
        }
        """, expandedSource: """
        class TestableService {
            init(dependency: TestDependency) {
                self.dependency = dependency
            }
            
            let dependency: TestDependency
            
            @Spy
            func processData(_ input: String) -> String {
                return dependency.transform(input)
            }
            
            static func register(in container: Container) {
                container.register(TestableService.self) { resolver in
                    TestableService(
                        dependency: resolver.synchronizedResolve(TestDependency.self)!
                    )
                }.inObjectScope(.graph)
            }
            
            struct ProcessDataSpyCall: SpyCall {
                let timestamp: Date
                let methodName: String
                let arguments: (String)
                let returnValue: String?
            }
            
            private var _processDataSpyCalls: [ProcessDataSpyCall] = []
            private let _processDataSpyLock = NSLock()
            var processDataSpyBehavior: ((String) -> String)?
            
            var processDataSpyCalls: [ProcessDataSpyCall] {
                _processDataSpyLock.lock()
                defer { _processDataSpyLock.unlock() }
                return _processDataSpyCalls
            }
            
            func resetProcessDataSpy() {
                _processDataSpyLock.lock()
                defer { _processDataSpyLock.unlock() }
                _processDataSpyCalls.removeAll()
            }
        }

        extension TestableService: Injectable {
        }
        """, macros: testMacros)
    }
    
    // MARK: - Test Utilities
    
    private let testMacros: [String: Macro.Type] = [
        "Injectable": InjectableMacro.self,
        "Retry": RetryMacro.self,
        "CircuitBreaker": CircuitBreakerMacro.self,
        "Cache": CacheMacro.self,
        "Spy": SpyMacro.self
    ]
}

// MARK: - Supporting Composition Test Types

struct NetworkData {
    let content: String
}

class HTTPClient {
    func get(_ path: String) async throws -> Data {
        return Data()
    }
}

class Logger {
    func log(_ message: String) {}
}

class TestDependency {
    func transform(_ input: String) -> String {
        return input.reversed().description
    }
}

// Mock infrastructure types (duplicated from other tests for completeness)
struct CompositionRetryError: Error {
    static func maxAttemptsExceeded(attempts: Int) -> CompositionRetryError {
        CompositionRetryError()
    }
}

struct CompositionRetryAttempt {
    let attemptNumber: Int
    let error: Error
    let delay: TimeInterval
}

enum CompositionCircuitBreakerError: Error {
    case circuitOpen(circuitName: String, lastFailureTime: Date?)
}

// Mock registries and managers
struct CompositionRetryMetricsManager {
    static func recordResult(for key: String, succeeded: Bool, attemptCount: Int, totalDelay: TimeInterval, finalError: Error? = nil) {}
    static func recordAttempt(_ attempt: CompositionRetryAttempt, for key: String) {}
}

struct CompositionCircuitBreakerRegistry {
    static func getCircuitBreaker(for key: String, failureThreshold: Int, timeout: TimeInterval, successThreshold: Int, monitoringWindow: TimeInterval) -> CompositionMockCircuitBreaker {
        return CompositionMockCircuitBreaker()
    }
    static func recordCall(_ call: CompositionCircuitBreakerCall, for key: String) {}
}

struct CompositionCacheRegistry {
    static func getCache(for key: String, maxSize: Int, ttl: TimeInterval, evictionPolicy: CompositionCacheEvictionPolicy) -> CompositionMockCache {
        return CompositionMockCache()
    }
    static func recordAccess(_ access: CompositionCacheAccess, for key: String) {}
}

// Supporting types for composition tests
struct CompositionCircuitBreakerCall {
    let wasSuccessful: Bool
    let wasBlocked: Bool
    let responseTime: TimeInterval
    let circuitState: String
    let error: Error?
    
    init(wasSuccessful: Bool, wasBlocked: Bool, responseTime: TimeInterval, circuitState: String, error: Error? = nil) {
        self.wasSuccessful = wasSuccessful
        self.wasBlocked = wasBlocked
        self.responseTime = responseTime
        self.circuitState = circuitState
        self.error = error
    }
}

struct CompositionCacheAccess {
    let key: String
    let wasHit: Bool
    let accessTime: Date
    let computationTime: TimeInterval
    let error: Error?
    
    init(key: String, wasHit: Bool, accessTime: Date, computationTime: TimeInterval, error: Error? = nil) {
        self.key = key
        self.wasHit = wasHit
        self.accessTime = accessTime
        self.computationTime = computationTime
        self.error = error
    }
}

enum CompositionCacheEvictionPolicy {
    case lru
}

struct CompositionMockCircuitBreaker {
    func shouldAllowCall() -> Bool { return true }
    let currentState = "closed"
    let lastOpenedTime: Date? = nil
    func recordCall(wasSuccessful: Bool) {}
}

struct CompositionMockCache {
    func get(_ key: String) -> Any? { return nil }
    func set(_ key: String, value: Any) {}
}

protocol SpyCallComposition {
    var timestamp: Date { get }
    var methodName: String { get }
}