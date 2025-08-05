// Injectable.swift - Core dependency injection macro declarations
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import Swinject

// MARK: - @Injectable Macro

/// Automatically generates dependency injection registration code for classes and structs.
///
/// This macro analyzes the initializer parameters of a class or struct and creates appropriate
/// container registration methods for Swinject. Dependencies are automatically detected based on
/// naming conventions and type analysis.
///
/// ## Features
/// - Automatic dependency detection from initializer parameters
/// - Type-safe container registration generation
/// - Support for optional dependencies and default parameters
/// - Generic type handling with constraint preservation
/// - Configurable object scopes (graph, container, transient, weak)
/// - Named service registration support
///
/// ## Usage
/// ```swift
/// @Injectable
/// class UserService {
///     init(apiClient: APIClient, database: Database) {
///         self.apiClient = apiClient
///         self.database = database
///     }
/// }
///
/// // Generates:
/// extension UserService: Injectable {
///     static func register(in container: Container) {
///         container.register(UserService.self) { resolver in
///             UserService(
///                 apiClient: resolver.synchronizedResolve(APIClient.self)!,
///                 database: resolver.synchronizedResolve(Database.self)!
///             )
///         }
///     }
/// }
/// ```
///
/// ## Advanced Usage with Scoping
/// ```swift
/// @Injectable(scope: .container, name: "userService")
/// class UserService {
///     init(apiClient: APIClient) {
///         self.apiClient = apiClient
///     }
/// }
/// ```
///
/// ## Generic Types
/// ```swift
/// @Injectable
/// class Repository<T: Codable> {
///     init(database: Database) {
///         self.database = database
///     }
/// }
/// ```
///
/// - Important: The class or struct must have exactly one public initializer.
/// - Note: Service dependencies are automatically detected using naming conventions.
/// - Warning: Circular dependencies will be detected at compile time and generate errors.
@attached(member, names: named(register))
@attached(extension, conformances: Injectable)
public macro Injectable(
    scope: ObjectScope = .graph,
    name: String? = nil
) = #externalMacro(module: "SwinjectMacrosImplementation", type: "InjectableMacro")

// MARK: - @AutoRegister Macro

/// Automatically registers multiple services in a container using batch registration.
///
/// This macro can be applied to assemblies, containers, or service collections to
/// automatically register all marked services in one operation.
///
/// ## Usage
/// ```swift
/// @AutoRegister
/// class ServiceAssembly: Assembly {
///     func assemble(container: Container) {
///         // All @Injectable services will be automatically registered
///     }
/// }
/// ```
///
/// ## Container Extension
/// ```swift
/// extension Container {
///     @AutoRegister
///     func registerServices() {
///         // Batch registration of all injectable services
///     }
/// }
/// ```
@attached(member, names: prefixed(register))
public macro AutoRegister() = #externalMacro(module: "SwinjectMacrosImplementation", type: "AutoRegisterMacro")

// MARK: - Object Scope Configuration

/// Object scope configuration for dependency injection
public enum ObjectScope {
    /// Object graph scope - shared during object graph construction (default)
    case graph
    /// Container scope - singleton-like behavior within container
    case container
    /// Transient scope - new instance every time
    case transient
    /// Weak scope - shared while strong references exist
    case weak

    /// Convert to Swinject ObjectScope
    var swinjectScope: Swinject.ObjectScope {
        switch self {
        case .graph:
            .graph
        case .container:
            .container
        case .transient:
            .transient
        case .weak:
            .weak
        }
    }
}

// MARK: - Dependency Information

/// Information about a detected dependency
public struct DependencyInfo {
    /// Parameter name
    public let name: String
    /// Parameter type
    public let type: String
    /// Whether the dependency is optional
    public let isOptional: Bool
    /// Default value if present
    public let defaultValue: String?
    /// Suggested scope for this dependency
    public let scopeHint: ObjectScope?

    public init(
        name: String,
        type: String,
        isOptional: Bool = false,
        defaultValue: String? = nil,
        scopeHint: ObjectScope? = nil
    ) {
        self.name = name
        self.type = type
        self.isOptional = isOptional
        self.defaultValue = defaultValue
        self.scopeHint = scopeHint
    }
}

// MARK: - Service Registration Helpers

/// Helper methods for service registration
extension Container {

    /// Register a service with automatic dependency resolution
    public func registerService<Service>(
        _ serviceType: Service.Type,
        scope: ObjectScope = .graph,
        name: String? = nil,
        factory: @escaping (Resolver) -> Service
    ) {
        let registration = register(serviceType, name: name, factory: factory)
        registration.inObjectScope(scope.swinjectScope)
    }

    /// Register a service with completion handler for circular dependencies
    public func registerService<Service>(
        _ serviceType: Service.Type,
        scope: ObjectScope = .graph,
        name: String? = nil,
        factory: @escaping (Resolver) -> Service,
        initCompleted: @escaping (Resolver, Service) -> Void
    ) {
        let registration = register(serviceType, name: name, factory: factory)
        registration.inObjectScope(scope.swinjectScope)
        registration.initCompleted(initCompleted)
    }
}

// MARK: - Assembly Integration

/// Protocol for assemblies that support auto-registration
public protocol AutoRegisterAssembly: Assembly {
    /// Called after all auto-registration is complete
    func didCompleteAutoRegistration(in container: Container)
}

extension AutoRegisterAssembly {
    /// Default implementation - no additional setup needed
    public func didCompleteAutoRegistration(in container: Container) {}
}
