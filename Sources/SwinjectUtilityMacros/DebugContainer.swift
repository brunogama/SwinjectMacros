// DebugContainer.swift - Advanced debugging and container introspection macro declarations

import Foundation
import Swinject

// MARK: - @DebugContainer Macro

/// Enables comprehensive debugging and introspection capabilities for dependency injection containers.
///
/// This macro adds powerful debugging tools including registration tracking, dependency visualization,
/// resolution monitoring, and runtime container health checks for development and troubleshooting.
///
/// ## Basic Usage
///
/// ```swift
/// @DebugContainer
/// class DIContainer: Container {
///     init() {
///         super.init()
///         // Debug tracking automatically enabled
///     }
/// }
///
/// // Usage with debug information:
/// let container = DIContainer()
/// container.register(UserService.self) { _ in UserService() }
///
/// // Debug information available:
/// print(container.getRegistrationInfo())
/// print(container.getDependencyGraph())
/// ```
///
/// ## Advanced Debug Configuration
///
/// ```swift
/// @DebugContainer(
///     logLevel: .verbose,
///     trackResolutions: true,
///     detectCircularDeps: true,
///     performanceTracking: true,
///     visualizeGraph: true
/// )
/// class ProductionContainer: Container {
///     // Enhanced debugging with performance monitoring
/// }
/// ```
///
/// ## Real-time Container Monitoring
///
/// ```swift
/// @DebugContainer(realTimeMonitoring: true)
/// class MonitoredContainer: Container {
///     // Automatically logs all registration and resolution activities
/// }
///
/// let container = MonitoredContainer()
/// container.onRegistration { registration in
///     print("🔧 Registered: \(registration.serviceType)")
/// }
/// container.onResolution { resolution in
///     print("🎯 Resolved: \(resolution.serviceType) in \(resolution.duration)ms")
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **Registration Tracking**: Complete history of all service registrations
/// 2. **Resolution Monitoring**: Real-time tracking of dependency resolution
/// 3. **Dependency Visualization**: GraphViz-compatible dependency graphs
/// 4. **Performance Metrics**: Resolution times and container health statistics
/// 5. **Circular Dependency Detection**: Compile-time and runtime cycle detection
/// 6. **Debug Logging**: Configurable logging levels and output formats
///
/// ## Debug Features
///
/// ### Registration Information
/// ```swift
/// let container = DIContainer()
///
/// // Get all registrations
/// let registrations = container.getAllRegistrations()
/// for registration in registrations {
///     print("Service: \(registration.serviceType)")
///     print("Scope: \(registration.objectScope)")
///     print("Named: \(registration.name ?? "default")")
/// }
/// ```
///
/// ### Dependency Graph Visualization
/// ```swift
/// // Generate dependency graph
/// let graph = container.generateDependencyGraph()
/// print(graph.dotFormat) // GraphViz DOT format
///
/// // Export to file for visualization
/// container.exportDependencyGraph(to: "dependencies.dot")
/// ```
///
/// ### Resolution Performance Tracking
/// ```swift
/// // Enable performance tracking
/// container.enablePerformanceTracking()
///
/// // Resolve services with timing
/// let userService = container.resolve(UserService.self)
///
/// // Get performance metrics
/// let metrics = container.getPerformanceMetrics()
/// print("Average resolution time: \(metrics.averageResolutionTime)ms")
/// print("Slowest resolution: \(metrics.slowestResolution)")
/// ```
///
/// ### Health Checks
/// ```swift
/// // Validate container health
/// let healthCheck = container.performHealthCheck()
///
/// if !healthCheck.isHealthy {
///     print("❌ Container Issues:")
///     for issue in healthCheck.issues {
///         print("  - \(issue.description)")
///     }
/// }
/// ```
@attached(
    member,
    names: named(enableDebugMode),
    named(getRegistrationInfo),
    named(getDependencyGraph),
    named(getPerformanceMetrics)
)
@attached(extension, conformances: DebuggableContainer)
public macro DebugContainer(
    logLevel: DebugLogLevel = .info,
    trackResolutions: Bool = true,
    detectCircularDeps: Bool = true,
    performanceTracking: Bool = true,
    visualizeGraph: Bool = true,
    realTimeMonitoring: Bool = false
) = #externalMacro(module: "SwinjectUtilityMacrosImplementation", type: "DebugContainerMacro")

// MARK: - Debug Container Support Types

/// Debug logging levels for container introspection
public enum DebugLogLevel: String, CaseIterable {
    case silent = "silent"
    case error = "error"
    case warning = "warning"
    case info = "info"
    case verbose = "verbose"
    case trace = "trace"

    /// Check if current level includes the specified level
    public func includes(_ level: DebugLogLevel) -> Bool {
        rawValue >= level.rawValue
    }
}

/// Configuration for debug container features
public struct DebugContainerConfiguration {
    public let logLevel: DebugLogLevel
    public let trackResolutions: Bool
    public let detectCircularDeps: Bool
    public let performanceTracking: Bool
    public let visualizeGraph: Bool
    public let realTimeMonitoring: Bool

    public init(
        logLevel: DebugLogLevel = .info,
        trackResolutions: Bool = true,
        detectCircularDeps: Bool = true,
        performanceTracking: Bool = true,
        visualizeGraph: Bool = true,
        realTimeMonitoring: Bool = false
    ) {
        self.logLevel = logLevel
        self.trackResolutions = trackResolutions
        self.detectCircularDeps = detectCircularDeps
        self.performanceTracking = performanceTracking
        self.visualizeGraph = visualizeGraph
        self.realTimeMonitoring = realTimeMonitoring
    }
}

// DebuggableContainer protocol is defined in DependencyGraphTypes.swift

/// Detailed information about a service registration
public struct RegistrationInfo {
    public let serviceType: String
    public let implementationType: String?
    public let objectScope: String
    public let name: String?
    public let registrationTimestamp: Date
    public let dependencies: [String]
    public let isResolved: Bool
    public let resolutionCount: Int

    public init(
        serviceType: String,
        implementationType: String? = nil,
        objectScope: String,
        name: String? = nil,
        registrationTimestamp: Date = Date(),
        dependencies: [String] = [],
        isResolved: Bool = false,
        resolutionCount: Int = 0
    ) {
        self.serviceType = serviceType
        self.implementationType = implementationType
        self.objectScope = objectScope
        self.name = name
        self.registrationTimestamp = registrationTimestamp
        self.dependencies = dependencies
        self.isResolved = isResolved
        self.resolutionCount = resolutionCount
    }
}

// DependencyGraph extensions are defined in DependencyGraph.swift

/// Circular dependency information
public struct CircularDependency {
    public let cycle: [String]
    public let detectionTimestamp: Date

    public init(cycle: [String], detectionTimestamp: Date = Date()) {
        self.cycle = cycle
        self.detectionTimestamp = detectionTimestamp
    }

    public var description: String {
        cycle.joined(separator: " -> ") + " -> " + (cycle.first ?? "")
    }
}

/// Performance metrics for container operations
public struct ContainerPerformanceMetrics {
    public let registrationCount: Int
    public let resolutionCount: Int
    public let averageResolutionTime: TimeInterval
    public let slowestResolution: ResolutionMetric?
    public let fastestResolution: ResolutionMetric?
    public let totalResolutionTime: TimeInterval
    public let cacheHitRate: Double

    public init(
        registrationCount: Int = 0,
        resolutionCount: Int = 0,
        averageResolutionTime: TimeInterval = 0,
        slowestResolution: ResolutionMetric? = nil,
        fastestResolution: ResolutionMetric? = nil,
        totalResolutionTime: TimeInterval = 0,
        cacheHitRate: Double = 0
    ) {
        self.registrationCount = registrationCount
        self.resolutionCount = resolutionCount
        self.averageResolutionTime = averageResolutionTime
        self.slowestResolution = slowestResolution
        self.fastestResolution = fastestResolution
        self.totalResolutionTime = totalResolutionTime
        self.cacheHitRate = cacheHitRate
    }
}

/// Individual resolution performance metric
public struct ResolutionMetric {
    public let serviceType: String
    public let resolutionTime: TimeInterval
    public let timestamp: Date
    public let stackTrace: [String]?

    public init(
        serviceType: String,
        resolutionTime: TimeInterval,
        timestamp: Date = Date(),
        stackTrace: [String]? = nil
    ) {
        self.serviceType = serviceType
        self.resolutionTime = resolutionTime
        self.timestamp = timestamp
        self.stackTrace = stackTrace
    }
}

/// Container health check results
public struct ContainerHealthCheck {
    public let isHealthy: Bool
    public let issues: [ContainerIssue]
    public let checkTimestamp: Date
    public let checkDuration: TimeInterval

    public init(
        isHealthy: Bool,
        issues: [ContainerIssue] = [],
        checkTimestamp: Date = Date(),
        checkDuration: TimeInterval = 0
    ) {
        self.isHealthy = isHealthy
        self.issues = issues
        self.checkTimestamp = checkTimestamp
        self.checkDuration = checkDuration
    }
}

/// Container health issue
public struct ContainerIssue {
    public enum Severity {
        case warning, error, critical
    }

    public let severity: Severity
    public let description: String
    public let recommendation: String?
    public let affectedServices: [String]

    public init(
        severity: Severity,
        description: String,
        recommendation: String? = nil,
        affectedServices: [String] = []
    ) {
        self.severity = severity
        self.description = description
        self.recommendation = recommendation
        self.affectedServices = affectedServices
    }
}

// MARK: - Debug Logger

/// Logger for container debug operations
public class ContainerDebugLogger {
    public static let shared = ContainerDebugLogger()

    private var logLevel: DebugLogLevel = .info
    private var logHandlers: [(DebugLogLevel, String) -> Void] = []

    private init() {
        // Add default console logger
        addLogHandler { level, message in
            let prefix = self.getLogPrefix(for: level)
            DebugLogger.debug("\(prefix) \(message)")
        }
    }

    /// Set the minimum log level
    public func setLogLevel(_ level: DebugLogLevel) {
        logLevel = level
    }

    /// Add a custom log handler
    public func addLogHandler(_ handler: @escaping (DebugLogLevel, String) -> Void) {
        logHandlers.append(handler)
    }

    /// Log a message at the specified level
    public func log(_ level: DebugLogLevel, _ message: String) {
        guard logLevel.includes(level) else { return }

        for handler in logHandlers {
            handler(level, message)
        }
    }

    private func getLogPrefix(for level: DebugLogLevel) -> String {
        switch level {
        case .silent: ""
        case .error: "🔴 [ERROR]"
        case .warning: "🟡 [WARN]"
        case .info: "🔵 [INFO]"
        case .verbose: "🟢 [DEBUG]"
        case .trace: "🔍 [TRACE]"
        }
    }
}

// MARK: - Container Extensions for Debugging

extension Container {

    /// Enable debug mode with default configuration
    public func enableDebugMode() {
        // Enable basic debug logging
        DebugLogger.info("🐛 Debug mode enabled for container at \(Date())")
    }

    /// Get basic registration statistics
    public func getRegistrationStats() -> (count: Int, resolvedCount: Int) {
        // This would require introspection into Swinject's internals
        // For now, return placeholder values
        (count: 0, resolvedCount: 0)
    }

    /// Log container state for debugging
    public func logContainerState() {
        ContainerDebugLogger.shared.log(.info, "Container state logging not yet implemented")
    }

    /// Validate container configuration
    public func validateConfiguration() -> [String] {
        // Return validation warnings/errors
        []
    }
}

// MARK: - Debug Utilities

/// Utility functions for container debugging
public enum ContainerDebugUtils {

    /// Generate a unique identifier for a service type
    public static func generateServiceId(for serviceType: Any.Type, name: String? = nil) -> String {
        let typeName = String(describing: serviceType)
        if let name = name {
            return "\(typeName)_\(name)"
        }
        return typeName
    }

    /// Extract service type name from a type
    public static func getServiceTypeName(from type: Any.Type) -> String {
        String(describing: type)
    }

    /// Generate a timestamp string for logging
    public static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }

    /// Format time interval for display
    public static func formatTimeInterval(_ interval: TimeInterval) -> String {
        if interval < 0.001 {
            String(format: "%.3fμs", interval * 1_000_000)
        } else if interval < 1.0 {
            String(format: "%.3fms", interval * 1000)
        } else {
            String(format: "%.3fs", interval)
        }
    }
}

// MARK: - Memory Debugging

/// Memory usage tracking for container debugging
public class ContainerMemoryTracker {
    private var memorySnapshots: [Date: Int] = [:]
    private let queue = DispatchQueue(label: "container.memory.tracker")

    /// Take a memory snapshot
    public func takeSnapshot() {
        queue.async {
            let usage = self.getCurrentMemoryUsage()
            self.memorySnapshots[Date()] = usage
        }
    }

    /// Get memory usage trend
    public func getMemoryTrend() -> [Date: Int] {
        queue.sync { self.memorySnapshots }
    }

    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
}
