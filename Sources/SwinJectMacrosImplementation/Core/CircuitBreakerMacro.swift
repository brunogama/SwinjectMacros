// CircuitBreakerMacro.swift - @CircuitBreaker macro implementation
// Copyright © 2025 SwinJectMacros. All rights reserved.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

/// Implementation of the @CircuitBreaker macro for automatic circuit breaker pattern.
public struct CircuitBreakerMacro: PeerMacro {
    
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
                message: CircuitBreakerMacroError(message: "@CircuitBreaker can only be applied to functions and methods")
            )
            context.diagnose(diagnostic)
            return []
        }
        
        // Parse macro configuration
        let config = try parseCircuitBreakerConfig(from: node)
        
        // Extract function information
        let functionInfo = extractFunctionInfo(from: functionDecl)
        
        // Generate circuit breaker-enabled version of the function
        let circuitBreakerFunction = try generateCircuitBreakerFunction(
            original: functionDecl,
            functionInfo: functionInfo,
            config: config,
            context: context
        )
        
        return [circuitBreakerFunction]
    }
    
    // MARK: - Configuration Parsing
    
    private static func parseCircuitBreakerConfig(from node: AttributeSyntax) throws -> CircuitBreakerConfig {
        var failureThreshold = 5
        var timeout = 60.0
        var successThreshold = 3
        var monitoringWindow = 60.0
        var fallbackValue: String? = nil
        let includeExceptions: [String] = []
        let excludeExceptions: [String] = []
        
        // Parse attribute arguments
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                switch argument.label?.text {
                case "failureThreshold":
                    if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                        failureThreshold = Int(intLiteral.literal.text) ?? 5
                    }
                case "timeout":
                    if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self) {
                        timeout = Double(floatLiteral.literal.text) ?? 60.0
                    } else if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                        timeout = Double(intLiteral.literal.text) ?? 60.0
                    }
                case "successThreshold":
                    if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                        successThreshold = Int(intLiteral.literal.text) ?? 3
                    }
                case "monitoringWindow":
                    if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self) {
                        monitoringWindow = Double(floatLiteral.literal.text) ?? 60.0
                    } else if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                        monitoringWindow = Double(intLiteral.literal.text) ?? 60.0
                    }
                case "fallbackValue":
                    // For simplicity, we'll handle basic string literals
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                        fallbackValue = segment.content.text
                    }
                default:
                    break
                }
            }
        }
        
        return CircuitBreakerConfig(
            failureThreshold: failureThreshold,
            timeout: timeout,
            successThreshold: successThreshold,
            monitoringWindow: monitoringWindow,
            fallbackValue: fallbackValue,
            includeExceptions: includeExceptions,
            excludeExceptions: excludeExceptions
        )
    }
    
    // MARK: - Function Information Extraction
    
    private static func extractFunctionInfo(from functionDecl: FunctionDeclSyntax) -> CircuitBreakerFunctionInfo {
        let functionName = functionDecl.name.text
        let isAsync = functionDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let canThrow = functionDecl.signature.effectSpecifiers?.throwsSpecifier != nil
        let returnType = functionDecl.signature.returnClause?.type.trimmedDescription ?? "Void"
        
        // Extract parameters
        let parameters = functionDecl.signature.parameterClause.parameters.map { param in
            let externalName = param.firstName.text
            let internalName = param.secondName?.text ?? param.firstName.text
            
            return CircuitBreakerParameterInfo(
                externalName: externalName,
                internalName: internalName,
                type: param.type.trimmedDescription,
                isOptional: param.type.isOptional,
                defaultValue: param.defaultValue?.value.trimmedDescription
            )
        }
        
        return CircuitBreakerFunctionInfo(
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
    
    private static func generateCircuitBreakerFunction(
        original: FunctionDeclSyntax,
        functionInfo: CircuitBreakerFunctionInfo,
        config: CircuitBreakerConfig,
        context: some MacroExpansionContext
    ) throws -> DeclSyntax {
        
        let originalName = functionInfo.name
        let circuitBreakerName = "\(originalName)CircuitBreaker"
        
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
        functionSignature += " func \(circuitBreakerName)(\(parameterList))"
        
        if functionInfo.isAsync {
            functionSignature += " async"
        }
        
        // Always make circuit breaker functions throwing since they handle circuit breaker errors
        functionSignature += " throws"
        
        if functionInfo.returnType != "Void" {
            functionSignature += " -> \(functionInfo.returnType)"
        }
        
        // Generate the circuit breaker function body
        let functionBody = try createCircuitBreakerFunctionBody(
            signature: functionSignature,
            originalName: originalName,
            parameterNames: parameterNames,
            config: config,
            functionInfo: functionInfo
        )
        
        return DeclSyntax.fromString(functionBody)
    }
    
    // MARK: - Helper Methods
    
    private static func createCircuitBreakerFunctionBody(
        signature: String,
        originalName: String,
        parameterNames: String,
        config: CircuitBreakerConfig,
        functionInfo: CircuitBreakerFunctionInfo
    ) throws -> String {
        
        // Generate circuit breaker key
        let circuitKey = "\(String(describing: type(of: self))).\(originalName)"
        
        // Generate method call
        let methodCall = if functionInfo.canThrow {
            "try \(functionInfo.isAsync ? "await " : "")\(originalName)(\(parameterNames))"
        } else {
            "\(functionInfo.isAsync ? "await " : "")\(originalName)(\(parameterNames))"
        }
        
        // Generate fallback logic
        let fallbackLogic = generateFallbackLogic(config: config, functionInfo: functionInfo)
        
        // Generate return statement
        let returnStatement = if functionInfo.returnType != "Void" {
            "return result"
        } else {
            ""
        }
        
        // Generate the complete circuit breaker function body
        return """
        \(signature) {
            let circuitKey = "\(circuitKey)"
            
            // Get or create circuit breaker instance
            let circuitBreaker = CircuitBreakerRegistry.getCircuitBreaker(
                for: circuitKey,
                failureThreshold: \(config.failureThreshold),
                timeout: \(config.timeout),
                successThreshold: \(config.successThreshold),
                monitoringWindow: \(config.monitoringWindow)
            )
            
            // Check if call should be allowed
            guard circuitBreaker.shouldAllowCall() else {
                // Circuit is open, record blocked call and handle fallback
                let blockedCall = CircuitBreakerCall(
                    wasSuccessful: false,
                    wasBlocked: true,
                    responseTime: 0.0,
                    circuitState: circuitBreaker.currentState
                )
                CircuitBreakerRegistry.recordCall(blockedCall, for: circuitKey)
                
                \(fallbackLogic)
            }
            
            // Execute the method with circuit breaker protection
            let startTime = CFAbsoluteTimeGetCurrent()
            var wasSuccessful = false
            var callError: Error?
            
            do {
                let result = \(methodCall)
                wasSuccessful = true
                
                // Record successful call
                let endTime = CFAbsoluteTimeGetCurrent()
                let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds
                
                let successfulCall = CircuitBreakerCall(
                    wasSuccessful: true,
                    wasBlocked: false,
                    responseTime: responseTime,
                    circuitState: circuitBreaker.currentState
                )
                CircuitBreakerRegistry.recordCall(successfulCall, for: circuitKey)
                
                // Update circuit breaker state
                circuitBreaker.recordCall(wasSuccessful: true)
                
                \(returnStatement)
            } catch {
                wasSuccessful = false
                callError = error
                
                // Record failed call
                let endTime = CFAbsoluteTimeGetCurrent()
                let responseTime = (endTime - startTime) * 1000
                
                let failedCall = CircuitBreakerCall(
                    wasSuccessful: false,
                    wasBlocked: false,
                    responseTime: responseTime,
                    circuitState: circuitBreaker.currentState,
                    error: error
                )
                CircuitBreakerRegistry.recordCall(failedCall, for: circuitKey)
                
                // Update circuit breaker state
                circuitBreaker.recordCall(wasSuccessful: false)
                
                // Re-throw the error
                throw error
            }
        }
        """
    }
    
    private static func generateFallbackLogic(config: CircuitBreakerConfig, functionInfo: CircuitBreakerFunctionInfo) -> String {
        if let fallbackValue = config.fallbackValue {
            if functionInfo.returnType == "Void" {
                return "return // Circuit is open, no operation performed"
            } else {
                return """
                // Safe fallback value handling
                if let fallback = "\(fallbackValue)" as? \(functionInfo.returnType) {
                    return fallback
                } else {
                    throw CircuitBreakerError.noFallbackAvailable(circuitName: circuitKey)
                }
                """
            }
        } else {
            return "throw CircuitBreakerError.circuitOpen(circuitName: circuitKey, lastFailureTime: circuitBreaker.lastOpenedTime)"
        }
    }
}

// MARK: - Supporting Types

private struct CircuitBreakerConfig {
    let failureThreshold: Int
    let timeout: Double
    let successThreshold: Int
    let monitoringWindow: Double
    let fallbackValue: String?
    let includeExceptions: [String]
    let excludeExceptions: [String]
}

private struct CircuitBreakerFunctionInfo {
    let name: String
    let parameters: [CircuitBreakerParameterInfo]
    let returnType: String
    let isAsync: Bool
    let canThrow: Bool
    let isStatic: Bool
    let accessLevel: String
}

private struct CircuitBreakerParameterInfo {
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

private struct CircuitBreakerMacroError: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinJectMacros", id: "CircuitBreakerError")
    let severity: DiagnosticSeverity = .error
}

private struct CircuitBreakerMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinJectMacros", id: "CircuitBreakerWarning")
    let severity: DiagnosticSeverity = .warning
}