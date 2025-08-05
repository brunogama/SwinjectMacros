// ModuleMacro.swift - Module macro implementation
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @Module macro
public struct ModuleMacro: ExtensionMacro, MemberMacro {

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Parse arguments
        let arguments = node.arguments?.as(LabeledExprListSyntax.self) ?? []
        let name = extractString(from: arguments, label: "name")
        let priority = extractInt(from: arguments, label: "priority") ?? 0

        var members: [DeclSyntax] = []

        // Add static properties
        if let name = name {
            members.append("""
            public static let name: String = "\(raw: name)"
            """)
        }

        if priority != 0 {
            members.append("""
            public static let priority: Int = \(raw: priority)
            """)
        }

        return members
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {

        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(
                    node: declaration,
                    message: ModuleMacroDiagnostic.requiresStruct
                )
            ])
        }

        let structName = structDecl.name.text
        let arguments = node.arguments?.as(LabeledExprListSyntax.self) ?? []
        let name = extractString(from: arguments, label: "name") ?? structName
        let priority = extractInt(from: arguments, label: "priority") ?? 0

        // Extract dependencies and exports from arguments
        let dependencies = extractTypeArray(from: arguments, label: "dependencies")
        let exports = extractTypeArray(from: arguments, label: "exports")

        // Check if configure method exists
        let hasConfigureMethod = structDecl.memberBlock.members.contains { member in
            if let function = member.decl.as(FunctionDeclSyntax.self) {
                return function.name.text == "configure" && function.modifiers.contains { $0.name.text == "static" }
            }
            return false
        }

        // Generate extension
        let extensionDecl = try ExtensionDeclSyntax("""
        extension \(raw: structName): ModuleProtocol {
            public static var name: String {
                "\(raw: name)"
            }

            public static var priority: Int {
                \(raw: priority)
            }

            public static var dependencies: [ModuleProtocol.Type] {
                [\(raw: dependencies.joined(separator: ", "))]
            }

            public static var exports: [Any.Type] {
                [\(raw: exports.joined(separator: ", "))]
            }

            \(raw: hasConfigureMethod ? "" : generateDefaultConfigure())

            public static func register(in system: ModuleSystem) {
                system.register(module: self)
            }
        }
        """)

        return [extensionDecl]
    }

    // MARK: - Helper Methods

    private static func extractString(from arguments: LabeledExprListSyntax, label: String) -> String? {
        for argument in arguments {
            if argument.label?.text == label {
                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                   let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
                {
                    return segment.content.text
                }
            }
        }
        return nil
    }

    private static func extractInt(from arguments: LabeledExprListSyntax, label: String) -> Int? {
        for argument in arguments {
            if argument.label?.text == label {
                if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                    return Int(intLiteral.literal.text)
                }
            }
        }
        return nil
    }

    private static func extractTypeArray(from arguments: LabeledExprListSyntax, label: String) -> [String] {
        for argument in arguments {
            if argument.label?.text == label {
                if let arrayExpr = argument.expression.as(ArrayExprSyntax.self) {
                    return arrayExpr.elements.compactMap { element in
                        if let memberAccess = element.expression.as(MemberAccessExprSyntax.self) {
                            if let base = memberAccess.base?.as(DeclReferenceExprSyntax.self) {
                                return "\(base.baseName.text).self"
                            }
                        }
                        return nil
                    }
                }
            }
        }
        return []
    }

    private static func generateDefaultConfigure() -> String {
        """
        public static func configure(_ container: Container) {
            // Default implementation - override in your module
            // Look for @Provides methods
            configureProvidedServices(in: container)
        }

        private static func configureProvidedServices(in container: Container) {
            // This will be populated by @Provides macro expansion
        }
        """
    }
}

// MARK: - Diagnostics

enum ModuleMacroDiagnostic: String, DiagnosticMessage {
    case requiresStruct = "@Module can only be applied to structs"
    case invalidConfiguration = "Invalid module configuration"

    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "SwinjectUtilityMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}
