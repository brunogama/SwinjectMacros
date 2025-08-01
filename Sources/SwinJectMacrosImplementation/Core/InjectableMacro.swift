// InjectableMacro.swift - @Injectable macro implementation
// Copyright © 2025 SwinJectMacros. All rights reserved.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

/// Implementation of the @Injectable macro
public struct InjectableMacro: MemberMacro, ExtensionMacro {
    
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
                message: InjectableMacroError(message: """
                @Injectable can only be applied to classes or structs.
                
                ✅ Correct usage:
                @Injectable
                class UserService {
                    init(repository: UserRepository) { ... }
                }
                
                ❌ Invalid usage:
                @Injectable
                enum Status { ... } // Enums not supported
                @Injectable
                protocol ServiceProtocol { ... } // Protocols not supported
                """)
            )
            context.diagnose(diagnostic)
            return []
        }
        
        // Extract service information
        guard let serviceInfo = try extractInjectableServiceInfo(from: declaration, context: context) else {
            return []
        }
        
        // Parse macro arguments
        let config = try parseInjectableConfig(from: node)
        
        // Generate registration method
        let registrationMethod = try generateRegistrationMethod(
            for: serviceInfo,
            config: config,
            context: context
        )
        
        return [registrationMethod]
    }
    
    // MARK: - ExtensionMacro Implementation
    
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        
        // Create Injectable protocol conformance extension
        let typeName = type.trimmedDescription
        
        let extensionDecl = try ExtensionDeclSyntax("extension \(raw: typeName): Injectable") {
            // Empty conformance - the register method is added via MemberMacro
        }
        
        return [extensionDecl]
    }
    
    // MARK: - Configuration Parsing
    
    private static func parseInjectableConfig(from node: AttributeSyntax) throws -> InjectableConfig {
        var scope: String = ".graph"
        var name: String? = nil
        
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
                        name = segment.content.text
                    }
                default:
                    break
                }
            }
        }
        
        return InjectableConfig(scope: scope, name: name)
    }
    
    // MARK: - Service Information Extraction
    
    private static func extractInjectableServiceInfo(
        from declaration: some DeclGroupSyntax,
        context: some MacroExpansionContext
    ) throws -> InjectableServiceInfo? {
        
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
                message: InjectableMacroError(message: "@Injectable can only be applied to classes or structs")
            )
            context.diagnose(diagnostic)
            return nil
        }
        
        // Find primary initializer
        guard let initializer = findPrimaryInitializer(in: memberBlock) else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: InjectableMacroError(message: """
                @Injectable requires a class or struct with at least one initializer.
                
                ✅ Correct usage with dependencies:
                @Injectable
                class UserService {
                    init(repository: UserRepository, logger: LoggerProtocol) {
                        // Dependency injection initializer
                    }
                }
                
                ✅ Correct usage without dependencies:
                @Injectable
                class ConfigService {
                    init() {
                        // Default initializer
                    }
                }
                
                ❌ Invalid usage:
                @Injectable
                class BadService {
                    // Missing initializer - add init() method
                }
                
                💡 Tip: Make your initializer public for better dependency injection control.
                """)
            )
            context.diagnose(diagnostic)
            return nil
        }
        
        // Analyze dependencies
        let dependencies = analyzeDependencies(from: initializer)
        
        // Check for circular dependencies (simplified check)
        let dependencyTypes = dependencies.compactMap { dep in
            dep.classification == InjectableParameterClassification.serviceDependency ? dep.type : nil
        }
        
        if dependencyTypes.contains(serviceName) {
            let diagnostic = Diagnostic(
                node: initializer.root,
                message: InjectableMacroWarning(message: """
                Potential circular dependency detected in \(serviceName).
                
                ⚠️  Problem: \(serviceName) depends on itself, which can cause infinite recursion.
                
                💡 Solutions:
                1. Break the cycle by introducing an abstraction/protocol
                2. Use lazy injection: @LazyInject instead of direct dependency
                3. Consider if the dependency is really needed
                
                Example fix:
                // Before (circular):
                class UserService {
                    init(userService: UserService) { ... } // ❌ Self-dependency
                }
                
                // After (using protocol):
                protocol UserServiceProtocol { ... }
                class UserService: UserServiceProtocol {
                    init(validator: UserValidatorProtocol) { ... } // ✅ External dependency
                }
                """)
            )
            context.diagnose(diagnostic)
        }
        
        return InjectableServiceInfo(
            name: serviceName,
            dependencies: dependencies,
            initializer: initializer
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
    
    private static func analyzeDependencies(from initializer: InitializerDeclSyntax) -> [InjectableDependencyInfo] {
        return initializer.signature.parameterClause.parameters.compactMap { param in
            let paramName = param.firstName.text
            let typeText = param.type.trimmedDescription
            let classification = classifyParameter(param)
            let isOptional = param.type.is(OptionalTypeSyntax.self) || typeText.hasSuffix("?")
            let defaultValue = param.defaultValue?.value.trimmedDescription
            
            return InjectableDependencyInfo(
                name: paramName,
                type: typeText,
                classification: classification,
                isOptional: isOptional,
                defaultValue: defaultValue,
                isGeneric: typeText.contains("<")
            )
        }
    }
    
    private static func classifyParameter(_ param: FunctionParameterSyntax) -> InjectableParameterClassification {
        let typeText = param.type.trimmedDescription
        let hasDefaultValue = param.defaultValue != nil
        
        // Service-like dependencies
        if typeText.hasSuffix("Service") || typeText.hasSuffix("Repository") || 
           typeText.hasSuffix("Client") || typeText.hasSuffix("Manager") {
            return .serviceDependency
        }
        
        // Protocol dependencies
        if typeText.starts(with: "any ") || typeText.contains("Protocol") {
            return .protocolDependency
        }
        
        // Configuration parameters with defaults
        if hasDefaultValue {
            return .configurationParameter
        }
        
        // Value types are likely runtime parameters (but shouldn't be in @Injectable)
        let valueTypes = ["String", "Int", "Double", "Float", "Bool", "UUID", "Date"]
        if valueTypes.contains(where: { typeText.hasPrefix($0) }) {
            return .runtimeParameter
        }
        
        // Default to service dependency
        return .serviceDependency
    }
    
    // MARK: - Code Generation
    
    private static func generateRegistrationMethod(
        for serviceInfo: InjectableServiceInfo,
        config: InjectableConfig,
        context: some MacroExpansionContext
    ) throws -> DeclSyntax {
        
        let serviceName = serviceInfo.name
        let dependencies = serviceInfo.dependencies.filter { dep in
            dep.classification == InjectableParameterClassification.serviceDependency || dep.classification == InjectableParameterClassification.protocolDependency
        }
        
        // Build parameter list for initializer call
        let parameterList = dependencies.map { dependency in
            if dependency.isOptional {
                return "\(dependency.name): resolver.resolve(\(dependency.type).self)"
            } else {
                return "\(dependency.name): resolver.resolve(\(dependency.type).self)!"
            }
        }.joined(separator: ",\n                ")
        
        // Build name parameter if provided
        let nameParameter = config.name.map { ", name: \"\($0)\"" } ?? ""
        
        // Construct the method using SwiftSyntaxBuilder
        let functionDecl = try FunctionDeclSyntax("static func register(in container: Container)") {
            CodeBlockItemListSyntax {
                ExprSyntax("""
                container.register(\(raw: serviceName).self\(raw: nameParameter)) { resolver in
                    \(raw: serviceName)(
                        \(raw: parameterList)
                    )
                }.inObjectScope(\(raw: config.scope))
                """)
            }
        }
        
        return DeclSyntax(functionDecl)
    }
    
    private static func generateResolverCall(for dependency: InjectableDependencyInfo) -> String {
        if dependency.isOptional {
            return "\(dependency.name): resolver.resolve(\(dependency.type).self)"
        } else {
            return "\(dependency.name): resolver.resolve(\(dependency.type).self)!"
        }
    }
}

// MARK: - Supporting Types

private struct InjectableConfig {
    let scope: String
    let name: String?
}

private struct InjectableServiceInfo {
    let name: String
    let dependencies: [InjectableDependencyInfo]
    let initializer: InitializerDeclSyntax
}

private struct InjectableDependencyInfo {
    let name: String
    let type: String
    let classification: InjectableParameterClassification
    let isOptional: Bool
    let defaultValue: String?
    let isGeneric: Bool
}

private enum InjectableParameterClassification {
    case serviceDependency
    case protocolDependency
    case runtimeParameter
    case configurationParameter
}

// MARK: - Diagnostic Messages

private struct InjectableMacroError: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinJectMacros", id: "InjectableError")
    let severity: DiagnosticSeverity = .error
}

private struct InjectableMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinJectMacros", id: "InjectableWarning")
    let severity: DiagnosticSeverity = .warning
}