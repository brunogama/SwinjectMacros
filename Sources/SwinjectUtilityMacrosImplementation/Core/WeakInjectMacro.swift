// WeakInjectMacro.swift - @WeakInject macro implementation
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

/// Implementation of the @WeakInject macro for weak dependency injection.
public struct WeakInjectMacro: PeerMacro {
    
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
                message: WeakInjectMacroError(message: "@WeakInject can only be applied to variable properties")
            )
            context.diagnose(diagnostic)
            return []
        }
        
        // Ensure it's a stored property (not computed)
        guard varDecl.bindings.first?.accessorBlock == nil else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: WeakInjectMacroError(message: "@WeakInject can only be applied to stored properties")
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
                message: WeakInjectMacroError(message: "@WeakInject requires an explicit type annotation")
            )
            context.diagnose(diagnostic)
            return []
        }
        
        let propertyName = identifier.identifier.text
        let propertyType = typeAnnotation.type.trimmedDescription
        
        // Validate that the type is optional (required for weak references)
        guard propertyType.hasSuffix("?") else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: WeakInjectMacroError(message: """
                @WeakInject requires an optional type because weak references must be optional.
                
                ✅ Correct usage:
                @WeakInject var delegate: UserServiceDelegate?
                @WeakInject var parent: ParentViewControllerProtocol?
                @WeakInject("cache") var cacheManager: CacheManagerProtocol?
                
                ❌ Invalid usage:
                @WeakInject var delegate: UserServiceDelegate // Missing '?' for optional
                @WeakInject var service: UserService // Non-optional type
                
                💡 Why optional is required:
                - Weak references can become nil when the referenced object is deallocated
                - This prevents strong reference cycles and memory leaks
                - Use @LazyInject instead if you need a strong reference
                
                Quick fix: Add '?' to make the type optional
                """)
            )
            context.diagnose(diagnostic)
            return []
        }
        
        // Parse macro configuration
        let config = try parseWeakInjectConfig(from: node)
        
        // Generate the backing storage and accessor methods
        let backingProperties = try generateWeakBackingStorage(
            propertyName: propertyName,
            propertyType: propertyType,
            config: config,
            context: context
        )
        
        return backingProperties
    }
    
    // MARK: - Configuration Parsing
    
    private static func parseWeakInjectConfig(from node: AttributeSyntax) throws -> WeakInjectConfig {
        var serviceName: String? = nil
        var containerName = "default"
        var autoResolve = true
        
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
                case "autoResolve":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        autoResolve = boolLiteral.literal.text == "true"
                    }
                default:
                    break
                }
            }
        }
        
        return WeakInjectConfig(
            serviceName: serviceName,
            containerName: containerName,
            autoResolve: autoResolve
        )
    }
    
    // MARK: - Backing Storage Generation
    
    private static func generateWeakBackingStorage(
        propertyName: String,
        propertyType: String,
        config: WeakInjectConfig,
        context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        let backingPropertyName = "_\(propertyName)WeakBacking"
        let onceTokenName = "_\(propertyName)OnceToken"
        let accessorMethodName = "_\(propertyName)WeakAccessor"
        
        // Extract the non-optional type for resolution
        let nonOptionalType = String(propertyType.dropLast()) // Remove the "?"
        
        // Generate backing weak storage property
        let backingProperty = """
        private weak var \(backingPropertyName): \(nonOptionalType)?
        """
        
        // Generate thread-safe initialization flag for first resolution
        let onceToken = """
        private var \(onceTokenName): Bool = false
        """
        
        // Generate thread-safe lock
        let onceLock = """
        private let \(onceTokenName)Lock = NSLock()
        """
        
        // Generate weak accessor method
        let accessorMethod = try createWeakAccessorMethod(
            methodName: accessorMethodName,
            propertyName: propertyName,
            propertyType: propertyType,
            nonOptionalType: nonOptionalType,
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
    
    private static func createWeakAccessorMethod(
        methodName: String,
        propertyName: String,
        propertyType: String,
        nonOptionalType: String,
        backingPropertyName: String,
        onceTokenName: String,
        config: WeakInjectConfig
    ) throws -> String {
        
        let containerLookup = if config.containerName == "default" {
            "Container.shared"
        } else {
            "Container.named(\"\(config.containerName)\")"
        }
        
        let serviceLookup = if let serviceName = config.serviceName {
            "\(containerLookup).synchronizedResolve(\(nonOptionalType).self, name: \"\(serviceName)\")"
        } else {
            "\(containerLookup).synchronizedResolve(\(nonOptionalType).self)"
        }
        
        let autoResolveLogic = if config.autoResolve {
            """
            // Auto-resolve if reference is nil and auto-resolve is enabled
            if \(backingPropertyName) == nil {
                \(onceTokenName)Lock.lock()
                if !\(onceTokenName) {
                    \(onceTokenName) = true
                    \(onceTokenName)Lock.unlock()
                    resolveWeakReference()
                } else {
                    \(onceTokenName)Lock.unlock()
                }
            }
            """
        } else {
            """
            // One-time resolution only (auto-resolve disabled)
            \(onceTokenName)Lock.lock()
            if !\(onceTokenName) {
                \(onceTokenName) = true
                \(onceTokenName)Lock.unlock()
                resolveWeakReference()
            } else {
                \(onceTokenName)Lock.unlock()
            }
            """
        }
        
        return """
        private func \(methodName)() -> \(propertyType) {
            func resolveWeakReference() {
                let startTime = CFAbsoluteTimeGetCurrent()
                
                // Register property for metrics tracking
                let pendingInfo = WeakPropertyInfo(
                    propertyName: "\(propertyName)",
                    propertyType: "\(nonOptionalType)",
                    containerName: "\(config.containerName)",
                    serviceName: \(config.serviceName.map { "\"\($0)\"" } ?? "nil"),
                    autoResolve: \(config.autoResolve),
                    state: .pending,
                    initialResolutionTime: Date(),
                    threadInfo: ThreadInfo()
                )
                WeakInjectionMetrics.recordAccess(pendingInfo)
                
                do {
                    // Resolve dependency as weak reference
                    if let resolved = \(serviceLookup) {
                        \(backingPropertyName) = resolved
                        
                        // Record successful resolution
                        let resolvedInfo = WeakPropertyInfo(
                            propertyName: "\(propertyName)",
                            propertyType: "\(nonOptionalType)",
                            containerName: "\(config.containerName)",
                            serviceName: \(config.serviceName.map { "\"\($0)\"" } ?? "nil"),
                            autoResolve: \(config.autoResolve),
                            state: .resolved,
                            initialResolutionTime: Date(),
                            lastAccessTime: Date(),
                            resolutionCount: 1,
                            threadInfo: ThreadInfo()
                        )
                        WeakInjectionMetrics.recordAccess(resolvedInfo)
                    } else {
                        // Service not found - record failure
                        let error = WeakInjectionError.serviceNotRegistered(serviceName: \(config.serviceName.map { "\"\($0)\"" } ?? "nil"), type: "\(nonOptionalType)")
                        
                        let failedInfo = WeakPropertyInfo(
                            propertyName: "\(propertyName)",
                            propertyType: "\(nonOptionalType)",
                            containerName: "\(config.containerName)",
                            serviceName: \(config.serviceName.map { "\"\($0)\"" } ?? "nil"),
                            autoResolve: \(config.autoResolve),
                            state: .failed,
                            initialResolutionTime: Date(),
                            resolutionError: error,
                            threadInfo: ThreadInfo()
                        )
                        WeakInjectionMetrics.recordAccess(failedInfo)
                    }
                } catch {
                    // Record failed resolution
                    let failedInfo = WeakPropertyInfo(
                        propertyName: "\(propertyName)",
                        propertyType: "\(nonOptionalType)",
                        containerName: "\(config.containerName)",
                        serviceName: \(config.serviceName.map { "\"\($0)\"" } ?? "nil"),
                        autoResolve: \(config.autoResolve),
                        state: .failed,
                        initialResolutionTime: Date(),
                        resolutionError: error,
                        threadInfo: ThreadInfo()
                    )
                    WeakInjectionMetrics.recordAccess(failedInfo)
                }
            }
            
            \(autoResolveLogic)
            
            // Check if reference was deallocated and record deallocation
            if \(backingPropertyName) == nil {
                let deallocatedInfo = WeakPropertyInfo(
                    propertyName: "\(propertyName)",
                    propertyType: "\(nonOptionalType)",
                    containerName: "\(config.containerName)",
                    serviceName: \(config.serviceName.map { "\"\($0)\"" } ?? "nil"),
                    autoResolve: \(config.autoResolve),
                    state: .deallocated,
                    lastAccessTime: Date(),
                    deallocationTime: Date(),
                    threadInfo: ThreadInfo()
                )
                WeakInjectionMetrics.recordAccess(deallocatedInfo)
            }
            
            return \(backingPropertyName)
        }
        """
    }
}

// MARK: - Supporting Types

private struct WeakInjectConfig {
    let serviceName: String?
    let containerName: String
    let autoResolve: Bool
}

// MARK: - Diagnostic Messages

private struct WeakInjectMacroError: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "WeakInjectError")
    let severity: DiagnosticSeverity = .error
}

private struct WeakInjectMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "WeakInjectWarning")
    let severity: DiagnosticSeverity = .warning
}