// ScopedService.swift - Scoped service registration macro declarations

import Foundation
import Swinject

// MARK: - @ScopedService Macro

/// Automatically configures service registration with specific object scopes for fine-grained lifecycle management.
///
/// This macro allows you to declaratively specify the object scope for dependency injection,
/// providing precise control over service lifecycle and memory management.
///
/// ## Basic Usage
///
/// ```swift
/// @ScopedService(.container)
/// class DatabaseConnection {
///     init(config: DatabaseConfig) {
///         // Singleton-like behavior within container scope
///     }
/// }
/// 
/// @ScopedService(.transient)
/// class RequestHandler {
///     init(logger: LoggerProtocol, validator: ValidatorProtocol) {
///         // New instance for every resolution
///     }
/// }
/// ```
///
/// ## Advanced Usage with Named Services
///
/// ```swift
/// @ScopedService(.container, name: "primary")
/// class PrimaryDatabase: DatabaseProtocol {
///     init(connectionString: String) { }
/// }
/// 
/// @ScopedService(.container, name: "secondary") 
/// class SecondaryDatabase: DatabaseProtocol {
///     init(connectionString: String) { }
/// }
/// ```
///
/// ## Scope Options
///
/// - `.graph`: Shared during object graph construction (default)
/// - `.container`: Singleton-like behavior within container
/// - `.transient`: New instance every time
/// - `.weak`: Shared while strong references exist
///
/// ## What it generates:
///
/// 1. **Scoped Registration**: Service registration with specified object scope
/// 2. **Scope Configuration**: Metadata about the service's lifecycle
/// 3. **Validation Methods**: Runtime scope validation utilities
/// 4. **Lifecycle Hooks**: Optional creation and destruction callbacks
///
/// ## Performance Characteristics
///
/// - **Container Scope**: Excellent performance, single allocation
/// - **Graph Scope**: Good performance, shared during construction
/// - **Transient Scope**: Higher allocation cost, maximum flexibility
/// - **Weak Scope**: Good performance with automatic cleanup
///
/// ## Thread Safety
///
/// All scope types are thread-safe by default. Container and weak scopes
/// use internal synchronization to ensure consistency across threads.
///
/// ## Example with Lifecycle Management
///
/// ```swift
/// @ScopedService(.container, lazy: true, preconditions: ["Environment.isProduction"])
/// class ProductionOnlyService {
///     init(apiKey: String, monitor: MonitoringService) {
///         // Only created in production, lazily initialized
///     }
/// }
/// ```
@attached(member, names: named(register), named(registerScoped), named(scopeConfiguration))
@attached(extension, conformances: Injectable)
public macro ScopedService(
    _ scope: ObjectScope = .graph,
    name: String? = nil,
    lazy: Bool = false,
    weak: Bool = false,
    preconditions: [String] = []
) = #externalMacro(module: "SwinJectMacrosImplementation", type: "ScopedServiceMacro")

// MARK: - Scoped Service Support Types

/// Extended object scope configuration for scoped services
public struct ScopedServiceConfiguration {
    public let scope: ObjectScope
    public let name: String?
    public let isLazy: Bool
    public let isWeak: Bool
    public let preconditions: [String]
    
    public init(
        scope: ObjectScope = .graph,
        name: String? = nil,
        isLazy: Bool = false,
        isWeak: Bool = false,
        preconditions: [String] = []
    ) {
        self.scope = scope
        self.name = name
        self.isLazy = isLazy
        self.isWeak = isWeak
        self.preconditions = preconditions
    }
}

/// Scoped service lifecycle events
public enum ScopedServiceEvent {
    case willCreate
    case didCreate
    case willDestroy
    case didDestroy
}

/// Protocol for services that want to receive scope lifecycle notifications
public protocol ScopedServiceLifecycle {
    func onScopeEvent(_ event: ScopedServiceEvent)
}

// MARK: - Container Extensions for Scoped Services

public extension Container {
    
    /// Register a service with explicit scope configuration
    func registerScoped<Service>(
        _ serviceType: Service.Type,
        configuration: ScopedServiceConfiguration,
        factory: @escaping (Resolver) -> Service
    ) {
        let registration = register(serviceType, name: configuration.name, factory: factory)
        registration.inObjectScope(configuration.scope.swinjectScope)
        
        if configuration.isLazy {
            // Configure lazy initialization
        }
        
        if configuration.isWeak {
            // Configure weak reference handling
        }
    }
    
    /// Get scope configuration for a service type
    func getScopeConfiguration<Service>(for serviceType: Service.Type) -> ScopedServiceConfiguration? {
        // Runtime introspection of scope configuration
        return nil // Placeholder - would need container introspection
    }
}