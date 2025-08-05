// ModuleScope.swift - Module-level singleton scope for dependency injection
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import Swinject

/// Custom object scope that maintains singletons at the module level
public final class ModuleScope: ObjectScopeProtocol {

    // MARK: - Properties

    /// Storage for module-scoped instances
    private var instances: [String: [String: Any]] = [:]

    /// Lock for thread-safe access
    private let lock = NSLock()

    /// Shared instance of module scope
    public static let shared = ModuleScope()

    // MARK: - Initialization

    private init() {}

    // MARK: - ObjectScopeProtocol Conformance

    public func makeStorage() -> InstanceStorage {
        ModuleScopeStorage()
    }

    // MARK: - ObjectScopeProtocol Implementation

    /// Stores an instance in the module scope
    /// - Parameters:
    ///   - instance: The instance to store
    ///   - key: The key to store the instance under
    ///   - moduleIdentifier: The module identifier to scope the instance to.
    ///                       If nil, uses "global" as the default module.
    ///                       This allows instances to be isolated per module.
    public func store(
        instance: some Any,
        key: String,
        moduleIdentifier: String? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }

        let moduleKey = moduleIdentifier ?? "global"

        if instances[moduleKey] == nil {
            instances[moduleKey] = [:]
        }

        instances[moduleKey]?[key] = instance
    }

    /// Retrieves an instance from the module scope
    /// - Parameters:
    ///   - key: The key the instance was stored under
    ///   - moduleIdentifier: The module identifier to retrieve the instance from.
    ///                       If nil, uses "global" as the default module.
    ///                       Must match the identifier used when storing the instance.
    /// - Returns: The stored instance if found and of the correct type, nil otherwise
    public func instance<Service>(
        for key: String,
        moduleIdentifier: String? = nil
    ) -> Service? {
        lock.lock()
        defer { lock.unlock() }

        let moduleKey = moduleIdentifier ?? "global"
        return instances[moduleKey]?[key] as? Service
    }

    // MARK: - Module Management

    /// Clears all instances for a specific module
    public func clearModule(_ moduleIdentifier: String) {
        lock.lock()
        defer { lock.unlock() }

        instances[moduleIdentifier] = nil
    }

    /// Clears all module-scoped instances
    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }

        instances.removeAll()
    }

    /// Returns the number of instances stored for a module
    public func instanceCount(for moduleIdentifier: String) -> Int {
        lock.lock()
        defer { lock.unlock() }

        return instances[moduleIdentifier]?.count ?? 0
    }

    /// Returns all module identifiers with stored instances
    public var moduleIdentifiers: [String] {
        lock.lock()
        defer { lock.unlock() }

        return Array(instances.keys)
    }
}

// MARK: - Swinject Extension for Module Scope

// extension ObjectScope {
//     /// Module-level singleton scope
//     /// Services are shared within the same module but isolated between modules
//     public static let module = ObjectScope(
//         storageFactory: ModuleScopeStorage.init,
//         description: "module"
//     )
// }

/// Storage implementation for module scope
final class ModuleScopeStorage: InstanceStorage {

    // MARK: - Properties

    private var instances: [String: Any] = [:]
    private let moduleIdentifier: String
    private let lock = NSLock()

    // MARK: - Initialization

    /// Creates a new module scope storage
    /// - Parameter moduleIdentifier: The identifier for this module's storage.
    ///                              Defaults to "default". This identifier is used
    ///                              as a fallback when ModuleContext.current is nil.
    init(moduleIdentifier: String = "default") {
        self.moduleIdentifier = moduleIdentifier
    }

    // MARK: - InstanceStorage Implementation

    var instance: Any? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return instances[graphIdentifier]
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            instances[graphIdentifier] = newValue
        }
    }

    var graphIdentifier: String {
        // Use the current module context if available
        ModuleContext.current?.identifier ?? moduleIdentifier
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        instances.removeAll()
    }
}

// MARK: - Module Context

/// Provides context for module-scoped resolution
public final class ModuleContext {

    // MARK: - Properties

    /// Thread-local storage for current module context
    private static let threadLocal = ThreadLocal<ModuleContext>()

    /// Current module context for the thread
    public static var current: ModuleContext? {
        threadLocal.value
    }

    /// Module identifier
    public let identifier: String

    /// Parent context (for nested modules)
    public let parent: ModuleContext?

    // MARK: - Initialization

    public init(identifier: String, parent: ModuleContext? = nil) {
        self.identifier = identifier
        self.parent = parent
    }

    // MARK: - Context Management

    /// Executes a closure within this module context
    public func execute<T>(_ closure: () throws -> T) rethrows -> T {
        let previous = Self.threadLocal.value
        Self.threadLocal.value = self
        defer { Self.threadLocal.value = previous }

        return try closure()
    }

    /// Executes an async closure within this module context
    public func execute<T>(_ closure: () async throws -> T) async rethrows -> T {
        let previous = Self.threadLocal.value
        Self.threadLocal.value = self
        defer { Self.threadLocal.value = previous }

        return try await closure()
    }
}

// MARK: - Thread Local Storage

/// Thread-local storage implementation
final class ThreadLocal<T> {
    private var key: pthread_key_t = 0

    init() {
        pthread_key_create(&key) { pointer in
            // Clean up the stored object when thread exits
            Unmanaged<AnyObject>.fromOpaque(pointer).release()
        }
    }

    deinit {
        pthread_key_delete(key)
    }

    var value: T? {
        get {
            guard let pointer = pthread_getspecific(key) else { return nil }
            let box = Unmanaged<Box<T>>.fromOpaque(pointer).takeUnretainedValue()
            return box.value
        }
        set {
            // Clear existing value
            if let pointer = pthread_getspecific(key) {
                Unmanaged<AnyObject>.fromOpaque(pointer).release()
            }

            // Set new value
            if let newValue = newValue {
                let box = Box(value: newValue)
                let pointer = Unmanaged.passRetained(box).toOpaque()
                pthread_setspecific(key, pointer)
            } else {
                pthread_setspecific(key, nil)
            }
        }
    }

    private class Box<U> {
        let value: U
        init(value: U) {
            self.value = value
        }
    }
}

// MARK: - Module-Aware Container Extension

extension Container {

    /// Registers a service with module scope
    public func registerModuleScoped<Service>(
        _ serviceType: Service.Type,
        name: String? = nil,
        factory: @escaping (Resolver) -> Service
    ) -> ServiceEntry<Service> {
register(serviceType, name: name, factory: factory)
            // .inObjectScope(ObjectScope.module)
    }

    /// Resolves a service within a module context
    public func resolveWithModule<Service>(
        _ serviceType: Service.Type,
        name: String? = nil,
        module: String
    ) -> Service? {
        let context = ModuleContext(identifier: module)
        return context.execute {
            self.resolve(serviceType, name: name)
        }
    }
}

// MARK: - ModuleScoped Property Wrapper

/// Property wrapper for module-scoped dependency injection
@propertyWrapper
public struct ModuleScoped<Service> {

    private let serviceType: Service.Type
    private let name: String?
    private let module: String?
    private var cached: Service?

    public init(
        _ serviceType: Service.Type,
        name: String? = nil,
        module: String? = nil
    ) {
        self.serviceType = serviceType
        self.name = name
        self.module = module
        cached = nil
    }

    public var wrappedValue: Service {
        mutating get {
            if let cached = cached {
                return cached
            }

            let resolved: Service?

            if let module = module {
                // Resolve within specific module context
                let context = ModuleContext(identifier: module)
                resolved = context.execute {
                    ModuleSystem.shared.resolve(serviceType, name: name, from: module)
                }
            } else {
                // Resolve from current module context
                resolved = ModuleSystem.shared.resolve(serviceType, name: name)
            }

            guard let service = resolved else {
                fatalError("Failed to resolve \(serviceType) with name: \(name ?? "default")")
            }

            cached = service
            return service
        }
    }
}

// MARK: - Usage Examples

/*
 // Example 1: Register module-scoped service
 container.registerModuleScoped(DatabaseService.self) { resolver in
     DatabaseService()
 }

 // Example 2: Use ModuleScoped property wrapper
 class UserViewModel {
     @ModuleScoped(UserService.self, module: "User")
     var userService: UserService

     @ModuleScoped(Analytics.self)
     var analytics: Analytics
 }

 // Example 3: Resolve within module context
 let context = ModuleContext(identifier: "Payment")
 context.execute {
     let paymentService = container.resolve(PaymentService.self)
     // Service resolved within Payment module context
 }

 // Example 4: Module scope in registration
 @Module(name: "Database")
 struct DatabaseModule {
     static func configure(_ container: Container) {
         // This service will be a singleton within the Database module
         container.register(DatabaseConnection.self) { _ in
             DatabaseConnection()
         }.inObjectScope(.module)
     }
 }
 */
