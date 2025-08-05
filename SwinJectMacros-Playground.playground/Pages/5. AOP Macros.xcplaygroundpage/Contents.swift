//: [Previous: @TestContainer Macro](@previous)
//: # AOP (Aspect-Oriented Programming) Macros
//: ## Cross-Cutting Concerns with Interceptors
//:
//: AOP macros provide powerful capabilities for implementing cross-cutting concerns
//: like logging, performance tracking, caching, and retry logic without cluttering business code.

import Foundation
import Swinject

//: ## What is Aspect-Oriented Programming?
//:
//: AOP allows you to modularize cross-cutting concerns that span multiple classes:
//: - **Logging**: Method entry/exit, parameter values, results
//: - **Performance Tracking**: Execution time monitoring
//: - **Caching**: Result caching with configurable expiration
//: - **Retry Logic**: Automatic retry with backoff strategies
//: - **Circuit Breaker**: Fail-fast patterns for external dependencies
//: - **Security**: Authentication and authorization checks

// MARK: - Supporting Types and Protocols

struct User {
    let id: String
    let name: String
    let email: String
}

struct CacheKey: Hashable {
    let method: String
    let parameters: String
}

enum NetworkError: Error {
    case connectionFailed
    case timeout
    case serverError(Int)
}

protocol Interceptor {
    func intercept<T>(_ execution: () throws -> T) rethrows -> T
}

// MARK: - Built-in Interceptors

class LoggingInterceptor: Interceptor {
    private let methodName: String

    init(methodName: String) {
        self.methodName = methodName
    }

    func intercept<T>(_ execution: () throws -> T) rethrows -> T {
        let executionId = UUID().uuidString.prefix(8)

        print("🚀 [\(executionId)] Entering \(methodName)")
        let startTime = CFAbsoluteTimeGetCurrent()

        defer {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("✅ [\(executionId)] Completed \(methodName) in \(String(format: "%.2f", duration))ms")
        }

        do {
            let result = try execution()
            print("📤 [\(executionId)] Result: \(result)")
            return result
        } catch {
            print("❌ [\(executionId)] Error: \(error)")
            throw error
        }
    }
}

class PerformanceInterceptor: Interceptor {
    private let methodName: String
    private static var metrics: [String: [Double]] = [:]

    init(methodName: String) {
        self.methodName = methodName
    }

    func intercept<T>(_ execution: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()

        defer {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            PerformanceInterceptor.metrics[methodName, default: []].append(duration)

            if duration > 1000 { // Slow operation threshold
                print("⚠️ SLOW OPERATION: \(methodName) took \(String(format: "%.2f", duration))ms")
            }
        }

        return try execution()
    }

    static func getStats(for method: String) -> (avg: Double, min: Double, max: Double, count: Int)? {
        guard let times = metrics[method], !times.isEmpty else { return nil }

        return (
            avg: times.reduce(0, +) / Double(times.count),
            min: times.min() ?? 0,
            max: times.max() ?? 0,
            count: times.count
        )
    }

    static func printReport() {
        print("\n📊 Performance Report:")
        for (method, times) in metrics {
            let avg = times.reduce(0, +) / Double(times.count)
            print("  \(method): avg=\(String(format: "%.2f", avg))ms, calls=\(times.count)")
        }
    }
}

class CacheInterceptor: Interceptor {
    private let methodName: String
    private static var cache: [CacheKey: (value: Any, expiry: Date)] = [:]
    private let ttl: TimeInterval

    init(methodName: String, ttl: TimeInterval = 300) { // 5 minutes default
        self.methodName = methodName
        self.ttl = ttl
    }

    func intercept<T>(_ execution: () throws -> T) rethrows -> T {
        let cacheKey = CacheKey(method: methodName, parameters: "default") // Simplified

        // Check cache
        if let cached = Self.cache[cacheKey],
           cached.expiry > Date(),
           let cachedValue = cached.value as? T
        {
            print("💾 Cache hit for \(methodName)")
            return cachedValue
        }

        // Execute and cache result
        let result = try execution()
        let expiry = Date().addingTimeInterval(ttl)
        Self.cache[cacheKey] = (value: result, expiry: expiry)

        print("💾 Cached result for \(methodName)")
        return result
    }
}

class RetryInterceptor: Interceptor {
    private let methodName: String
    private let maxAttempts: Int
    private let baseDelay: TimeInterval

    init(methodName: String, maxAttempts: Int = 3, baseDelay: TimeInterval = 1.0) {
        self.methodName = methodName
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
    }

    func intercept<T>(_ execution: () throws -> T) rethrows -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                let result = try execution()
                if attempt > 1 {
                    print("✅ \(methodName) succeeded on attempt \(attempt)")
                }
                return result
            } catch {
                lastError = error

                if attempt < maxAttempts {
                    let delay = baseDelay * pow(2.0, Double(attempt - 1)) // Exponential backoff
                    print("🔄 \(methodName) failed on attempt \(attempt), retrying in \(delay)s...")
                    Thread.sleep(forTimeInterval: delay)
                } else {
                    print("❌ \(methodName) failed after \(maxAttempts) attempts")
                }
            }
        }

        throw lastError!
    }
}

//: ## @Interceptor Macro Examples

// What you write:
// @Interceptor(before: ["LoggingInterceptor"])
class UserService {
    func getUser(id: String) -> User {
        print("  → UserService.getUser executing...")
        Thread.sleep(forTimeInterval: 0.1) // Simulate work
        return User(id: id, name: "John Doe", email: "john@example.com")
    }

    // What the macro generates:
    func getUserIntercepted(id: String) -> User {
        let interceptor = LoggingInterceptor(methodName: "UserService.getUser")
        return interceptor.intercept {
            getUser(id: id)
        }
    }
}

//: ## @PerformanceTracked Macro

// What you write:
// @PerformanceTracked
class DataProcessor {
    func processLargeDataset() -> String {
        print("  → Processing large dataset...")
        Thread.sleep(forTimeInterval: 0.2) // Simulate heavy computation
        return "Processed 10,000 records"
    }

    func quickOperation() -> String {
        print("  → Quick operation...")
        Thread.sleep(forTimeInterval: 0.01) // Fast operation
        return "Quick result"
    }

    // What the macro generates:
    func processLargeDatasetTracked() -> String {
        let interceptor = PerformanceInterceptor(methodName: "DataProcessor.processLargeDataset")
        return interceptor.intercept {
            processLargeDataset()
        }
    }

    func quickOperationTracked() -> String {
        let interceptor = PerformanceInterceptor(methodName: "DataProcessor.quickOperation")
        return interceptor.intercept {
            quickOperation()
        }
    }
}

//: ## @Cache Macro

// What you write:
// @Cache(ttl: 600) // 10 minutes
class ExpensiveService {
    func expensiveCalculation() -> Double {
        print("  → Performing expensive calculation...")
        Thread.sleep(forTimeInterval: 0.5) // Simulate expensive operation
        return Double.random(in: 1...100)
    }

    // What the macro generates:
    func expensiveCalculationCached() -> Double {
        let interceptor = CacheInterceptor(methodName: "ExpensiveService.expensiveCalculation", ttl: 600)
        return interceptor.intercept {
            expensiveCalculation()
        }
    }
}

//: ## @Retry Macro

// What you write:
// @Retry(maxAttempts: 3, backoffStrategy: .exponential)
class NetworkService {
    private var attemptCount = 0

    func unreliableNetworkCall() throws -> String {
        attemptCount += 1
        print("  → Network call attempt \(attemptCount)...")

        // Simulate network failure for first 2 attempts
        if attemptCount <= 2 {
            throw NetworkError.connectionFailed
        }

        return "Network response: Success"
    }

    // What the macro generates:
    func unreliableNetworkCallWithRetry() throws -> String {
        let interceptor = RetryInterceptor(
            methodName: "NetworkService.unreliableNetworkCall",
            maxAttempts: 3,
            baseDelay: 1.0
        )
        return try interceptor.intercept {
            try unreliableNetworkCall()
        }
    }

    func resetAttempts() {
        attemptCount = 0
    }
}

//: ## Multiple Interceptors Chain

// What you write:
// @Interceptor(before: ["LoggingInterceptor", "PerformanceInterceptor"])
// @Cache(ttl: 300)
// @Retry(maxAttempts: 2)
class ComplexService {
    func complexOperation(input: String) throws -> String {
        print("  → ComplexService.complexOperation executing with: \(input)")

        // Simulate occasional failure
        if input == "fail" {
            throw NetworkError.serverError(500)
        }

        Thread.sleep(forTimeInterval: 0.15) // Simulate processing
        return "Processed: \(input.uppercased())"
    }

    // What the macro generates (conceptual - actual implementation would be more sophisticated):
    func complexOperationIntercepted(input: String) throws -> String {
        // Chain interceptors in order
        let loggingInterceptor = LoggingInterceptor(methodName: "ComplexService.complexOperation")
        let performanceInterceptor = PerformanceInterceptor(methodName: "ComplexService.complexOperation")
        let cacheInterceptor = CacheInterceptor(methodName: "ComplexService.complexOperation", ttl: 300)
        let retryInterceptor = RetryInterceptor(methodName: "ComplexService.complexOperation", maxAttempts: 2)

        return try loggingInterceptor.intercept {
            try performanceInterceptor.intercept {
                try cacheInterceptor.intercept {
                    try retryInterceptor.intercept {
                        try complexOperation(input: input)
                    }
                }
            }
        }
    }
}

//: ## Circuit Breaker Pattern

enum CircuitState {
    case closed // Normal operation
    case open // Failing, reject requests
    case halfOpen // Testing if service recovered
}

class CircuitBreakerInterceptor: Interceptor {
    private let methodName: String
    private let failureThreshold: Int
    private let timeout: TimeInterval

    private var state: CircuitState = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?

    init(methodName: String, failureThreshold: Int = 5, timeout: TimeInterval = 60) {
        self.methodName = methodName
        self.failureThreshold = failureThreshold
        self.timeout = timeout
    }

    func intercept<T>(_ execution: () throws -> T) rethrows -> T {
        switch state {
        case .open:
            // Check if timeout has passed
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > timeout
            {
                state = .halfOpen
                print("🔄 Circuit breaker half-open for \(methodName)")
            } else {
                print("⚡ Circuit breaker OPEN - rejecting call to \(methodName)")
                throw NetworkError.connectionFailed
            }

        case .halfOpen:
            // Try one request to see if service recovered
            break

        case .closed:
            // Normal operation
            break
        }

        do {
            let result = try execution()

            // Success - reset failure count and close circuit
            if state != .closed {
                print("✅ Circuit breaker reset for \(methodName)")
                state = .closed
                failureCount = 0
            }

            return result

        } catch {
            failureCount += 1
            lastFailureTime = Date()

            if failureCount >= failureThreshold {
                state = .open
                print("⚡ Circuit breaker OPENED for \(methodName) after \(failureCount) failures")
            }

            throw error
        }
    }
}

// What you write:
// @CircuitBreaker(failureThreshold: 3, timeout: 30)
class ExternalService {
    private var shouldFail = true

    func callExternalAPI() throws -> String {
        print("  → Calling external API...")

        if shouldFail {
            throw NetworkError.serverError(503)
        }

        return "External API response"
    }

    func makeReliable() {
        shouldFail = false
    }

    // What the macro generates:
    func callExternalAPIWithCircuitBreaker() throws -> String {
        let interceptor = CircuitBreakerInterceptor(
            methodName: "ExternalService.callExternalAPI",
            failureThreshold: 3,
            timeout: 30
        )
        return try interceptor.intercept {
            try callExternalAPI()
        }
    }
}

//: ## Testing AOP Macros

print("=== Testing AOP Macros ===")

// Test basic interceptor
let userService = UserService()
let user = userService.getUserIntercepted(id: "123")
print("Retrieved: \(user.name)\n")

// Test performance tracking
let processor = DataProcessor()
_ = processor.processLargeDatasetTracked()
_ = processor.quickOperationTracked()
_ = processor.processLargeDatasetTracked() // Call again

PerformanceInterceptor.printReport()

// Test caching
let expensiveService = ExpensiveService()
print("\nTesting cache:")
let result1 = expensiveService.expensiveCalculationCached()
let result2 = expensiveService.expensiveCalculationCached() // Should be cached
print("First result: \(result1)")
print("Second result: \(result2) (from cache)")

// Test retry logic
let networkService = NetworkService()
print("\nTesting retry:")
do {
    let result = try networkService.unreliableNetworkCallWithRetry()
    print("Network result: \(result)")
} catch {
    print("Network failed: \(error)")
}

// Test complex chained interceptors
let complexService = ComplexService()
print("\nTesting chained interceptors:")

do {
    let result1 = try complexService.complexOperationIntercepted(input: "hello")
    print("Result 1: \(result1)")

    let result2 = try complexService.complexOperationIntercepted(input: "hello") // Should be cached
    print("Result 2: \(result2)")

} catch {
    print("Complex operation failed: \(error)")
}

// Test circuit breaker
let externalService = ExternalService()
print("\nTesting circuit breaker:")

// Generate failures to open circuit
for i in 1...5 {
    do {
        _ = try externalService.callExternalAPIWithCircuitBreaker()
    } catch {
        print("Attempt \(i) failed: \(error)")
    }
}

// Circuit should be open now
do {
    _ = try externalService.callExternalAPIWithCircuitBreaker()
} catch {
    print("Circuit breaker prevented call: \(error)")
}

//: ## Key Benefits of AOP Macros
//:
//: 1. **Separation of Concerns**: Business logic separated from cross-cutting concerns
//: 2. **Code Reuse**: Interceptors can be applied to multiple methods
//: 3. **Composability**: Multiple interceptors can be chained together
//: 4. **Non-Intrusive**: Original method remains unchanged
//: 5. **Testability**: Can test business logic and concerns separately
//: 6. **Maintainability**: Changes to concerns don't affect business logic

//: ## Interceptor Chain Execution Order
//:
//: When multiple interceptors are applied:
//: 1. **Before interceptors** execute in order (outer to inner)
//: 2. **Original method** executes
//: 3. **After interceptors** execute in reverse order (inner to outer)
//: 4. **Error handlers** execute if exceptions occur

//: ## Best Practices
//:
//: - Use `@PerformanceTracked` for methods that might be slow
//: - Apply `@Cache` to expensive, pure functions
//: - Use `@Retry` for network calls and external dependencies
//: - Apply `@CircuitBreaker` to prevent cascade failures
//: - Chain interceptors thoughtfully - order matters
//: - Keep interceptors stateless when possible

print("\n✅ AOP Macros demonstration complete!")

//: [Next: Advanced Patterns](@next)
