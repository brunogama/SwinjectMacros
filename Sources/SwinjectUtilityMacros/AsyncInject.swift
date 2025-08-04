// AsyncInject.swift - Async dependency injection macro declarations and support types
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import Swinject

// MARK: - @AsyncInject Macro

/// Automatically generates async dependency injection accessors for asynchronous dependency resolution.
///
/// This macro transforms properties into async-resolved dependencies, perfect for services that require
/// asynchronous initialization, network-based configuration, or complex startup sequences.
///
/// ## Basic Usage
///
/// ```swift
/// class DataService {
///     @AsyncInject var database: DatabaseProtocol
///     @AsyncInject var configService: ConfigurationService
///
///     func fetchData() async throws -> [DataModel] {
///         // Dependencies are resolved asynchronously on first access
///         let db = try await database
///         let config = try await configService
///
///         return try await db.query(config.defaultQuery)
///     }
/// }
/// ```
///
/// ## Advanced Usage with Custom Initialization
///
/// ```swift
/// class NetworkManager {
///     @AsyncInject("primary") var primaryAPI: APIClientProtocol
///     @AsyncInject(container: "network", timeout: 10.0) var authService: AuthServiceProtocol
///     @AsyncInject(initializationTimeout: 30.0) var cryptoService: CryptoServiceProtocol
///
///     func makeAuthenticatedRequest() async throws -> APIResponse {
///         // Async resolution with custom timeouts and initialization
///         async let api = try await primaryAPI
///         async let auth = try await authService
///         async let crypto = try await cryptoService
///
///         let (resolvedAPI, resolvedAuth, resolvedCrypto) = try await (api, auth, crypto)
///
///         let token = try await resolvedAuth.getToken()
///         let signature = try await resolvedCrypto.sign(token)
///
///         return try await resolvedAPI.request(token: token, signature: signature)
///     }
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **Async Storage**: Task-based async storage for dependency resolution
/// 2. **Concurrent Resolution**: Parallel resolution of multiple dependencies
/// 3. **Timeout Handling**: Configurable timeouts for async initialization
/// 4. **Error Propagation**: Proper async error handling and propagation
/// 5. **State Management**: Thread-safe async state tracking
/// 6. **Cancellation Support**: Cooperative cancellation for long-running resolutions
///
/// ## Async Resolution Benefits
///
/// The macro provides several advantages for async-heavy applications:
///
/// ```swift
/// // Synchronous injection - blocks on complex initialization
/// @Injectable var syncService: ExpensiveService // Blocks thread during init
///
/// // Async injection - non-blocking resolution
/// @AsyncInject var asyncService: ExpensiveService // Async resolution with await
/// ```
///
/// **Performance Benefits:**
/// - **Non-Blocking**: Doesn't block threads during complex initialization
/// - **Concurrent Resolution**: Multiple dependencies resolved in parallel
/// - **Timeout Control**: Prevents hanging on slow-initializing services
/// - **Memory Efficient**: Lazy async resolution reduces startup memory pressure
///
/// ## Container Integration
///
/// Works with async-capable containers and initialization patterns:
///
/// ```swift
/// // Default async container resolution
/// @AsyncInject var service: ServiceProtocol
///
/// // Named async service resolution
/// @AsyncInject("background") var backgroundService: BackgroundServiceProtocol
///
/// // Custom container with timeout
/// @AsyncInject(container: "async-pool", timeout: 15.0) var pooledService: PooledServiceProtocol
/// ```
///
/// ## Concurrency and Task Management
///
/// Handles Swift concurrency patterns and actor isolation:
///
/// ```swift
/// actor DataProcessor {
///     @AsyncInject var databasePool: DatabasePoolProtocol
///     @AsyncInject var cacheManager: CacheManagerProtocol
///
///     func processData(_ data: [DataItem]) async throws -> [ProcessedData] {
///         // Async resolution within actor context
///         async let db = try await databasePool
///         async let cache = try await cacheManager
///
///         let (database, cacheSystem) = try await (db, cache)
///
///         // Concurrent processing with resolved dependencies
///         return try await withTaskGroup(of: ProcessedData.self) { group in
///             for item in data {
///                 group.addTask {
///                     try await self.processItem(item, database: database, cache: cacheSystem)
///                 }
///             }
///
///             var results: [ProcessedData] = []
///             for try await result in group {
///                 results.append(result)
///             }
///             return results
///         }
///     }
/// }
/// ```
///
/// ## Integration with Metrics
///
/// ```swift
/// // Get async injection statistics
/// let stats = AsyncInjectionMetrics.getStats()
/// print("Total async properties: \\(stats.totalAsyncProperties)")
/// print("Resolved properties: \\(stats.resolvedProperties)")
/// print("Average resolution time: \\(stats.averageResolutionTime)ms")
/// print("Timeout failures: \\(stats.timeoutFailures)")
///
/// // Track async resolution performance
/// AsyncInjectionMetrics.printAsyncResolutionReport()
/// ```
///
/// ## Parameters:
/// - `name`: Optional service name for named registration lookup
/// - `container`: Container identifier for multi-container scenarios
/// - `timeout`: Maximum time to wait for async resolution (default: 30.0 seconds)
/// - `initializationTimeout`: Timeout for service initialization (default: 60.0 seconds)
/// - `retryCount`: Number of resolution retry attempts (default: 3)
/// - `onResolution`: Callback executed after successful async resolution
/// - `fallback`: Async fallback service provider for resolution failures
///
/// ## Requirements:
/// - Property must have an explicit type annotation
/// - Type should support async initialization or be registered in async-capable container
/// - Can be applied to stored properties in classes, structs, and actors
/// - Requires Swift 5.5+ for async/await support
///
/// ## Generated Behavior:
/// 1. **Property Access**: Returns a Task that resolves the dependency asynchronously
/// 2. **Async Resolution**: Queries container and initializes service asynchronously
/// 3. **Caching**: Caches resolved Task to prevent duplicate resolutions
/// 4. **Timeout Handling**: Cancels resolution if timeout is exceeded
/// 5. **Error Handling**: Propagates async errors with proper context
/// 6. **Metrics Collection**: Records async resolution timing and success rates
///
/// ## Performance Characteristics:
/// - **First Access**: Async container resolution (~10-100ms depending on service)
/// - **Subsequent Access**: Cached Task access (~1-10ns)
/// - **Memory Overhead**: One Task storage per async dependency
/// - **Concurrency Safe**: Thread-safe async resolution with proper isolation
///
/// ## Real-World Examples:
///
/// ```swift
/// class ApplicationBootstrap {
///     @AsyncInject var configurationService: ConfigurationService
///     @AsyncInject("database") var primaryDatabase: DatabaseService
///     @AsyncInject(container: "external", timeout: 20.0) var externalAPIClient: ExternalAPIClient
///     @AsyncInject(initializationTimeout: 45.0) var mlModelService: MLModelService
///
///     func initializeApplication() async throws {
///         // Concurrent initialization of all async dependencies
///         async let config = try await configurationService
///         async let database = try await primaryDatabase
///         async let apiClient = try await externalAPIClient
///         async let mlModel = try await mlModelService
///
///         let (cfg, db, api, ml) = try await (config, database, apiClient, mlModel)
///
///         // Configure services based on resolved dependencies
///         try await db.configure(with: cfg.databaseConfig)
///         try await api.authenticate(with: cfg.apiCredentials)
///         try await ml.loadModel(cfg.modelPath)
///
///         print("Application fully initialized with async dependencies")
///     }
/// }
///
/// class StreamingService {
///     @AsyncInject var mediaEncoder: MediaEncoderProtocol
///     @AsyncInject("gpu") var gpuAccelerator: GPUAcceleratorProtocol?
///     @AsyncInject(container: "streaming") var streamManager: StreamManagerProtocol
///
///     func startStream(input: MediaInput) async throws -> StreamHandle {
///         // Parallel resolution of streaming dependencies
///         async let encoder = try await mediaEncoder
///         async let gpu = try await gpuAccelerator
///         async let manager = try await streamManager
///
///         let (resolvedEncoder, resolvedGPU, resolvedManager) = try await (encoder, gpu, manager)
///
///         // Configure encoding pipeline
///         if let gpuAccel = resolvedGPU {
///             try await resolvedEncoder.enableGPUAcceleration(gpuAccel)
///         }
///
///         // Start streaming with fully configured dependencies
///         return try await resolvedManager.createStream(
///             input: input,
///             encoder: resolvedEncoder
///         )
///     }
/// }
///
/// // Monitor async injection performance
/// AsyncInjectionMetrics.printAsyncResolutionReport()
/// // Output:
/// // 🔄 Async Injection Report
/// // ==========================================
/// // Property              Resolved  AvgTime  Timeouts  Status
/// // configurationService  true      125ms    0         Success
/// // primaryDatabase       true      340ms    0         Success
/// // externalAPIClient     true      2.1s     1         Success
/// // mlModelService        true      8.7s     0         Success
/// // mediaEncoder          true      45ms     0         Success
/// // gpuAccelerator        false     -        2         Failed
/// // streamManager         true      78ms     0         Success
/// ```
@attached(peer, names: arbitrary)
public macro AsyncInject(
    _ name: String? = nil,
    container: String = "default",
    timeout: TimeInterval = 30.0,
    initializationTimeout: TimeInterval = 60.0,
    retryCount: Int = 3,
    onResolution: ((Any) async -> Void)? = nil,
    fallback: (() async throws -> Any?)? = nil
) = #externalMacro(module: "SwinjectUtilityMacrosImplementation", type: "AsyncInjectMacro")

// MARK: - Async Injection Support Types

/// Async resolution states for tracking lifecycle
public enum AsyncResolutionState: String, CaseIterable {
    case pending = "PENDING" // Not yet started resolution
    case resolving = "RESOLVING" // Currently resolving asynchronously
    case resolved = "RESOLVED" // Successfully resolved
    case failed = "FAILED" // Resolution failed
    case timedOut = "TIMED_OUT" // Resolution timed out
    case cancelled = "CANCELLED" // Resolution was cancelled

    public var description: String {
        rawValue
    }
}

/// Individual async property resolution information
public struct AsyncPropertyInfo {
    /// Property name
    public let propertyName: String

    /// Property type
    public let propertyType: String

    /// Container name used for resolution
    public let containerName: String

    /// Service name (if named injection)
    public let serviceName: String?

    /// Timeout configuration
    public let timeout: TimeInterval

    /// Initialization timeout
    public let initializationTimeout: TimeInterval

    /// Retry count configuration
    public let retryCount: Int

    /// Current async resolution state
    public let state: AsyncResolutionState

    /// When resolution was started
    public let resolutionStartTime: Date?

    /// When resolution completed (success or failure)
    public let resolutionEndTime: Date?

    /// Time taken for resolution (milliseconds)
    public let resolutionDuration: TimeInterval?

    /// Number of retry attempts made
    public let attemptCount: Int

    /// Error encountered during resolution
    public let resolutionError: Error?

    /// Task information
    public let taskInfo: TaskInfo?

    public init(
        propertyName: String,
        propertyType: String,
        containerName: String,
        serviceName: String? = nil,
        timeout: TimeInterval = 30.0,
        initializationTimeout: TimeInterval = 60.0,
        retryCount: Int = 3,
        state: AsyncResolutionState = .pending,
        resolutionStartTime: Date? = nil,
        resolutionEndTime: Date? = nil,
        resolutionDuration: TimeInterval? = nil,
        attemptCount: Int = 0,
        resolutionError: Error? = nil,
        taskInfo: TaskInfo? = nil
    ) {
        self.propertyName = propertyName
        self.propertyType = propertyType
        self.containerName = containerName
        self.serviceName = serviceName
        self.timeout = timeout
        self.initializationTimeout = initializationTimeout
        self.retryCount = retryCount
        self.state = state
        self.resolutionStartTime = resolutionStartTime
        self.resolutionEndTime = resolutionEndTime
        self.resolutionDuration = resolutionDuration
        self.attemptCount = attemptCount
        self.resolutionError = resolutionError
        self.taskInfo = taskInfo
    }
}

/// Task information for async tracking
public struct TaskInfo {
    /// Task priority
    public let priority: TaskPriority?

    /// Whether task is cancelled
    public let isCancelled: Bool

    /// Task creation time
    public let creationTime: Date

    public init(priority: TaskPriority? = nil, isCancelled: Bool = false, creationTime: Date = Date()) {
        self.priority = priority
        self.isCancelled = isCancelled
        self.creationTime = creationTime
    }
}

/// Comprehensive async injection metrics
public struct AsyncInjectionStats {
    /// Total number of async properties registered
    public let totalAsyncProperties: Int

    /// Number of properties that have been resolved successfully
    public let resolvedProperties: Int

    /// Number of properties currently resolving
    public let resolvingProperties: Int

    /// Number of properties that failed to resolve
    public let failedProperties: Int

    /// Number of properties that timed out
    public let timedOutProperties: Int

    /// Number of properties that were cancelled
    public let cancelledProperties: Int

    /// Average time for successful resolutions (milliseconds)
    public let averageResolutionTime: TimeInterval

    /// Total time spent on all resolutions (milliseconds)
    public let totalResolutionTime: TimeInterval

    /// Average number of retry attempts per property
    public let averageRetryAttempts: Double

    /// Properties by resolution state
    public let propertiesByState: [AsyncResolutionState: Int]

    /// Container usage statistics
    public let containerUsage: [String: Int]

    /// Timeout configuration statistics
    public let timeoutDistribution: [TimeInterval: Int]

    /// Most common resolution errors
    public let commonErrors: [String: Int]

    /// Time range covered by these statistics
    public let timeRange: DateInterval

    public init(
        totalAsyncProperties: Int,
        resolvedProperties: Int,
        resolvingProperties: Int,
        failedProperties: Int,
        timedOutProperties: Int,
        cancelledProperties: Int,
        averageResolutionTime: TimeInterval,
        totalResolutionTime: TimeInterval,
        averageRetryAttempts: Double,
        propertiesByState: [AsyncResolutionState: Int],
        containerUsage: [String: Int],
        timeoutDistribution: [TimeInterval: Int],
        commonErrors: [String: Int],
        timeRange: DateInterval
    ) {
        self.totalAsyncProperties = totalAsyncProperties
        self.resolvedProperties = resolvedProperties
        self.resolvingProperties = resolvingProperties
        self.failedProperties = failedProperties
        self.timedOutProperties = timedOutProperties
        self.cancelledProperties = cancelledProperties
        self.averageResolutionTime = averageResolutionTime
        self.totalResolutionTime = totalResolutionTime
        self.averageRetryAttempts = averageRetryAttempts
        self.propertiesByState = propertiesByState
        self.containerUsage = containerUsage
        self.timeoutDistribution = timeoutDistribution
        self.commonErrors = commonErrors
        self.timeRange = timeRange
    }
}

// MARK: - Async Injection Metrics Manager

/// Thread-safe async injection metrics tracking and reporting
public class AsyncInjectionMetrics {
    private static var propertyRegistry: [String: AsyncPropertyInfo] = [:]
    private static var resolutionHistory: [String: [AsyncPropertyInfo]] = [:]
    private static let metricsQueue = DispatchQueue(label: "async.injection.metrics", attributes: .concurrent)
    private static let maxHistoryPerProperty = 100 // Circular buffer size

    /// Registers an async property for tracking
    public static func registerProperty(_ info: AsyncPropertyInfo) {
        metricsQueue.async(flags: .barrier) {
            let key = "\(info.propertyName):\(info.propertyType)"
            self.propertyRegistry[key] = info
        }
    }

    /// Records an async resolution state change
    public static func recordResolution(_ info: AsyncPropertyInfo) {
        metricsQueue.async(flags: .barrier) {
            let key = "\(info.propertyName):\(info.propertyType)"
            self.propertyRegistry[key] = info

            self.resolutionHistory[key, default: []].append(info)

            // Maintain circular buffer
            if self.resolutionHistory[key]!.count > self.maxHistoryPerProperty {
                self.resolutionHistory[key]!.removeFirst()
            }
        }
    }

    /// Gets statistics for all async properties
    public static func getStats() -> AsyncInjectionStats {
        metricsQueue.sync {
            let properties = Array(propertyRegistry.values)
            let totalProperties = properties.count
            let resolvedProperties = properties.filter { $0.state == .resolved }.count
            let resolvingProperties = properties.filter { $0.state == .resolving }.count
            let failedProperties = properties.filter { $0.state == .failed }.count
            let timedOutProperties = properties.filter { $0.state == .timedOut }.count
            let cancelledProperties = properties.filter { $0.state == .cancelled }.count

            let resolutionTimes = properties.compactMap { $0.resolutionDuration }
            let averageResolutionTime = resolutionTimes.isEmpty ? 0.0 : resolutionTimes
                .reduce(0, +) / Double(resolutionTimes.count)
            let totalResolutionTime = resolutionTimes.reduce(0, +)

            let totalAttempts = properties.map { $0.attemptCount }.reduce(0, +)
            let averageRetryAttempts = totalProperties > 0 ? Double(totalAttempts) / Double(totalProperties) : 0.0

            // Calculate properties by state
            var propertiesByState: [AsyncResolutionState: Int] = [:]
            for state in AsyncResolutionState.allCases {
                propertiesByState[state] = properties.filter { $0.state == state }.count
            }

            // Calculate container usage
            let containerUsage = properties.reduce(into: [String: Int]()) { counts, property in
                counts[property.containerName, default: 0] += 1
            }

            // Calculate timeout distribution
            let timeoutDistribution = properties.reduce(into: [TimeInterval: Int]()) { counts, property in
                counts[property.timeout, default: 0] += 1
            }

            // Calculate common errors
            let commonErrors = properties.compactMap { $0.resolutionError?.localizedDescription }
                .reduce(into: [String: Int]()) { counts, error in
                    counts[error, default: 0] += 1
                }

            // Calculate time range
            let allTimes = properties.compactMap { property in
                [property.resolutionStartTime, property.resolutionEndTime].compactMap { $0 }
            }.flatMap { $0 }

            let timeRange = DateInterval(
                start: allTimes.min() ?? Date(),
                end: allTimes.max() ?? Date()
            )

            return AsyncInjectionStats(
                totalAsyncProperties: totalProperties,
                resolvedProperties: resolvedProperties,
                resolvingProperties: resolvingProperties,
                failedProperties: failedProperties,
                timedOutProperties: timedOutProperties,
                cancelledProperties: cancelledProperties,
                averageResolutionTime: averageResolutionTime,
                totalResolutionTime: totalResolutionTime,
                averageRetryAttempts: averageRetryAttempts,
                propertiesByState: propertiesByState,
                containerUsage: containerUsage,
                timeoutDistribution: timeoutDistribution,
                commonErrors: commonErrors,
                timeRange: timeRange
            )
        }
    }

    /// Gets information for a specific property
    public static func getPropertyInfo(name: String, type: String) -> AsyncPropertyInfo? {
        metricsQueue.sync {
            let key = "\(name):\(type)"
            return self.propertyRegistry[key]
        }
    }

    /// Gets all registered async properties
    public static func getAllProperties() -> [AsyncPropertyInfo] {
        metricsQueue.sync {
            Array(self.propertyRegistry.values)
        }
    }

    /// Prints a comprehensive async resolution report
    public static func printAsyncResolutionReport() {
        let stats = getStats()
        let properties = getAllProperties()

        guard !properties.isEmpty else {
            print("🔄 No async injection data available")
            return
        }

        print("\n🔄 Async Injection Report")
        print("=" * 80)
        print(String(format: "%-30s %-12s %8s %8s %10s", "Property", "State", "ResTime", "Attempts", "Container"))
        print("-" * 80)

        for property in properties.sorted(by: { $0.propertyName < $1.propertyName }) {
            let resolutionTime = property.resolutionDuration.map { String(format: "%.0fms", $0 * 1000) } ?? "-"

            print(String(
                format: "%-30s %-12s %8s %8d %10s",
                property.propertyName.suffix(30),
                property.state.description,
                resolutionTime,
                property.attemptCount,
                property.containerName.suffix(10)
            ))
        }

        print("-" * 80)
        print("Summary:")
        print("  Total Properties: \(stats.totalAsyncProperties)")
        print("  Resolved: \(stats.resolvedProperties)")
        print("  Failed: \(stats.failedProperties)")
        print("  Timed Out: \(stats.timedOutProperties)")
        print("  Average Resolution Time: \(String(format: "%.0f", stats.averageResolutionTime * 1000))ms")
        print("  Average Retry Attempts: \(String(format: "%.1f", stats.averageRetryAttempts))")
    }

    /// Gets properties that are currently resolving
    public static func getResolvingProperties() -> [AsyncPropertyInfo] {
        getAllProperties().filter { $0.state == .resolving }
    }

    /// Gets properties that failed to resolve
    public static func getFailedProperties() -> [AsyncPropertyInfo] {
        getAllProperties().filter { $0.state == .failed }
    }

    /// Gets properties that timed out
    public static func getTimedOutProperties() -> [AsyncPropertyInfo] {
        getAllProperties().filter { $0.state == .timedOut }
    }

    /// Clears all metrics data
    public static func reset() {
        metricsQueue.async(flags: .barrier) {
            self.propertyRegistry.removeAll()
            self.resolutionHistory.removeAll()
        }
    }

    /// Gets the success rate for async resolutions
    public static func getSuccessRate() -> Double {
        let stats = getStats()
        let totalCompleted = stats.resolvedProperties + stats.failedProperties + stats.timedOutProperties + stats
            .cancelledProperties
        guard totalCompleted > 0 else { return 0.0 }
        return Double(stats.resolvedProperties) / Double(totalCompleted)
    }
}

// MARK: - Async Injection Errors

/// Errors that can occur during async dependency injection
public enum AsyncInjectionError: Error, LocalizedError {
    case containerNotFound(containerName: String)
    case serviceNotRegistered(serviceName: String?, type: String)
    case resolutionTimeout(type: String, timeout: TimeInterval)
    case initializationTimeout(type: String, timeout: TimeInterval)
    case resolutionFailed(type: String, underlyingError: Error?)
    case resolutionCancelled(type: String)
    case maxRetriesExceeded(type: String, attempts: Int)

    public var errorDescription: String? {
        switch self {
        case .containerNotFound(let containerName):
            return "Container '\(containerName)' not found for async injection"
        case .serviceNotRegistered(let serviceName, let type):
            let service = serviceName.map { " named '\($0)'" } ?? ""
            return "Service\(service) of type '\(type)' is not registered for async injection"
        case .resolutionTimeout(let type, let timeout):
            return "Async resolution timeout for service of type '\(type)' (timeout: \(timeout)s)"
        case .initializationTimeout(let type, let timeout):
            return "Async initialization timeout for service of type '\(type)' (timeout: \(timeout)s)"
        case .resolutionFailed(let type, let underlyingError):
            let underlying = underlyingError.map { " - \($0.localizedDescription)" } ?? ""
            return "Failed to resolve async service of type '\(type)'\(underlying)"
        case .resolutionCancelled(let type):
            return "Async resolution was cancelled for service of type '\(type)'"
        case .maxRetriesExceeded(let type, let attempts):
            return "Maximum retry attempts exceeded for service of type '\(type)' (attempts: \(attempts))"
        }
    }
}

// MARK: - String Extension for Pretty Printing

// String * operator moved to StringExtensions.swift

// MARK: - Thread Information Support
// Note: ThreadInfo is defined in PerformanceTracked.swift and shared across all macro types
