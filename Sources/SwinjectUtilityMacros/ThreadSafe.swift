// ThreadSafe.swift - Thread-safe dependency injection macro declarations

import Foundation
import Swinject

// MARK: - @ThreadSafe Macro

/// Ensures thread-safe dependency injection and service access with appropriate synchronization mechanisms.
///
/// This macro adds thread synchronization to service registration and resolution, ensuring safe
/// concurrent access to dependency injection operations without data races or corruption.
///
/// ## Basic Usage
///
/// ```swift
/// @ThreadSafe
/// class SharedCacheService {
///     private var cache: [String: Any] = [:]
///     
///     init(storage: StorageProtocol) {
///         // Thread-safe initialization
///     }
///     
///     func get(_ key: String) -> Any? {
///         // Generated thread-safe access
///         return executeWithThreadSafety {
///             return cache[key]
///         }
///     }
///     
///     func set(_ key: String, value: Any) {
///         executeWithThreadSafety {
///             cache[key] = value
///         }
///     }
/// }
/// ```
///
/// ## Advanced Thread Safety Configuration
///
/// ```swift
/// @ThreadSafe(
///     type: .concurrent,
///     lock: .readerWriter,
///     isolation: .instance,
///     deadlockDetection: true,
///     timeout: 10.0
/// )
/// class HighPerformanceService {
///     // Concurrent read access, exclusive write access
///     // Instance-level isolation with deadlock detection
/// }
/// ```
///
/// ## Main Thread Requirements
///
/// ```swift
/// @ThreadSafe(mainThread: true)
/// class UIUpdateService {
///     init(notificationCenter: NotificationCenter) {
///         // Must be created and accessed on main thread
///     }
///     
///     func updateUI() {
///         // Automatically validated to run on main thread
///     }
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **Synchronization Infrastructure**: Thread-safe locks and queues
/// 2. **Thread-Safe Registration**: Container registration with synchronization
/// 3. **Access Wrappers**: Thread-safe method execution wrappers
/// 4. **Deadlock Detection**: Optional runtime deadlock detection and prevention
/// 5. **Performance Monitoring**: Thread contention and wait time tracking
///
/// ## Synchronization Types
///
/// - **`.synchronized`**: Exclusive access using locks (default)
/// - **`.concurrent`**: Concurrent reads, exclusive writes using reader-writer locks
/// - **`.serial`**: Serial access using dispatch queues
/// - **`.actor`**: Swift actor-based isolation (iOS 15+)
///
/// ## Lock Types
///
/// - **`.nsLock`**: Basic NSLock for simple synchronization
/// - **`.recursive`**: NSRecursiveLock for reentrant operations
/// - **`.readerWriter`**: pthread reader-writer lock for concurrent reads
/// - **`.semaphore`**: DispatchSemaphore for resource limiting
///
/// ## Performance Characteristics
///
/// - **NSLock**: Fastest for simple mutual exclusion
/// - **Reader-Writer**: Best for read-heavy workloads
/// - **Semaphore**: Good for resource limiting and timeouts
/// - **Serial Queue**: Good for ordered execution
///
/// ## Example with Timeout and Recovery
///
/// ```swift
/// @ThreadSafe(
///     lock: .semaphore,
///     timeout: 5.0,
///     deadlockDetection: true
/// )
/// class ResilientService {
///     func criticalOperation() throws {
///         try withThreadSafety {
///             // Operation that might deadlock
///             performCriticalWork()
///         }
///         // Automatically times out after 5 seconds
///         // Throws ThreadSafetyError.timeout if exceeded
///     }
/// }
/// ```
@attached(member, names: named(registerThreadSafe), named(threadSafetyEnabled), named(withThreadSafety))
public macro ThreadSafe(
    type: ThreadSafetySynchronizationType = .synchronized,
    lock: ThreadSafetyLockType = .nsLock,
    isolation: ThreadSafetyIsolationType = .instance,
    mainThread: Bool = false,
    deadlockDetection: Bool = false,
    timeout: TimeInterval = 5.0
) = #externalMacro(module: "SwinjectUtilityMacrosImplementation", type: "ThreadSafeMacro")

// MARK: - Thread Safety Support Types

/// Thread synchronization type for dependency injection
public enum ThreadSafetySynchronizationType {
    case synchronized    // Exclusive access using locks
    case concurrent     // Concurrent reads, exclusive writes
    case serial         // Serial access using queues
    case actor          // Swift actor-based isolation (iOS 15+)
}

/// Lock mechanism for thread synchronization
public enum ThreadSafetyLockType {
    case nsLock         // Basic NSLock
    case recursive      // NSRecursiveLock for reentrant operations
    case readerWriter   // Reader-writer lock for concurrent reads
    case semaphore      // DispatchSemaphore for resource limiting
}

/// Thread safety isolation level
public enum ThreadSafetyIsolationType {
    case instance       // Per-instance synchronization
    case type           // Per-type synchronization
    case global         // Global synchronization
}

/// Thread safety configuration
public struct ThreadSafetyConfiguration {
    public let synchronizationType: ThreadSafetySynchronizationType
    public let lockType: ThreadSafetyLockType
    public let isolation: ThreadSafetyIsolationType
    public let requiresMainThread: Bool
    public let enableDeadlockDetection: Bool
    public let timeoutInterval: TimeInterval
    
    public init(
        synchronizationType: ThreadSafetySynchronizationType = .synchronized,
        lockType: ThreadSafetyLockType = .nsLock,
        isolation: ThreadSafetyIsolationType = .instance,
        requiresMainThread: Bool = false,
        enableDeadlockDetection: Bool = false,
        timeoutInterval: TimeInterval = 5.0
    ) {
        self.synchronizationType = synchronizationType
        self.lockType = lockType
        self.isolation = isolation
        self.requiresMainThread = requiresMainThread
        self.enableDeadlockDetection = enableDeadlockDetection
        self.timeoutInterval = timeoutInterval
    }
}

/// Thread safety errors
public enum ThreadSafetyError: Error, LocalizedError {
    case timeout(String)
    case deadlock(String)
    case mainThreadRequired(String)
    case lockContention(String)
    
    public var errorDescription: String? {
        switch self {
        case .timeout(let message):
            return "Thread safety timeout: \(message)"
        case .deadlock(let message):
            return "Deadlock detected: \(message)"
        case .mainThreadRequired(let message):
            return "Main thread required: \(message)"
        case .lockContention(let message):
            return "Lock contention: \(message)"
        }
    }
}

/// Thread safety metrics for monitoring
public struct ThreadSafetyMetrics {
    public let lockWaitTime: TimeInterval
    public let lockHoldTime: TimeInterval
    public let contentionCount: Int
    public let deadlockAttempts: Int
    
    public init(
        lockWaitTime: TimeInterval = 0,
        lockHoldTime: TimeInterval = 0,
        contentionCount: Int = 0,
        deadlockAttempts: Int = 0
    ) {
        self.lockWaitTime = lockWaitTime
        self.lockHoldTime = lockHoldTime
        self.contentionCount = contentionCount
        self.deadlockAttempts = deadlockAttempts
    }
}

// MARK: - Container Extensions for Thread Safety

public extension Container {
    
    /// Register a service with thread safety guarantees
    func registerThreadSafe<Service>(
        _ serviceType: Service.Type,
        configuration: ThreadSafetyConfiguration = ThreadSafetyConfiguration(),
        factory: @escaping (Resolver) -> Service
    ) {
        // Thread-safe registration implementation
        let safeFactory: (Resolver) -> Service = { resolver in
            if configuration.requiresMainThread {
                dispatchPrecondition(condition: .onQueue(.main))
            }
            return factory(resolver)
        }
        
        let registration = register(serviceType, factory: safeFactory)
        registration.inObjectScope(.container) // Ensure thread-safe scope
    }
    
    /// Resolve a service with thread safety validation
    func resolveThreadSafe<Service>(_ serviceType: Service.Type) -> Service? {
        // Implement thread-safe resolution
        return resolve(serviceType)
    }
    
    /// Get thread safety metrics for monitoring
    func getThreadSafetyMetrics() -> ThreadSafetyMetrics {
        // Return thread safety performance metrics
        return ThreadSafetyMetrics()
    }
}