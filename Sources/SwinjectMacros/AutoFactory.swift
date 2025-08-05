// AutoFactory.swift - Factory protocol generation macros
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import Swinject

// MARK: - @AutoFactory Macro

/// Automatically generates factory protocols and implementations for services that require runtime parameters.
///
/// This macro analyzes service initializers and separates injected dependencies from runtime parameters,
/// creating appropriate factory interfaces for dynamic service creation.
///
/// ## Features
/// - Automatic separation of dependencies vs runtime parameters
/// - Factory protocol generation with proper type signatures
/// - Support for async and throwing factories
/// - Generic factory support with constraint preservation
/// - Multiple parameter variants (1, 2, or multi-parameter factories)
///
/// ## Usage
/// ```swift
/// @AutoFactory
/// class UserProfileService {
///     init(apiClient: APIClient, database: Database, userId: String) {
///         // apiClient and database are dependencies (injected)
///         // userId is a runtime parameter (factory parameter)
///     }
/// }
///
/// // Generates:
/// protocol UserProfileServiceFactory {
///     func makeUserProfileService(userId: String) -> UserProfileService
/// }
///
/// class UserProfileServiceFactoryImpl: UserProfileServiceFactory {
///     private let resolver: Resolver
///
///     init(resolver: Resolver) {
///         self.resolver = resolver
///     }
///
///     func makeUserProfileService(userId: String) -> UserProfileService {
///         return UserProfileService(
///             apiClient: resolver.synchronizedResolve(APIClient.self)!,
///             database: resolver.synchronizedResolve(Database.self)!,
///             userId: userId
///         )
///     }
/// }
/// ```
///
/// ## Async Factory
/// ```swift
/// @AutoFactory
/// class AsyncUserService {
///     init(apiClient: APIClient, userId: String) async {
///         // Implementation
///     }
/// }
///
/// // Generates async factory:
/// protocol AsyncUserServiceFactory {
///     func makeAsyncUserService(userId: String) async -> AsyncUserService
/// }
/// ```
///
/// ## Throwing Factory
/// ```swift
/// @AutoFactory
/// class ThrowingUserService {
///     init(apiClient: APIClient, userId: String) throws {
///         // Implementation
///     }
/// }
///
/// // Generates throwing factory:
/// protocol ThrowingUserServiceFactory {
///     func makeThrowingUserService(userId: String) throws -> ThrowingUserService
/// }
/// ```
@attached(peer, names: suffixed(Factory), suffixed(FactoryImpl))
@attached(member, names: named(registerFactory))
public macro AutoFactory() = #externalMacro(module: "SwinjectMacrosImplementation", type: "AutoFactoryMacro")

// MARK: - Specialized Factory Macros

/// Single-parameter factory macro for services with exactly one runtime parameter
@attached(peer, names: suffixed(Factory), suffixed(FactoryImpl))
public macro AutoFactory1() = #externalMacro(module: "SwinjectMacrosImplementation", type: "AutoFactory1Macro")

/// Two-parameter factory macro for services with exactly two runtime parameters
@attached(peer, names: suffixed(Factory), suffixed(FactoryImpl))
public macro AutoFactory2() = #externalMacro(module: "SwinjectMacrosImplementation", type: "AutoFactory2Macro")

/// Multi-parameter factory macro for services with 3+ runtime parameters
@attached(peer, names: suffixed(Factory), suffixed(FactoryImpl))
public macro AutoFactoryMulti() = #externalMacro(
    module: "SwinjectMacrosImplementation",
    type: "AutoFactoryMultiMacro"
)

// MARK: - Factory Configuration

/// Configuration for factory generation behavior
public struct FactoryConfig {
    /// Whether to generate async factory methods
    public let isAsync: Bool
    /// Whether to generate throwing factory methods
    public let canThrow: Bool
    /// Custom factory protocol name
    public let protocolName: String?
    /// Custom factory implementation name
    public let implName: String?

    public init(
        isAsync: Bool = false,
        canThrow: Bool = false,
        protocolName: String? = nil,
        implName: String? = nil
    ) {
        self.isAsync = isAsync
        self.canThrow = canThrow
        self.protocolName = protocolName
        self.implName = implName
    }
}

// MARK: - Parameter Classification

/// Classification of initializer parameters
public enum ParameterType {
    /// Service dependency (injected from container)
    case dependency
    /// Runtime parameter (provided at factory call time)
    case runtime
    /// Configuration parameter (loaded from config/environment)
    case configuration
    /// Optional parameter with default value
    case optional
}

/// Information about a factory parameter
public struct ParameterInfo {
    /// Parameter name
    public let name: String
    /// Parameter type
    public let type: String
    /// Parameter classification
    public let parameterType: ParameterType
    /// Whether parameter is optional
    public let isOptional: Bool
    /// Default value if present
    public let defaultValue: String?
    /// Parameter label for factory method
    public let label: String?

    public init(
        name: String,
        type: String,
        parameterType: ParameterType,
        isOptional: Bool = false,
        defaultValue: String? = nil,
        label: String? = nil
    ) {
        self.name = name
        self.type = type
        self.parameterType = parameterType
        self.isOptional = isOptional
        self.defaultValue = defaultValue
        self.label = label ?? name
    }
}

// MARK: - Factory Base Protocol

/// Base protocol that all generated factories conform to
public protocol BaseFactory {
    /// The resolver used for dependency injection
    var resolver: Resolver { get }

    /// Initialize factory with resolver
    init(resolver: Resolver)
}

// MARK: - Factory Registration Extensions

extension Container {

    /// Register a factory for a service type
    public func registerFactory(
        _ factoryType: (some BaseFactory).Type,
        scope: ObjectScope = .container
    ) {
        let registration = register(factoryType) { resolver in
            factoryType.init(resolver: resolver)
        }
        registration.inObjectScope(scope.swinjectScope)
    }

    /// Register a factory with custom implementation
    public func registerFactory<Factory>(
        _ factoryType: Factory.Type,
        implementation: (some BaseFactory).Type,
        scope: ObjectScope = .container
    ) {
        let registration = register(factoryType) { resolver in
            implementation.init(resolver: resolver) as! Factory
        }
        registration.inObjectScope(scope.swinjectScope)
    }
}

// MARK: - Factory Utilities

/// Utilities for working with factories
public enum FactoryUtils {

    /// Determine if a parameter should be injected vs provided at runtime
    static func classifyParameter(name: String, type: String, hasDefault: Bool) -> ParameterType {
        // Service-like types are dependencies
        if type.hasSuffix("Service") ||
            type.hasSuffix("Repository") ||
            type.hasSuffix("Client") ||
            type.hasSuffix("Manager")
        {
            return .dependency
        }

        // Protocol types are likely dependencies
        if type.starts(with: "any ") || type.contains("Protocol") {
            return .dependency
        }

        // Optional parameters with defaults are configuration
        if hasDefault {
            return .optional
        }

        // Value types are likely runtime parameters
        if isValueType(type) {
            return .runtime
        }

        // Default to runtime parameter
        return .runtime
    }

    /// Check if a type is a value type (String, Int, Bool, etc.)
    static func isValueType(_ type: String) -> Bool {
        let valueTypes = [
            "String", "Int", "Double", "Float", "Bool", "UUID", "Date",
            "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64"
        ]

        return valueTypes.contains { type.hasPrefix($0) }
    }

    /// Generate factory method name from service name
    static func factoryMethodName(for serviceName: String) -> String {
        let withoutSuffix = serviceName.replacingOccurrences(of: "Service", with: "")
            .replacingOccurrences(of: "Repository", with: "")
            .replacingOccurrences(of: "Client", with: "")

        return "make\(withoutSuffix.isEmpty ? serviceName : withoutSuffix)"
    }
}

// MARK: - Factory Error Types

/// Errors that can occur during factory operations
public enum FactoryError: Error, LocalizedError {
    case parameterClassificationFailed(String)
    case invalidFactoryConfiguration(String)
    case dependencyResolutionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .parameterClassificationFailed(let param):
            "Failed to classify parameter: \(param)"
        case .invalidFactoryConfiguration(let message):
            "Invalid factory configuration: \(message)"
        case .dependencyResolutionFailed(let dependency):
            "Failed to resolve dependency: \(dependency)"
        }
    }
}
