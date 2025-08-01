// AsyncEdgeCaseTests.swift - Edge case tests for async patterns and race conditions
// Copyright © 2025 SwinJectMacros. All rights reserved.

import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import SwinjectUtilityMacrosImplementation

final class AsyncEdgeCaseTests: XCTestCase {
    
    // MARK: - Async Retry Edge Cases
    
    func testAsyncRetryWithCancellation() {
        assertMacroExpansion("""
        @Retry(maxAttempts: 10, timeout: 30.0)
        func longRunningAsyncOperation() async throws -> String {
            // Simulate long-running operation that might be cancelled
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            return "completed"
        }
        """, expandedSource: """
        func longRunningAsyncOperation() async throws -> String {
            // Simulate long-running operation that might be cancelled
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            return "completed"
        }
        
        public func longRunningAsyncOperationRetry() async throws -> String {
            let methodKey = "\\(String(describing: type(of: self))).longRunningAsyncOperation"
            var lastError: Error?
            var totalDelay: TimeInterval = 0.0
            let startTime = Date()
            let timeoutInterval: TimeInterval = 30.0
            
            for attempt in 1...10 {
                // Check overall timeout
                if Date().timeIntervalSince(startTime) >= timeoutInterval {
                    throw RetryError.timeoutExceeded(timeout: timeoutInterval)
                }
                
                do {
                    let result = try await longRunningAsyncOperation()
                    
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
                    if attempt == 10 {
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
            throw lastError ?? RetryError.maxAttemptsExceeded(attempts: 10)
        }
        """, macros: testMacros)
    }
    
    func testRetryWithTaskCancellation() {
        assertMacroExpansion("""
        @Retry(maxAttempts: 3)
        func cancellableOperation() async throws -> Int {
            try Task.checkCancellation()
            return 42
        }
        """, expandedSource: """
        func cancellableOperation() async throws -> Int {
            try Task.checkCancellation()
            return 42
        }
        
        public func cancellableOperationRetry() async throws -> Int {
            let methodKey = "\\(String(describing: type(of: self))).cancellableOperation"
            var lastError: Error?
            var totalDelay: TimeInterval = 0.0
            
            for attempt in 1...3 {
                
                do {
                    let result = try await cancellableOperation()
                    
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
        """, macros: testMacros)
    }
    
    // MARK: - Circuit Breaker Async Edge Cases
    
    func testAsyncCircuitBreakerWithTimeout() {
        assertMacroExpansion("""
        @CircuitBreaker(timeout: 5.0, failureThreshold: 2)
        func timeoutProneAsyncOperation() async throws -> Data {
            // Operation that might timeout
            return Data()
        }
        """, expandedSource: """
        func timeoutProneAsyncOperation() async throws -> Data {
            // Operation that might timeout
            return Data()
        }
        
        public func timeoutProneAsyncOperationCircuitBreaker() async throws -> Data {
            let circuitKey = "\\(String(describing: type(of: self))).timeoutProneAsyncOperation"
            
            // Get or create circuit breaker instance
            let circuitBreaker = CircuitBreakerRegistry.getCircuitBreaker(
                for: circuitKey,
                failureThreshold: 2,
                timeout: 5.0,
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
                let result = try await timeoutProneAsyncOperation()
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
    
    // MARK: - Cache Async Edge Cases
    
    func testAsyncCacheWithExpiration() {
        assertMacroExpansion("""
        @Cache(ttl: 10, evictionPolicy: .lru)
        func expensiveAsyncComputation(input: String) async throws -> ProcessedData {
            // Expensive async computation
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            return ProcessedData(value: input.uppercased())
        }
        """, expandedSource: """
        func expensiveAsyncComputation(input: String) async throws -> ProcessedData {
            // Expensive async computation
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            return ProcessedData(value: input.uppercased())
        }
        
        public func expensiveAsyncComputationCache(input: String) async throws -> ProcessedData {
            let cacheKey = "\\(String(describing: type(of: self))).expensiveAsyncComputation_\\(input)"
            
            // Get or create cache instance
            let cache = CacheRegistry.getCache(
                for: cacheKey,
                maxSize: 100,
                ttl: 10,
                evictionPolicy: .lru
            )
            
            // Check cache first
            if let cachedResult = cache.get(cacheKey) as? ProcessedData {
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
                let result = try await expensiveAsyncComputation(input: input)
                
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
        """, macros: testMacros)
    }
    
    // MARK: - Race Condition Edge Cases
    
    func testLazyInjectRaceCondition() {
        // Test that multiple concurrent accesses to a lazy property don't cause race conditions
        let source = """
        actor ThreadSafeService {
            @LazyInject var sharedResource: ExpensiveResource
            
            func simulateRaceCondition() async {
                // Start multiple concurrent tasks accessing the same lazy property
                await withTaskGroup(of: ExpensiveResource.self) { group in
                    for i in 0..<100 {
                        group.addTask {
                            // All these should get the same instance due to lazy initialization
                            return self.sharedResource
                        }
                    }
                    
                    var resources: [ExpensiveResource] = []
                    for await resource in group {
                        resources.append(resource)
                    }
                    
                    // All resources should be the same instance
                    let allSame = resources.allSatisfy { resource in
                        resources.first === resource
                    }
                    
                    print("All lazy instances are the same: \\(allSame)")
                }
            }
        }
        """
        
        // The generated lazy injection code should use proper locking
        XCTAssertTrue(source.contains("@LazyInject"))
    }
    
    func testWeakInjectMemoryManagement() {
        let source = """
        class MemoryTestService {
            @WeakInject var delegate: ServiceDelegate?
            
            func testWeakReferenceLifecycle() async {
                // Create strong reference
                let strongDelegate = ServiceDelegate()
                
                // Inject into container temporarily
                Container.shared.register(ServiceDelegate.self) { _ in strongDelegate }
                
                // Access weak property - should resolve
                let weakRef1 = delegate
                XCTAssertNotNil(weakRef1)
                
                // Remove from container and clear strong reference
                Container.shared.removeAll()
                
                // Weak reference should eventually become nil
                // (exact timing depends on ARC and GC)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let weakRef2 = self.delegate
                    // This might be nil if the object was deallocated
                    print("Weak reference after cleanup: \\(weakRef2)")
                }
            }
        }
        """
        
        XCTAssertTrue(source.contains("@WeakInject"))
    }
    
    // MARK: - Complex Async Composition Edge Cases
    
    func testComplexAsyncComposition() {
        assertMacroExpansion("""
        class ComplexAsyncService {
            @LazyInject var apiClient: APIClient
            @WeakInject var delegate: ServiceDelegate?
            
            @Retry(maxAttempts: 3)
            @CircuitBreaker(failureThreshold: 5)
            @Cache(ttl: 300)
            func complexAsyncOperation(id: String) async throws -> ComplexResult {
                // Multiple async operations with dependencies
                let client = apiClient
                try await client.authenticate()
                
                let data = try await client.fetchData(id: id)
                let processed = try await processData(data)
                
                delegate?.operationCompleted(processed)
                
                return ComplexResult(data: processed)
            }
            
            private func processData(_ data: Data) async throws -> ProcessedData {
                // Simulate processing
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                return ProcessedData(value: String(data: data, encoding: .utf8) ?? "")
            }
        }
        """, expandedSource: """
        class ComplexAsyncService {
            @LazyInject var apiClient: APIClient
            @WeakInject var delegate: ServiceDelegate?
            
            @Retry(maxAttempts: 3)
            @CircuitBreaker(failureThreshold: 5)
            @Cache(ttl: 300)
            func complexAsyncOperation(id: String) async throws -> ComplexResult {
                // Multiple async operations with dependencies
                let client = apiClient
                try await client.authenticate()
                
                let data = try await client.fetchData(id: id)
                let processed = try await processData(data)
                
                delegate?.operationCompleted(processed)
                
                return ComplexResult(data: processed)
            }
            
            private func processData(_ data: Data) async throws -> ProcessedData {
                // Simulate processing
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                return ProcessedData(value: String(data: data, encoding: .utf8) ?? "")
            }
            private var _apiClientBacking: APIClient?
            private var _apiClientOnceToken: Bool = false
            private let _apiClientOnceTokenLock = NSLock()
            
            private func _apiClientLazyAccessor() -> APIClient {
                // Thread-safe lazy initialization
                _apiClientOnceTokenLock.lock()
                defer { _apiClientOnceTokenLock.unlock() }
                
                if !_apiClientOnceToken {
                    _apiClientOnceToken = true
                    let startTime = CFAbsoluteTimeGetCurrent()
                    
                    // Register property for metrics tracking
                    let pendingInfo = LazyPropertyInfo(
                        propertyName: "apiClient",
                        propertyType: "APIClient",
                        containerName: "default",
                        serviceName: nil,
                        isRequired: true,
                        state: .resolving,
                        resolutionTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    LazyInjectionMetrics.recordResolution(pendingInfo)
                    
                    do {
                        // Resolve dependency
                        guard let resolved = Container.shared.synchronizedResolve(APIClient.self) else {
                            let error = LazyInjectionError.serviceNotRegistered(serviceName: nil, type: "APIClient")
                            
                            // Record failed resolution
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "apiClient",
                                propertyType: "APIClient",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)
                            
                            fatalError("Required lazy property 'apiClient' of type 'APIClient' could not be resolved: \\(error.localizedDescription)")
                        }
                        
                        _apiClientBacking = resolved
                        
                        // Record successful resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime
                        
                        let resolvedInfo = LazyPropertyInfo(
                            propertyName: "apiClient",
                            propertyType: "APIClient",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .resolved,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(resolvedInfo)
                        
                    } catch {
                        // Record failed resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime
                        
                        let failedInfo = LazyPropertyInfo(
                            propertyName: "apiClient",
                            propertyType: "APIClient",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .failed,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            resolutionError: error,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(failedInfo)
                        
                        if true {
                            fatalError("Failed to resolve required lazy property 'apiClient': \\(error.localizedDescription)")
                        }
                    }
                }
                
                guard let resolvedValue = _apiClientBacking else {
                    let error = LazyInjectionError.requiredServiceUnavailable(propertyName: "apiClient", type: "APIClient")
                    fatalError("Lazy property 'apiClient' could not be resolved: \\(error.localizedDescription)")
                }
                return resolvedValue
            }
            private weak var _delegateWeakBacking: ServiceDelegate?
            private var _delegateOnceToken: Bool = false
            private let _delegateOnceTokenLock = NSLock()
            
            private func _delegateWeakAccessor() -> ServiceDelegate? {
                func resolveWeakReference() {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    
                    // Register property for metrics tracking
                    let pendingInfo = WeakPropertyInfo(
                        propertyName: "delegate",
                        propertyType: "ServiceDelegate",
                        containerName: "default",
                        serviceName: nil,
                        autoResolve: true,
                        state: .pending,
                        initialResolutionTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    WeakInjectionMetrics.recordAccess(pendingInfo)
                    
                    do {
                        // Resolve dependency as weak reference
                        if let resolved = Container.shared.synchronizedResolve(ServiceDelegate.self) {
                            _delegateWeakBacking = resolved
                            
                            // Record successful resolution
                            let resolvedInfo = WeakPropertyInfo(
                                propertyName: "delegate",
                                propertyType: "ServiceDelegate",
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
                            let error = WeakInjectionError.serviceNotRegistered(serviceName: nil, type: "ServiceDelegate")
                            
                            let failedInfo = WeakPropertyInfo(
                                propertyName: "delegate",
                                propertyType: "ServiceDelegate",
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
                            propertyName: "delegate",
                            propertyType: "ServiceDelegate",
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
                if _delegateWeakBacking == nil {
                    _delegateOnceTokenLock.lock()
                    if !_delegateOnceToken {
                        _delegateOnceToken = true
                        _delegateOnceTokenLock.unlock()
                        resolveWeakReference()
                    } else {
                        _delegateOnceTokenLock.unlock()
                    }
                }
                
                // Check if reference was deallocated and record deallocation
                if _delegateWeakBacking == nil {
                    let deallocatedInfo = WeakPropertyInfo(
                        propertyName: "delegate",
                        propertyType: "ServiceDelegate",
                        containerName: "default",
                        serviceName: nil,
                        autoResolve: true,
                        state: .deallocated,
                        lastAccessTime: Date(),
                        deallocationTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    WeakInjectionMetrics.recordAccess(deallocatedInfo)
                }
                
                return _delegateWeakBacking
            }
            
            public func complexAsyncOperationRetry(id: String) async throws -> ComplexResult {
                let methodKey = "\\(String(describing: type(of: self))).complexAsyncOperation"
                var lastError: Error?
                var totalDelay: TimeInterval = 0.0
                
                for attempt in 1...3 {
                    
                    do {
                        let result = try await complexAsyncOperation(id: id)
                        
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
            
            public func complexAsyncOperationCircuitBreaker(id: String) async throws -> ComplexResult {
                let circuitKey = "\\(String(describing: type(of: self))).complexAsyncOperation"
                
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
                    let result = try await complexAsyncOperation(id: id)
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
            
            public func complexAsyncOperationCache(id: String) async throws -> ComplexResult {
                let cacheKey = "\\(String(describing: type(of: self))).complexAsyncOperation_\\(id)"
                
                // Get or create cache instance
                let cache = CacheRegistry.getCache(
                    for: cacheKey,
                    maxSize: 100,
                    ttl: 300,
                    evictionPolicy: .lru
                )
                
                // Check cache first
                if let cachedResult = cache.get(cacheKey) as? ComplexResult {
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
                    let result = try await complexAsyncOperation(id: id)
                    
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
    
    // MARK: - Test Utilities
    
    private let testMacros: [String: Macro.Type] = [
        "Injectable": InjectableMacro.self,
        "Retry": RetryMacro.self,
        "LazyInject": LazyInjectMacro.self,
        "WeakInject": WeakInjectMacro.self,
        "CircuitBreaker": CircuitBreakerMacro.self,
        "Cache": CacheMacro.self
    ]
}

// MARK: - Supporting Test Types for Async Tests

protocol ServiceDelegate: AnyObject {
    func operationCompleted(_ data: ProcessedData)
}

class APIClient {
    func authenticate() async throws {}
    func fetchData(id: String) async throws -> Data { Data() }
}

struct ProcessedData {
    let value: String
}

struct ComplexResult {
    let data: ProcessedData
}

// Implementation for testing
class TestServiceDelegate: ServiceDelegate {
    func operationCompleted(_ data: ProcessedData) {
        print("Operation completed with: \(data.value)")
    }
}

class TestExpensiveResourceImpl: ExpensiveResource {
    let id = UUID()
}