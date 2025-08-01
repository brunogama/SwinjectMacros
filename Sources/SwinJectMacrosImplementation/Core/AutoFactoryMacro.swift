// AutoFactoryMacro.swift - @AutoFactory macro implementation
// Copyright © 2025 SwinJectMacros. All rights reserved.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

/// Implementation of the @AutoFactory macro
public struct AutoFactoryMacro: PeerMacro {
    
    // MARK: - PeerMacro Implementation
    
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        // Validate that this is applied to a class or struct
        guard declaration.is(ClassDeclSyntax.self) || declaration.is(StructDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: AutoFactoryMacroError(message: "@AutoFactory can only be applied to classes or structs")
            )
            context.diagnose(diagnostic)
            return []
        }
        
        // Extract service information
        guard let serviceInfo = try extractAutoFactoryServiceInfo(from: declaration, context: context) else {
            return []
        }
        
        // Parse macro arguments
        let config = try parseAutoFactoryConfig(from: node)
        
        // Generate factory protocol and implementation
        let factoryProtocol = try generateFactoryProtocol(
            for: serviceInfo,
            config: config,
            context: context
        )
        
        let factoryImplementation = try generateFactoryImplementation(
            for: serviceInfo,
            config: config,
            context: context
        )
        
        return [factoryProtocol, factoryImplementation]
    }
    
    // MARK: - Configuration Parsing
    
    private static func parseAutoFactoryConfig(from node: AttributeSyntax) throws -> AutoFactoryConfig {
        var scope: String = ".container"
        var factoryName: String? = nil
        var isAsync: Bool = false
        var canThrow: Bool = false
        
        // Parse attribute arguments
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                switch argument.label?.text {
                case "scope":
                    if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
                        scope = ".\(memberAccess.declName.baseName.text)"
                    }
                case "name":
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                        factoryName = segment.content.text
                    }
                case "async":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        isAsync = boolLiteral.literal.text == "true"
                    }
                case "throws":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        canThrow = boolLiteral.literal.text == "true"
                    }
                default:
                    break
                }
            }
        }
        
        return AutoFactoryConfig(
            scope: scope,
            factoryName: factoryName,
            isAsync: isAsync,
            canThrow: canThrow
        )
    }
    
    // MARK: - Service Information Extraction
    
    private static func extractAutoFactoryServiceInfo(
        from declaration: some DeclSyntaxProtocol,
        context: some MacroExpansionContext
    ) throws -> AutoFactoryServiceInfo? {
        
        let serviceName: String
        let memberBlock: MemberBlockSyntax
        
        // Extract name and member block based on declaration type
        if let classDecl = declaration.as(ClassDeclSyntax.self) {
            serviceName = classDecl.name.text
            memberBlock = classDecl.memberBlock
        } else if let structDecl = declaration.as(StructDeclSyntax.self) {
            serviceName = structDecl.name.text
            memberBlock = structDecl.memberBlock
        } else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: AutoFactoryMacroError(message: "@AutoFactory can only be applied to classes or structs")
            )
            context.diagnose(diagnostic)
            return nil
        }
        
        // Find primary initializer
        guard let initializer = findPrimaryInitializer(in: memberBlock) else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: AutoFactoryMacroError(message: "@AutoFactory requires a class or struct with an initializer")
            )
            context.diagnose(diagnostic)
            return nil
        }
        
        // Analyze dependencies and separate injected vs runtime parameters
        let allDependencies = analyzeDependencies(from: initializer)
        let (injectedDependencies, runtimeParameters) = separateDependencies(allDependencies)
        
        // Validate that we have at least one runtime parameter (otherwise use @Injectable)
        if runtimeParameters.isEmpty {
            let diagnostic = Diagnostic(
                node: initializer.root,
                message: AutoFactoryMacroWarning(message: "@AutoFactory is designed for services with runtime parameters. Consider using @Injectable instead.")
            )
            context.diagnose(diagnostic)
        }
        
        return AutoFactoryServiceInfo(
            name: serviceName,
            injectedDependencies: injectedDependencies,
            runtimeParameters: runtimeParameters,
            initializer: initializer,
            isAsync: initializer.isAsync,
            canThrow: initializer.canThrow
        )
    }
    
    private static func findPrimaryInitializer(in memberBlock: MemberBlockSyntax) -> InitializerDeclSyntax? {
        let initializers = memberBlock.members.compactMap { member in
            member.decl.as(InitializerDeclSyntax.self)
        }
        
        // Prefer public initializers
        let publicInitializers = initializers.filter { initializer in
            initializer.modifiers.contains { $0.name.text == "public" }
        }
        
        return publicInitializers.first ?? initializers.first
    }
    
    private static func analyzeDependencies(from initializer: InitializerDeclSyntax) -> [AutoFactoryDependencyInfo] {
        return initializer.signature.parameterClause.parameters.compactMap { param in
            let paramName = param.firstName.text
            let typeText = param.type.trimmedDescription
            let classification = classifyParameter(param)
            let isOptional = param.type.is(OptionalTypeSyntax.self) || typeText.hasSuffix("?")
            let defaultValue = param.defaultValue?.value.trimmedDescription
            
            return AutoFactoryDependencyInfo(
                name: paramName,
                type: typeText,
                classification: classification,
                isOptional: isOptional,
                defaultValue: defaultValue,
                isGeneric: typeText.contains("<")
            )
        }
    }
    
    private static func separateDependencies(_ dependencies: [AutoFactoryDependencyInfo]) -> (injected: [AutoFactoryDependencyInfo], runtime: [AutoFactoryDependencyInfo]) {
        let injected = dependencies.filter { dep in
            dep.classification == .serviceDependency || dep.classification == .protocolDependency
        }
        
        let runtime = dependencies.filter { dep in
            dep.classification == .runtimeParameter || dep.classification == .configurationParameter
        }
        
        return (injected, runtime)
    }
    
    private static func classifyParameter(_ param: FunctionParameterSyntax) -> AutoFactoryParameterClassification {
        let typeText = param.type.trimmedDescription
        let hasDefaultValue = param.defaultValue != nil
        
        // Service-like dependencies (will be injected)
        if typeText.hasSuffix("Service") || typeText.hasSuffix("Repository") || 
           typeText.hasSuffix("Client") || typeText.hasSuffix("Manager") {
            return .serviceDependency
        }
        
        // Protocol dependencies (will be injected)
        if typeText.starts(with: "any ") || typeText.contains("Protocol") {
            return .protocolDependency
        }
        
        // Configuration parameters with defaults (runtime)
        if hasDefaultValue {
            return .configurationParameter
        }
        
        // Value types are likely runtime parameters
        let valueTypes = ["String", "Int", "Double", "Float", "Bool", "UUID", "Date", "URL"]
        if valueTypes.contains(where: { typeText.hasPrefix($0) }) {
            return .runtimeParameter
        }
        
        // Default to service dependency for other types
        return .serviceDependency
    }
    
    // MARK: - Code Generation
    
    private static func generateFactoryProtocol(
        for serviceInfo: AutoFactoryServiceInfo,
        config: AutoFactoryConfig,
        context: some MacroExpansionContext
    ) throws -> DeclSyntax {
        
        let serviceName = serviceInfo.name
        let factoryName = config.factoryName ?? "\(serviceName)Factory"
        let methodName = "make\(serviceName)"
        
        // Generate parameter list for runtime parameters
        let parameterList = serviceInfo.runtimeParameters.map { param in
            "\(param.name): \(param.type)"
        }.joined(separator: ", ")
        
        // Build method signature
        var methodSignature = "func \(methodName)(\(parameterList))"
        
        if config.isAsync || serviceInfo.isAsync {
            methodSignature += " async"
        }
        
        if config.canThrow || serviceInfo.canThrow {
            methodSignature += " throws"
        }
        
        methodSignature += " -> \(serviceName)"
        
        let protocolCode = """
        protocol \(factoryName) {
            \(methodSignature)
        }
        """
        
        return DeclSyntax.fromString(protocolCode)
    }
    
    private static func generateFactoryImplementation(
        for serviceInfo: AutoFactoryServiceInfo,
        config: AutoFactoryConfig,
        context: some MacroExpansionContext
    ) throws -> DeclSyntax {
        
        let serviceName = serviceInfo.name
        let factoryName = config.factoryName ?? "\(serviceName)Factory"
        let implName = "\(serviceName)FactoryImpl"
        let methodName = "make\(serviceName)"
        
        // Generate parameter list for runtime parameters
        let parameterList = serviceInfo.runtimeParameters.map { param in
            "\(param.name): \(param.type)"
        }.joined(separator: ", ")
        
        // Generate parameter resolution for injected dependencies
        let injectedParams = serviceInfo.injectedDependencies.map { dependency in
            generateResolverCall(for: dependency)
        }
        
        // Generate parameter list for service initialization
        let initParams = (injectedParams + serviceInfo.runtimeParameters.map { "\($0.name): \($0.name)" })
            .joined(separator: ",\n                ")
        
        // Build method signature
        var methodSignature = "func \(methodName)(\(parameterList))"
        
        if config.isAsync || serviceInfo.isAsync {
            methodSignature += " async"
        }
        
        if config.canThrow || serviceInfo.canThrow {
            methodSignature += " throws"
        }
        
        methodSignature += " -> \(serviceName)"
        
        let implCode = """
        class \(implName): \(factoryName), BaseFactory {
            let resolver: Resolver
            
            init(resolver: Resolver) {
                self.resolver = resolver
            }
            
            \(methodSignature) {
                \((config.canThrow || serviceInfo.canThrow) ? "try " : "")\((config.isAsync || serviceInfo.isAsync) ? "await " : "")\(serviceName)(
                    \(initParams)
                )
            }
        }
        """
        
        return DeclSyntax.fromString(implCode)
    }
    
    private static func generateResolverCall(for dependency: AutoFactoryDependencyInfo) -> String {
        if dependency.isOptional {
            return "\(dependency.name): resolver.synchronizedResolve(\(dependency.type).self)"
        } else {
            return "\(dependency.name): resolver.synchronizedResolve(\(dependency.type).self)!"
        }
    }
}

// MARK: - Supporting Types

private struct AutoFactoryConfig {
    let scope: String
    let factoryName: String?
    let isAsync: Bool
    let canThrow: Bool
}

private struct AutoFactoryServiceInfo {
    let name: String
    let injectedDependencies: [AutoFactoryDependencyInfo]
    let runtimeParameters: [AutoFactoryDependencyInfo]
    let initializer: InitializerDeclSyntax
    let isAsync: Bool
    let canThrow: Bool
}

private struct AutoFactoryDependencyInfo {
    let name: String
    let type: String
    let classification: AutoFactoryParameterClassification
    let isOptional: Bool
    let defaultValue: String?
    let isGeneric: Bool
}

private enum AutoFactoryParameterClassification {
    case serviceDependency
    case protocolDependency
    case runtimeParameter
    case configurationParameter
}

// MARK: - Diagnostic Messages

private struct AutoFactoryMacroError: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinJectMacros", id: "AutoFactoryError")
    let severity: DiagnosticSeverity = .error
}

private struct AutoFactoryMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinJectMacros", id: "AutoFactoryWarning")  
    let severity: DiagnosticSeverity = .warning
}