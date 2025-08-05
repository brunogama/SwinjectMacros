// OptionalInjectMacro.swift - Optional dependency injection implementation
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @OptionalInject macro
///
/// Enables optional dependency injection where services may or may not be available,
/// providing graceful degradation when dependencies are not registered.
public struct OptionalInjectMacro: AccessorMacro {

    // MARK: - AccessorMacro Implementation

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {

        // Validate that this is applied to a variable
        guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: OptionalInjectMacroError(message: """
                @OptionalInject can only be applied to variable properties.

                ✅ Correct usage:
                class NotificationService {
                    @OptionalInject var pushService: PushServiceProtocol?
                    @OptionalInject("primary") var database: DatabaseProtocol?
                    @OptionalInject(default: ConsoleLogger()) var logger: LoggerProtocol
                }

                ❌ Invalid usage:
                @OptionalInject
                func getService() -> Service { ... } // Functions not supported

                @OptionalInject
                let constValue = "test" // Constants not supported

                💡 Tips:
                - Use optional types for truly optional dependencies
                - Provide default values for fallback behavior
                - Consider @LazyInject for required dependencies
                """)
            )
            context.diagnose(diagnostic)
            return []
        }

        // Get the property information
        guard let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
              let typeAnnotation = binding.typeAnnotation
        else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: OptionalInjectMacroError(message: """
                @OptionalInject requires an explicit type annotation.

                ✅ Correct:
                @OptionalInject var service: ServiceProtocol?

                ❌ Invalid:
                @OptionalInject var service // Missing type
                """)
            )
            context.diagnose(diagnostic)
            return []
        }

        let propertyName = identifier.identifier.text
        let typeName = typeAnnotation.type.trimmedDescription

        // Parse macro arguments
        let arguments = parseMacroArguments(from: node)

        // Validate: Non-optional types must have a default or fallback
        let isOptional = typeName.hasSuffix("?") || typeName.hasSuffix("!")
        let hasDefault = arguments.defaultValue != nil || arguments.fallbackMethod != nil

        if !isOptional && !hasDefault {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: OptionalInjectMacroError(message: """
                @OptionalInject on non-optional type '\(typeName)' requires a default value or fallback method.

                ✅ Solutions:
                1. Make the property optional:
                   @OptionalInject var \(propertyName): \(typeName)?

                2. Provide a default value:
                   @OptionalInject(default: Default\(typeName)()) var \(propertyName): \(typeName)

                3. Provide a fallback method:
                   @OptionalInject(fallback: "createDefault\(typeName)") var \(propertyName): \(typeName)

                4. Use @LazyInject instead for required dependencies:
                   @LazyInject var \(propertyName): \(typeName)

                💡 @OptionalInject is designed for optional dependencies that may not be available.
                For required dependencies, use @LazyInject or @Injectable.
                """)
            )
            context.diagnose(diagnostic)
            return []
        }

        // Generate the backing storage property name
        let storageName = "_\(propertyName)_optionalInject"
        let lockName = "_\(propertyName)_lock"

        // Generate the getter implementation
        let getterBody = generateGetterBody(
            propertyName: propertyName,
            typeName: typeName,
            storageName: storageName,
            lockName: lockName,
            arguments: arguments
        )

        let getter = AccessorDeclSyntax(
            accessorSpecifier: .keyword(.get)
        ) {
            getterBody
        }

        // For @OptionalInject, we only provide a getter since it's meant for
        // optional dependencies that are resolved from the container
        return [getter]
    }

    // MARK: - Helper Methods

    private struct MacroArguments {
        let name: String?
        let defaultValue: String?
        let fallbackMethod: String?
        let isLazy: Bool
        let resolverName: String
    }

    private static func parseMacroArguments(from node: AttributeSyntax) -> MacroArguments {
        var name: String? = nil
        var defaultValue: String? = nil
        var fallbackMethod: String? = nil
        var isLazy = true
        var resolverName = "resolver"

        // Parse the arguments
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                if let label = argument.label?.text {
                    switch label {
                    case "_", "name":
                        if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                           let value = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
                        {
                            name = value.content.text
                        }
                    case "default":
                        defaultValue = argument.expression.trimmedDescription
                    case "fallback":
                        if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                           let value = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
                        {
                            fallbackMethod = value.content.text
                        }
                    case "lazy":
                        if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                            isLazy = boolLiteral.literal.text == "true"
                        }
                    case "resolver":
                        if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                           let value = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
                        {
                            resolverName = value.content.text
                        }
                    default:
                        break
                    }
                } else if argument == arguments.first {
                    // First unlabeled argument is the name
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                       let value = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
                    {
                        name = value.content.text
                    }
                }
            }
        }

        return MacroArguments(
            name: name,
            defaultValue: defaultValue,
            fallbackMethod: fallbackMethod,
            isLazy: isLazy,
            resolverName: resolverName
        )
    }

    private static func generateGetterBody(
        propertyName: String,
        typeName: String,
        storageName: String,
        lockName: String,
        arguments: MacroArguments
    ) -> CodeBlockItemListSyntax {

        let isOptional = typeName.hasSuffix("?") || typeName.hasSuffix("!")
        let baseType = typeName.trimmingCharacters(in: CharacterSet(charactersIn: "?!"))

        var getterCode = ""

        // Since we can't declare backing storage with AccessorMacro,
        // we'll use a simpler approach without caching for lazy mode
        // The user can switch to @LazyInject if they need caching

        // Resolution logic
        if let name = arguments.name {
            getterCode = """
            let resolved = \(arguments.resolverName).resolve(\(baseType).self, name: "\(name)")
            """
        } else {
            getterCode = """
            let resolved = \(arguments.resolverName).resolve(\(baseType).self)
            """
        }

        // Handle fallback/default
        if let fallbackMethod = arguments.fallbackMethod {
            getterCode += """

            return resolved ?? \(fallbackMethod)()
            """
        } else if let defaultValue = arguments.defaultValue {
            getterCode += """

            return resolved ?? \(defaultValue)
            """
        } else if isOptional {
            getterCode += """

            return resolved
            """
        } else {
            // This case should never be reached due to compile-time validation
            getterCode += """

            return resolved
            """
        }

        return CodeBlockItemListSyntax([
            CodeBlockItemSyntax(item: .expr(ExprSyntax(stringLiteral: getterCode)))
        ])
    }
}

// MARK: - Diagnostic Messages

private struct OptionalInjectMacroError: DiagnosticMessage, Error {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "OptionalInjectError")
    let severity: DiagnosticSeverity = .error
}

private struct OptionalInjectMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "OptionalInjectWarning")
    let severity: DiagnosticSeverity = .warning
}
