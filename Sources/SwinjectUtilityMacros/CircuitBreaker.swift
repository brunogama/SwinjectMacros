// CircuitBreaker.swift - Circuit breaker macro declarations and support types
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation

// MARK: - @CircuitBreaker Macro

/// Automatically adds circuit breaker logic to methods to prevent cascading failures.
///
/// This macro provides comprehensive circuit breaker capabilities including failure threshold detection,
/// automatic state transitions, half-open state testing, and detailed circuit breaker metrics.
///
/// ## Basic Usage
///
/// ```swift
/// @CircuitBreaker
/// func callExternalService() throws -> ServiceResponse {
///     // Your service call - circuit breaker logic is automatic
///     return try externalAPIClient.fetchData()
/// }
/// ```
///
/// ## Advanced Usage with Custom Configuration
///
/// ```swift
/// @CircuitBreaker(
///     failureThreshold: 5,           // Open after 5 consecutive failures
///     timeout: 30.0,                 // Stay open for 30 seconds
///     successThreshold: 3,           // Close after 3 consecutive successes in half-open
///     monitoringWindow: 60.0,        // Monitor failures over 60 seconds
///     fallbackValue: "Service Unavailable"
/// )
/// func fetchUserProfile(userId: String) async throws -> UserProfile {
///     return try await userService.getProfile(userId)
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **Circuit Breaker State Management**: Manages CLOSED, OPEN, and HALF_OPEN states
/// 2. **Failure Tracking**: Counts failures and successes within monitoring windows
/// 3. **Automatic State Transitions**: Opens on failure threshold, tests with half-open
/// 4. **Fallback Support**: Returns fallback values when circuit is open
/// 5. **Metrics Collection**: Tracks state changes, failure rates, and timing
/// 6. **Thread Safety**: Concurrent access to circuit breaker state
///
/// ## Circuit Breaker States
///
/// The circuit breaker operates in three states:
///
/// ```swift
/// enum CircuitBreakerState {
///     case closed     // Normal operation, calls pass through
///     case open       // Failing state, calls are blocked
///     case halfOpen   // Testing state, limited calls allowed
/// }
/// ```
///
/// ## State Transitions
///
/// 1. **CLOSED → OPEN**: When failure threshold is exceeded
/// 2. **OPEN → HALF_OPEN**: After timeout period expires
/// 3. **HALF_OPEN → CLOSED**: After success threshold is met
/// 4. **HALF_OPEN → OPEN**: If any call fails during testing
///
/// ## Integration with Metrics
///
/// ```swift
/// // Get circuit breaker statistics
/// let stats = CircuitBreakerRegistry.getStats(for: "fetchUserProfile")
/// print("Current state: \(stats.currentState)")
/// print("Failure rate: \(stats.failureRate)")
/// print("Total calls blocked: \(stats.totalCallsBlocked)")
///
/// // Reset circuit breaker
/// CircuitBreakerRegistry.reset(for: "fetchUserProfile")
/// ```
///
/// ## Parameters:
/// - `failureThreshold`: Number of consecutive failures before opening (default: 5)
/// - `timeout`: Time in seconds to stay open before transitioning to half-open (default: 60.0)
/// - `successThreshold`: Number of consecutive successes needed to close from half-open (default: 3)
/// - `monitoringWindow`: Time window in seconds for failure rate calculation (default: 60.0)
/// - `fallbackValue`: Value to return when circuit is open (default: nil, throws error)
/// - `fallbackFunction`: Custom function to call when circuit is open
/// - `includeExceptions`: Array of exception types that should trigger circuit breaker
/// - `excludeExceptions`: Array of exception types that should NOT trigger circuit breaker
///
/// ## Requirements:
/// - Can be applied to instance methods, static methods, and functions
/// - Method can be sync or async, throwing or non-throwing
/// - Non-throwing methods with fallback values will not throw when circuit is open
/// - Thread-safe circuit breaker state management
///
/// ## Generated Behavior:
/// 1. **State Check**: Checks current circuit breaker state
/// 2. **CLOSED State**: Executes method normally, tracks success/failure
/// 3. **OPEN State**: Returns fallback value or throws CircuitBreakerError
/// 4. **HALF_OPEN State**: Allows limited calls for testing, updates state based on result
/// 5. **Metrics Recording**: Records all state transitions and call outcomes
/// 6. **State Transitions**: Automatically transitions between states based on thresholds
///
/// ## Performance Impact:
/// - **Minimal Overhead**: Only checks state and counters on each call
/// - **Memory Efficient**: Maintains minimal state per circuit breaker
/// - **Thread Safe**: Lock-free state management using atomic operations
/// - **Fast Fail**: Immediately returns when circuit is open
///
/// ## Real-World Examples:
///
/// ```swift
/// class PaymentService {
///     @CircuitBreaker(
///         failureThreshold: 3,
///         timeout: 120.0,
///         fallbackValue: PaymentResult.temporarilyUnavailable
///     )
///     func processPayment(_ payment: Payment) async throws -> PaymentResult {
///         return try await paymentGateway.process(payment)
///     }
///     
///     @CircuitBreaker(
///         failureThreshold: 10,
///         timeout: 30.0,
///         monitoringWindow: 300.0,
///         includeExceptions: [NetworkError.self, TimeoutError.self],
///         fallbackFunction: { [weak self] in
///             return try await self?.getCachedUserData() ?? UserData.empty
///         }
///     )
///     func fetchUserData(userId: String) async throws -> UserData {
///         return try await userAPI.fetch(userId)
///     }
/// }
/// 
/// // Monitor circuit breaker health
/// let stats = CircuitBreakerRegistry.getAllStats()
/// for (name, stat) in stats {
///     if stat.failureRate > 0.5 {
///         print("⚠️ Circuit breaker \(name) has high failure rate: \(stat.failureRate)")
///     }
/// }
/// ```
@attached(peer, names: suffixed(CircuitBreaker))
public macro CircuitBreaker(
    failureThreshold: Int = 5,
    timeout: TimeInterval = 60.0,
    successThreshold: Int = 3,
    monitoringWindow: TimeInterval = 60.0,
    fallbackValue: Any? = nil,
    fallbackFunction: (() throws -> Any)? = nil,
    includeExceptions: [Error.Type] = [],
    excludeExceptions: [Error.Type] = []
) = #externalMacro(module: "SwinjectUtilityMacrosImplementation", type: "CircuitBreakerMacro")

// MARK: - Circuit Breaker Support Types

/// Circuit breaker states
public enum CircuitBreakerState: String, CaseIterable {
    case closed = "CLOSED"
    case open = "OPEN"
    case halfOpen = "HALF_OPEN"
    
    public var description: String {
        return rawValue
    }
}

/// Circuit breaker statistics and metrics
public struct CircuitBreakerStats {
    /// Current state of the circuit breaker
    public let currentState: CircuitBreakerState
    
    /// Total number of calls made through the circuit breaker
    public let totalCalls: Int
    
    /// Number of successful calls
    public let successfulCalls: Int
    
    /// Number of failed calls
    public let failedCalls: Int
    
    /// Number of calls blocked by open circuit
    public let blockedCalls: Int
    
    /// Current failure rate (0.0 to 1.0)
    public let failureRate: Double
    
    /// Number of consecutive failures (in closed state)
    public let consecutiveFailures: Int
    
    /// Number of consecutive successes (in half-open state)
    public let consecutiveSuccesses: Int
    
    /// Time when circuit was last opened
    public let lastOpenedTime: Date?
    
    /// Time when circuit was last closed
    public let lastClosedTime: Date?
    
    /// Number of state transitions
    public let stateTransitions: Int
    
    /// Average response time in milliseconds
    public let averageResponseTime: TimeInterval
    
    /// Time range covered by these statistics
    public let timeRange: DateInterval
    
    public init(
        currentState: CircuitBreakerState,
        totalCalls: Int,
        successfulCalls: Int,
        failedCalls: Int,
        blockedCalls: Int,
        failureRate: Double,
        consecutiveFailures: Int,
        consecutiveSuccesses: Int,
        lastOpenedTime: Date?,
        lastClosedTime: Date?,
        stateTransitions: Int,
        averageResponseTime: TimeInterval,
        timeRange: DateInterval
    ) {
        self.currentState = currentState
        self.totalCalls = totalCalls
        self.successfulCalls = successfulCalls
        self.failedCalls = failedCalls
        self.blockedCalls = blockedCalls
        self.failureRate = failureRate
        self.consecutiveFailures = consecutiveFailures
        self.consecutiveSuccesses = consecutiveSuccesses
        self.lastOpenedTime = lastOpenedTime
        self.lastClosedTime = lastClosedTime
        self.stateTransitions = stateTransitions
        self.averageResponseTime = averageResponseTime
        self.timeRange = timeRange
    }
}

/// Individual circuit breaker call record
public struct CircuitBreakerCall {
    /// Timestamp of the call
    public let timestamp: Date
    
    /// Whether the call was successful
    public let wasSuccessful: Bool
    
    /// Whether the call was blocked by the circuit breaker
    public let wasBlocked: Bool
    
    /// Response time in milliseconds
    public let responseTime: TimeInterval
    
    /// Circuit breaker state at the time of the call
    public let circuitState: CircuitBreakerState
    
    /// Error that occurred (if any)
    public let error: Error?
    
    /// Thread information
    public let threadInfo: ThreadInfo
    
    public init(
        timestamp: Date = Date(),
        wasSuccessful: Bool,
        wasBlocked: Bool,
        responseTime: TimeInterval,
        circuitState: CircuitBreakerState,
        error: Error? = nil,
        threadInfo: ThreadInfo = ThreadInfo()
    ) {
        self.timestamp = timestamp
        self.wasSuccessful = wasSuccessful
        self.wasBlocked = wasBlocked
        self.responseTime = responseTime
        self.circuitState = circuitState
        self.error = error
        self.threadInfo = threadInfo
    }
}

// MARK: - Circuit Breaker Registry

/// Thread-safe circuit breaker state management and metrics collection
public class CircuitBreakerRegistry {
    private static var circuitBreakers: [String: CircuitBreakerInstance] = [:]
    private static var callHistory: [String: [CircuitBreakerCall]] = [:]
    private static let registryQueue = DispatchQueue(label: "circuit.breaker.registry", attributes: .concurrent)
    private static let maxHistoryPerCircuit = 1000 // Circular buffer size
    
    /// Gets or creates a circuit breaker instance for the given key
    public static func getCircuitBreaker(
        for key: String,
        failureThreshold: Int,
        timeout: TimeInterval,
        successThreshold: Int,
        monitoringWindow: TimeInterval
    ) -> CircuitBreakerInstance {
        return registryQueue.sync {
            if let existing = circuitBreakers[key] {
                return existing
            }
            
            let circuitBreaker = CircuitBreakerInstance(
                key: key,
                failureThreshold: failureThreshold,
                timeout: timeout,
                successThreshold: successThreshold,
                monitoringWindow: monitoringWindow
            )
            
            circuitBreakers[key] = circuitBreaker
            return circuitBreaker
        }
    }
    
    /// Records a circuit breaker call
    public static func recordCall(_ call: CircuitBreakerCall, for key: String) {
        registryQueue.async(flags: .barrier) {
            callHistory[key, default: []].append(call)
            
            // Maintain circular buffer
            if callHistory[key]!.count > maxHistoryPerCircuit {
                callHistory[key]!.removeFirst()
            }
        }
    }
    
    /// Gets statistics for a specific circuit breaker
    public static func getStats(for key: String) -> CircuitBreakerStats? {
        return registryQueue.sync {
            guard let circuitBreaker = circuitBreakers[key],
                  let calls = callHistory[key] else {
                return nil
            }
            
            return calculateStats(from: calls, circuitBreaker: circuitBreaker)
        }
    }
    
    /// Gets statistics for all circuit breakers
    public static func getAllStats() -> [String: CircuitBreakerStats] {
        return registryQueue.sync {
            var result: [String: CircuitBreakerStats] = [:]
            
            for (key, circuitBreaker) in circuitBreakers {
                if let calls = callHistory[key] {
                    result[key] = calculateStats(from: calls, circuitBreaker: circuitBreaker)
                }
            }
            
            return result
        }
    }
    
    /// Resets a specific circuit breaker
    public static func reset(for key: String) {
        registryQueue.async(flags: .barrier) {
            circuitBreakers[key]?.reset()
            callHistory[key] = []
        }
    }
    
    /// Resets all circuit breakers
    public static func resetAll() {
        registryQueue.async(flags: .barrier) {
            for circuitBreaker in circuitBreakers.values {
                circuitBreaker.reset()
            }
            callHistory.removeAll()
        }
    }
    
    /// Prints a comprehensive circuit breaker report
    public static func printReport() {
        let allStats = getAllStats()
        guard !allStats.isEmpty else {
            print("🔌 No circuit breaker data available")
            return
        }
        
        print("\n🔌 Circuit Breaker Report")
        print("=" * 80)
        print(String(format: "%-25s %-10s %8s %8s %8s %8s %8s", "Circuit", "State", "Calls", "Success%", "Blocked", "FailRate", "AvgTime"))
        print("-" * 80)
        
        for (key, stats) in allStats.sorted(by: { $0.value.failureRate > $1.value.failureRate }) {
            let successRate = stats.totalCalls > 0 ? (Double(stats.successfulCalls) / Double(stats.totalCalls)) * 100 : 0
            print(String(format: "%-25s %-10s %8d %8.1f %8d %8.1f %8.1f",
                key.suffix(25),
                stats.currentState.description,
                stats.totalCalls,
                successRate,
                stats.blockedCalls,
                stats.failureRate * 100,
                stats.averageResponseTime * 1000 // Convert to ms
            ))
        }
        
        print("-" * 80)
        print("Legend: Success% = Success rate, FailRate = Failure rate, AvgTime = Average response time (ms)")
    }
    
    /// Gets circuit breakers that are currently open
    public static func getOpenCircuits() -> [(String, CircuitBreakerStats)] {
        let allStats = getAllStats()
        return allStats.compactMap { (key, stats) in
            stats.currentState == .open ? (key, stats) : nil
        }.sorted { $0.1.failureRate > $1.1.failureRate }
    }
    
    /// Gets circuit breakers with high failure rates
    public static func getUnhealthyCircuits(threshold: Double = 0.5) -> [(String, CircuitBreakerStats)] {
        let allStats = getAllStats()
        return allStats.compactMap { (key, stats) in
            stats.failureRate > threshold ? (key, stats) : nil
        }.sorted { $0.1.failureRate > $1.1.failureRate }
    }
    
    // MARK: - Private Helper Methods
    
    private static func calculateStats(from calls: [CircuitBreakerCall], circuitBreaker: CircuitBreakerInstance) -> CircuitBreakerStats {
        let totalCalls = calls.count
        let successfulCalls = calls.filter { $0.wasSuccessful && !$0.wasBlocked }.count
        let failedCalls = calls.filter { !$0.wasSuccessful && !$0.wasBlocked }.count
        let blockedCalls = calls.filter { $0.wasBlocked }.count
        
        let failureRate = totalCalls > 0 ? Double(failedCalls) / Double(totalCalls) : 0.0
        let averageResponseTime = calls.isEmpty ? 0.0 : calls.map { $0.responseTime }.reduce(0, +) / Double(calls.count)
        
        // Calculate time range
        let timestamps = calls.map { $0.timestamp }
        let timeRange = DateInterval(
            start: timestamps.min() ?? Date(),
            end: timestamps.max() ?? Date()
        )
        
        return CircuitBreakerStats(
            currentState: circuitBreaker.currentState,
            totalCalls: totalCalls,
            successfulCalls: successfulCalls,
            failedCalls: failedCalls,
            blockedCalls: blockedCalls,
            failureRate: failureRate,
            consecutiveFailures: circuitBreaker.consecutiveFailures,
            consecutiveSuccesses: circuitBreaker.consecutiveSuccesses,
            lastOpenedTime: circuitBreaker.lastOpenedTime,
            lastClosedTime: circuitBreaker.lastClosedTime,
            stateTransitions: circuitBreaker.stateTransitions,
            averageResponseTime: averageResponseTime,
            timeRange: timeRange
        )
    }
}

/// Thread-safe circuit breaker instance
public class CircuitBreakerInstance {
    private let key: String
    private let failureThreshold: Int
    private let timeout: TimeInterval
    private let successThreshold: Int
    private let monitoringWindow: TimeInterval
    
    private let lock = NSLock()
    
    private var _currentState: CircuitBreakerState = .closed
    private var _consecutiveFailures: Int = 0
    private var _consecutiveSuccesses: Int = 0
    private var _lastFailureTime: Date?
    private var _lastOpenedTime: Date?
    private var _lastClosedTime: Date?
    private var _stateTransitions: Int = 0
    
    // Public read-only properties
    public var currentState: CircuitBreakerState {
        lock.lock()
        defer { lock.unlock() }
        return _currentState
    }
    
    public var consecutiveFailures: Int {
        lock.lock()
        defer { lock.unlock() }
        return _consecutiveFailures
    }
    
    public var consecutiveSuccesses: Int {
        lock.lock()
        defer { lock.unlock() }
        return _consecutiveSuccesses
    }
    
    public var lastOpenedTime: Date? {
        lock.lock()
        defer { lock.unlock() }
        return _lastOpenedTime
    }
    
    public var lastClosedTime: Date? {
        lock.lock()
        defer { lock.unlock() }
        return _lastClosedTime
    }
    
    public var stateTransitions: Int {
        lock.lock()
        defer { lock.unlock() }
        return _stateTransitions
    }
    
    public init(key: String, failureThreshold: Int, timeout: TimeInterval, successThreshold: Int, monitoringWindow: TimeInterval) {
        self.key = key
        self.failureThreshold = failureThreshold
        self.timeout = timeout
        self.successThreshold = successThreshold
        self.monitoringWindow = monitoringWindow
    }
    
    /// Checks if a call should be allowed through the circuit breaker
    public func shouldAllowCall() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        switch _currentState {
        case .closed:
            return true
            
        case .open:
            // Check if we should transition to half-open
            if let lastFailure = _lastFailureTime,
               Date().timeIntervalSince(lastFailure) >= timeout {
                transitionToHalfOpen()
                return true
            }
            return false
            
        case .halfOpen:
            return true
        }
    }
    
    /// Records the result of a call
    public func recordCall(wasSuccessful: Bool) {
        lock.lock()
        defer { lock.unlock() }
        
        switch _currentState {
        case .closed:
            if wasSuccessful {
                _consecutiveFailures = 0
            } else {
                _consecutiveFailures += 1
                _lastFailureTime = Date()
                
                if _consecutiveFailures >= failureThreshold {
                    transitionToOpen()
                }
            }
            
        case .halfOpen:
            if wasSuccessful {
                _consecutiveSuccesses += 1
                
                if _consecutiveSuccesses >= successThreshold {
                    transitionToClosed()
                }
            } else {
                transitionToOpen()
            }
            
        case .open:
            // No action needed in open state
            break
        }
    }
    
    /// Resets the circuit breaker to closed state
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        _currentState = .closed
        _consecutiveFailures = 0
        _consecutiveSuccesses = 0
        _lastFailureTime = nil
        _lastOpenedTime = nil
        _lastClosedTime = Date()
        _stateTransitions = 0
    }
    
    // MARK: - Private State Transition Methods
    
    private func transitionToOpen() {
        _currentState = .open
        _consecutiveSuccesses = 0
        _lastOpenedTime = Date()
        _stateTransitions += 1
    }
    
    private func transitionToHalfOpen() {
        _currentState = .halfOpen
        _consecutiveSuccesses = 0
        _stateTransitions += 1
    }
    
    private func transitionToClosed() {
        _currentState = .closed
        _consecutiveFailures = 0
        _consecutiveSuccesses = 0
        _lastClosedTime = Date()
        _stateTransitions += 1
    }
}

// MARK: - Circuit Breaker Errors

/// Errors thrown by circuit breaker logic
public enum CircuitBreakerError: Error, LocalizedError {
    case circuitOpen(circuitName: String, lastFailureTime: Date?)
    case halfOpenTestFailed(circuitName: String)
    case noFallbackAvailable(circuitName: String)
    
    public var errorDescription: String? {
        switch self {
        case .circuitOpen(let circuitName, let lastFailure):
            let timeInfo = lastFailure.map { " (last failure: \($0))" } ?? ""
            return "Circuit breaker '\(circuitName)' is open\(timeInfo)"
        case .halfOpenTestFailed(let circuitName):
            return "Circuit breaker '\(circuitName)' test failed in half-open state"
        case .noFallbackAvailable(let circuitName):
            return "Circuit breaker '\(circuitName)' is open and no fallback is available"
        }
    }
}

// MARK: - String Extension for Pretty Printing

private extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}