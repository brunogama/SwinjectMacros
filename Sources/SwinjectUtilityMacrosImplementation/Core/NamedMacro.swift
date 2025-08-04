// NamedMacro.swift - Named service registration implementation
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @Named macro
///
/// Enables named service registration for scenarios where multiple implementations
/// of the same protocol need to be distinguished by name.
public struct NamedMacro: MemberMacro {

    // MARK: - MemberMacro Implementation

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // Validate that this is applied to a class or struct
        guard declaration.is(ClassDeclSyntax.self) || declaration.is(StructDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: NamedMacroError(message: """
                @Named can only be applied to classes or structs.

                ✅ Correct usage:
                @Named("primary")
                class PrimaryDatabase: DatabaseProtocol {
                    init(connectionString: String) { }
                }

                @Named("redis", aliases: ["cache", "fast-storage"])
                struct RedisCache: CacheProtocol {
                    init(redisClient: RedisClient) { }
                }

                ❌ Invalid usage:
                @Named("test")
                protocol TestProtocol { } // Protocols not supported

                @Named("test")
                enum TestEnum { } // Enums not supported

                💡 Tips:
                - Use different names for multiple implementations of the same protocol
                - Add aliases for alternative names
                - Mark one implementation as default with 'default: true'
                """)
            )
            context.diagnose(diagnostic)
            return []
        }

        // Parse macro arguments
        let arguments = parseMacroArguments(from: node)

        // Get the type name
        let typeName = getTypeName(from: declaration)

        // Generate member declarations
        var members: [DeclSyntax] = []

        // Add service name constant
        members.append(DeclSyntax("""
        /// Primary service name for registration
        static let serviceName = "\(raw: arguments.primaryName)"
        """))

        // Add all names array if there are multiple names or aliases
        if arguments.allNames.count > 1 {
            let namesLiteral = arguments.allNames.map { "\"\($0)\"" }.joined(separator: ", ")
            members.append(DeclSyntax("""

            /// All service names including aliases
            static let serviceNames = [\(raw: namesLiteral)]
            """))
        }

        // Add priority if specified
        if arguments.priority != 0 {
            members.append(DeclSyntax("""

            /// Service registration priority
            static let servicePriority = \(raw: arguments.priority)
            """))
        }

        // Add scope constant
        let scopeValue = scopeToSwiftCode(arguments.scope)
        members.append(DeclSyntax("""

        /// Service object scope
        static let serviceScope: ObjectScope = \(raw: scopeValue)
        """))

        // Add named registration method
        let protocolTypeParam = arguments.protocolType.map { ", protocolType: \($0).self" } ?? ""
        let registerMethodBody = generateRegisterMethodBody(
            typeName: typeName,
            arguments: arguments,
            protocolTypeParam: protocolTypeParam
        )

        members.append(DeclSyntax("""

        /// Register this service with the specified names in a container
        static func registerNamed(
            in container: Container,
            names: [String]? = nil,
            factory: ((Resolver) -> \(raw: typeName))? = nil
        ) {
            let namesToRegister = names ?? serviceNames
            let configuration = NamedServiceConfiguration(
                names: namesToRegister,
                protocolType: \(raw: arguments.protocolType != nil ? "\"\(arguments.protocolType!)\"" : "nil"),
                scope: serviceScope,
                isDefault: \(raw: arguments.isDefault),
                aliases: \(
                    raw: arguments.aliases
                        .isEmpty ? "[]" : "[\(arguments.aliases.map { "\"\($0)\"" }.joined(separator: ", "))]"
        ),
                priority: \(raw: arguments.priority)
            )

            // Register the configuration
            NamedServiceRegistry.register(configuration, for: "\(raw: typeName)")

            \(raw: registerMethodBody)
        }
        """))

        // Add name validation method
        members.append(DeclSyntax("""

        /// Check if a name is valid for this service
        static func isValidName(_ name: String) -> Bool {
            return serviceNames.contains(name) || name == serviceName
        }
        """))

        // Add resolution helper
        members.append(DeclSyntax("""

        /// Resolve this service by name from a container
        static func resolve(from container: Container, name: String? = nil) -> \(raw: typeName)? {
            let nameToUse = name ?? serviceName
            return container.resolve(\(raw: typeName).self, name: nameToUse)
        }
        """))

        return members
    }

    // MARK: - Helper Methods

    private struct MacroArguments {
        let primaryName: String
        let additionalNames: [String]
        let protocolType: String?
        let scope: String
        let isDefault: Bool
        let aliases: [String]
        let priority: Int

        var allNames: [String] {
            var names = [primaryName]
            names.append(contentsOf: additionalNames)
            names.append(contentsOf: aliases)
            return names
        }
    }

    private static func parseMacroArguments(from node: AttributeSyntax) -> MacroArguments {
        var primaryName = "default"
        var additionalNames: [String] = []
        var protocolType: String? = nil
        var scope = "graph"
        var isDefault = false
        var aliases: [String] = []
        var priority = 0

        // Parse the arguments
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for (index, argument) in arguments.enumerated() {
                if let label = argument.label?.text {
                    switch label {
                    case "_", "name":
                        if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                           let value = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
                        {
                            primaryName = value.content.text
                        }
                    case "names":
                        additionalNames = parseStringArray(from: argument.expression)
                    case "protocol":
                        if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                           let value = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
                        {
                            protocolType = value.content.text
                        }
                    case "scope":
                        scope = parseScopeArgument(from: argument.expression)
                    case "default":
                        if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                            isDefault = boolLiteral.literal.text == "true"
                        }
                    case "aliases":
                        aliases = parseStringArray(from: argument.expression)
                    case "priority":
                        if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                            priority = Int(intLiteral.literal.text) ?? 0
                        }
                    default:
                        break
                    }
                } else if index == 0 {
                    // First unlabeled argument is the primary name
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                       let value = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
                    {
                        primaryName = value.content.text
                    }
                }
            }
        }

        return MacroArguments(
            primaryName: primaryName,
            additionalNames: additionalNames,
            protocolType: protocolType,
            scope: scope,
            isDefault: isDefault,
            aliases: aliases,
            priority: priority
        )
    }

    private static func parseStringArray(from expression: ExprSyntax) -> [String] {
        var strings: [String] = []

        if let arrayExpr = expression.as(ArrayExprSyntax.self) {
            for element in arrayExpr.elements {
                if let stringLiteral = element.expression.as(StringLiteralExprSyntax.self),
                   let value = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
                {
                    strings.append(value.content.text)
                }
            }
        }

        return strings
    }

    private static func parseScopeArgument(from expression: ExprSyntax) -> String {
        let scopeText = expression.trimmedDescription

        // Handle ObjectScope enum cases
        if scopeText.contains(".container") || scopeText.contains("container") {
            return "container"
        } else if scopeText.contains(".transient") || scopeText.contains("transient") {
            return "transient"
        } else if scopeText.contains(".weak") || scopeText.contains("weak") {
            return "weak"
        } else {
            return "graph" // Default
        }
    }

    private static func scopeToSwiftCode(_ scope: String) -> String {
        switch scope {
        case "container":
            ".container"
        case "transient":
            ".transient"
        case "weak":
            ".weak"
        default:
            ".graph"
        }
    }

    private static func getTypeName(from declaration: DeclGroupSyntax) -> String {
        if let classDecl = declaration.as(ClassDeclSyntax.self) {
            return classDecl.name.text
        } else if let structDecl = declaration.as(StructDeclSyntax.self) {
            return structDecl.name.text
        }
        return "Unknown"
    }

    private static func generateRegisterMethodBody(
        typeName: String,
        arguments: MacroArguments,
        protocolTypeParam: String
    ) -> String {
        var body = """
        // Create factory if not provided
        let serviceFactory = factory ?? { resolver in
            // Attempt to resolve dependencies and create instance
            // For types conforming to Injectable, they should be resolved from the container
            // Otherwise, attempt a parameterless init
            return resolver.resolve(\(typeName).self) ?? \(typeName)()
        }

        // Register with primary name
        for name in namesToRegister {
            let registration = container.register(\(typeName).self, name: name, factory: serviceFactory)
            registration.inObjectScope(serviceScope)
        }
        """

        // Add default registration if specified
        if arguments.isDefault {
            body += """


            // Register as default (without name)
            let defaultRegistration = container.register(\(typeName).self, factory: serviceFactory)
            defaultRegistration.inObjectScope(serviceScope)
            """
        }

        return body
    }
}

// MARK: - Diagnostic Messages

private struct NamedMacroError: DiagnosticMessage, Error {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "NamedError")
    let severity: DiagnosticSeverity = .error
}

private struct NamedMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "NamedWarning")
    let severity: DiagnosticSeverity = .warning
}
