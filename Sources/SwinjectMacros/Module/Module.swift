// Module.swift - Module system for dependency injection
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import Swinject

/// Marks a type as a module that contains service registrations
///
/// The `@Module` macro enables modular organization of dependency injection configurations.
/// It provides compile-time validation, automatic service discovery, and module composition.
///
/// ## Basic Usage
/// ```swift
/// @Module
/// struct NetworkModule {
///     static func configure(_ container: Container) {
///         container.register(HTTPClient.self) { _ in
///             URLSessionHTTPClient()
///         }
///     }
/// }
/// ```
///
/// ## Named Module
/// ```swift
/// @Module(name: "Network", priority: 100)
/// struct NetworkModule {
///     static func configure(_ container: Container) {
///         // Service registrations
///     }
/// }
/// ```
///
/// ## Module Composition
/// ```swift
/// @Module
/// struct AppModule {
///     @Include(NetworkModule.self)
///     @Include(DatabaseModule.self)
///     @Include(UIModule.self)
///
///     static func configure(_ container: Container) {
///         // Additional app-level registrations
///     }
/// }
/// ```
@attached(
    extension,
    conformances: ModuleProtocol,
    names: named(name),
    named(priority),
    named(dependencies),
    named(exports),
    named(configure),
    named(register)
)
@attached(member, names: named(name), named(priority), named(dependencies), named(exports))
public macro Module(
    name: String? = nil,
    priority: Int = 0,
    dependencies: [Any.Type] = [],
    exports: [Any.Type] = []
) = #externalMacro(
    module: "SwinjectMacrosImplementation",
    type: "ModuleMacro"
)

/// Includes another module's configuration in the current module
///
/// ## Usage
/// ```swift
/// @Module
/// struct AppModule {
///     @Include(UserModule.self)
///     @Include(PaymentModule.self, condition: .featureFlag("payments_enabled"))
/// }
/// ```
@attached(peer)
public macro Include(
    _ module: Any.Type,
    condition: ModuleCondition = .always
) = #externalMacro(
    module: "SwinjectMacrosImplementation",
    type: "IncludeMacro"
)

/// Marks a protocol as a module interface that can be used across module boundaries
///
/// ## Usage
/// ```swift
/// @ModuleInterface
/// protocol UserServiceInterface {
///     func getUser(id: String) async throws -> User
/// }
/// ```
@attached(extension, names: named(moduleInterfaceIdentifier))
public macro ModuleInterface() = #externalMacro(
    module: "SwinjectMacrosImplementation",
    type: "ModuleInterfaceMacro"
)

/// Provides a service registration within a module
///
/// ## Usage
/// ```swift
/// @Module
/// struct DataModule {
///     @Provides
///     static func database() -> Database {
///         return SQLiteDatabase()
///     }
///
///     @Provides(scope: .singleton)
///     static func cache() -> Cache {
///         return InMemoryCache()
///     }
/// }
/// ```
@attached(peer)
public macro Provides(
    scope: ObjectScope = .graph,
    name: String? = nil,
    implements: Any.Type? = nil
) = #externalMacro(
    module: "SwinjectMacrosImplementation",
    type: "ProvidesMacro"
)

/// Exports a service from a module for use by other modules
///
/// ## Usage
/// ```swift
/// @Module
/// struct UserModule {
///     @Export
///     static var userService: UserServiceInterface {
///         // Return the service instance
///     }
/// }
/// ```
@attached(peer)
public macro Export(
    as interfaceType: Any.Type? = nil
) = #externalMacro(
    module: "SwinjectMacrosImplementation",
    type: "ExportMacro"
)

/// Imports a service from another module
///
/// ## Usage
/// ```swift
/// @Module
/// struct OrderModule {
///     @Import(from: UserModule.self)
///     static var userService: UserServiceInterface
/// }
/// ```
@attached(accessor)
public macro Import(
    from module: Any.Type,
    name: String? = nil
) = #externalMacro(
    module: "SwinjectMacrosImplementation",
    type: "ImportMacro"
)

// MARK: - Module System Types

/// Protocol that all modules must conform to
public protocol ModuleProtocol {
    /// The unique name of the module
    static var name: String { get }

    /// The priority for module initialization (higher = earlier)
    static var priority: Int { get }

    /// Other modules this module depends on
    static var dependencies: [ModuleProtocol.Type] { get }

    /// Services this module exports for other modules
    static var exports: [Any.Type] { get }

    /// Configures the module's services in the container
    static func configure(_ container: Container)

    /// Registers the module in the module system
    static func register(in system: ModuleSystem)
}

/// Default implementation for ModuleProtocol
extension ModuleProtocol {
    public static var name: String {
        String(describing: self)
    }

    public static var priority: Int { 0 }

    public static var dependencies: [ModuleProtocol.Type] { [] }

    public static var exports: [Any.Type] { [] }

    public static func register(in system: ModuleSystem) {
        system.register(module: self)
    }
}

/// Conditions for including modules
public enum ModuleCondition {
    /// Always include the module
    case always

    /// Include only in debug builds
    case debug

    /// Include only in release builds
    case release

    /// Include based on a feature flag
    case featureFlag(String)

    /// Include based on a custom condition
    case custom(() -> Bool)

    /// Evaluates whether the condition is met
    public var isMet: Bool {
        switch self {
        case .always:
            return true
        case .debug:
            #if DEBUG
                return true
            #else
                return false
            #endif
        case .release:
            #if DEBUG
                return false
            #else
                return true
            #endif
        case let .featureFlag(flag):
            return FeatureFlags.isEnabled(flag)
        case let .custom(condition):
            return condition()
        }
    }
}

/// Feature flags system for conditional module loading
public enum FeatureFlags {
    private static var flags: Set<String> = []

    /// Enables a feature flag
    public static func enable(_ flag: String) {
        flags.insert(flag)
    }

    /// Disables a feature flag
    public static func disable(_ flag: String) {
        flags.remove(flag)
    }

    /// Checks if a feature flag is enabled
    public static func isEnabled(_ flag: String) -> Bool {
        flags.contains(flag)
    }

    /// Resets all feature flags
    public static func reset() {
        flags.removeAll()
    }
}
