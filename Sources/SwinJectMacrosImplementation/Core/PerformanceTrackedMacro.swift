// PerformanceTrackedMacro.swift - @PerformanceTracked macro implementation
// Copyright © 2025 SwinJectMacros. All rights reserved.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

/// Implementation of the @PerformanceTracked macro for automatic performance monitoring.
public struct PerformanceTrackedMacro: PeerMacro {
    
    // MARK: - PeerMacro Implementation
    
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        // Validate that this is applied to a function
        guard let functionDecl = declaration.as(FunctionDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: PerformanceTrackedMacroError(message: "@PerformanceTracked can only be applied to functions and methods")
            )
            context.diagnose(diagnostic)
            return []
        }
        
        // Parse macro configuration
        let config = try parsePerformanceTrackedConfig(from: node)
        
        // Extract function information
        let functionInfo = extractFunctionInfo(from: functionDecl)
        
        // Generate performance-tracked version of the function
        let performanceTrackedFunction = try generatePerformanceTrackedFunction(
            original: functionDecl,
            functionInfo: functionInfo,
            config: config,
            context: context
        )
        
        return [performanceTrackedFunction]
    }
    
    // MARK: - Configuration Parsing
    
    private static func parsePerformanceTrackedConfig(from node: AttributeSyntax) throws -> PerformanceTrackedConfig {
        var threshold: Double = 1000.0
        var sampleRate: Double = 1.0
        var memoryTracking: Bool = false
        var includeStackTrace: Bool = false
        var includeParameters: Bool = false
        var category: String? = nil
        
        // Parse attribute arguments
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                switch argument.label?.text {
                case "threshold":
                    if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self) {
                        threshold = Double(floatLiteral.literal.text) ?? 1000.0
                    } else if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                        threshold = Double(intLiteral.literal.text) ?? 1000.0
                    }
                case "sampleRate":
                    if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self) {
                        sampleRate = Double(floatLiteral.literal.text) ?? 1.0
                    }
                case "memoryTracking":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        memoryTracking = boolLiteral.literal.text == "true"
                    }
                case "includeStackTrace":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        includeStackTrace = boolLiteral.literal.text == "true"
                    }
                case "includeParameters":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        includeParameters = boolLiteral.literal.text == "true"
                    }
                case "category":
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                        category = segment.content.text
                    }
                default:
                    break
                }
            }
        }
        
        return PerformanceTrackedConfig(
            threshold: threshold,
            sampleRate: sampleRate,
            memoryTracking: memoryTracking,
            includeStackTrace: includeStackTrace,
            includeParameters: includeParameters,
            category: category
        )
    }
    
    // MARK: - Function Information Extraction
    
    private static func extractFunctionInfo(from functionDecl: FunctionDeclSyntax) -> PerformanceTrackedFunctionInfo {
        let functionName = functionDecl.name.text
        let isAsync = functionDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let canThrow = functionDecl.signature.effectSpecifiers?.throwsSpecifier != nil
        let returnType = functionDecl.signature.returnClause?.type.trimmedDescription ?? "Void"
        
        // Extract parameters
        let parameters = functionDecl.signature.parameterClause.parameters.map { param in
            let externalName = param.firstName.text
            let internalName = param.secondName?.text ?? param.firstName.text
            
            return PerformanceTrackedParameterInfo(
                externalName: externalName,
                internalName: internalName,
                type: param.type.trimmedDescription,
                isOptional: param.type.isOptional,
                defaultValue: param.defaultValue?.value.trimmedDescription
            )
        }
        
        return PerformanceTrackedFunctionInfo(
            name: functionName,
            parameters: parameters,
            returnType: returnType,
            isAsync: isAsync,
            canThrow: canThrow,
            isStatic: functionDecl.modifiers.contains { $0.name.text == "static" },
            accessLevel: extractAccessLevel(from: functionDecl.modifiers)
        )
    }
    
    private static func extractAccessLevel(from modifiers: DeclModifierListSyntax) -> String {
        for modifier in modifiers {
            switch modifier.name.text {
            case "public": return "public"
            case "internal": return "internal"
            case "fileprivate": return "fileprivate"
            case "private": return "private"
            default: continue
            }
        }
        return "internal" // Default access level
    }
    
    // MARK: - Code Generation
    
    private static func generatePerformanceTrackedFunction(
        original: FunctionDeclSyntax,
        functionInfo: PerformanceTrackedFunctionInfo,
        config: PerformanceTrackedConfig,
        context: some MacroExpansionContext
    ) throws -> DeclSyntax {
        
        let originalName = functionInfo.name
        let performanceTrackedName = "\(originalName)PerformanceTracked"
        
        // Generate parameter list for function signature
        let parameterList = functionInfo.parameters.map { param in
            let fullParam = param.fullSignatureParameter
            let paramType = param.type
            if let defaultValue = param.defaultValue {
                return "\(fullParam): \(paramType) = \(defaultValue)"
            } else {
                return "\(fullParam): \(paramType)"
            }
        }.joined(separator: ", ")
        
        // Generate parameter names for original function call
        let parameterNames = functionInfo.parameters.map { param in
            param.callParameter
        }.joined(separator: ", ")
        
        
        // Build function signature
        var functionSignature = "public"
        if functionInfo.isStatic {
            functionSignature += " static"
        }
        functionSignature += " func \(performanceTrackedName)(\(parameterList))"
        
        if functionInfo.isAsync {
            functionSignature += " async"
        }
        
        if functionInfo.canThrow {
            functionSignature += " throws"
        }
        
        if functionInfo.returnType != "Void" {
            functionSignature += " -> \(functionInfo.returnType)"
        }
        
        // Generate return statement
        let returnStatement = if functionInfo.returnType != "Void" {
            "return result"
        } else {
            ""
        }
        
        // Create properly formatted function body
        let functionBody = try createFormattedFunctionBody(
            signature: functionSignature,
            originalName: originalName,
            parameterNames: parameterNames,
            returnStatement: returnStatement,
            config: config,
            functionInfo: functionInfo
        )
        
        return DeclSyntax.fromString(functionBody)
    }
    
    // MARK: - Helper Methods
    
    private static func createFormattedFunctionBody(
        signature: String,
        originalName: String,
        parameterNames: String,
        returnStatement: String,
        config: PerformanceTrackedConfig,
        functionInfo: PerformanceTrackedFunctionInfo
    ) throws -> String {
        
        // Generate sampling check if needed
        let samplingCheck = if config.sampleRate < 1.0 {
            """
                // Sample rate check - only track \(config.sampleRate * 100)% of calls
                guard Double.random(in: 0...1) <= \(config.sampleRate) else {
                    // Execute without performance tracking
                    \(functionInfo.canThrow ? "return try " : "return ")\(functionInfo.isAsync ? "await " : "")\(originalName)(\(parameterNames))
                }
            """
        } else {
            ""
        }
        
        // Generate memory tracking setup
        let memorySetup = if config.memoryTracking {
            """
            let initialMemory = MemoryMonitor.getCurrentMemoryUsage()
            var peakMemory = initialMemory
            """
        } else {
            """
            let initialMemory: Int64 = 0
            let peakMemory: Int64 = 0
            """
        }
        
        // Generate method execution
        let methodExecution = if config.memoryTracking {
            """
            let memoryResult = MemoryMonitor.trackMemoryUsage {
                \(functionInfo.canThrow ? "try " : "")\(functionInfo.isAsync ? "await " : "")\(originalName)(\(parameterNames))
            }
            let result = memoryResult.result
            let memoryUsed = memoryResult.memoryUsed
            let finalPeakMemory = memoryResult.peakMemory
            """
        } else {
            """
            let result = \(functionInfo.canThrow ? "try " : "")\(functionInfo.isAsync ? "await " : "")\(originalName)(\(parameterNames))
            let memoryUsed: Int64 = 0
            let finalPeakMemory: Int64 = 0
            """
        }
        
        // Generate stack trace collection
        let stackTraceCollection = if config.includeStackTrace {
            """
            let stackTrace: [String]? = if executionTime > \(config.threshold) {
                Thread.callStackSymbols
            } else {
                nil
            }
            """
        } else {
            "let stackTrace: [String]? = nil"
        }
        
        // Generate parameters collection
        let parametersCollection: String
        if config.includeParameters {
            let paramDict = functionInfo.parameters.map { param in
                "\"\(param.internalName)\": \(param.internalName)"
            }.joined(separator: ", ")
            parametersCollection = "let parameters: [String: Any] = [\(paramDict)]"
        } else {
            parametersCollection = "let parameters: [String: Any]? = nil"
        }
        
        // Generate category determination
        let categoryDetermination = if let category = config.category {
            "let category = \"\(category)\""
        } else {
            "let category = String(describing: type(of: self))"
        }
        
        // Generate threshold logging
        let thresholdLogging = """
        if executionTime > \(config.threshold) {
                    print("⚠️ SLOW METHOD: \\(typeName).\\(methodName) took \\(String(format: \"%.2f\", executionTime))ms (threshold: \(config.threshold)ms)")
                }
        """
        
        // Build the complete function body
        return """
        \(signature) {\(samplingCheck.isEmpty ? "" : "\n\(samplingCheck)\n")
            // Performance tracking setup
            let startTime = CFAbsoluteTimeGetCurrent()
            let threadInfo = ThreadInfo()
            \(memorySetup)
            
            let methodName = "\(originalName)"
            let typeName = String(describing: type(of: self))
            \(categoryDetermination)
            
            do {
                // Execute original method with memory tracking
                \(methodExecution)
                
                // Calculate performance metrics
                let endTime = CFAbsoluteTimeGetCurrent()
                let executionTime = (endTime - startTime) * 1000 // Convert to milliseconds
                
                // Generate stack trace if needed for slow calls
                \(stackTraceCollection)
                
                // Collect parameters if enabled
                \(parametersCollection)
                
                // Create performance metrics
                let metrics = PerformanceMetrics(
                    methodName: methodName,
                    typeName: typeName,
                    category: category,
                    executionTime: executionTime,
                    memoryAllocated: memoryUsed,
                    peakMemoryUsage: finalPeakMemory,
                    timestamp: Date(),
                    threadInfo: threadInfo,
                    parameters: parameters,
                    stackTrace: stackTrace
                )
                
                // Record performance data
                PerformanceMonitor.record(metrics)
                
                // Log slow methods
                \(thresholdLogging)
                
                \(returnStatement)
            } catch {
                // Record performance data even for failed calls
                let endTime = CFAbsoluteTimeGetCurrent()
                let executionTime = (endTime - startTime) * 1000
                
                let metrics = PerformanceMetrics(
                    methodName: methodName,
                    typeName: typeName,
                    category: category,
                    executionTime: executionTime,
                    memoryAllocated: memoryUsed,
                    peakMemoryUsage: finalPeakMemory,
                    timestamp: Date(),
                    threadInfo: threadInfo,
                    parameters: \(config.includeParameters ? "parameters" : "nil"),
                    stackTrace: nil
                )
                
                PerformanceMonitor.record(metrics)
                
                print("❌ METHOD FAILED: \\(typeName).\\(methodName) failed after \\(String(format: \"%.2f\", executionTime))ms with error: \\(error)")
                throw error
            }
        }
        """
    }
}

// MARK: - Supporting Types

private struct PerformanceTrackedConfig {
    let threshold: Double
    let sampleRate: Double
    let memoryTracking: Bool
    let includeStackTrace: Bool
    let includeParameters: Bool
    let category: String?
}

private struct PerformanceTrackedFunctionInfo {
    let name: String
    let parameters: [PerformanceTrackedParameterInfo]
    let returnType: String
    let isAsync: Bool
    let canThrow: Bool
    let isStatic: Bool
    let accessLevel: String
}

private struct PerformanceTrackedParameterInfo {
    let externalName: String  // The external parameter name (e.g., "from")
    let internalName: String  // The internal parameter name (e.g., "url")
    let type: String
    let isOptional: Bool
    let defaultValue: String?
    
    // Helper to get the full parameter for function signature
    var fullSignatureParameter: String {
        if externalName == internalName || externalName == "_" {
            return internalName
        } else {
            return "\(externalName) \(internalName)"
        }
    }
    
    // Helper to get the parameter for calling the original function
    var callParameter: String {
        if externalName == "_" {
            return internalName
        } else {
            return "\(externalName): \(internalName)"
        }
    }
}

// MARK: - Diagnostic Messages

private struct PerformanceTrackedMacroError: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinJectMacros", id: "PerformanceTrackedError")
    let severity: DiagnosticSeverity = .error
}

private struct PerformanceTrackedMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinJectMacros", id: "PerformanceTrackedWarning")
    let severity: DiagnosticSeverity = .warning
}