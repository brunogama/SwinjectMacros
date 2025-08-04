// TypeAnalyzer.swift - Swift type analysis utilities for macro implementations
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import SwiftSyntax
import SwiftSyntaxMacros
@testable import SwinjectUtilityMacros

/// Analyzes Swift types from SwiftSyntax AST nodes for dependency injection purposes
public enum TypeAnalyzer {

    // MARK: - Type Classification

    /// Classifies a parameter based on its type and characteristics
    public static func classifyParameter(_ param: FunctionParameterSyntax) -> ParameterClassification {
        // Defensive check for empty type
        let typeText = param.type.trimmedDescription
        guard !typeText.isEmpty else {
            DebugLogger.warning("Parameter has empty type description")
            return .unknownDependency
        }

        let hasDefaultValue = param.defaultValue != nil

        // Service-like dependencies
        if self.isServiceType(typeText) {
            return .serviceDependency
        }

        // Protocol dependencies
        if self.isProtocolType(typeText) {
            return .protocolDependency
        }

        // Optional parameters with defaults are configuration
        if hasDefaultValue {
            return .configurationParameter
        }

        // Value types are likely runtime parameters
        if self.isValueType(typeText) {
            return .runtimeParameter
        }

        // Closure types might be dependencies
        if self.isClosureType(typeText) {
            return .closureDependency
        }

        // Default to unknown for manual classification
        return .unknownDependency
    }

    /// Determines if a type is a service-like dependency
    public static func isServiceType(_ type: String) -> Bool {
        let serviceSuffixes = ["Service", "Repository", "Client", "Manager", "Provider", "Handler", "Controller"]
        return serviceSuffixes.contains { type.hasSuffix($0) }
    }

    /// Determines if a type is a protocol type
    public static func isProtocolType(_ type: String) -> Bool {
        type.starts(with: "any ") ||
            type.contains("Protocol") ||
            type.starts(with: "some ")
    }

    /// Determines if a type is a value type
    public static func isValueType(_ type: String) -> Bool {
        let valueTypes = [
            "String", "Int", "Double", "Float", "Bool", "UUID", "Date", "URL", "Data",
            "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
            "Character", "Substring"
        ]

        // Check for direct matches
        if valueTypes.contains(where: { type.hasPrefix($0) }) {
            return true
        }

        // Check for optional value types
        if type.hasSuffix("?") {
            let nonOptionalType = String(type.dropLast())
            return valueTypes.contains(where: { nonOptionalType.hasPrefix($0) })
        }

        return false
    }

    /// Determines if a type is a closure type
    public static func isClosureType(_ type: String) -> Bool {
        type.contains("->") || type.contains("@escaping")
    }

    // MARK: - Generic Type Analysis

    /// Extracts generic parameters from a type
    public static func extractGenericParameters(_ type: TypeSyntax) -> [GenericParameterInfo] {
        guard let genericType = type.as(IdentifierTypeSyntax.self),
              let genericArguments = genericType.genericArgumentClause
        else {
            return []
        }

        return genericArguments.arguments.compactMap { arg in
            GenericParameterInfo(
                name: arg.argument.trimmedDescription,
                constraints: self.extractConstraints(from: arg.argument)
            )
        }
    }

    /// Extracts constraints from a generic parameter
    public static func extractConstraints(from type: TypeSyntax) -> [String] {
        // This is a simplified implementation
        // In a full implementation, we'd analyze the generic clause more thoroughly
        []
    }

    // MARK: - Initializer Analysis

    /// Finds the primary initializer in a class or struct declaration
    public static func findPrimaryInitializer(in decl: some DeclSyntaxProtocol) -> InitializerDeclSyntax? {
        guard let memberBlock = getMemberBlock(from: decl) else { return nil }

        let initializers = memberBlock.members.compactMap { member in
            member.decl.as(InitializerDeclSyntax.self)
        }

        // Prefer public initializers
        let publicInitializers = initializers.filter { initializer in
            self.hasPublicModifier(initializer.modifiers)
        }

        if !publicInitializers.isEmpty {
            // Return the first public initializer
            return publicInitializers.first
        }

        // Fall back to any initializer
        return initializers.first
    }

    /// Gets the member block from a declaration
    private static func getMemberBlock(from decl: some DeclSyntaxProtocol) -> MemberBlockSyntax? {
        if let classDecl = decl.as(ClassDeclSyntax.self) {
            return classDecl.memberBlock
        } else if let structDecl = decl.as(StructDeclSyntax.self) {
            return structDecl.memberBlock
        }
        return nil
    }

    /// Checks if modifiers contain public access
    private static func hasPublicModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains { modifier in
            modifier.name.text == "public"
        }
    }

    // MARK: - Dependency Analysis

    /// Analyzes all dependencies from an initializer
    public static func analyzeDependencies(from initializer: InitializerDeclSyntax) -> [DependencyInfo] {
        initializer.signature.parameterClause.parameters.compactMap { param in
            let classification = self.classifyParameter(param)
            let paramName = param.firstName.text
            let typeText = param.type.trimmedDescription
            let isOptional = self.isOptionalType(param.type)
            let defaultValue = param.defaultValue?.value.trimmedDescription

            return DependencyInfo(
                name: paramName,
                type: typeText,
                classification: classification,
                isOptional: isOptional,
                defaultValue: defaultValue,
                isGeneric: self.containsGenericParameters(param.type)
            )
        }
    }

    /// Checks if a type is optional
    public static func isOptionalType(_ type: TypeSyntax) -> Bool {
        if type.as(OptionalTypeSyntax.self) != nil {
            return true
        }

        let typeText = type.trimmedDescription
        return typeText.hasSuffix("?")
    }

    /// Checks if a type contains generic parameters
    public static func containsGenericParameters(_ type: TypeSyntax) -> Bool {
        let typeText = type.trimmedDescription
        return typeText.contains("<") && typeText.contains(">")
    }

    // MARK: - Assembly Detection

    /// Checks if a type conforms to Swinject's Assembly protocol
    public static func conformsToAssembly(_ decl: some DeclSyntaxProtocol) -> Bool {
        if let classDecl = decl.as(ClassDeclSyntax.self) {
            return self.conformsToAssembly(inheritanceClause: classDecl.inheritanceClause)
        } else if let structDecl = decl.as(StructDeclSyntax.self) {
            return self.conformsToAssembly(inheritanceClause: structDecl.inheritanceClause)
        }
        return false
    }

    private static func conformsToAssembly(inheritanceClause: InheritanceClauseSyntax?) -> Bool {
        guard let clause = inheritanceClause else { return false }

        return clause.inheritedTypes.contains { inheritedType in
            let typeName = inheritedType.type.trimmedDescription
            return typeName == "Assembly" || typeName.contains("Assembly")
        }
    }
}

// MARK: - Supporting Types

/// Classification of function parameters for dependency injection
public enum ParameterClassification {
    case serviceDependency // Service-like dependencies (UserService, APIClient)
    case protocolDependency // Protocol dependencies (any UserServiceProtocol)
    case runtimeParameter // Runtime parameters (String, Int, etc.)
    case configurationParameter // Configuration with defaults
    case closureDependency // Closure dependencies (@escaping closures)
    case unknownDependency // Requires manual classification
}

/// Information about a dependency extracted from analysis
public struct DependencyInfo {
    public let name: String
    public let type: String
    public let classification: ParameterClassification
    public let isOptional: Bool
    public let defaultValue: String?
    public let isGeneric: Bool

    public init(
        name: String,
        type: String,
        classification: ParameterClassification,
        isOptional: Bool = false,
        defaultValue: String? = nil,
        isGeneric: Bool = false
    ) {
        self.name = name
        self.type = type
        self.classification = classification
        self.isOptional = isOptional
        self.defaultValue = defaultValue
        self.isGeneric = isGeneric
    }
}

/// Information about generic parameters
public struct GenericParameterInfo {
    public let name: String
    public let constraints: [String]

    public init(name: String, constraints: [String] = []) {
        self.name = name
        self.constraints = constraints
    }
}

/// Service information extracted from type analysis
public struct ServiceInfo {
    public let name: String
    public let protocolType: String?
    public let implementationType: String
    public let dependencies: [DependencyInfo]
    public let isGeneric: Bool
    public let genericParameters: [GenericParameterInfo]
    public let conformsToAssembly: Bool

    public init(
        name: String,
        protocolType: String? = nil,
        implementationType: String,
        dependencies: [DependencyInfo] = [],
        isGeneric: Bool = false,
        genericParameters: [GenericParameterInfo] = [],
        conformsToAssembly: Bool = false
    ) {
        self.name = name
        self.protocolType = protocolType
        self.implementationType = implementationType
        self.dependencies = dependencies
        self.isGeneric = isGeneric
        self.genericParameters = genericParameters
        self.conformsToAssembly = conformsToAssembly
    }
}
