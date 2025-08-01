// Named.swift - Named service registration macro declarations

import Foundation
import Swinject

// MARK: - @Named Macro

/// Enables named service registration for scenarios where multiple implementations of the same protocol need to be distinguished.
///
/// This macro allows you to register multiple implementations of the same service type under different names,
/// enabling flexible service selection and implementation strategies.
///
/// ## Basic Usage
///
/// ```swift
/// @Named("primary")
/// class PrimaryDatabase: DatabaseProtocol {
///     init(connectionString: String) {
///         // Primary database implementation
///     }
/// }
/// 
/// @Named("secondary")
/// class SecondaryDatabase: DatabaseProtocol {
///     init(connectionString: String) {
///         // Secondary/backup database implementation
///     }
/// }
/// ```
///
/// ## Multiple Names and Aliases
///
/// ```swift
/// @Named(
///     names: ["redis", "cache", "fast-storage"],
///     aliases: ["memory", "temp"],
///     default: true,
///     priority: 10
/// )
/// class RedisCache: CacheProtocol {
///     init(redisClient: RedisClient) {
///         // Redis-based caching implementation
///     }
/// }
/// ```
///
/// ## Protocol-Based Named Services
///
/// ```swift
/// @Named("http", protocol: "NetworkClientProtocol")
/// class HTTPClient: NetworkClientProtocol {
///     func request(_ url: URL) async throws -> Data { }
/// }
/// 
/// @Named("websocket", protocol: "NetworkClientProtocol") 
/// class WebSocketClient: NetworkClientProtocol {
///     func request(_ url: URL) async throws -> Data { }
/// }
/// ```
///
/// ## Usage in Client Code
///
/// ```swift
/// class ApiService {
///     init(
///         @Named("primary") primaryDB: DatabaseProtocol,
///         @Named("secondary") secondaryDB: DatabaseProtocol,
///         @Named("redis") cache: CacheProtocol
///     ) {
///         // Named dependencies injected automatically
///     }
/// }
/// 
/// // Or resolve explicitly:
/// let primaryDB = container.resolve(DatabaseProtocol.self, name: "primary")
/// let cache = container.resolve(CacheProtocol.self, name: "redis")
/// ```
///
/// ## What it generates:
///
/// 1. **Named Registration**: Service registration with specified names
/// 2. **Alias Registration**: Additional name aliases for the same service
/// 3. **Default Registration**: Optional default implementation registration
/// 4. **Name Validation**: Runtime validation of service names
/// 5. **Resolution Helpers**: Convenience methods for named resolution
///
/// ## Advanced Features
///
/// ### Priority-Based Selection
/// ```swift
/// @Named("payment-gateway", priority: 100)
/// class PremiumPaymentGateway: PaymentGatewayProtocol { }
/// 
/// @Named("payment-gateway", priority: 50)
/// class BasicPaymentGateway: PaymentGatewayProtocol { }
/// 
/// // Higher priority service is preferred when multiple services share a name
/// ```
///
/// ### Conditional Registration
/// ```swift
/// @Named("analytics", condition: "Environment.isProduction")
/// class ProductionAnalytics: AnalyticsProtocol { }
/// 
/// @Named("analytics", condition: "Environment.isDevelopment")
/// class DevelopmentAnalytics: AnalyticsProtocol { }
/// ```
///
/// ### Scoped Named Services
/// ```swift
/// @Named("session-cache", scope: .container)
/// class SessionCache: CacheProtocol {
///     // Singleton session cache
/// }
/// 
/// @Named("request-cache", scope: .transient)
/// class RequestCache: CacheProtocol {
///     // New cache per request
/// }
/// ```
@attached(member, names: named(registerNamed), named(serviceName), named(isValidName))
public macro Named(
    _ name: String,
    names: [String] = [],
    protocol protocolType: String? = nil,
    scope: ObjectScope = .graph,
    default: Bool = false,
    aliases: [String] = [],
    priority: Int = 0
) = #externalMacro(module: "SwinJectMacrosImplementation", type: "NamedMacro")

// MARK: - Named Service Support Types

/// Named service configuration
public struct NamedServiceConfiguration {
    public let names: [String]
    public let protocolType: String?
    public let scope: ObjectScope
    public let isDefault: Bool
    public let aliases: [String]
    public let priority: Int
    
    public init(
        names: [String],
        protocolType: String? = nil,
        scope: ObjectScope = .graph,
        isDefault: Bool = false,
        aliases: [String] = [],
        priority: Int = 0
    ) {
        self.names = names
        self.protocolType = protocolType
        self.scope = scope
        self.isDefault = isDefault
        self.aliases = aliases
        self.priority = priority
    }
    
    /// All names including aliases
    public var allNames: [String] {
        return names + aliases
    }
    
    /// Primary name (first in names array)
    public var primaryName: String {
        return names.first ?? ""
    }
}

/// Named service registry for runtime introspection
public class NamedServiceRegistry {
    private static var registrations: [String: [NamedServiceConfiguration]] = [:]
    private static let lock = NSLock()
    
    /// Register a named service configuration
    public static func register(_ configuration: NamedServiceConfiguration, for typeName: String) {
        lock.lock()
        defer { lock.unlock() }
        
        if registrations[typeName] == nil {
            registrations[typeName] = []
        }
        registrations[typeName]?.append(configuration)
    }
    
    /// Get all configurations for a service type
    public static func getConfigurations(for typeName: String) -> [NamedServiceConfiguration] {
        lock.lock()
        defer { lock.unlock() }
        return registrations[typeName] ?? []
    }
    
    /// Find configuration by name
    public static func findConfiguration(name: String, for typeName: String) -> NamedServiceConfiguration? {
        let configurations = getConfigurations(for: typeName)
        return configurations.first { config in
            config.allNames.contains(name)
        }
    }
    
    /// Get all registered service names
    public static func getAllNames(for typeName: String) -> [String] {
        let configurations = getConfigurations(for: typeName)
        return configurations.flatMap { $0.allNames }
    }
}

/// Named service resolution strategy
public enum NamedResolutionStrategy {
    case exact          // Must match exact name
    case fuzzy          // Allow partial matches
    case priority       // Use highest priority service
    case fallback       // Try exact, then priority, then default
}

// MARK: - Container Extensions for Named Services

public extension Container {
    
    /// Register a service with multiple names
    func registerNamed<Service>(
        _ serviceType: Service.Type,
        configuration: NamedServiceConfiguration,
        factory: @escaping (Resolver) -> Service
    ) {
        // Register with primary name
        if let primaryName = configuration.names.first {
            let registration = register(serviceType, name: primaryName, factory: factory)
            registration.inObjectScope(configuration.scope.swinjectScope)
        }
        
        // Register aliases
        for alias in configuration.aliases {
            let registration = register(serviceType, name: alias) { resolver in
                // Resolve via primary name
                return resolver.resolve(serviceType, name: configuration.primaryName)!
            }
            registration.inObjectScope(configuration.scope.swinjectScope)
        }
        
        // Register as default if specified
        if configuration.isDefault {
            let registration = register(serviceType, factory: factory)
            registration.inObjectScope(configuration.scope.swinjectScope)
        }
    }
    
    /// Resolve service by name with fallback strategy
    func resolveNamed<Service>(
        _ serviceType: Service.Type,
        name: String,
        strategy: NamedResolutionStrategy = .exact
    ) -> Service? {
        switch strategy {
        case .exact:
            return resolve(serviceType, name: name)
            
        case .priority:
            // Find highest priority service with this name
            let typeName = String(describing: serviceType)
            let configurations = NamedServiceRegistry.getConfigurations(for: typeName)
            let matchingConfigs = configurations.filter { $0.allNames.contains(name) }
            let highestPriority = matchingConfigs.max(by: { $0.priority < $1.priority })
            
            if let config = highestPriority {
                return resolve(serviceType, name: config.primaryName)
            }
            return nil
            
        case .fallback:
            // Try exact match first, then priority, then default
            if let exact = resolve(serviceType, name: name) {
                return exact
            }
            if let priority = resolveNamed(serviceType, name: name, strategy: .priority) {
                return priority
            }
            return resolve(serviceType) // Default registration
            
        case .fuzzy:
            // Find names that contain the search term
            let typeName = String(describing: serviceType)
            let allNames = NamedServiceRegistry.getAllNames(for: typeName)
            let fuzzyMatches = allNames.filter { $0.lowercased().contains(name.lowercased()) }
            
            for match in fuzzyMatches {
                if let service = resolve(serviceType, name: match) {
                    return service
                }
            }
            return nil
        }
    }
    
    /// Get all registered names for a service type
    func getRegisteredNames<Service>(for serviceType: Service.Type) -> [String] {
        let typeName = String(describing: serviceType)
        return NamedServiceRegistry.getAllNames(for: typeName)
    }
    
    /// Check if a named service is available
    func isNamedServiceAvailable<Service>(_ serviceType: Service.Type, name: String) -> Bool {
        return resolve(serviceType, name: name) != nil
    }
}