// WeakInject.swift - Weak dependency injection macro declarations and support types
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import Swinject

// MARK: - @WeakInject Macro

/// Automatically generates weak dependency injection accessors that hold weak references to dependencies.
///
/// This macro transforms properties into weak references, preventing retain cycles and memory leaks
/// in circular dependency scenarios while maintaining automatic dependency resolution.
///
/// ## Basic Usage
///
/// ```swift
/// class NotificationService {
///     @WeakInject var delegate: NotificationDelegate?
///     @WeakInject var eventLogger: EventLoggingProtocol?
///
///     func sendNotification(_ message: String) {
///         // Weak references prevent retain cycles
///         delegate?.willSendNotification(message)
///         eventLogger?.logEvent("notification_sent", data: ["message": message])
///     }
/// }
/// ```
///
/// ## Advanced Usage with Observer Patterns
///
/// ```swift
/// class DataProcessor {
///     @WeakInject var progressObserver: ProgressObserver?
///     @WeakInject("analytics") var analyticsService: AnalyticsProtocol?
///     @WeakInject(container: "observers") var statusObserver: StatusObserver?
///
///     func processLargeDataset(_ data: [DataItem]) {
///         // Weak references allow observers to be deallocated safely
///         progressObserver?.onProgressStarted(totalItems: data.count)
///
///         for (index, item) in data.enumerated() {
///             processItem(item)
///             progressObserver?.onProgress(completed: index + 1, total: data.count)
///         }
///
///         analyticsService?.track("dataset_processed", metadata: ["count": data.count])
///         statusObserver?.onStatusChanged(.completed)
///     }
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **Weak Storage**: Backing weak storage for the dependency reference
/// 2. **Automatic Resolution**: Lazy resolution on first access with weak assignment
/// 3. **Nil Safety**: Automatic nil checking and graceful handling of deallocated references
/// 4. **Container Integration**: Seamless integration with dependency injection containers
/// 5. **Memory Safety**: Prevents retain cycles and reduces memory pressure
/// 6. **Debug Support**: Weak reference tracking and lifecycle monitoring
///
/// ## Weak Reference Benefits
///
/// The macro provides several advantages for observer and delegate patterns:
///
/// ```swift
/// // Strong reference - can cause retain cycles
/// @Injectable var strongObserver: ObserverProtocol // Retains the observer
///
/// // Weak reference - prevents retain cycles
/// @WeakInject var weakObserver: ObserverProtocol? // Does not retain the observer
/// ```
///
/// **Memory Benefits:**
/// - **Prevent Retain Cycles**: Breaks circular references automatically
/// - **Reduce Memory Pressure**: Allows early deallocation of unused dependencies
/// - **Observer Pattern Safety**: Perfect for delegate and observer implementations
/// - **Optional by Design**: All weak dependencies are inherently optional
///
/// ## Container Integration
///
/// Works with different container configurations and service lifetimes:
///
/// ```swift
/// // Default container resolution with weak reference
/// @WeakInject var service: ServiceProtocol?
///
/// // Named service resolution with weak reference
/// @WeakInject("background") var backgroundService: BackgroundServiceProtocol?
///
/// // Custom container with weak reference
/// @WeakInject(container: "observers") var observer: ObserverProtocol?
/// ```
///
/// ## Lifecycle Management
///
/// Handles object lifecycle and automatic cleanup:
///
/// ```swift
/// class EventManager {
///     @WeakInject var listener: EventListener?
///
///     func fireEvent(_ event: Event) {
///         // Automatically handles nil references if listener was deallocated
///         if let listener = listener {
///             listener.onEvent(event)
///         } else {
///             // Listener has been deallocated - no memory leak
///             print("No active listener for event: \\(event.name)")
///         }
///     }
/// }
/// ```
///
/// ## Integration with Metrics
///
/// ```swift
/// // Get weak injection statistics
/// let stats = WeakInjectionMetrics.getStats()
/// print("Total weak properties: \(stats.totalWeakProperties)")
/// print("Active references: \(stats.activeReferences)")
/// print("Deallocated references: \(stats.deallocatedReferences)")
///
/// // Track weak reference lifecycle
/// WeakInjectionMetrics.printWeakReferenceReport()
/// ```
///
/// ## Parameters:
/// - `name`: Optional service name for named registration lookup
/// - `container`: Container identifier for multi-container scenarios
/// - `autoResolve`: Whether to automatically resolve on first access (default: true)
/// - `onDeallocation`: Callback executed when weak reference becomes nil
/// - `fallback`: Fallback service provider when reference is nil
///
/// ## Requirements:
/// - Property must have an explicit optional type annotation
/// - Property type must be a class type (weak references require reference types)
/// - Can be applied to stored properties in classes (not structs)
/// - Service must be registered in the dependency injection container
///
/// ## Generated Behavior:
/// 1. **Property Access**: First access triggers dependency resolution if needed
/// 2. **Weak Assignment**: Assigns resolved service as weak reference
/// 3. **Nil Handling**: Gracefully handles deallocated references
/// 4. **Auto-Resolution**: Re-resolves if reference becomes nil and autoResolve is enabled
/// 5. **Metrics Tracking**: Records weak reference lifecycle events
/// 6. **Debug Support**: Provides weak reference monitoring and diagnostics
///
/// ## Memory Characteristics:
/// - **Zero Retain Count Impact**: Does not affect reference counting
/// - **Automatic Cleanup**: References automatically become nil when target deallocates
/// - **Memory Efficient**: No additional memory overhead beyond weak reference storage
/// - **Leak Prevention**: Eliminates retain cycle possibilities
///
/// ## Real-World Examples:
///
/// ```swift
/// class ChatManager {
///     @WeakInject var delegate: ChatManagerDelegate?
///     @WeakInject("ui") var uiUpdateHandler: UIUpdateHandler?
///     @WeakInject var analyticsCollector: AnalyticsCollector?
///
///     func sendMessage(_ message: Message) {
///         // Process message
///         let processedMessage = processMessage(message)
///
///         // Notify delegate (weak reference prevents retain cycle)
///         delegate?.chatManager(self, didSendMessage: processedMessage)
///
///         // Update UI (weak reference allows UI components to be deallocated)
///         uiUpdateHandler?.updateMessageUI(processedMessage)
///
///         // Track analytics (weak reference prevents analytics from keeping chat alive)
///         analyticsCollector?.trackMessageSent(processedMessage)
///     }
/// }
///
/// class AudioPlayer {
///     @WeakInject var delegate: AudioPlayerDelegate?
///     @WeakInject("visualizer") var visualizer: AudioVisualizerProtocol?
///     @WeakInject(container: "observers") var progressObserver: PlaybackProgressObserver?
///
///     func play(_ audioFile: AudioFile) {
///         delegate?.audioPlayerWillStartPlaying(self)
///
///         // Start playback
///         startPlayback(audioFile)
///
///         // Update visualizer if available (weak - can be deallocated)
///         visualizer?.startVisualization(for: audioFile)
///
///         // Notify progress observer (weak - observer lifecycle independent)
///         progressObserver?.onPlaybackStarted(duration: audioFile.duration)
///     }
/// }
///
/// // Monitor weak reference health
/// WeakInjectionMetrics.printWeakReferenceReport()
/// // Output:
/// // 🔗 Weak Reference Report
/// // ====================================
/// // Property             Active  Resolved  Deallocated
/// // delegate             true    true      false
/// // uiUpdateHandler      false   true      true
/// // analyticsCollector   true    true      false
/// // visualizer           true    true      false
/// // progressObserver     false   false     false
/// ```
@attached(peer, names: arbitrary)
public macro WeakInject(
    _ name: String? = nil,
    container: String = "default",
    autoResolve: Bool = true,
    onDeallocation: (() -> Void)? = nil,
    fallback: (() -> Any?)? = nil
) = #externalMacro(module: "SwinjectUtilityMacrosImplementation", type: "WeakInjectMacro")

// MARK: - Weak Injection Support Types

/// Weak reference states for tracking lifecycle
public enum WeakReferenceState: String, CaseIterable {
    case pending = "PENDING" // Not yet resolved
    case resolved = "RESOLVED" // Successfully resolved and active
    case deallocated = "DEALLOCATED" // Reference became nil due to deallocation
    case failed = "FAILED" // Resolution failed

    public var description: String {
        rawValue
    }
}

/// Individual weak property reference information
public struct WeakPropertyInfo {
    /// Property name
    public let propertyName: String

    /// Property type (without optional wrapper)
    public let propertyType: String

    /// Container name used for resolution
    public let containerName: String

    /// Service name (if named injection)
    public let serviceName: String?

    /// Whether auto-resolution is enabled
    public let autoResolve: Bool

    /// Current weak reference state
    public let state: WeakReferenceState

    /// When resolution was first attempted
    public let initialResolutionTime: Date?

    /// When reference was last accessed
    public let lastAccessTime: Date?

    /// When reference became nil (if deallocated)
    public let deallocationTime: Date?

    /// Number of times this reference has been resolved
    public let resolutionCount: Int

    /// Error encountered during resolution
    public let resolutionError: Error?

    /// Thread information for last access
    public let threadInfo: ThreadInfo?

    public init(
        propertyName: String,
        propertyType: String,
        containerName: String,
        serviceName: String? = nil,
        autoResolve: Bool = true,
        state: WeakReferenceState = .pending,
        initialResolutionTime: Date? = nil,
        lastAccessTime: Date? = nil,
        deallocationTime: Date? = nil,
        resolutionCount: Int = 0,
        resolutionError: Error? = nil,
        threadInfo: ThreadInfo? = nil
    ) {
        self.propertyName = propertyName
        self.propertyType = propertyType
        self.containerName = containerName
        self.serviceName = serviceName
        self.autoResolve = autoResolve
        self.state = state
        self.initialResolutionTime = initialResolutionTime
        self.lastAccessTime = lastAccessTime
        self.deallocationTime = deallocationTime
        self.resolutionCount = resolutionCount
        self.resolutionError = resolutionError
        self.threadInfo = threadInfo
    }
}

/// Comprehensive weak injection metrics
public struct WeakInjectionStats {
    /// Total number of weak properties registered
    public let totalWeakProperties: Int

    /// Number of properties with active (non-nil) references
    public let activeReferences: Int

    /// Number of properties that have been resolved at some point
    public let resolvedReferences: Int

    /// Number of references that became nil due to deallocation
    public let deallocatedReferences: Int

    /// Number of properties with resolution failures
    public let failedReferences: Int

    /// Average number of resolutions per property
    public let averageResolutionCount: Double

    /// Properties by state
    public let propertiesByState: [WeakReferenceState: Int]

    /// Container usage statistics
    public let containerUsage: [String: Int]

    /// Auto-resolve enabled vs disabled
    public let autoResolveUsage: [Bool: Int]

    /// Most common resolution errors
    public let commonErrors: [String: Int]

    /// Time range covered by these statistics
    public let timeRange: DateInterval

    public init(
        totalWeakProperties: Int,
        activeReferences: Int,
        resolvedReferences: Int,
        deallocatedReferences: Int,
        failedReferences: Int,
        averageResolutionCount: Double,
        propertiesByState: [WeakReferenceState: Int],
        containerUsage: [String: Int],
        autoResolveUsage: [Bool: Int],
        commonErrors: [String: Int],
        timeRange: DateInterval
    ) {
        self.totalWeakProperties = totalWeakProperties
        self.activeReferences = activeReferences
        self.resolvedReferences = resolvedReferences
        self.deallocatedReferences = deallocatedReferences
        self.failedReferences = failedReferences
        self.averageResolutionCount = averageResolutionCount
        self.propertiesByState = propertiesByState
        self.containerUsage = containerUsage
        self.autoResolveUsage = autoResolveUsage
        self.commonErrors = commonErrors
        self.timeRange = timeRange
    }
}

// MARK: - Weak Injection Metrics Manager

/// Thread-safe weak injection metrics tracking and reporting
public class WeakInjectionMetrics {
    private static var propertyRegistry: [String: WeakPropertyInfo] = [:]
    private static var accessHistory: [String: [WeakPropertyInfo]] = [:]
    private static let metricsQueue = DispatchQueue(label: "weak.injection.metrics", attributes: .concurrent)
    private static let maxHistoryPerProperty = 100 // Circular buffer size

    /// Registers a weak property for tracking
    public static func registerProperty(_ info: WeakPropertyInfo) {
        metricsQueue.async(flags: .barrier) {
            let key = "\(info.propertyName):\(info.propertyType)"
            self.propertyRegistry[key] = info
        }
    }

    /// Records a weak property access or state change
    public static func recordAccess(_ info: WeakPropertyInfo) {
        metricsQueue.async(flags: .barrier) {
            let key = "\(info.propertyName):\(info.propertyType)"
            self.propertyRegistry[key] = info

            self.accessHistory[key, default: []].append(info)

            // Maintain circular buffer
            if self.accessHistory[key]!.count > self.maxHistoryPerProperty {
                self.accessHistory[key]!.removeFirst()
            }
        }
    }

    /// Gets statistics for all weak properties
    public static func getStats() -> WeakInjectionStats {
        metricsQueue.sync {
            let properties = Array(propertyRegistry.values)
            let totalProperties = properties.count
            let activeReferences = properties.filter { $0.state == .resolved }.count
            let resolvedReferences = properties.filter { $0.resolutionCount > 0 }.count
            let deallocatedReferences = properties.filter { $0.state == .deallocated }.count
            let failedReferences = properties.filter { $0.state == .failed }.count

            let totalResolutions = properties.map { $0.resolutionCount }.reduce(0, +)
            let averageResolutionCount = totalProperties > 0 ? Double(totalResolutions) / Double(totalProperties) : 0.0

            // Calculate properties by state
            var propertiesByState: [WeakReferenceState: Int] = [:]
            for state in WeakReferenceState.allCases {
                propertiesByState[state] = properties.filter { $0.state == state }.count
            }

            // Calculate container usage
            let containerUsage = properties.reduce(into: [String: Int]()) { counts, property in
                counts[property.containerName, default: 0] += 1
            }

            // Calculate auto-resolve usage
            let autoResolveUsage = properties.reduce(into: [Bool: Int]()) { counts, property in
                counts[property.autoResolve, default: 0] += 1
            }

            // Calculate common errors
            let commonErrors = properties.compactMap { $0.resolutionError?.localizedDescription }
                .reduce(into: [String: Int]()) { counts, error in
                    counts[error, default: 0] += 1
                }

            // Calculate time range
            let allTimes = properties.compactMap { property in
                [property.initialResolutionTime, property.lastAccessTime, property.deallocationTime].compactMap { $0 }
            }.flatMap { $0 }

            let timeRange = DateInterval(
                start: allTimes.min() ?? Date(),
                end: allTimes.max() ?? Date()
            )

            return WeakInjectionStats(
                totalWeakProperties: totalProperties,
                activeReferences: activeReferences,
                resolvedReferences: resolvedReferences,
                deallocatedReferences: deallocatedReferences,
                failedReferences: failedReferences,
                averageResolutionCount: averageResolutionCount,
                propertiesByState: propertiesByState,
                containerUsage: containerUsage,
                autoResolveUsage: autoResolveUsage,
                commonErrors: commonErrors,
                timeRange: timeRange
            )
        }
    }

    /// Gets information for a specific property
    public static func getPropertyInfo(name: String, type: String) -> WeakPropertyInfo? {
        metricsQueue.sync {
            let key = "\(name):\(type)"
            return self.propertyRegistry[key]
        }
    }

    /// Gets all registered weak properties
    public static func getAllProperties() -> [WeakPropertyInfo] {
        metricsQueue.sync {
            Array(self.propertyRegistry.values)
        }
    }

    /// Prints a comprehensive weak reference report
    public static func printWeakReferenceReport() {
        let stats = getStats()
        let properties = getAllProperties()

        guard !properties.isEmpty else {
            print("🔗 No weak injection data available")
            return
        }

        print("\n🔗 Weak Reference Report")
        print("=" * 80)
        print(String(format: "%-30s %-12s %8s %10s %12s", "Property", "State", "Resolved", "Container", "AutoResolve"))
        print("-" * 80)

        for property in properties.sorted(by: { $0.propertyName < $1.propertyName }) {
            let resolvedCount = property.resolutionCount
            let autoResolveStr = property.autoResolve ? "Yes" : "No"

            print(String(
                format: "%-30s %-12s %8d %10s %12s",
                property.propertyName.suffix(30),
                property.state.description,
                resolvedCount,
                property.containerName.suffix(10),
                autoResolveStr
            ))
        }

        print("-" * 80)
        print("Summary:")
        print("  Total Properties: \(stats.totalWeakProperties)")
        print("  Active References: \(stats.activeReferences)")
        print("  Deallocated: \(stats.deallocatedReferences)")
        print("  Failed: \(stats.failedReferences)")
        print("  Average Resolutions: \(String(format: "%.1f", stats.averageResolutionCount))")
    }

    /// Gets properties that are currently active (non-nil)
    public static func getActiveProperties() -> [WeakPropertyInfo] {
        getAllProperties().filter { $0.state == .resolved }
    }

    /// Gets properties that have been deallocated
    public static func getDeallocatedProperties() -> [WeakPropertyInfo] {
        getAllProperties().filter { $0.state == .deallocated }
    }

    /// Gets properties that failed to resolve
    public static func getFailedProperties() -> [WeakPropertyInfo] {
        getAllProperties().filter { $0.state == .failed }
    }

    /// Clears all metrics data
    public static func reset() {
        metricsQueue.async(flags: .barrier) {
            self.propertyRegistry.removeAll()
            self.accessHistory.removeAll()
        }
    }

    /// Gets the percentage of references that are currently active
    public static func getActiveReferenceRate() -> Double {
        let stats = getStats()
        guard stats.totalWeakProperties > 0 else { return 0.0 }
        return Double(stats.activeReferences) / Double(stats.totalWeakProperties)
    }

    /// Gets the percentage of references that have been deallocated
    public static func getDeallocationRate() -> Double {
        let stats = getStats()
        guard stats.resolvedReferences > 0 else { return 0.0 }
        return Double(stats.deallocatedReferences) / Double(stats.resolvedReferences)
    }
}

// MARK: - Weak Injection Errors

/// Errors that can occur during weak dependency injection
public enum WeakInjectionError: Error, LocalizedError {
    case containerNotFound(containerName: String)
    case serviceNotRegistered(serviceName: String?, type: String)
    case resolutionFailed(type: String, underlyingError: Error?)
    case invalidWeakType(type: String, reason: String)
    case weakReferenceUnavailable(propertyName: String, type: String)

    public var errorDescription: String? {
        switch self {
        case .containerNotFound(let containerName):
            return "Container '\(containerName)' not found for weak injection"
        case .serviceNotRegistered(let serviceName, let type):
            let service = serviceName.map { " named '\($0)'" } ?? ""
            return "Service\(service) of type '\(type)' is not registered for weak injection"
        case .resolutionFailed(let type, let underlyingError):
            let underlying = underlyingError.map { " - \($0.localizedDescription)" } ?? ""
            return "Failed to resolve weak service of type '\(type)'\(underlying)"
        case .invalidWeakType(let type, let reason):
            return "Invalid type '\(type)' for weak injection: \(reason)"
        case .weakReferenceUnavailable(let propertyName, let type):
            return "Weak property '\(propertyName)' of type '\(type)' is no longer available"
        }
    }
}

// MARK: - String Extension for Pretty Printing

// String * operator moved to StringExtensions.swift

// MARK: - Thread Information Support
// Note: ThreadInfo is defined in PerformanceTracked.swift and shared across all macro types
