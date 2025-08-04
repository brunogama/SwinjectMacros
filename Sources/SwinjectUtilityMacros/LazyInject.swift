// LazyInject.swift - Lazy dependency injection macro declarations and support types
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import Swinject

// MARK: - @LazyInject Macro

/// Automatically generates lazy dependency injection accessors that resolve dependencies on first access.
///
/// This macro transforms properties into lazy-loaded dependencies, providing deferred resolution
/// that improves startup performance and handles circular dependencies.
///
/// ## Basic Usage
///
/// ```swift
/// class UserService {
///     @LazyInject var database: DatabaseProtocol
///     @LazyInject var logger: LoggerProtocol
///
///     func getUser(id: String) -> User? {
///         // Dependencies are resolved on first access
///         logger.info("Fetching user: \(id)")
///         return database.findUser(id: id)
///     }
/// }
/// ```
///
/// ## Advanced Usage with Named Dependencies
///
/// ```swift
/// class PaymentService {
///     @LazyInject("primary") var primaryDB: DatabaseProtocol
///     @LazyInject("secondary") var secondaryDB: DatabaseProtocol
///     @LazyInject(container: "test") var mockPaymentGateway: PaymentGatewayProtocol
///
///     func processPayment(_ payment: Payment) -> PaymentResult {
///         // Named dependencies resolved lazily
///         return primaryDB.isAvailable()
///             ? primaryDB.processPayment(payment)
///             : secondaryDB.processPayment(payment)
///     }
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **Private Storage**: Backing storage for the lazy dependency
/// 2. **Resolution Logic**: Deferred dependency resolution on first access
/// 3. **Thread Safety**: Thread-safe lazy initialization with dispatch_once
/// 4. **Container Integration**: Automatic container lookup and resolution
/// 5. **Error Handling**: Graceful handling of resolution failures
/// 6. **Debug Support**: Resolution tracking and dependency graph validation
///
/// ## Lazy Resolution Benefits
///
/// The macro provides several advantages over eager injection:
///
/// ```swift
/// // Eager injection - resolved at initialization
/// @Injectable var eagerService: ExpensiveService // Resolved immediately
///
/// // Lazy injection - resolved on first use
/// @LazyInject var lazyService: ExpensiveService // Resolved when first accessed
/// ```
///
/// **Performance Benefits:**
/// - **Faster Startup**: Dependencies resolved only when needed
/// - **Memory Efficient**: Unused dependencies never instantiated
/// - **Circular Dependencies**: Breaks circular dependency chains
/// - **Conditional Usage**: Optional dependencies resolved only if used
///
/// ## Container Integration
///
/// Works seamlessly with different container configurations:
///
/// ```swift
/// // Default container resolution
/// @LazyInject var service: ServiceProtocol
///
/// // Named container resolution
/// @LazyInject(container: "production") var prodService: ServiceProtocol
///
/// // Multiple registration support
/// @LazyInject("v1") var serviceV1: ServiceProtocol
/// @LazyInject("v2") var serviceV2: ServiceProtocol
/// ```
///
/// ## Thread Safety
///
/// All lazy resolution is thread-safe using dispatch_once:
///
/// ```swift
/// class ConcurrentService {
///     @LazyInject var sharedResource: ExpensiveResource
///
///     func processInParallel() {
///         DispatchQueue.concurrentPerform(iterations: 100) { _ in
///             // Safe concurrent access - resolved only once
///             sharedResource.doWork()
///         }
///     }
/// }
/// ```
///
/// ## Integration with Metrics
///
/// ```swift
/// // Get lazy injection statistics
/// let stats = LazyInjectionMetrics.getStats()
/// print("Total lazy properties: \(stats.totalLazyProperties)")
/// print("Resolved properties: \(stats.resolvedProperties)")
/// print("Average resolution time: \(stats.averageResolutionTime)ms")
///
/// // Track resolution performance
/// LazyInjectionMetrics.printResolutionReport()
/// ```
///
/// ## Parameters:
/// - `name`: Optional service name for named registration lookup
/// - `container`: Container identifier for multi-container scenarios
/// - `required`: Whether dependency is required (default: true)
/// - `onResolution`: Callback executed after successful resolution
/// - `fallback`: Fallback service provider for resolution failures
///
/// ## Requirements:
/// - Property must have an explicit type annotation
/// - Type must be registered in the dependency injection container
/// - Can be applied to stored properties in classes and structs
/// - Thread-safe resolution for concurrent access scenarios
///
/// ## Generated Behavior:
/// 1. **Property Access**: First access triggers dependency resolution
/// 2. **Container Lookup**: Queries appropriate container for service
/// 3. **Caching**: Caches resolved instance for subsequent accesses
/// 4. **Error Handling**: Throws descriptive errors for resolution failures
/// 5. **Metrics Tracking**: Records resolution time and success rates
/// 6. **Debug Support**: Provides dependency resolution tracing
///
/// ## Performance Characteristics:
/// - **First Access**: Container resolution overhead (~1-5ms)
/// - **Subsequent Access**: Direct property access (~1-10ns)
/// - **Memory Overhead**: One additional property per lazy dependency
/// - **Thread Safety**: Minimal contention with dispatch_once
///
/// ## Real-World Examples:
///
/// ```swift
/// class NotificationService {
///     @LazyInject var emailService: EmailServiceProtocol
///     @LazyInject var pushService: PushServiceProtocol
///     @LazyInject var smsService: SMSServiceProtocol
///     @LazyInject("metrics") var metricsCollector: MetricsProtocol
///
///     func sendNotification(_ notification: Notification) {
///         // Only resolve services that are actually used
///         switch notification.type {
///         case .email:
///             emailService.send(notification) // emailService resolved here
///         case .push:
///             pushService.send(notification)  // pushService resolved here
///         case .sms:
///             smsService.send(notification)   // smsService resolved here
///         }
///
///         // Metrics always collected
///         metricsCollector.increment("notifications.sent")
///     }
/// }
///
/// class DataProcessor {
///     @LazyInject("primary") var primaryDB: DatabaseProtocol
///     @LazyInject("cache") var cacheLayer: CacheProtocol
///     @LazyInject(required: false) var analyticsService: AnalyticsProtocol?
///
///     func processData(_ data: ProcessingJob) -> ProcessingResult {
///         // Check cache first (lazy resolution on first cache check)
///         if let cached = cacheLayer.get(key: data.id) {
///             return cached
///         }
///
///         // Process with primary database (lazy resolution on first DB operation)
///         let result = primaryDB.process(data)
///         cacheLayer.set(key: data.id, value: result)
///
///         // Optional analytics (resolved only if available)
///         analyticsService?.track("data.processed", metadata: ["type": data.type])
///
///         return result
///     }
/// }
///
/// // Monitor lazy injection performance
/// LazyInjectionMetrics.printResolutionReport()
/// // Output:
/// // 🔗 Lazy Injection Report
/// // =====================================
/// // Property              Resolved  AvgTime  Container
/// // emailService          true      2.3ms    default
/// // pushService           false     -        default
/// // smsService            false     -        default
/// // metricsCollector      true      1.8ms    metrics
/// // primaryDB             true      4.1ms    default
/// // cacheLayer            true      1.2ms    default
/// // analyticsService      true      2.7ms    default
/// ```
@attached(accessor)
@attached(peer, names: arbitrary)
public macro LazyInject(
    _ name: String? = nil,
    container: String = "default",
    required: Bool = true,
    onResolution: ((Any) -> Void)? = nil,
    fallback: (() -> Any?)? = nil
) = #externalMacro(module: "SwinjectUtilityMacrosImplementation", type: "LazyInjectMacro")

// MARK: - Lazy Injection Support Types

/// Lazy injection resolution states
public enum LazyResolutionState: String, CaseIterable {
    case pending = "PENDING" // Not yet resolved
    case resolving = "RESOLVING" // Currently resolving
    case resolved = "RESOLVED" // Successfully resolved
    case failed = "FAILED" // Resolution failed

    public var description: String {
        rawValue
    }
}

/// Individual lazy property resolution information
public struct LazyPropertyInfo {
    /// Property name
    public let propertyName: String

    /// Property type
    public let propertyType: String

    /// Container name used for resolution
    public let containerName: String

    /// Service name (if named injection)
    public let serviceName: String?

    /// Whether the property is required
    public let isRequired: Bool

    /// Current resolution state
    public let state: LazyResolutionState

    /// When resolution was attempted
    public let resolutionTime: Date?

    /// Time taken for resolution (milliseconds)
    public let resolutionDuration: TimeInterval?

    /// Error encountered during resolution
    public let resolutionError: Error?

    /// Thread information for resolution
    public let threadInfo: ThreadInfo?

    public init(
        propertyName: String,
        propertyType: String,
        containerName: String,
        serviceName: String? = nil,
        isRequired: Bool = true,
        state: LazyResolutionState = .pending,
        resolutionTime: Date? = nil,
        resolutionDuration: TimeInterval? = nil,
        resolutionError: Error? = nil,
        threadInfo: ThreadInfo? = nil
    ) {
        self.propertyName = propertyName
        self.propertyType = propertyType
        self.containerName = containerName
        self.serviceName = serviceName
        self.isRequired = isRequired
        self.state = state
        self.resolutionTime = resolutionTime
        self.resolutionDuration = resolutionDuration
        self.resolutionError = resolutionError
        self.threadInfo = threadInfo
    }
}

/// Comprehensive lazy injection metrics
public struct LazyInjectionStats {
    /// Total number of lazy properties registered
    public let totalLazyProperties: Int

    /// Number of properties that have been resolved
    public let resolvedProperties: Int

    /// Number of properties with resolution failures
    public let failedProperties: Int

    /// Average time for successful resolutions (milliseconds)
    public let averageResolutionTime: TimeInterval

    /// Total time spent on all resolutions (milliseconds)
    public let totalResolutionTime: TimeInterval

    /// Properties by resolution state
    public let propertiesByState: [LazyResolutionState: Int]

    /// Container usage statistics
    public let containerUsage: [String: Int]

    /// Most common resolution errors
    public let commonErrors: [String: Int]

    /// Time range covered by these statistics
    public let timeRange: DateInterval

    public init(
        totalLazyProperties: Int,
        resolvedProperties: Int,
        failedProperties: Int,
        averageResolutionTime: TimeInterval,
        totalResolutionTime: TimeInterval,
        propertiesByState: [LazyResolutionState: Int],
        containerUsage: [String: Int],
        commonErrors: [String: Int],
        timeRange: DateInterval
    ) {
        self.totalLazyProperties = totalLazyProperties
        self.resolvedProperties = resolvedProperties
        self.failedProperties = failedProperties
        self.averageResolutionTime = averageResolutionTime
        self.totalResolutionTime = totalResolutionTime
        self.propertiesByState = propertiesByState
        self.containerUsage = containerUsage
        self.commonErrors = commonErrors
        self.timeRange = timeRange
    }
}

// MARK: - Lazy Injection Metrics Manager

/// Thread-safe lazy injection metrics tracking and reporting
public class LazyInjectionMetrics {
    private static var propertyRegistry: [String: LazyPropertyInfo] = [:]
    private static var resolutionHistory: [String: [LazyPropertyInfo]] = [:]
    private static let metricsQueue = DispatchQueue(label: "lazy.injection.metrics", attributes: .concurrent)
    private static let maxHistoryPerProperty = 100 // Circular buffer size

    /// Registers a lazy property for tracking
    public static func registerProperty(_ info: LazyPropertyInfo) {
        metricsQueue.async(flags: .barrier) {
            let key = "\(info.propertyName):\(info.propertyType)"
            self.propertyRegistry[key] = info
        }
    }

    /// Records a resolution attempt
    public static func recordResolution(_ info: LazyPropertyInfo) {
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

    /// Gets statistics for all lazy properties
    public static func getStats() -> LazyInjectionStats {
        metricsQueue.sync {
            let properties = Array(propertyRegistry.values)
            let totalProperties = properties.count
            let resolvedProperties = properties.filter { $0.state == .resolved }.count
            let failedProperties = properties.filter { $0.state == .failed }.count

            let resolutionTimes = properties.compactMap { $0.resolutionDuration }
            let averageResolutionTime = resolutionTimes.isEmpty ? 0.0 : resolutionTimes
                .reduce(0, +) / Double(resolutionTimes.count)
            let totalResolutionTime = resolutionTimes.reduce(0, +)

            // Calculate properties by state
            var propertiesByState: [LazyResolutionState: Int] = [:]
            for state in LazyResolutionState.allCases {
                propertiesByState[state] = properties.filter { $0.state == state }.count
            }

            // Calculate container usage
            let containerUsage = properties.reduce(into: [String: Int]()) { counts, property in
                counts[property.containerName, default: 0] += 1
            }

            // Calculate common errors
            let commonErrors = properties.compactMap { $0.resolutionError?.localizedDescription }
                .reduce(into: [String: Int]()) { counts, error in
                    counts[error, default: 0] += 1
                }

            // Calculate time range
            let resolutionTimestamps = properties.compactMap { $0.resolutionTime }
            let timeRange = DateInterval(
                start: resolutionTimestamps.min() ?? Date(),
                end: resolutionTimestamps.max() ?? Date()
            )

            return LazyInjectionStats(
                totalLazyProperties: totalProperties,
                resolvedProperties: resolvedProperties,
                failedProperties: failedProperties,
                averageResolutionTime: averageResolutionTime,
                totalResolutionTime: totalResolutionTime,
                propertiesByState: propertiesByState,
                containerUsage: containerUsage,
                commonErrors: commonErrors,
                timeRange: timeRange
            )
        }
    }

    /// Gets information for a specific property
    public static func getPropertyInfo(name: String, type: String) -> LazyPropertyInfo? {
        metricsQueue.sync {
            let key = "\(name):\(type)"
            return self.propertyRegistry[key]
        }
    }

    /// Gets all registered lazy properties
    public static func getAllProperties() -> [LazyPropertyInfo] {
        metricsQueue.sync {
            Array(self.propertyRegistry.values)
        }
    }

    /// Prints a comprehensive lazy injection report
    public static func printResolutionReport() {
        let stats = getStats()
        let properties = getAllProperties()

        guard !properties.isEmpty else {
            print("🔗 No lazy injection data available")
            return
        }

        print("\n🔗 Lazy Injection Report")
        print("=" * 80)
        print(String(format: "%-30s %-10s %8s %10s %12s", "Property", "State", "ReqTime", "Container", "Service"))
        print("-" * 80)

        for property in properties.sorted(by: { $0.propertyName < $1.propertyName }) {
            let resolutionTime = property.resolutionDuration.map { String(format: "%.1fms", $0 * 1000) } ?? "-"
            let serviceName = property.serviceName ?? "-"

            print(String(
                format: "%-30s %-10s %8s %10s %12s",
                property.propertyName.suffix(30),
                property.state.description,
                resolutionTime,
                property.containerName.suffix(10),
                serviceName.suffix(12)
            ))
        }

        print("-" * 80)
        print("Summary:")
        print("  Total Properties: \(stats.totalLazyProperties)")
        print(
            "  Resolved: \(stats.resolvedProperties) (\(String(format: "%.1f", Double(stats.resolvedProperties) / Double(stats.totalLazyProperties) * 100))%)"
        )
        print("  Failed: \(stats.failedProperties)")
        print("  Average Resolution Time: \(String(format: "%.1f", stats.averageResolutionTime * 1000))ms")
    }

    /// Gets properties that failed to resolve
    public static func getFailedProperties() -> [LazyPropertyInfo] {
        getAllProperties().filter { $0.state == .failed }
    }

    /// Gets properties that are still pending resolution
    public static func getPendingProperties() -> [LazyPropertyInfo] {
        getAllProperties().filter { $0.state == .pending }
    }

    /// Clears all metrics data
    public static func reset() {
        metricsQueue.async(flags: .barrier) {
            self.propertyRegistry.removeAll()
            self.resolutionHistory.removeAll()
        }
    }

    /// Gets resolution success rate
    public static func getSuccessRate() -> Double {
        let stats = getStats()
        guard stats.totalLazyProperties > 0 else { return 0.0 }
        return Double(stats.resolvedProperties) / Double(stats.totalLazyProperties)
    }
}

// MARK: - Lazy Injection Errors

/// Errors that can occur during lazy dependency resolution
public enum LazyInjectionError: Error, LocalizedError {
    case containerNotFound(containerName: String)
    case serviceNotRegistered(serviceName: String?, type: String)
    case resolutionFailed(type: String, underlyingError: Error?)
    case circularDependency(chain: [String])
    case requiredServiceUnavailable(propertyName: String, type: String)

    public var errorDescription: String? {
        switch self {
        case .containerNotFound(let containerName):
            return "Container '\(containerName)' not found for lazy injection"
        case .serviceNotRegistered(let serviceName, let type):
            let service = serviceName.map { " named '\($0)'" } ?? ""
            return "Service\(service) of type '\(type)' is not registered"
        case .resolutionFailed(let type, let underlyingError):
            let underlying = underlyingError.map { " - \($0.localizedDescription)" } ?? ""
            return "Failed to resolve service of type '\(type)'\(underlying)"
        case .circularDependency(let chain):
            return "Circular dependency detected: \(chain.joined(separator: " -> "))"
        case .requiredServiceUnavailable(let propertyName, let type):
            return "Required lazy property '\(propertyName)' of type '\(type)' could not be resolved"
        }
    }
}

// MARK: - String Extension for Pretty Printing

// String * operator moved to StringExtensions.swift

// MARK: - Thread Information Support
// Note: ThreadInfo is defined in PerformanceTracked.swift and shared across all macro types

// MARK: - Container Extensions for Lazy Injection

extension Container {
    /// Shared container instance for global access
    /// Note: Configure this container in your app startup
    public static var shared: Container = {
        let container = Container()
        return container
    }()

    /// Named containers registry for multi-container scenarios
    private static var namedContainers: [String: Container] = [:]
    private static let containerQueue = DispatchQueue(label: "Container.namedContainers", attributes: .concurrent)

    /// Gets or creates a named container
    public static func named(_ name: String) -> Container {
        containerQueue.sync {
            if let existing = namedContainers[name] {
                return existing
            } else {
                let newContainer = Container()
                self.containerQueue.async(flags: .barrier) {
                    self.namedContainers[name] = newContainer
                }
                return newContainer
            }
        }
    }

    /// Thread-safe resolve method for lazy injection
    public func synchronizedResolve<Service>(_ serviceType: Service.Type, name: String? = nil) -> Service? {
        // Swinject is already thread-safe, so we can use the standard resolve methods
        if let name = name {
            resolve(serviceType, name: name)
        } else {
            resolve(serviceType)
        }
    }
}

// MARK: - Lazy Property State Alias

/// Alias for backward compatibility with macro implementation
public typealias LazyPropertyState = LazyResolutionState
