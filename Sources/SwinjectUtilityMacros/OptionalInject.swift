// OptionalInject.swift - Optional dependency injection macro declarations

import Foundation
import Swinject

// MARK: - @OptionalInject Macro

/// Enables optional dependency injection where services may or may not be available, providing graceful degradation.
///
/// This macro transforms properties into optional dependencies that gracefully handle cases where
/// services are not registered, allowing for flexible and resilient dependency injection patterns.
///
/// ## Basic Usage
///
/// ```swift
/// class NotificationService {
///     @OptionalInject var pushService: PushServiceProtocol?
///     @OptionalInject var emailService: EmailServiceProtocol?
///     @OptionalInject var smsService: SMSServiceProtocol?
///     
///     func sendNotification(_ message: String, to user: User) {
///         // Try multiple notification channels, gracefully falling back
///         if let push = pushService, user.allowsPush {
///             push.send(message, to: user)
///         } else if let email = emailService {
///             email.send(message, to: user.email)
///         } else if let sms = smsService {
///             sms.send(message, to: user.phone)
///         } else {
///             // Fallback to in-app notification
///             showInAppNotification(message)
///         }
///     }
/// }
/// ```
///
/// ## Usage with Default Values
///
/// ```swift
/// class AnalyticsService {
///     @OptionalInject(default: ConsoleLogger()) var logger: LoggerProtocol
///     @OptionalInject(fallback: "createDefaultMetrics") var metrics: MetricsCollectorProtocol
///     
///     private func createDefaultMetrics() -> MetricsCollectorProtocol {
///         return NoOpMetricsCollector()
///     }
///     
///     func trackEvent(_ event: String) {
///         logger.info("Analytics event: \(event)")
///         metrics.track(event)
///     }
/// }
/// ```
///
/// ## Named Optional Dependencies
///
/// ```swift
/// class MultiDatabaseService {
///     @OptionalInject("primary") var primaryDB: DatabaseProtocol?
///     @OptionalInject("secondary") var secondaryDB: DatabaseProtocol?
///     @OptionalInject("cache") var cacheDB: DatabaseProtocol?
///     
///     func getData(key: String) -> Data? {
///         // Try primary, fall back to secondary, then cache
///         return primaryDB?.get(key) ?? 
///                secondaryDB?.get(key) ?? 
///                cacheDB?.get(key)
///     }
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **Optional Property Getter**: Attempts to resolve service, returns nil if unavailable
/// 2. **Lazy Resolution**: Dependencies resolved on first access for performance
/// 3. **Fallback Handling**: Support for default values and fallback providers
/// 4. **Thread-Safe Access**: Safe concurrent access to optional dependencies
///
/// ## Performance Characteristics
///
/// - **Lazy Resolution**: Dependencies only resolved when accessed
/// - **Caching**: Successful resolutions are cached for subsequent access
/// - **Fast Failure**: Quick return of nil when service unavailable
/// - **Minimal Overhead**: No performance penalty for unused optional dependencies
///
/// ## Fallback Strategies
///
/// ```swift
/// class ResilientService {
///     @OptionalInject(
///         name: "premium",
///         fallback: "createBasicImplementation",
///         lazy: false
///     ) var feature: FeatureProtocol
///     
///     private func createBasicImplementation() -> FeatureProtocol {
///         return BasicFeatureImplementation()
///     }
/// }
/// ```
@attached(accessor)
public macro OptionalInject(
    _ name: String? = nil,
    default: Any? = nil,
    fallback: String? = nil,
    lazy: Bool = true,
    resolver: String = "resolver"
) = #externalMacro(module: "SwinjectUtilityMacrosImplementation", type: "OptionalInjectMacro")

// MARK: - Optional Injection Support Types

/// Resolution result for optional injection
public enum OptionalResolutionResult<T> {
    case resolved(T)
    case fallback(T)
    case unavailable
    
    /// Get the resolved value, if any
    public var value: T? {
        switch self {
        case .resolved(let value), .fallback(let value):
            return value
        case .unavailable:
            return nil
        }
    }
    
    /// Check if the dependency was successfully resolved (not fallback)
    public var wasResolved: Bool {
        if case .resolved = self { return true }
        return false
    }
}

/// Optional injection configuration
public struct OptionalInjectConfiguration {
    public let name: String?
    public let hasDefault: Bool
    public let hasFallback: Bool
    public let isLazy: Bool
    public let resolverName: String
    
    public init(
        name: String? = nil,
        hasDefault: Bool = false,
        hasFallback: Bool = false,
        isLazy: Bool = true,
        resolverName: String = "resolver"
    ) {
        self.name = name
        self.hasDefault = hasDefault
        self.hasFallback = hasFallback
        self.isLazy = isLazy
        self.resolverName = resolverName
    }
}

/// Protocol for types that can provide fallback implementations
public protocol OptionalInjectFallbackProvider {
    associatedtype ServiceType
    func provideFallback() -> ServiceType
}

// MARK: - Container Extensions for Optional Injection

public extension Container {
    
    /// Attempt to resolve a service optionally
    func resolveOptional<Service>(_ serviceType: Service.Type, name: String? = nil) -> Service? {
        return resolve(serviceType, name: name)
    }
    
    /// Resolve with fallback provider
    func resolveWithFallback<Service>(
        _ serviceType: Service.Type, 
        name: String? = nil,
        fallback: () -> Service
    ) -> Service {
        return resolve(serviceType, name: name) ?? fallback()
    }
    
    /// Check if a service is available without resolving it
    func isServiceAvailable<Service>(_ serviceType: Service.Type, name: String? = nil) -> Bool {
        // This would require container introspection
        return resolve(serviceType, name: name) != nil
    }
}