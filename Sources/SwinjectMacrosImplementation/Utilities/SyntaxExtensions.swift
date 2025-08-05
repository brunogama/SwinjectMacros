// SyntaxExtensions.swift - SwiftSyntax convenience extensions
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import SwiftDiagnostics
import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - TypeSyntax Extensions

extension TypeSyntax {
    /// Returns the trimmed description without trivia
    var cleanDescription: String {
        trimmedDescription
    }

    /// Checks if this type is optional
    var isOptional: Bool {
        self.as(OptionalTypeSyntax.self) != nil ||
            trimmedDescription.hasSuffix("?")
    }

    /// Returns the non-optional version of this type
    var nonOptionalType: TypeSyntax {
        if let optionalType = self.as(OptionalTypeSyntax.self) {
            return optionalType.wrappedType
        }

        let description = trimmedDescription
        if description.hasSuffix("?") {
            let nonOptionalDescription = String(description.dropLast())
            return TypeSyntax(stringLiteral: nonOptionalDescription)
        }

        return self
    }

    /// Checks if this type has generic parameters
    var hasGenericParameters: Bool {
        let description = trimmedDescription
        return description.contains("<") && description.contains(">")
    }

    /// Extracts the base type name without generic parameters
    var baseTypeName: String {
        let description = trimmedDescription
        if let index = description.firstIndex(of: "<") {
            return String(description[..<index])
        }
        return description
    }
}

// MARK: - FunctionDeclSyntax Extensions

extension FunctionDeclSyntax {
    /// Returns the function name as a string
    var functionName: String {
        name.text
    }

    /// Checks if the function is async
    var isAsync: Bool {
        signature.effectSpecifiers?.asyncSpecifier != nil
    }

    /// Checks if the function can throw
    var canThrow: Bool {
        signature.effectSpecifiers?.throwsSpecifier != nil
    }

    /// Returns the return type or Void if none specified
    var returnTypeName: String {
        signature.returnClause?.type.trimmedDescription ?? "Void"
    }

    /// Returns all parameter names
    var parameterNames: [String] {
        signature.parameterClause.parameters.map { $0.firstName.text }
    }

    /// Returns all parameter types
    var parameterTypes: [String] {
        signature.parameterClause.parameters.map { $0.type.trimmedDescription }
    }

    /// Checks if function has public access
    var isPublic: Bool {
        modifiers.contains { $0.name.text == "public" }
    }

    /// Checks if function is static
    var isStatic: Bool {
        modifiers.contains { $0.name.text == "static" }
    }
}

// MARK: - InitializerDeclSyntax Extensions

extension InitializerDeclSyntax {
    /// Returns all parameter information
    var parameterInfo: [ParameterInfo] {
        signature.parameterClause.parameters.map { param in
            ParameterInfo(
                name: param.firstName.text,
                type: param.type.trimmedDescription,
                isOptional: param.type.isOptional,
                defaultValue: param.defaultValue?.value.trimmedDescription,
                label: param.secondName?.text
            )
        }
    }

    /// Checks if initializer is public
    var isPublic: Bool {
        modifiers.contains { $0.name.text == "public" }
    }

    /// Checks if initializer can throw
    var canThrow: Bool {
        signature.effectSpecifiers?.throwsSpecifier != nil
    }

    /// Checks if initializer is async
    var isAsync: Bool {
        signature.effectSpecifiers?.asyncSpecifier != nil
    }
}

// MARK: - ClassDeclSyntax Extensions

extension ClassDeclSyntax {
    /// Returns the class name as a string
    var className: String {
        name.text
    }

    /// Returns all initializers in the class
    var initializers: [InitializerDeclSyntax] {
        memberBlock.members.compactMap { member in
            member.decl.as(InitializerDeclSyntax.self)
        }
    }

    /// Returns the primary (first public or first available) initializer
    var primaryInitializer: InitializerDeclSyntax? {
        let publicInitializers = initializers.filter { $0.isPublic }
        return publicInitializers.first ?? initializers.first
    }

    /// Returns all inherited types (protocols, superclasses)
    var inheritedTypeNames: [String] {
        inheritanceClause?.inheritedTypes.map {
            $0.type.trimmedDescription
        } ?? []
    }

    /// Checks if class conforms to a specific protocol
    func conformsTo(_ protocolName: String) -> Bool {
        inheritedTypeNames.contains(protocolName)
    }

    /// Checks if class is public
    var isPublic: Bool {
        modifiers.contains { $0.name.text == "public" }
    }

    /// Checks if class is final
    var isFinal: Bool {
        modifiers.contains { $0.name.text == "final" }
    }

    /// Returns generic parameters if any
    var genericParameters: [String] {
        genericParameterClause?.parameters.map { $0.name.text } ?? []
    }

    /// Checks if class is generic
    var isGeneric: Bool {
        genericParameterClause != nil
    }
}

// MARK: - StructDeclSyntax Extensions

extension StructDeclSyntax {
    /// Returns the struct name as a string
    var structName: String {
        name.text
    }

    /// Returns all initializers in the struct
    var initializers: [InitializerDeclSyntax] {
        memberBlock.members.compactMap { member in
            member.decl.as(InitializerDeclSyntax.self)
        }
    }

    /// Returns the primary (first public or first available) initializer
    var primaryInitializer: InitializerDeclSyntax? {
        let publicInitializers = initializers.filter { $0.isPublic }
        return publicInitializers.first ?? initializers.first
    }

    /// Returns all inherited types (protocols)
    var inheritedTypeNames: [String] {
        inheritanceClause?.inheritedTypes.map {
            $0.type.trimmedDescription
        } ?? []
    }

    /// Checks if struct conforms to a specific protocol
    func conformsTo(_ protocolName: String) -> Bool {
        inheritedTypeNames.contains(protocolName)
    }

    /// Checks if struct is public
    var isPublic: Bool {
        modifiers.contains { $0.name.text == "public" }
    }

    /// Returns generic parameters if any
    var genericParameters: [String] {
        genericParameterClause?.parameters.map { $0.name.text } ?? []
    }

    /// Checks if struct is generic
    var isGeneric: Bool {
        genericParameterClause != nil
    }
}

// MARK: - FunctionParameterSyntax Extensions

extension FunctionParameterSyntax {
    /// Returns parameter information
    var parameterInfo: ParameterInfo {
        ParameterInfo(
            name: firstName.text,
            type: type.trimmedDescription,
            isOptional: type.isOptional,
            defaultValue: defaultValue?.value.trimmedDescription,
            label: secondName?.text
        )
    }

    /// Checks if parameter has a default value
    var hasDefaultValue: Bool {
        defaultValue != nil
    }

    /// Returns the parameter label (external name)
    var label: String {
        secondName?.text ?? firstName.text
    }

    /// Returns the parameter name (internal name)
    var parameterName: String {
        firstName.text
    }
}

// MARK: - AttributeSyntax Extensions

extension AttributeSyntax {
    /// Returns the attribute name
    var attributeNameText: String {
        attributeName.trimmedDescription
    }

    /// Extracts string arguments from the attribute
    var stringArguments: [String] {
        guard let arguments = arguments?.as(LabeledExprListSyntax.self) else {
            return []
        }

        return arguments.compactMap { arg in
            if let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self) {
                return stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text
            }
            return nil
        }
    }

    /// Extracts named arguments from the attribute
    var namedArguments: [String: String] {
        guard let arguments = arguments?.as(LabeledExprListSyntax.self) else {
            return [:]
        }

        var result: [String: String] = [:]

        for arg in arguments {
            let key = arg.label?.text ?? ""

            if let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
               let value = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text
            {
                result[key] = value
            } else {
                result[key] = arg.expression.trimmedDescription
            }
        }

        return result
    }
}

// MARK: - DeclModifierListSyntax Extensions

extension DeclModifierListSyntax {
    /// Checks if modifiers contain a specific modifier
    func contains(_ modifierName: String) -> Bool {
        contains { $0.name.text == modifierName }
    }

    /// Returns all modifier names
    var modifierNames: [String] {
        map { $0.name.text }
    }

    /// Checks for access level modifiers
    var accessLevel: AccessLevel {
        if contains("public") { return .public }
        if contains("internal") { return .internal }
        if contains("fileprivate") { return .fileprivate }
        if contains("private") { return .private }
        return .internal // Default access level
    }
}

// MARK: - Supporting Types

/// Parameter information extracted from syntax
public struct ParameterInfo {
    public let name: String
    public let type: String
    public let isOptional: Bool
    public let defaultValue: String?
    public let label: String?

    public init(
        name: String,
        type: String,
        isOptional: Bool = false,
        defaultValue: String? = nil,
        label: String? = nil
    ) {
        self.name = name
        self.type = type
        self.isOptional = isOptional
        self.defaultValue = defaultValue
        self.label = label
    }
}

/// Access level enumeration
public enum AccessLevel {
    case `public`
    case `internal`
    case `fileprivate`
    case `private`
}

/// Simple diagnostic message implementation
public struct SimpleDiagnosticMessage: DiagnosticMessage {
    public let message: String
    public let diagnosticID: MessageID
    public let severity: DiagnosticSeverity

    public init(message: String, diagnosticID: MessageID, severity: DiagnosticSeverity) {
        self.message = message
        self.diagnosticID = diagnosticID
        self.severity = severity
    }
}

// MARK: - DeclSyntax Creation Helpers

extension DeclSyntax {
    /// Creates a function declaration from a string
    static func function(_ code: String) -> DeclSyntax {
        // In practice, you would use SwiftSyntaxBuilder to construct proper syntax trees
        // This is a placeholder implementation
        DeclSyntax(stringLiteral: code)
    }

    /// Creates an extension declaration from a string
    static func `extension`(_ code: String) -> DeclSyntax {
        DeclSyntax(stringLiteral: code)
    }
}

// MARK: - String Literal DeclSyntax (Placeholder Implementation)
// Note: In actual implementation, use proper SwiftSyntaxBuilder APIs instead of string literals

extension DeclSyntax {
    /// Creates a DeclSyntax from a string by parsing it
    static func fromString(_ value: String) -> DeclSyntax {
        // Parse the string and extract the first declaration
        let sourceFile = Parser.parse(source: value)
        if let firstDecl = sourceFile.statements.first?.item.as(DeclSyntax.self) {
            return firstDecl
        } else {
            // Fallback: create a variable declaration as placeholder
            return DeclSyntax(
                VariableDeclSyntax(
                    bindingSpecifier: TokenSyntax.keyword(.var),
                    bindings: PatternBindingListSyntax([
                        PatternBindingSyntax(
                            pattern: IdentifierPatternSyntax(identifier: .identifier("placeholder")),
                            typeAnnotation: TypeAnnotationSyntax(
                                type: IdentifierTypeSyntax(name: .identifier("String"))
                            ),
                            initializer: InitializerClauseSyntax(value: StringLiteralExprSyntax(content: "placeholder"))
                        )
                    ])
                )
            )
        }
    }
}
