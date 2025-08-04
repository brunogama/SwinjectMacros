// Retry.swift - Retry macro declarations and support types
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation

// MARK: - @Retry Macro

/// Automatically adds retry logic to methods with configurable backoff strategies and failure conditions.
///
/// This macro provides comprehensive retry capabilities including exponential backoff, linear backoff,
/// custom retry conditions, maximum attempts, and detailed retry metrics.
///
/// ## Basic Usage
///
/// ```swift
/// @Retry(maxAttempts: 3)
/// func fetchUserData(userId: String) throws -> UserData {
///     // Your business logic - retry logic is automatic
///     return try apiClient.fetchUser(userId)
/// }
/// ```
///
/// ## Advanced Usage with Exponential Backoff
///
/// ```swift
/// @Retry(
///     maxAttempts: 5,
///     backoffStrategy: .exponential(baseDelay: 1.0, multiplier: 2.0),
///     retryableErrors: [NetworkError.timeout, NetworkError.serverError],
///     jitter: true
/// )
/// func uploadFile(data: Data, path: String) async throws -> UploadResult {
///     return try await fileService.upload(data, to: path)
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **Retry Wrapper**: Creates a retry-enabled version of your method
/// 2. **Backoff Strategies**: Supports exponential, linear, and fixed delays
/// 3. **Error Filtering**: Only retries on specified error types or conditions
/// 4. **Jitter Support**: Adds randomization to prevent thundering herd
/// 5. **Retry Metrics**: Tracks attempt counts, delays, and success rates
/// 6. **Async Support**: Full support for async/await methods
///
/// ## Retry Strategies
///
/// The macro supports multiple backoff strategies:
///
/// ```swift
/// // Exponential backoff: 1s, 2s, 4s, 8s...
/// @Retry(backoffStrategy: .exponential(baseDelay: 1.0, multiplier: 2.0))
///
/// // Linear backoff: 1s, 2s, 3s, 4s...
/// @Retry(backoffStrategy: .linear(baseDelay: 1.0, increment: 1.0))
///
/// // Fixed delay: 2s, 2s, 2s, 2s...
/// @Retry(backoffStrategy: .fixed(delay: 2.0))
///
/// // Custom backoff with function
/// @Retry(backoffStrategy: .custom { attempt in
///     return Double(attempt) * 0.5 + randomJitter()
/// })
/// ```
///
/// ## Error Filtering
///
/// Control which errors trigger retries:
///
/// ```swift
/// // Retry only on specific error types
/// @Retry(retryableErrors: [NetworkError.timeout, DatabaseError.connectionLost])
///
/// // Retry based on custom condition
/// @Retry(retryCondition: { error in
///     if let httpError = error as? HTTPError {
///         return httpError.statusCode >= 500 // Only retry server errors
///     }
///     return false
/// })
/// ```
///
/// ## Integration with Metrics
///
/// ```swift
/// // Get retry statistics
/// let stats = RetryMetrics.getStats(for: "fetchUserData")
/// print("Success rate: \(stats.successRate)")
/// print("Average attempts: \(stats.averageAttempts)")
/// print("Total retries: \(stats.totalRetries)")
///
/// // Reset metrics
/// RetryMetrics.reset()
/// ```
///
/// ## Parameters:
/// - `maxAttempts`: Maximum number of retry attempts (default: 3)
/// - `backoffStrategy`: Delay strategy between retries (default: .exponential)
/// - `retryableErrors`: Array of error types that should trigger retries
/// - `retryCondition`: Custom function to determine if an error should trigger retry
/// - `jitter`: Add randomization to delays to prevent thundering herd (default: false)
/// - `maxDelay`: Maximum delay between attempts in seconds (default: 60.0)
/// - `timeout`: Overall timeout for all attempts in seconds (default: nil)
/// - `onRetry`: Callback executed before each retry attempt
///
/// ## Requirements:
/// - Can be applied to instance methods, static methods, and functions
/// - Method can be sync or async, throwing or non-throwing
/// - Non-throwing methods will be converted to throwing methods
/// - Thread-safe retry metrics collection
///
/// ## Generated Behavior:
/// 1. **Initial Attempt**: Executes the original method
/// 2. **Error Handling**: Catches errors and checks retry conditions
/// 3. **Backoff Calculation**: Calculates delay based on strategy and attempt number
/// 4. **Delay Execution**: Waits for calculated delay (with optional jitter)
/// 5. **Retry Attempt**: Re-executes the original method
/// 6. **Metrics Collection**: Records attempt counts and timing information
/// 7. **Final Failure**: Throws the last error if all attempts fail
///
/// ## Performance Considerations:
/// - **Minimal Overhead**: Only adds retry logic when errors occur
/// - **Memory Efficient**: Doesn't store large retry histories
/// - **Thread Safe**: Concurrent retry metrics without locks
/// - **Timeout Support**: Prevents infinite retry scenarios
///
/// ## Real-World Examples:
///
/// ```swift
/// class APIClient {
///     @Retry(
///         maxAttempts: 5,
///         backoffStrategy: .exponential(baseDelay: 0.5, multiplier: 2.0),
///         retryableErrors: [URLError.timedOut, URLError.networkConnectionLost],
///         jitter: true,
///         maxDelay: 30.0
///     )
///     func fetchData(from url: URL) async throws -> Data {
///         return try await URLSession.shared.data(from: url).0
///     }
///
///     @Retry(
///         maxAttempts: 3,
///         backoffStrategy: .linear(baseDelay: 1.0, increment: 0.5),
///         retryCondition: { error in
///             // Custom retry logic
///             if let httpError = error as? HTTPError {
///                 return httpError.statusCode >= 500
///             }
///             return error is TimeoutError
///         },
///         onRetry: { attempt, error, delay in
///             print("Retry attempt \(attempt) after error: \(error), waiting \(delay)s")
///         }
///     )
///     func uploadFile(_ data: Data) async throws -> String {
///         return try await performUpload(data)
///     }
/// }
/// ```
@attached(peer, names: suffixed(Retry))
public macro Retry(
    maxAttempts: Int = 3,
    backoffStrategy: BackoffStrategy = .exponential(baseDelay: 1.0, multiplier: 2.0),
    retryableErrors: [Error.Type] = [],
    retryCondition: ((Error) -> Bool)? = nil,
    jitter: Bool = false,
    maxDelay: TimeInterval = 60.0,
    timeout: TimeInterval? = nil,
    onRetry: ((Int, Error, TimeInterval) -> Void)? = nil
) = #externalMacro(module: "SwinjectUtilityMacrosImplementation", type: "RetryMacro")

// MARK: - Retry Support Types

/// Backoff strategies for retry delays.
public enum BackoffStrategy {
    /// Exponential backoff: delay = baseDelay * (multiplier ^ attempt)
    case exponential(baseDelay: TimeInterval, multiplier: Double)

    /// Linear backoff: delay = baseDelay + (increment * attempt)
    case linear(baseDelay: TimeInterval, increment: TimeInterval)

    /// Fixed delay between all attempts
    case fixed(delay: TimeInterval)

    /// Custom backoff strategy with user-defined function
    case custom((Int) -> TimeInterval)

    /// Calculate delay for a given attempt number
    public func calculateDelay(for attempt: Int, maxDelay: TimeInterval, jitter: Bool) -> TimeInterval {
        let baseDelay: TimeInterval = switch self {
        case let .exponential(base, multiplier):
            base * pow(multiplier, Double(attempt - 1))

        case let .linear(base, increment):
            base + (increment * Double(attempt - 1))

        case let .fixed(delay):
            delay

        case let .custom(calculator):
            calculator(attempt)
        }

        var finalDelay = min(baseDelay, maxDelay)

        // Add jitter if enabled (±25% of delay)
        if jitter {
            let jitterRange = finalDelay * 0.25
            let randomJitter = Double.random(in: -jitterRange...jitterRange)
            finalDelay = max(0, finalDelay + randomJitter)
        }

        return finalDelay
    }
}

/// Detailed metrics for retry operations.
public struct RetryMetrics {
    /// Method name being tracked
    public let methodName: String

    /// Total number of method calls
    public let totalCalls: Int

    /// Number of calls that succeeded without retry
    public let immediateSuccesses: Int

    /// Number of calls that succeeded after retries
    public let eventualSuccesses: Int

    /// Number of calls that failed after all retries
    public let totalFailures: Int

    /// Total number of retry attempts across all calls
    public let totalRetries: Int

    /// Average number of attempts per call
    public let averageAttempts: Double

    /// Success rate (0.0 to 1.0)
    public let successRate: Double

    /// Average delay time per retry (milliseconds)
    public let averageRetryDelay: TimeInterval

    /// Most common error types that trigger retries
    public let commonErrors: [String: Int]

    /// Time range covered by these metrics
    public let timeRange: DateInterval

    public init(
        methodName: String,
        totalCalls: Int,
        immediateSuccesses: Int,
        eventualSuccesses: Int,
        totalFailures: Int,
        totalRetries: Int,
        averageAttempts: Double,
        successRate: Double,
        averageRetryDelay: TimeInterval,
        commonErrors: [String: Int],
        timeRange: DateInterval
    ) {
        self.methodName = methodName
        self.totalCalls = totalCalls
        self.immediateSuccesses = immediateSuccesses
        self.eventualSuccesses = eventualSuccesses
        self.totalFailures = totalFailures
        self.totalRetries = totalRetries
        self.averageAttempts = averageAttempts
        self.successRate = successRate
        self.averageRetryDelay = averageRetryDelay
        self.commonErrors = commonErrors
        self.timeRange = timeRange
    }
}

/// Individual retry attempt information.
public struct RetryAttempt {
    /// Attempt number (1-based)
    public let attemptNumber: Int

    /// Error that triggered this retry
    public let error: Error

    /// Delay before this attempt (seconds)
    public let delay: TimeInterval

    /// Timestamp of this attempt
    public let timestamp: Date

    /// Thread information
    public let threadInfo: ThreadInfo

    public init(
        attemptNumber: Int,
        error: Error,
        delay: TimeInterval,
        timestamp: Date = Date(),
        threadInfo: ThreadInfo = ThreadInfo()
    ) {
        self.attemptNumber = attemptNumber
        self.error = error
        self.delay = delay
        self.timestamp = timestamp
        self.threadInfo = threadInfo
    }
}

// MARK: - Retry Metrics Manager

/// Central retry metrics tracking and reporting system.
public class RetryMetricsManager {
    private static var attemptHistory: [String: [RetryAttempt]] = [:]
    private static var callResults: [String: [CallResult]] = [:]
    private static let metricsQueue = DispatchQueue(label: "retry.metrics", attributes: .concurrent)
    private static let maxHistoryPerMethod = 1000 // Circular buffer size

    private struct CallResult {
        let succeeded: Bool
        let attemptCount: Int
        let totalDelay: TimeInterval
        let timestamp: Date
        let finalError: String?
    }

    /// Records a retry attempt
    public static func recordAttempt(_ attempt: RetryAttempt, for methodKey: String) {
        metricsQueue.async(flags: .barrier) {
            self.attemptHistory[methodKey, default: []].append(attempt)

            // Maintain circular buffer
            if self.attemptHistory[methodKey]!.count > self.maxHistoryPerMethod {
                self.attemptHistory[methodKey]!.removeFirst()
            }
        }
    }

    /// Records the final result of a method call
    public static func recordResult(
        for methodKey: String,
        succeeded: Bool,
        attemptCount: Int,
        totalDelay: TimeInterval,
        finalError: Error? = nil
    ) {
        metricsQueue.async(flags: .barrier) {
            let result = CallResult(
                succeeded: succeeded,
                attemptCount: attemptCount,
                totalDelay: totalDelay,
                timestamp: Date(),
                finalError: finalError?.localizedDescription
            )

            self.callResults[methodKey, default: []].append(result)

            // Maintain circular buffer
            if self.callResults[methodKey]!.count > self.maxHistoryPerMethod {
                self.callResults[methodKey]!.removeFirst()
            }
        }
    }

    /// Gets retry metrics for a specific method
    public static func getMetrics(for methodKey: String) -> RetryMetrics? {
        metricsQueue.sync {
            guard let results = callResults[methodKey], !results.isEmpty else {
                return nil
            }

            let attempts = self.attemptHistory[methodKey] ?? []

            let totalCalls = results.count
            let immediateSuccesses = results.filter { $0.succeeded && $0.attemptCount == 1 }.count
            let eventualSuccesses = results.filter { $0.succeeded && $0.attemptCount > 1 }.count
            let totalFailures = results.filter { !$0.succeeded }.count
            let totalRetries = results.map { $0.attemptCount - 1 }.reduce(0, +)

            let averageAttempts = Double(results.map { $0.attemptCount }.reduce(0, +)) / Double(totalCalls)
            let successRate = Double(immediateSuccesses + eventualSuccesses) / Double(totalCalls)
            let averageRetryDelay = attempts.isEmpty ? 0.0 : attempts.map { $0.delay }
                .reduce(0, +) / Double(attempts.count)

            // Calculate common errors
            let errorCounts = attempts.reduce(into: [String: Int]()) { counts, attempt in
                let errorType = String(describing: type(of: attempt.error))
                counts[errorType, default: 0] += 1
            }

            // Calculate time range
            let timestamps = results.map { $0.timestamp }
            let timeRange = DateInterval(
                start: timestamps.min() ?? Date(),
                end: timestamps.max() ?? Date()
            )

            return RetryMetrics(
                methodName: methodKey,
                totalCalls: totalCalls,
                immediateSuccesses: immediateSuccesses,
                eventualSuccesses: eventualSuccesses,
                totalFailures: totalFailures,
                totalRetries: totalRetries,
                averageAttempts: averageAttempts,
                successRate: successRate,
                averageRetryDelay: averageRetryDelay,
                commonErrors: errorCounts,
                timeRange: timeRange
            )
        }
    }

    /// Gets metrics for all tracked methods
    public static func getAllMetrics() -> [String: RetryMetrics] {
        metricsQueue.sync {
            var result: [String: RetryMetrics] = [:]

            for methodKey in self.callResults.keys {
                if let metrics = getMetrics(for: methodKey) {
                    result[methodKey] = metrics
                }
            }

            return result
        }
    }

    /// Prints a comprehensive retry report
    public static func printRetryReport() {
        let allMetrics = getAllMetrics()
        guard !allMetrics.isEmpty else {
            DebugLogger.info("📊 No retry data available")
            return
        }

        DebugLogger.info("\n🔄 Retry Report")
        DebugLogger.info(String(repeating: "=", count: 80))
        DebugLogger.info(String(
            format: "%-30s %8s %8s %8s %8s %8s",
            "Method",
            "Calls",
            "Success%",
            "AvgAttempts",
            "Retries",
            "AvgDelay"
        ))
        DebugLogger.info(String(repeating: "-", count: 80))

        for (methodKey, metrics) in allMetrics.sorted(by: { $0.value.totalRetries > $1.value.totalRetries }) {
            DebugLogger.info(String(
                format: "%-30s %8d %8.1f %8.1f %8d %8.1f",
                String(methodKey.suffix(30)),
                metrics.totalCalls,
                metrics.successRate * 100,
                metrics.averageAttempts,
                metrics.totalRetries,
                metrics.averageRetryDelay * 1000 // Convert to ms
            ))
        }

        DebugLogger.info(String(repeating: "-", count: 80))
        DebugLogger
            .info(
                "Legend: Success% = Success rate, AvgAttempts = Average attempts per call, AvgDelay = Average retry delay (ms)"
            )
    }

    /// Clears all retry metrics
    public static func reset() {
        metricsQueue.async(flags: .barrier) {
            self.attemptHistory.removeAll()
            self.callResults.removeAll()
        }
    }

    /// Gets methods with high failure rates
    public static func getProblematicMethods(threshold: Double = 0.5) -> [(String, RetryMetrics)] {
        let allMetrics = getAllMetrics()
        return allMetrics.compactMap { key, metrics in
            metrics.successRate < threshold ? (key, metrics) : nil
        }.sorted { $0.1.successRate < $1.1.successRate }
    }
}

// MARK: - Retry Error Types

/// Errors that can be thrown by retry logic
public enum RetryError: Error, LocalizedError {
    case maxAttemptsExceeded(attempts: Int)
    case timeoutExceeded(timeout: TimeInterval)
    case customConditionFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case let .maxAttemptsExceeded(attempts):
            "Maximum retry attempts exceeded (\(attempts) attempts)"
        case let .timeoutExceeded(timeout):
            "Retry timeout exceeded (\(timeout) seconds)"
        case let .customConditionFailed(reason):
            "Custom retry condition failed: \(reason)"
        }
    }
}

// MARK: - String Extension for Pretty Printing

// String * operator moved to StringExtensions.swift
