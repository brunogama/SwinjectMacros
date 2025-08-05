// EnvironmentInjectMacro.swift - @EnvironmentInject macro implementation

import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @EnvironmentInject macro for SwiftUI Environment-based dependency injection.
public struct EnvironmentInjectMacro: AccessorMacro {

    // MARK: - AccessorMacro Implementation

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {

        // Validate that this is applied to a variable property
        guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: EnvironmentInjectMacroError(message: """
                @EnvironmentInject can only be applied to variable properties.

                ✅ Correct usage:
                struct ContentView: View {
                    @EnvironmentInject var userService: UserServiceProtocol
                    @EnvironmentInject var analytics: AnalyticsProtocol
                }

                ❌ Invalid usage:
                @EnvironmentInject
                func getUserService() -> UserService { ... } // Functions not supported

                @EnvironmentInject
                let service = UserService() // Constants not supported

                💡 Solution: Use 'var' for properties that should be injected from the environment.
                """)
            )
            context.diagnose(diagnostic)
            return []
        }

        // Ensure it's a stored property (not computed)
        guard varDecl.bindings.first?.accessorBlock == nil else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: EnvironmentInjectMacroError(message: """
                @EnvironmentInject can only be applied to stored properties, not computed properties.

                ✅ Correct usage (stored property):
                @EnvironmentInject var userService: UserServiceProtocol

                ❌ Invalid usage (computed property):
                @EnvironmentInject var userService: UserServiceProtocol {
                    get { ... }
                    set { ... }
                }

                💡 Solution: Remove the getter/setter and let @EnvironmentInject handle property access.
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
                message: EnvironmentInjectMacroError(message: """
                @EnvironmentInject requires an explicit type annotation.

                ✅ Correct usage:
                @EnvironmentInject var userService: UserServiceProtocol
                @EnvironmentInject var analytics: AnalyticsService
                @EnvironmentInject var optionalService: OptionalService?

                ❌ Invalid usage:
                @EnvironmentInject var userService // Missing type annotation
                @EnvironmentInject var service = SomeService() // Type inferred from assignment

                💡 Tips:
                - Always provide explicit type annotations for injected properties
                - Use protocols for better testability and flexibility
                - Mark as optional (T?) if the service might not be available
                """)
            )
            context.diagnose(diagnostic)
            return []
        }

        let propertyName = identifier.identifier.text
        let propertyType = typeAnnotation.type.trimmedDescription

        // Check if the type is optional
        let isOptional = propertyType.hasSuffix("?")
        let nonOptionalType = isOptional ? String(propertyType.dropLast()) : propertyType

        // Parse macro configuration
        let config = try parseEnvironmentInjectConfig(from: node)

        // Generate the property getter that resolves from SwiftUI Environment
        let getter = try generateEnvironmentGetter(
            propertyName: propertyName,
            propertyType: propertyType,
            nonOptionalType: nonOptionalType,
            isOptional: isOptional,
            config: config,
            context: context
        )

        return [
            AccessorDeclSyntax(accessorSpecifier: .keyword(.get)) {
                getter
            }
        ]
    }

    // MARK: - Configuration Parsing

    private static func parseEnvironmentInjectConfig(from node: AttributeSyntax) throws -> EnvironmentInjectConfig {
        var serviceName: String? = nil
        var required = true
        var containerKeyPath = "\\.diContainer"

        // Parse attribute arguments
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                switch argument.label?.text {
                case nil: // First unlabeled argument is service name
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
                    {
                        serviceName = segment.content.text
                    }
                case "required":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        required = boolLiteral.literal.text == "true"
                    }
                case "container":
                    // Handle container key path - simplified for now
                    containerKeyPath = argument.expression.trimmedDescription
                default:
                    break
                }
            }
        }

        return EnvironmentInjectConfig(
            serviceName: serviceName,
            required: required,
            containerKeyPath: containerKeyPath
        )
    }

    // MARK: - Code Generation

    private static func generateEnvironmentGetter(
        propertyName: String,
        propertyType: String,
        nonOptionalType: String,
        isOptional: Bool,
        config: EnvironmentInjectConfig,
        context: some MacroExpansionContext
    ) throws -> CodeBlockItemListSyntax {

        let containerAccess = "Environment(\\EnvironmentValues\(config.containerKeyPath)).wrappedValue"
        let serviceLookup = if let serviceName = config.serviceName {
            "\(containerAccess).resolve(\(nonOptionalType).self, name: \"\(serviceName)\")"
        } else {
            "\(containerAccess).resolve(\(nonOptionalType).self)"
        }

        let errorHandling = if config.required && !isOptional {
            """
            guard let resolved = \(serviceLookup) else {
                let error = EnvironmentInjectError.requiredServiceMissing(type: "\(nonOptionalType)")
                fatalError("Environment injection failed: \\(error.localizedDescription)")
            }
            return resolved
            """
        } else {
            """
            return \(serviceLookup)
            """
        }

        let getterBody = """
        // Environment-based dependency injection
        let startTime = CFAbsoluteTimeGetCurrent()

        // Access DI container from SwiftUI Environment
        \(errorHandling)
        """

        // Parse the generated code into SwiftSyntax
        guard let sourceFile = Parser.parse(source: """
        func dummyFunction() {
            \(getterBody)
        }
        """).as(SourceFileSyntax.self),
            let functionDecl = sourceFile.statements.first?.item.as(FunctionDeclSyntax.self),
            let codeBlock = functionDecl.body?.statements
        else {
            throw EnvironmentInjectMacroError(message: "Failed to generate getter implementation")
        }

        return codeBlock
    }
}

// MARK: - Supporting Types

private struct EnvironmentInjectConfig {
    let serviceName: String?
    let required: Bool
    let containerKeyPath: String
}

// MARK: - Diagnostic Messages

private struct EnvironmentInjectMacroError: DiagnosticMessage, Error {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "EnvironmentInjectError")
    let severity: DiagnosticSeverity = .error
}

private struct EnvironmentInjectMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "EnvironmentInjectWarning")
    let severity: DiagnosticSeverity = .warning
}
