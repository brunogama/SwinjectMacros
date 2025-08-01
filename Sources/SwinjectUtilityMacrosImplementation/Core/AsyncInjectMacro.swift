// AsyncInjectMacro.swift - @AsyncInject macro implementation
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

/// Implementation of the @AsyncInject macro for asynchronous dependency injection.
public struct AsyncInjectMacro: PeerMacro {
    
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
                message: AsyncInjectMacroError(message: """
                @AsyncInject can only be applied to variable properties.
                
                ✅ Correct usage:
                class DataService {
                    @AsyncInject var database: DatabaseProtocol
                    @AsyncInject var apiClient: APIClientProtocol
                }
                
                ❌ Invalid usage:
                @AsyncInject
                func getDatabaseConnection() -> Database { ... } // Functions not supported
                
                @AsyncInject
                let constValue = "test" // Constants not supported
                
                💡 Tips:
                - Use 'var' instead of 'let' for async properties
                - Provide explicit type annotations for better injection
                - Consider @LazyInject for synchronous lazy resolution
                """)
            )
            context.diagnose(diagnostic)
            return []
        }
        
        // Ensure it's a stored property (not computed)
        guard varDecl.bindings.first?.accessorBlock == nil else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: AsyncInjectMacroError(message: """
                @AsyncInject can only be applied to stored properties, not computed properties.
                
                ✅ Correct usage (stored property):
                @AsyncInject var database: DatabaseProtocol
                
                ❌ Invalid usage (computed property):
                @AsyncInject var database: DatabaseProtocol {
                    get { ... }
                    set { ... }
                }
                
                💡 Solution: Remove the getter/setter and let @AsyncInject generate the async access logic.
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
                message: AsyncInjectMacroError(message: """
                @AsyncInject requires an explicit type annotation to determine what to inject.
                
                ✅ Correct usage:
                @AsyncInject var database: DatabaseProtocol
                @AsyncInject var apiClient: APIClientProtocol
                @AsyncInject var cache: CacheProtocol?
                
                ❌ Invalid usage:
                @AsyncInject var service // Missing type annotation
                @AsyncInject var service = SomeService() // Type inferred from assignment
                
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
        let config = try parseAsyncInjectConfig(from: node)
        
        // Generate the async storage and accessor methods
        let asyncProperties = try generateAsyncStorage(
            propertyName: propertyName,
            propertyType: propertyType,
            config: config,
            context: context
        )
        
        return asyncProperties
    }
    
    // MARK: - Configuration Parsing
    
    private static func parseAsyncInjectConfig(from node: AttributeSyntax) throws -> AsyncInjectConfig {
        var serviceName: String? = nil
        var containerName = "default"
        var timeout: TimeInterval = 30.0
        var initializationTimeout: TimeInterval = 60.0
        var retryCount = 3
        
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
                case "timeout":
                    if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self),
                       let timeoutValue = Double(floatLiteral.literal.text) {
                        timeout = timeoutValue
                    } else if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self),
                              let timeoutValue = Double(intLiteral.literal.text) {
                        timeout = timeoutValue
                    }
                case "initializationTimeout":
                    if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self),
                       let timeoutValue = Double(floatLiteral.literal.text) {
                        initializationTimeout = timeoutValue
                    } else if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self),
                              let timeoutValue = Double(intLiteral.literal.text) {
                        initializationTimeout = timeoutValue
                    }
                case "retryCount":
                    if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self),
                       let retryValue = Int(intLiteral.literal.text) {
                        retryCount = retryValue
                    }
                default:
                    break
                }
            }
        }
        
        return AsyncInjectConfig(
            serviceName: serviceName,
            containerName: containerName,
            timeout: timeout,
            initializationTimeout: initializationTimeout,
            retryCount: retryCount
        )
    }
    
    // MARK: - Async Storage Generation
    
    private static func generateAsyncStorage(
        propertyName: String,
        propertyType: String,
        config: AsyncInjectConfig,
        context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        let taskPropertyName = "_\(propertyName)Task"
        let lockPropertyName = "_\(propertyName)Lock"
        let accessorMethodName = "_\(propertyName)AsyncAccessor"
        
        // Generate async task storage property
        let taskProperty = """
        private var \(taskPropertyName): Task<\(propertyType), Error>?
        """
        
        // Generate lock for thread safety
        let lockProperty = """
        private let \(lockPropertyName) = NSLock()
        """
        
        // Generate async accessor method
        let accessorMethod = try createAsyncAccessorMethod(
            methodName: accessorMethodName,
            propertyName: propertyName,
            propertyType: propertyType,
            taskPropertyName: taskPropertyName,
            lockPropertyName: lockPropertyName,
            config: config
        )
        
        // Generate computed property that returns the task
        let computedProperty = """
        var \(propertyName): Task<\(propertyType), Error> {
            get {
                return \(accessorMethodName)()
            }
        }
        """
        
        return [
            DeclSyntax.fromString(taskProperty),
            DeclSyntax.fromString(lockProperty), 
            DeclSyntax.fromString(accessorMethod),
            DeclSyntax.fromString(computedProperty)
        ]
    }
    
    // MARK: - Helper Methods
    
    private static func createAsyncAccessorMethod(
        methodName: String,
        propertyName: String,
        propertyType: String,
        taskPropertyName: String,
        lockPropertyName: String,
        config: AsyncInjectConfig
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
        
        return """
        private func \(methodName)() -> Task<\(propertyType), Error> {
            \(lockPropertyName).lock()
            defer { \(lockPropertyName).unlock() }
            
            // Return existing task if already created
            if let existingTask = \(taskPropertyName) {
                return existingTask
            }
            
            // Create new async resolution task
            let task = Task<\(propertyType), Error> {
                let startTime = Date()
                
                // Register property for metrics tracking
                let pendingInfo = AsyncPropertyInfo(
                    propertyName: "\(propertyName)",
                    propertyType: "\(propertyType)",
                    containerName: "\(config.containerName)",
                    serviceName: \(config.serviceName.map { "\"\($0)\"" } ?? "nil"),
                    timeout: \(config.timeout),
                    initializationTimeout: \(config.initializationTimeout),
                    retryCount: \(config.retryCount),
                    state: .resolving,
                    resolutionStartTime: startTime,
                    attemptCount: 0,
                    taskInfo: TaskInfo()
                )
                AsyncInjectionMetrics.recordResolution(pendingInfo)
                
                var lastError: Error?
                var attemptCount = 0
                
                // Retry logic
                while attemptCount <= \(config.retryCount) {
                    attemptCount += 1
                    
                    do {
                        // Perform async resolution with timeout
                        let resolved = try await withThrowingTaskGroup(of: \(propertyType)?.self) { group in
                            group.addTask {
                                try await Task.sleep(nanoseconds: 0) // Yield execution
                                return \(serviceLookup)
                            }
                            
                            group.addTask {
                                try await Task.sleep(nanoseconds: UInt64(\(config.timeout) * 1_000_000_000))
                                throw AsyncInjectionError.resolutionTimeout(type: "\(propertyType)", timeout: \(config.timeout))
                            }
                            
                            if let result = try await group.next() {
                                group.cancelAll()
                                return result
                            }
                            
                            throw AsyncInjectionError.resolutionFailed(type: "\(propertyType)", underlyingError: nil)
                        }
                        
                        guard let service = resolved else {
                            throw AsyncInjectionError.serviceNotRegistered(serviceName: \(config.serviceName.map { "\"\($0)\"" } ?? "nil"), type: "\(propertyType)")
                        }
                        
                        // Record successful resolution
                        let endTime = Date()
                        let duration = endTime.timeIntervalSince(startTime)
                        
                        let resolvedInfo = AsyncPropertyInfo(
                            propertyName: "\(propertyName)",
                            propertyType: "\(propertyType)",
                            containerName: "\(config.containerName)",
                            serviceName: \(config.serviceName.map { "\"\($0)\"" } ?? "nil"),
                            timeout: \(config.timeout),
                            initializationTimeout: \(config.initializationTimeout),
                            retryCount: \(config.retryCount),
                            state: .resolved,
                            resolutionStartTime: startTime,
                            resolutionEndTime: endTime,
                            resolutionDuration: duration,
                            attemptCount: attemptCount,
                            taskInfo: TaskInfo()
                        )
                        AsyncInjectionMetrics.recordResolution(resolvedInfo)
                        
                        return service
                        
                    } catch {
                        lastError = error
                        
                        // If this is not the last attempt, wait before retrying
                        if attemptCount <= \(config.retryCount) {
                            let backoffDelay = Double(attemptCount) * 0.5 // Exponential backoff
                            try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                        }
                    }
                }
                
                // Record failed resolution
                let endTime = Date()
                let duration = endTime.timeIntervalSince(startTime)
                let finalError = lastError ?? AsyncInjectionError.maxRetriesExceeded(type: "\(propertyType)", attempts: attemptCount)
                
                let failedInfo = AsyncPropertyInfo(
                    propertyName: "\(propertyName)",
                    propertyType: "\(propertyType)",
                    containerName: "\(config.containerName)",
                    serviceName: \(config.serviceName.map { "\"\($0)\"" } ?? "nil"),
                    timeout: \(config.timeout),
                    initializationTimeout: \(config.initializationTimeout),
                    retryCount: \(config.retryCount),
                    state: .failed,
                    resolutionStartTime: startTime,
                    resolutionEndTime: endTime,
                    resolutionDuration: duration,
                    attemptCount: attemptCount,
                    resolutionError: finalError,
                    taskInfo: TaskInfo()
                )
                AsyncInjectionMetrics.recordResolution(failedInfo)
                
                throw finalError
            }
            
            \(taskPropertyName) = task
            return task
        }
        """
    }
}

// MARK: - Supporting Types

private struct AsyncInjectConfig {
    let serviceName: String?
    let containerName: String
    let timeout: TimeInterval
    let initializationTimeout: TimeInterval
    let retryCount: Int
}

// MARK: - Diagnostic Messages

private struct AsyncInjectMacroError: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "AsyncInjectError")
    let severity: DiagnosticSeverity = .error
}

private struct AsyncInjectMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "AsyncInjectWarning")
    let severity: DiagnosticSeverity = .warning
}