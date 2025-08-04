// ModuleSystem.swift - Module system management and orchestration
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import os.log
import Swinject

/// Central system for managing modular dependency injection
public final class ModuleSystem {

    // MARK: - Properties

    /// Shared instance of the module system
    public static var shared = ModuleSystem()

    /// Reset the shared instance (useful for testing)
    public static func resetShared() {
        shared = ModuleSystem()
    }

    /// Logger for module system operations
    private let logger = Logger(subsystem: "com.swinjectutilitymacros", category: "module-system")

    /// Registered modules
    private var modules: [String: ModuleProtocol.Type] = [:]

    /// Module containers with parent/child hierarchy
    private var moduleContainers: [String: ModuleContainer] = [:]

    /// Root container for the application
    public private(set) var rootContainer: Container

    /// Module initialization order based on dependencies
    private var initializationOrder: [String] = []

    /// Lock for thread-safe operations
    private let lock = NSLock()

    /// Module lifecycle state
    private var lifecycleState: ModuleLifecycleState = .uninitialized

    // MARK: - Initialization

    /// Creates a new module system
    public init(rootContainer: Container? = nil) {
        self.rootContainer = rootContainer ?? Container()
        setupRootContainer()
    }

    private func setupRootContainer() {
        // Register module system itself in the container
        rootContainer.register(ModuleSystem.self) { _ in self }
            .inObjectScope(.container)
    }

    // MARK: - Module Registration

    /// Registers a module in the system
    public func register(module: ModuleProtocol.Type) {
        lock.lock()
        defer { lock.unlock() }

        let moduleName = module.name

        if modules[moduleName] != nil {
            logger.warning("Module '\(moduleName)' is already registered. Skipping.")
            return
        }

        modules[moduleName] = module
        logger.info("Registered module: \(moduleName)")

        // Create module container
        let moduleContainer = ModuleContainer(
            name: moduleName,
            parent: rootContainer,
            priority: module.priority
        )
        moduleContainers[moduleName] = moduleContainer

        // Invalidate initialization order
        initializationOrder.removeAll()
    }

    /// Registers multiple modules
    public func register(modules: [ModuleProtocol.Type]) {
        modules.forEach { self.register(module: $0) }
    }

    // MARK: - Module Initialization

    /// Initializes all registered modules
    public func initialize() throws {
        lock.lock()
        defer { lock.unlock() }

        guard lifecycleState == .uninitialized else {
            logger.warning("Module system is already initialized")
            return
        }

        lifecycleState = .initializing

        do {
            // Calculate initialization order
            try calculateInitializationOrder()

            // Initialize modules in order
            for moduleName in initializationOrder {
                try initializeModule(named: moduleName)
            }

            // Validate all dependencies are satisfied
            try validateDependencies()

            lifecycleState = .initialized
            logger.info("Module system initialized successfully with \(modules.count) modules")

        } catch {
            lifecycleState = .failed(error)
            logger.error("Module system initialization failed: \(error)")
            throw error
        }
    }

    private func initializeModule(named name: String) throws {
        guard let module = modules[name] else {
            throw ModuleError.moduleNotFound(name)
        }

        guard let container = moduleContainers[name] else {
            throw ModuleError.containerNotFound(name)
        }

        logger.debug("Initializing module: \(name)")

        // Check dependencies are initialized
        for dependency in module.dependencies {
            let depName = dependency.name
            guard let depContainer = moduleContainers[depName],
                  depContainer.isInitialized
            else {
                throw ModuleError.dependencyNotInitialized(module: name, dependency: depName)
            }
        }

        // Configure the module
        module.configure(container.container)
        container.markInitialized()

        logger.info("Module '\(name)' initialized")
    }

    // MARK: - Dependency Resolution

    private func calculateInitializationOrder() throws {
        var visited = Set<String>()
        var visiting = Set<String>()
        var order: [String] = []

        for moduleName in modules.keys {
            try visitModule(
                moduleName,
                visited: &visited,
                visiting: &visiting,
                order: &order
            )
        }

        initializationOrder = order
        logger.debug("Module initialization order: \(order.joined(separator: " -> "))")
    }

    private func visitModule(
        _ name: String,
        visited: inout Set<String>,
        visiting: inout Set<String>,
        order: inout [String]
    ) throws {
        if visited.contains(name) {
            return
        }

        if visiting.contains(name) {
            throw ModuleError.circularDependency(module: name)
        }

        visiting.insert(name)

        if let module = modules[name] {
            for dependency in module.dependencies {
                try visitModule(
                    dependency.name,
                    visited: &visited,
                    visiting: &visiting,
                    order: &order
                )
            }
        }

        visiting.remove(name)
        visited.insert(name)
        order.append(name)
    }

    private func validateDependencies() throws {
        for (name, module) in modules {
            for dependency in module.dependencies {
                if modules[dependency.name] == nil {
                    throw ModuleError.missingDependency(
                        module: name,
                        dependency: dependency.name
                    )
                }
            }
        }
    }

    // MARK: - Service Resolution

    /// Resolves a service from the appropriate module
    public func resolve<Service>(
        _ serviceType: Service.Type,
        name: String? = nil,
        from module: String? = nil
    ) -> Service? {
        lock.lock()
        defer { lock.unlock() }

        // If module specified, try that first
        if let moduleName = module,
           let container = moduleContainers[moduleName]
        {
            if let service = container.resolve(serviceType, name: name) {
                return service
            }
        }

        // Try all module containers
        for container in moduleContainers.values.sorted(by: { $0.priority > $1.priority }) {
            if let service = container.resolve(serviceType, name: name) {
                return service
            }
        }

        // Fall back to root container
        return rootContainer.resolve(serviceType, name: name)
    }

    // MARK: - Module Access

    /// Gets a module container by name
    public func container(for module: String) -> Container? {
        lock.lock()
        defer { lock.unlock() }

        return moduleContainers[module]?.container
    }

    /// Gets all module names
    public var moduleNames: [String] {
        lock.lock()
        defer { lock.unlock() }

        return Array(modules.keys).sorted()
    }

    /// Gets module info
    public func info(for moduleName: String) -> ModuleInfo? {
        lock.lock()
        defer { lock.unlock() }

        guard let module = modules[moduleName],
              let container = moduleContainers[moduleName]
        else {
            return nil
        }

        return ModuleInfo(
            name: moduleName,
            priority: module.priority,
            dependencies: module.dependencies.map { $0.name },
            exports: module.exports.map { String(describing: $0) },
            isInitialized: container.isInitialized
        )
    }

    // MARK: - Lifecycle Management

    /// Resets the module system
    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        modules.removeAll()
        moduleContainers.removeAll()
        initializationOrder.removeAll()
        lifecycleState = .uninitialized
        rootContainer = Container()
        setupRootContainer()

        logger.info("Module system reset")
    }

    /// Shuts down the module system
    public func shutdown() {
        lock.lock()
        defer { lock.unlock() }

        // Shutdown modules in reverse initialization order
        for moduleName in initializationOrder.reversed() {
            if let container = moduleContainers[moduleName] {
                container.shutdown()
                logger.debug("Shut down module: \(moduleName)")
            }
        }

        lifecycleState = .shutdown
        logger.info("Module system shut down")
    }
}

// MARK: - Supporting Types

/// Container wrapper for a module
public final class ModuleContainer {
    let name: String
    let container: Container
    let priority: Int
    private(set) var isInitialized = false

    init(name: String, parent: Container, priority: Int) {
        self.name = name
        container = Container(parent: parent)
        self.priority = priority
    }

    func markInitialized() {
        isInitialized = true
    }

    func resolve<Service>(_ serviceType: Service.Type, name: String? = nil) -> Service? {
        container.resolve(serviceType, name: name)
    }

    func shutdown() {
        container.removeAll()
        isInitialized = false
    }
}

/// Module lifecycle states
public enum ModuleLifecycleState: Equatable {
    case uninitialized
    case initializing
    case initialized
    case failed(Error)
    case shutdown

    public static func == (lhs: ModuleLifecycleState, rhs: ModuleLifecycleState) -> Bool {
        switch (lhs, rhs) {
        case (.uninitialized, .uninitialized),
             (.initializing, .initializing),
             (.initialized, .initialized),
             (.shutdown, .shutdown):
            true
        case (.failed, .failed):
            true // Consider all failed states equal for simplicity
        default:
            false
        }
    }
}

/// Information about a module
public struct ModuleInfo {
    public let name: String
    public let priority: Int
    public let dependencies: [String]
    public let exports: [String]
    public let isInitialized: Bool
}

/// Module system errors
public enum ModuleError: LocalizedError {
    case moduleNotFound(String)
    case containerNotFound(String)
    case dependencyNotInitialized(module: String, dependency: String)
    case circularDependency(module: String)
    case missingDependency(module: String, dependency: String)
    case initializationFailed(module: String, error: Error)

    public var errorDescription: String? {
        switch self {
        case let .moduleNotFound(name):
            "Module '\(name)' not found"
        case let .containerNotFound(name):
            "Container for module '\(name)' not found"
        case let .dependencyNotInitialized(module, dependency):
            "Module '\(module)' depends on '\(dependency)' which is not initialized"
        case let .circularDependency(module):
            "Circular dependency detected involving module '\(module)'"
        case let .missingDependency(module, dependency):
            "Module '\(module)' depends on '\(dependency)' which is not registered"
        case let .initializationFailed(module, error):
            "Module '\(module)' initialization failed: \(error)"
        }
    }
}
