// ValidatedContainerMacro.swift - @ValidatedContainer macro implementation

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @ValidatedContainer macro for compile-time container validation.
public struct ValidatedContainerMacro: PeerMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // Validate that this is applied to a class
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: ValidatedContainerMacroError(message: """
                @ValidatedContainer can only be applied to classes.

                ✅ Correct usage:
                @ValidatedContainer
                class AppContainer {
                    static func configure() -> Container {
                        let container = Container()
                        // Service registrations...
                        return container
                    }
                }

                ❌ Invalid usage:
                @ValidatedContainer
                struct AppContainer { ... } // Structs not supported

                @ValidatedContainer
                protocol ContainerProtocol { ... } // Protocols not supported

                💡 Solution: Use classes for container configuration with static methods.
                """)
            )
            context.diagnose(diagnostic)
            return []
        }

        let className = classDecl.name.text

        // Parse macro configuration
        let config = try parseValidatedContainerConfig(from: node)

        // Analyze container methods to understand service registrations
        let containerAnalysis = try analyzeContainerMethods(in: classDecl, context: context)

        // Perform validation analysis
        let validationResults = try performValidationAnalysis(
            analysis: containerAnalysis,
            config: config,
            declaration: declaration,
            context: context
        )

        // Generate validation infrastructure
        var generatedDeclarations: [DeclSyntax] = []

        // Generate validation methods
        let validationMethods = try generateValidationMethods(
            className: className,
            analysis: containerAnalysis,
            config: config
        )
        generatedDeclarations.append(contentsOf: validationMethods)

        // Generate dependency graph methods
        let graphMethods = try generateDependencyGraphMethods(
            className: className,
            analysis: containerAnalysis
        )
        generatedDeclarations.append(contentsOf: graphMethods)

        // Generate documentation if requested
        if config.generateDocumentation {
            let documentationMethods = try generateDocumentationMethods(
                className: className,
                analysis: containerAnalysis
            )
            generatedDeclarations.append(contentsOf: documentationMethods)
        }

        return generatedDeclarations
    }

    // MARK: - Configuration Parsing

    private static func parseValidatedContainerConfig(from node: AttributeSyntax) throws -> ValidatedContainerConfig {
        var strictMode = false
        var validateScopes = true
        var checkCircularDependencies = true
        var requireDocumentation = false
        var analyzePerformance = false
        var generateDocumentation = false

        // Parse attribute arguments
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                switch argument.label?.text {
                case "strictMode":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        strictMode = boolLiteral.literal.text == "true"
                    }
                case "validateScopes":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        validateScopes = boolLiteral.literal.text == "true"
                    }
                case "checkCircularDependencies":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        checkCircularDependencies = boolLiteral.literal.text == "true"
                    }
                case "requireDocumentation":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        requireDocumentation = boolLiteral.literal.text == "true"
                    }
                case "analyzePerformance":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        analyzePerformance = boolLiteral.literal.text == "true"
                    }
                case "generateDocumentation":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        generateDocumentation = boolLiteral.literal.text == "true"
                    }
                default:
                    break
                }
            }
        }

        return ValidatedContainerConfig(
            strictMode: strictMode,
            validateScopes: validateScopes,
            checkCircularDependencies: checkCircularDependencies,
            requireDocumentation: requireDocumentation,
            analyzePerformance: analyzePerformance,
            generateDocumentation: generateDocumentation
        )
    }

    // MARK: - Container Analysis

    private static func analyzeContainerMethods(
        in classDecl: ClassDeclSyntax,
        context: some MacroExpansionContext
    ) throws -> ContainerAnalysis {

        var serviceMethods: [String] = []
        var serviceRegistrations: [ServiceRegistration] = []

        // Look for static methods that return Container
        for member in classDecl.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self),
               funcDecl.modifiers.contains(where: { $0.name.text == "static" }),
               let returnType = funcDecl.signature.returnClause?.type.trimmedDescription,
               returnType == "Container"
            {

                serviceMethods.append(funcDecl.name.text)

                // Analyze method body for service registrations
                if let body = funcDecl.body {
                    let registrations = try analyzeServiceRegistrations(in: body)
                    serviceRegistrations.append(contentsOf: registrations)
                }
            }
        }

        return ContainerAnalysis(
            serviceMethods: serviceMethods,
            serviceRegistrations: serviceRegistrations
        )
    }

    private static func analyzeServiceRegistrations(in body: CodeBlockSyntax) throws -> [ServiceRegistration] {
        var registrations: [ServiceRegistration] = []

        // This is a simplified analysis - in a real implementation,
        // we would parse the AST to extract actual service registrations
        for statement in body.statements {
            // Look for container.register() calls
            if let exprStmt = statement.item.as(ExpressionStmtSyntax.self),
               let funcCall = exprStmt.expression.as(FunctionCallExprSyntax.self)
            {

                // Extract service type from the call if possible
                if let serviceType = extractServiceType(from: funcCall) {
                    registrations.append(ServiceRegistration(
                        serviceType: serviceType,
                        scope: extractScope(from: funcCall) ?? "transient",
                        dependencies: extractDependencies(from: funcCall)
                    ))
                }
            }
        }

        return registrations
    }

    private static func extractServiceType(from funcCall: FunctionCallExprSyntax) -> String? {
        // Simplified extraction - would need more sophisticated parsing
        // to handle all cases of container.register(ServiceType.self) { ... }
        nil // Placeholder
    }

    private static func extractScope(from funcCall: FunctionCallExprSyntax) -> String? {
        // Extract .inObjectScope(...) calls
        nil // Placeholder
    }

    private static func extractDependencies(from funcCall: FunctionCallExprSyntax) -> [String] {
        // Extract resolver.resolve(...) calls from the factory closure
        [] // Placeholder
    }

    // MARK: - Validation Analysis

    private static func performValidationAnalysis(
        analysis: ContainerAnalysis,
        config: ValidatedContainerConfig,
        declaration: some DeclSyntaxProtocol,
        context: some MacroExpansionContext
    ) throws -> ValidationResults {

        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []

        // Check for circular dependencies if enabled
        if config.checkCircularDependencies {
            let circularDeps = detectCircularDependencies(in: analysis)
            errors.append(contentsOf: circularDeps.map { .circularDependency($0) })
        }

        // Validate scopes if enabled
        if config.validateScopes {
            let scopeIssues = validateScopes(in: analysis)
            warnings.append(contentsOf: scopeIssues.map { .invalidScope($0) })
        }

        // Check documentation if required
        if config.requireDocumentation {
            let docIssues = validateDocumentation(in: analysis)
            errors.append(contentsOf: docIssues.map { .missingDocumentation($0) })
        }

        // Report errors and warnings
        for error in errors {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: ValidatedContainerMacroError(message: error.description)
            )
            context.diagnose(diagnostic)
        }

        for warning in warnings {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: ValidatedContainerMacroWarning(message: warning.description)
            )
            context.diagnose(diagnostic)
        }

        return ValidationResults(errors: errors, warnings: warnings)
    }

    private static func detectCircularDependencies(in analysis: ContainerAnalysis) -> [String] {
        // Implement circular dependency detection algorithm
        [] // Placeholder
    }

    private static func validateScopes(in analysis: ContainerAnalysis) -> [String] {
        // Validate scope configurations
        [] // Placeholder
    }

    private static func validateDocumentation(in analysis: ContainerAnalysis) -> [String] {
        // Check for missing documentation
        [] // Placeholder
    }

    // MARK: - Code Generation

    private static func generateValidationMethods(
        className: String,
        analysis: ContainerAnalysis,
        config: ValidatedContainerConfig
    ) throws -> [DeclSyntax] {

        var declarations: [DeclSyntax] = []

        // Generate main validation method
        let validationMethod = """
            /// Validates the container configuration at runtime
            static func validateContainer(_ container: Container) throws {
                \(
                    analysis.serviceRegistrations
                        .map { "try validate\($0.serviceType.replacingOccurrences(of: ".", with: ""))(container)" }
                        .joined(separator: "\n                ")
            )
            }
            """
        declarations.append(DeclSyntax.fromString(validationMethod))

        // Generate individual service validation methods
        for registration in analysis.serviceRegistrations {
            let serviceValidation = generateServiceValidationMethod(for: registration)
            declarations.append(DeclSyntax.fromString(serviceValidation))
        }

        return declarations
    }

    private static func generateServiceValidationMethod(for registration: ServiceRegistration) -> String {
        let serviceName = registration.serviceType.replacingOccurrences(of: ".", with: "")
        return """
        private static func validate\(serviceName)(_ container: Container) throws {
            guard container.resolve(\(registration.serviceType).self) != nil else {
                throw ContainerValidationError.serviceNotRegistered("\(registration.serviceType)")
            }
        }
        """
    }

    private static func generateDependencyGraphMethods(
        className: String,
        analysis: ContainerAnalysis
    ) throws -> [DeclSyntax] {

        let graphMethod = """
            /// Returns the dependency graph for this container
            static func getDependencyGraph() -> DependencyGraph {
                let services: Set<String> = [\(
                    analysis.serviceRegistrations.map { "\"\($0.serviceType)\"" }
                        .joined(separator: ", ")
            )]
                let dependencies: [String: Set<String>] = [
                    \(analysis.serviceRegistrations.map { registration in
                        let deps = registration.dependencies.map { "\"\($0)\"" }.joined(separator: ", ")
                        return "\"\(registration.serviceType)\": [\(deps)]"
                    }.joined(separator: ",\n                    "))
                ]
                return DependencyGraph(services: services, dependencies: dependencies)
            }
            """

        return [DeclSyntax.fromString(graphMethod)]
    }

    private static func generateDocumentationMethods(
        className: String,
        analysis: ContainerAnalysis
    ) throws -> [DeclSyntax] {

        let docMethod = """
            /// Returns documentation for all registered services
            static func getServiceDocumentation() -> [String: String] {
                return [
                    \(
                        analysis.serviceRegistrations
                            .map { "\"\($0.serviceType)\": \"Service registration for \($0.serviceType)\"" }
                            .joined(separator: ",\n                    ")
            )
                ]
            }
            """

        return [DeclSyntax.fromString(docMethod)]
    }
}

// MARK: - Supporting Types

private struct ValidatedContainerConfig {
    let strictMode: Bool
    let validateScopes: Bool
    let checkCircularDependencies: Bool
    let requireDocumentation: Bool
    let analyzePerformance: Bool
    let generateDocumentation: Bool
}

private struct ContainerAnalysis {
    let serviceMethods: [String]
    let serviceRegistrations: [ServiceRegistration]
}

private struct ServiceRegistration {
    let serviceType: String
    let scope: String
    let dependencies: [String]
}

private struct ValidationResults {
    let errors: [ValidationError]
    let warnings: [ValidationWarning]
}

private enum ValidationError {
    case circularDependency(String)
    case missingService(String)
    case missingDocumentation(String)

    var description: String {
        switch self {
        case .circularDependency(let cycle):
            "Circular dependency detected: \(cycle)"
        case .missingService(let service):
            "Service not registered: \(service)"
        case .missingDocumentation(let service):
            "Missing documentation for service: \(service)"
        }
    }
}

private enum ValidationWarning {
    case invalidScope(String)
    case performanceIssue(String)

    var description: String {
        switch self {
        case .invalidScope(let issue):
            "Scope configuration issue: \(issue)"
        case .performanceIssue(let issue):
            "Performance concern: \(issue)"
        }
    }
}

// MARK: - Diagnostic Messages

private struct ValidatedContainerMacroError: DiagnosticMessage, Error {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "ValidatedContainerError")
    let severity: DiagnosticSeverity = .error
}

private struct ValidatedContainerMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "ValidatedContainerWarning")
    let severity: DiagnosticSeverity = .warning
}
