// LazyInjectMacro.swift - @LazyInject macro implementation
// Copyright © 2025 SwinJectMacros. All rights reserved.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

/// Implementation of the @LazyInject macro for lazy dependency injection.
public struct LazyInjectMacro: PeerMacro {
    
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
              let typeAnnotation = binding.typeAnnotation else {
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
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                        serviceName = segment.content.text
                    }
                case "container":
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
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
        
        let backingPropertyName = "_\(propertyName)Backing"
        let onceTokenName = "_\(propertyName)OnceToken"
        let accessorMethodName = "_\(propertyName)LazyAccessor"
        
        // Generate backing storage property
        let backingProperty = """
        private var \(backingPropertyName): \(propertyType)?
        """
        
        // Generate thread-safe lazy initialization flag
        let onceToken = """
        private var \(onceTokenName): Bool = false
        """
        
        // Generate thread-safe lock
        let onceLock = """
        private let \(onceTokenName)Lock = NSLock()
        """
        
        // Generate lazy accessor method
        let accessorMethod = try createAccessorMethod(
            methodName: accessorMethodName,
            propertyName: propertyName,
            propertyType: propertyType,
            backingPropertyName: backingPropertyName,
            onceTokenName: onceTokenName,
            config: config
        )
        
        return [
            DeclSyntax.fromString(backingProperty),
            DeclSyntax.fromString(onceToken),
            DeclSyntax.fromString(onceLock),
            DeclSyntax.fromString(accessorMethod)
        ]
    }
    
    // MARK: - Helper Methods
    
    private static func createAccessorMethod(
        methodName: String,
        propertyName: String,
        propertyType: String,
        backingPropertyName: String,
        onceTokenName: String,
        config: LazyInjectConfig
    ) throws -> String {
        
        let containerLookup = if config.containerName == "default" {
            "Container.shared"
        } else {
            "Container.named(\"\(config.containerName)\")"
        }
        
        let serviceLookup = if let serviceName = config.serviceName {
            "\(containerLookup).synchronizedResolve(\(propertyType).self, name: \"\(serviceName)\")"
        } else {
            "\(containerLookup).synchronizedResolve(\(propertyType).self)"
        }
        
        let resolutionHandling = if config.isRequired {
            """
            guard let resolved = \(serviceLookup) else {
                let error = LazyInjectionError.serviceNotRegistered(serviceName: \(config.serviceName.map { "\"\($0)\"" } ?? "nil"), type: "\(propertyType)")
                
                // Record failed resolution
                let failedInfo = LazyPropertyInfo(
                    propertyName: "\(propertyName)",
                    propertyType: "\(propertyType)",
                    containerName: "\(config.containerName)",
                    serviceName: \(config.serviceName.map { "\"\($0)\"" } ?? "nil"),
                    isRequired: \(config.isRequired),
                    state: .failed,
                    resolutionTime: Date(),
                    resolutionError: error,
                    threadInfo: ThreadInfo()
                )
                LazyInjectionMetrics.recordResolution(failedInfo)
                
                fatalError("Required lazy property '\(propertyName)' of type '\(propertyType)' could not be resolved: \\(error.localizedDescription)")
            }
            
            \(backingPropertyName) = resolved
            """
        } else {
            """
            \(backingPropertyName) = \(serviceLookup)
            """
        }
        
        return """
        private func \(methodName)() -> \(propertyType) {
            // Thread-safe lazy initialization
            \(onceTokenName)Lock.lock()
            defer { \(onceTokenName)Lock.unlock() }
            
            if !\(onceTokenName) {
                \(onceTokenName) = true
                let startTime = CFAbsoluteTimeGetCurrent()
                
                // Register property for metrics tracking
                let pendingInfo = LazyPropertyInfo(
                    propertyName: "\(propertyName)",
                    propertyType: "\(propertyType)",
                    containerName: "\(config.containerName)",
                    serviceName: \(config.serviceName.map { "\"\($0)\"" } ?? "nil"),
                    isRequired: \(config.isRequired),
                    state: .resolving,
                    resolutionTime: Date(),
                    threadInfo: ThreadInfo()
                )
                LazyInjectionMetrics.recordResolution(pendingInfo)
                
                do {
                    // Resolve dependency
                    \(resolutionHandling)
                    
                    // Record successful resolution
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let resolutionDuration = endTime - startTime
                    
                    let resolvedInfo = LazyPropertyInfo(
                        propertyName: "\(propertyName)",
                        propertyType: "\(propertyType)",
                        containerName: "\(config.containerName)",
                        serviceName: \(config.serviceName.map { "\"\($0)\"" } ?? "nil"),
                        isRequired: \(config.isRequired),
                        state: .resolved,
                        resolutionTime: Date(),
                        resolutionDuration: resolutionDuration,
                        threadInfo: ThreadInfo()
                    )
                    LazyInjectionMetrics.recordResolution(resolvedInfo)
                    
                } catch {
                    // Record failed resolution
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let resolutionDuration = endTime - startTime
                    
                    let failedInfo = LazyPropertyInfo(
                        propertyName: "\(propertyName)",
                        propertyType: "\(propertyType)",
                        containerName: "\(config.containerName)",
                        serviceName: \(config.serviceName.map { "\"\($0)\"" } ?? "nil"),
                        isRequired: \(config.isRequired),
                        state: .failed,
                        resolutionTime: Date(),
                        resolutionDuration: resolutionDuration,
                        resolutionError: error,
                        threadInfo: ThreadInfo()
                    )
                    LazyInjectionMetrics.recordResolution(failedInfo)
                    
                    if \(config.isRequired) {
                        fatalError("Failed to resolve required lazy property '\(propertyName)': \\(error.localizedDescription)")
                    }
                }
            }
            
            guard let resolvedValue = \(backingPropertyName) else {
                let error = LazyInjectionError.requiredServiceUnavailable(propertyName: "\(propertyName)", type: "\(propertyType)")
                fatalError("Lazy property '\(propertyName)' could not be resolved: \\(error.localizedDescription)")
            }
            return resolvedValue
        }
        """
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
    let diagnosticID = MessageID(domain: "SwinJectMacros", id: "LazyInjectError")
    let severity: DiagnosticSeverity = .error
}

private struct LazyInjectMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinJectMacros", id: "LazyInjectWarning")
    let severity: DiagnosticSeverity = .warning
}