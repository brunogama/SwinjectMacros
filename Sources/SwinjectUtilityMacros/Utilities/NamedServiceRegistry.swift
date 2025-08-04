// NamedServiceRegistry.swift - Registry for named service configurations
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import Swinject

/// Configuration for a named service registration
public struct NamedServiceConfiguration {
    /// The names this service is registered under
    public let names: [String]

    /// The protocol type as a string (for debugging)
    public let protocolType: String?

    /// The object scope for this service
    public let scope: ObjectScope

    /// Whether this is the default implementation when no name is specified
    public let isDefault: Bool

    /// Alternative names for this service
    public let aliases: [String]

    /// Registration priority (higher values register first)
    public let priority: Int

    /// Initialize a named service configuration
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
        names + aliases
    }

    /// Primary name (first in names array)
    public var primaryName: String {
        names.first ?? ""
    }
}

/// Registry for managing named service configurations
public final class NamedServiceRegistry {

    /// Shared registry instance - allows multiple configurations per type
    private static var registrations: [String: [NamedServiceConfiguration]] = [:]

    /// Thread safety lock
    private static let lock = NSLock()

    /// Register a configuration for a service type
    ///
    /// - Parameters:
    ///   - configuration: The service configuration
    ///   - typeName: The type name to register under
    public static func register(_ configuration: NamedServiceConfiguration, for typeName: String) {
        // Validation
        guard !typeName.isEmpty else {
            DebugLogger.error("Cannot register service with empty type name")
            return
        }

        guard !configuration.names.isEmpty else {
            DebugLogger.error("Cannot register service configuration without any names for type: \(typeName)")
            return
        }

        lock.lock()
        defer { lock.unlock() }

        if registrations[typeName] == nil {
            registrations[typeName] = []
        }
        registrations[typeName]?.append(configuration)

        DebugLogger.debug("Registered named service: \(typeName) with names: \(configuration.names)")
    }

    /// Get all configurations for a service type
    ///
    /// - Parameter typeName: The type name to look up
    /// - Returns: Array of configurations for this type
    public static func getConfigurations(for typeName: String) -> [NamedServiceConfiguration] {
        lock.lock()
        defer { lock.unlock() }

        return registrations[typeName] ?? []
    }

    /// Get configuration for a service type (returns first if multiple)
    ///
    /// - Parameter typeName: The type name to look up
    /// - Returns: The first configuration if registered, nil otherwise
    public static func getConfiguration(for typeName: String) -> NamedServiceConfiguration? {
        getConfigurations(for: typeName).first
    }

    /// Get all registered configurations
    ///
    /// - Returns: Dictionary of type names to configuration arrays
    public static func getAllConfigurations() -> [String: [NamedServiceConfiguration]] {
        lock.lock()
        defer { lock.unlock() }

        return registrations
    }

    /// Find configuration by name
    ///
    /// - Parameters:
    ///   - name: The name to search for
    ///   - typeName: The type to search in
    /// - Returns: The configuration if found
    public static func findConfiguration(name: String, for typeName: String) -> NamedServiceConfiguration? {
        let configurations = getConfigurations(for: typeName)
        return configurations.first { config in
            config.allNames.contains(name)
        }
    }

    /// Get all registered service names for a type
    ///
    /// - Parameter typeName: The type name
    /// - Returns: Array of all names (including aliases)
    public static func getAllNames(for typeName: String) -> [String] {
        let configurations = getConfigurations(for: typeName)
        return configurations.flatMap { $0.allNames }
    }

    /// Find all services registered with a specific name
    ///
    /// - Parameter name: The name to search for
    /// - Returns: Array of type names that have this name
    public static func findServices(byName name: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        return registrations.compactMap { typeName, configs in
            if configs.contains(where: { $0.names.contains(name) || $0.aliases.contains(name) }) {
                return typeName
            }
            return nil
        }
    }

    /// Clear all registered configurations
    public static func clear() {
        lock.lock()
        defer { lock.unlock() }

        registrations.removeAll()
    }

    /// Get debug information about registered services
    ///
    /// - Returns: String with debug information
    public static func debugDescription() -> String {
        lock.lock()
        defer { lock.unlock() }

        var description = "Named Service Registry:\n"
        description += "========================\n"

        for (typeName, configs) in registrations.sorted(by: { $0.key < $1.key }) {
            description += "\nType: \(typeName)\n"
            for config in configs {
                description += "  Names: \(config.names.joined(separator: ", "))\n"
                if !config.aliases.isEmpty {
                    description += "  Aliases: \(config.aliases.joined(separator: ", "))\n"
                }
                if let protocolType = config.protocolType {
                    description += "  Protocol: \(protocolType)\n"
                }
                description += "  Scope: \(config.scope)\n"
                description += "  Default: \(config.isDefault)\n"
                description += "  Priority: \(config.priority)\n"
            }
        }

        return description
    }
}

/// Protocol that types can conform to for automatic named registration
public protocol NamedServiceProtocol {
    /// The primary name for this service
    static var serviceName: String { get }

    /// All names including aliases
    static var serviceNames: [String] { get }

    /// The object scope for this service
    static var serviceScope: ObjectScope { get }

    /// Register this service with names in a container
    static func registerNamed(
        in container: Container,
        names: [String]?,
        factory: ((Resolver) -> Self)?
    )

    /// Check if a name is valid for this service
    static func isValidName(_ name: String) -> Bool

    /// Resolve this service by name from a container
    static func resolve(from container: Container, name: String?) -> Self?
}

/// Extension to provide default implementations
extension NamedServiceProtocol {

    public static var serviceNames: [String] {
        [serviceName]
    }

    public static var serviceScope: ObjectScope {
        .graph
    }

    public static func isValidName(_ name: String) -> Bool {
        serviceNames.contains(name)
    }

    public static func resolve(from container: Container, name: String?) -> Self? {
        let nameToUse = name ?? serviceName
        return container.resolve(Self.self, name: nameToUse)
    }
}
