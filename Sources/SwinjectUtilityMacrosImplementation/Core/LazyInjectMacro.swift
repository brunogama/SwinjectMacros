// LazyInjectMacro.swift - @LazyInject macro implementation
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @LazyInject macro for lazy dependency injection.
public struct LazyInjectMacro: AccessorMacro, PeerMacro {

    // MARK: - AccessorMacro Implementation

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {

        // Validate that this is applied to a variable
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
              let typeAnnotation = binding.typeAnnotation
        else {
            return []
        }

        let propertyName = identifier.identifier.text
        let propertyType = typeAnnotation.type.trimmedDescription
        let config = try parseLazyInjectConfig(from: node)

        // Determine the container reference
        let containerRef = config.containerName == "default"
            ? "Container.shared"
            : "LazyInjectionContainerRegistry.container(named: \"\(config.containerName)\")"

        // Build the service lookup expression
        let serviceLookup = config.serviceName.map { name in
            "\(containerRef).synchronizedResolve(\(propertyType).self, name: \"\(name)\")"
        } ?? "\(containerRef).synchronizedResolve(\(propertyType).self)"

        // Generate getter accessor
        let getter = AccessorDeclSyntax(
            accessorSpecifier: .keyword(.get),
            body: CodeBlockSyntax {
                // Check if already resolved
                """
                if _\(raw: propertyName)LazyResolved {
                    return _\(raw: propertyName)LazyValue!
                }

                // Thread-safe resolution
                _\(raw: propertyName)LazyLock.lock()
                defer { _\(raw: propertyName)LazyLock.unlock() }

                // Double-check after acquiring lock
                if _\(raw: propertyName)LazyResolved {
                    return _\(raw: propertyName)LazyValue!
                }

                // Track resolution
                let pendingInfo = LazyPropertyInfo(
                    propertyName: "\(raw: propertyName)",
                    propertyType: "\(raw: propertyType)",
                    containerName: "\(raw: config.containerName)",
                    serviceName: \(raw: config.serviceName.map { "\"\($0)\"" } ?? "nil"),
                    isRequired: \(raw: config.isRequired),
                    state: .pending,
                    resolutionTime: Date()
                )
                LazyInjectionMetrics.recordResolution(pendingInfo)

                do {
                    // Resolve dependency
                    guard let resolved = \(raw: serviceLookup) else {
                        let error = LazyInjectionError.serviceNotRegistered(serviceName: \(raw: config.serviceName
                    .map { "\"\($0)\"" } ?? "nil"
                ), type: "\(raw: propertyType)")

                        let failedInfo = LazyPropertyInfo(
                            propertyName: "\(raw: propertyName)",
                            propertyType: "\(raw: propertyType)",
                            containerName: "\(raw: config.containerName)",
                            serviceName: \(raw: config.serviceName.map { "\"\($0)\"" } ?? "nil"),
                            isRequired: \(raw: config.isRequired),
                            state: .failed,
                            resolutionTime: Date(),
                            resolutionError: error
                        )
                        LazyInjectionMetrics.recordResolution(failedInfo)

                        \(raw: config
                    .isRequired ? "fatalError(\"[LazyInject] Failed to resolve required dependency: \\(error)\")" :
                    "return nil"
                )
                    }

                    _\(raw: propertyName)LazyValue = resolved
                    _\(raw: propertyName)LazyResolved = true

                    let resolvedInfo = LazyPropertyInfo(
                        propertyName: "\(raw: propertyName)",
                        propertyType: "\(raw: propertyType)",
                        containerName: "\(raw: config.containerName)",
                        serviceName: \(raw: config.serviceName.map { "\"\($0)\"" } ?? "nil"),
                        isRequired: \(raw: config.isRequired),
                        state: .resolved,
                        resolutionTime: Date()
                    )
                    LazyInjectionMetrics.recordResolution(resolvedInfo)

                    return resolved
                } catch {
                    let failedInfo = LazyPropertyInfo(
                        propertyName: "\(raw: propertyName)",
                        propertyType: "\(raw: propertyType)",
                        containerName: "\(raw: config.containerName)",
                        serviceName: \(raw: config.serviceName.map { "\"\($0)\"" } ?? "nil"),
                        isRequired: \(raw: config.isRequired),
                        state: .failed,
                        resolutionTime: Date(),
                        resolutionError: error
                    )
                    LazyInjectionMetrics.recordResolution(failedInfo)

                    \(raw: config
                    .isRequired ? "fatalError(\"[LazyInject] Failed to resolve required dependency: \\(error)\")" :
                    "return nil"
                )
                }
                """
            }
        )

        return [getter]
    }

    // MARK: - PeerMacro Implementation

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // Validate that this is applied to a variable
        guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: LazyInjectMacroError(message: """
                @LazyInject can only be applied to variable properties.

                ✅ Correct usage:
                class UserService {
                    @LazyInject var repository: UserRepositoryProtocol
                    @LazyInject("database") var dbConnection: DatabaseConnection
                    @LazyInject(container: "network") var apiClient: APIClient
                }

                ❌ Invalid usage:
                @LazyInject
                func getRepository() -> Repository { ... } // Functions not supported

                @LazyInject
                let constValue = "test" // Constants not supported

                @LazyInject
                class MyService { ... } // Types not supported

                💡 Tips:
                - Use 'var' instead of 'let' for lazy properties
                - Provide explicit type annotations for better injection
                - Consider @WeakInject for optional weak references
                """)
            )
            context.diagnose(diagnostic)
            return []
        }

        // Ensure it's a stored property (not computed)
        guard varDecl.bindings.first?.accessorBlock == nil else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: LazyInjectMacroError(message: """
                @LazyInject can only be applied to stored properties, not computed properties.

                ✅ Correct usage (stored property):
                @LazyInject var repository: UserRepositoryProtocol

                ❌ Invalid usage (computed property):
                @LazyInject var repository: UserRepositoryProtocol {
                    get { ... }
                    set { ... }
                }

                💡 Solution: Remove the getter/setter and let @LazyInject generate the lazy access logic.
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
                message: LazyInjectMacroError(message: """
                @LazyInject requires an explicit type annotation to determine what to inject.

                ✅ Correct usage:
                @LazyInject var repository: UserRepositoryProtocol
                @LazyInject var apiClient: APIClientProtocol
                @LazyInject var database: DatabaseConnection?

                ❌ Invalid usage:
                @LazyInject var repository // Missing type annotation
                @LazyInject var service = SomeService() // Type inferred from assignment

                💡 Tips:
                - Always provide explicit type annotations
                - Use protocols for better testability
                - Mark as optional if the service might not be available
                """)
            )
            context.diagnose(diagnostic)
            return []
        }

        let propertyName = identifier.identifier.text
        let propertyType = typeAnnotation.type.trimmedDescription

        // Parse macro configuration
        let config = try parseLazyInjectConfig(from: node)

        // Generate the backing storage and accessor methods
        let backingProperties = try generateBackingStorage(
            propertyName: propertyName,
            propertyType: propertyType,
            config: config,
            context: context
        )

        return backingProperties
    }

    // MARK: - Configuration Parsing

    private static func parseLazyInjectConfig(from node: AttributeSyntax) throws -> LazyInjectConfig {
        var serviceName: String? = nil
        var containerName = "default"
        var isRequired = true

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
                case "container":
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
                    {
                        containerName = segment.content.text
                    }
                case "required":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        isRequired = boolLiteral.literal.text == "true"
                    }
                default:
                    break
                }
            }
        }

        return LazyInjectConfig(
            serviceName: serviceName,
            containerName: containerName,
            isRequired: isRequired
        )
    }

    // MARK: - Backing Storage Generation

    private static func generateBackingStorage(
        propertyName: String,
        propertyType: String,
        config: LazyInjectConfig,
        context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        let valueName = "_\(propertyName)LazyValue"
        let resolvedName = "_\(propertyName)LazyResolved"
        let lockName = "_\(propertyName)LazyLock"

        // Generate backing value storage
        let valueProperty = VariableDeclSyntax(
            modifiers: [DeclModifierSyntax(name: .keyword(.private))],
            bindingSpecifier: .keyword(.var),
            bindings: PatternBindingListSyntax {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier(valueName)),
                    typeAnnotation: TypeAnnotationSyntax(
                        type: OptionalTypeSyntax(
                            wrappedType: IdentifierTypeSyntax(name: .identifier(propertyType))
                        )
                    )
                )
            }
        )

        // Generate resolved flag
        let resolvedFlag = VariableDeclSyntax(
            modifiers: [DeclModifierSyntax(name: .keyword(.private))],
            bindingSpecifier: .keyword(.var),
            bindings: PatternBindingListSyntax {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier(resolvedName)),
                    typeAnnotation: TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: .identifier("Bool"))),
                    initializer: InitializerClauseSyntax(value: BooleanLiteralExprSyntax(literal: .keyword(.false)))
                )
            }
        )

        // Generate thread-safe lock using AST
        let lock = VariableDeclSyntax(
            modifiers: [DeclModifierSyntax(name: .keyword(.private))],
            bindingSpecifier: .keyword(.let),
            bindings: PatternBindingListSyntax {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier(lockName)),
                    initializer: InitializerClauseSyntax(
                        value: FunctionCallExprSyntax(
                            calledExpression: ExprSyntax("NSLock"),
                            leftParen: .leftParenToken(),
                            arguments: [],
                            rightParen: .rightParenToken()
                        )
                    )
                )
            }
        )

        return [
            DeclSyntax(valueProperty),
            DeclSyntax(resolvedFlag),
            DeclSyntax(lock)
        ]
    }
}

// MARK: - Supporting Types

private struct LazyInjectConfig {
    let serviceName: String?
    let containerName: String
    let isRequired: Bool
}

// MARK: - Diagnostic Messages

private struct LazyInjectMacroError: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "LazyInjectError")
    let severity: DiagnosticSeverity = .error
}

private struct LazyInjectMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "LazyInjectWarning")
    let severity: DiagnosticSeverity = .warning
}
