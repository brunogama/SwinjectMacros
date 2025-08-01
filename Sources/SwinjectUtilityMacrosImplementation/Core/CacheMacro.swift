// CacheMacro.swift - @Cache macro implementation
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

/// Implementation of the @Cache macro for automatic method result caching.
public struct CacheMacro: PeerMacro {
    
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
                message: CacheMacroError(message: "@Cache can only be applied to functions and methods")
            )
            context.diagnose(diagnostic)
            return []
        }
        
        // Parse macro configuration
        let config = try parseCacheConfig(from: node)
        
        // Extract function information
        let functionInfo = extractFunctionInfo(from: functionDecl)
        
        // Generate cached version of the function
        let cachedFunction = try generateCachedFunction(
            original: functionDecl,
            functionInfo: functionInfo,
            config: config,
            context: context
        )
        
        return [cachedFunction]
    }
    
    // MARK: - Configuration Parsing
    
    private static func parseCacheConfig(from node: AttributeSyntax) throws -> CacheConfig {
        var ttl = 300.0
        var maxEntries = 1000
        var evictionPolicy = "lru"
        var keyParameters: [String] = []
        var shouldCache: String? = nil
        var refreshInBackground = false
        var serializationStrategy = "memory"
        
        // Parse attribute arguments
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                switch argument.label?.text {
                case "ttl":
                    if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self) {
                        ttl = Double(floatLiteral.literal.text) ?? 300.0
                    } else if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                        ttl = Double(intLiteral.literal.text) ?? 300.0
                    }
                case "maxEntries":
                    if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                        maxEntries = Int(intLiteral.literal.text) ?? 1000
                    }
                case "evictionPolicy":
                    if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
                        evictionPolicy = memberAccess.declName.baseName.text
                    }
                case "refreshInBackground":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        refreshInBackground = boolLiteral.literal.text == "true"
                    }
                case "serializationStrategy":
                    if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
                        serializationStrategy = memberAccess.declName.baseName.text
                    }
                default:
                    break
                }
            }
        }
        
        return CacheConfig(
            ttl: ttl,
            maxEntries: maxEntries,
            evictionPolicy: evictionPolicy,
            keyParameters: keyParameters,
            shouldCache: shouldCache,
            refreshInBackground: refreshInBackground,
            serializationStrategy: serializationStrategy
        )
    }
    
    // MARK: - Function Information Extraction
    
    private static func extractFunctionInfo(from functionDecl: FunctionDeclSyntax) -> CacheFunctionInfo {
        let functionName = functionDecl.name.text
        let isAsync = functionDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let canThrow = functionDecl.signature.effectSpecifiers?.throwsSpecifier != nil
        let returnType = functionDecl.signature.returnClause?.type.trimmedDescription ?? "Void"
        
        // Extract parameters
        let parameters = functionDecl.signature.parameterClause.parameters.map { param in
            let externalName = param.firstName.text
            let internalName = param.secondName?.text ?? param.firstName.text
            
            return CacheParameterInfo(
                externalName: externalName,
                internalName: internalName,
                type: param.type.trimmedDescription,
                isOptional: param.type.isOptional,
                defaultValue: param.defaultValue?.value.trimmedDescription
            )
        }
        
        return CacheFunctionInfo(
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
    
    private static func generateCachedFunction(
        original: FunctionDeclSyntax,
        functionInfo: CacheFunctionInfo,
        config: CacheConfig,
        context: some MacroExpansionContext
    ) throws -> DeclSyntax {
        
        let originalName = functionInfo.name
        let cachedName = "\(originalName)Cached"
        
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
        functionSignature += " func \(cachedName)(\(parameterList))"
        
        if functionInfo.isAsync {
            functionSignature += " async"
        }
        
        if functionInfo.canThrow {
            functionSignature += " throws"
        }
        
        if functionInfo.returnType != "Void" {
            functionSignature += " -> \(functionInfo.returnType)"
        }
        
        // Generate the cached function body
        let functionBody = try createCachedFunctionBody(
            signature: functionSignature,
            originalName: originalName,
            parameterNames: parameterNames,
            config: config,
            functionInfo: functionInfo
        )
        
        return DeclSyntax.fromString(functionBody)
    }
    
    // MARK: - Helper Methods
    
    private static func createCachedFunctionBody(
        signature: String,
        originalName: String,
        parameterNames: String,
        config: CacheConfig,
        functionInfo: CacheFunctionInfo
    ) throws -> String {
        
        // Generate cache key
        let cacheKey = generateCacheKey(originalName: originalName, functionInfo: functionInfo)
        
        // Generate method call
        let methodCall = if functionInfo.canThrow {
            "try \(functionInfo.isAsync ? "await " : "")\(originalName)(\(parameterNames))"
        } else {
            "\(functionInfo.isAsync ? "await " : "")\(originalName)(\(parameterNames))"
        }
        
        // Generate return handling
        let returnHandling = generateReturnHandling(functionInfo: functionInfo)
        
        // Generate the complete cached function body
        return """
        \(signature) {
            let cacheKey = \(cacheKey)
            
            // Get or create cache instance
            let cache = CacheRegistry.getCache(
                for: "\(originalName)",
                ttl: \(config.ttl),
                maxEntries: \(config.maxEntries),
                evictionPolicy: .\(config.evictionPolicy)
            )
            
            // Record cache operation start time
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Check for cached result
            if let cachedResult = cache.get(key: cacheKey, type: \(functionInfo.returnType).self) {
                // Cache hit - record metrics and return cached result
                let endTime = CFAbsoluteTimeGetCurrent()
                let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds
                
                let hitOperation = CacheOperation(
                    wasHit: true,
                    key: cacheKey,
                    responseTime: responseTime,
                    valueSize: MemoryLayout.size(ofValue: cachedResult)
                )
                CacheRegistry.recordOperation(hitOperation, for: "\(originalName)")
                
                return cachedResult
            }
            
            // Cache miss - execute original method
            let result = \(methodCall)
            
            // Record cache miss metrics
            let endTime = CFAbsoluteTimeGetCurrent()
            let responseTime = (endTime - startTime) * 1000
            
            let missOperation = CacheOperation(
                wasHit: false,
                key: cacheKey,
                responseTime: responseTime,
                valueSize: MemoryLayout.size(ofValue: result)
            )
            CacheRegistry.recordOperation(missOperation, for: "\(originalName)")
            
            // Store result in cache
            cache.set(key: cacheKey, value: result)
            
            \(returnHandling)
        }
        """
    }
    
    private static func generateCacheKey(originalName: String, functionInfo: CacheFunctionInfo) -> String {
        // Generate a cache key based on method name and parameters
        let parameterKeyParts = functionInfo.parameters.map { param in
            "\\(\(param.internalName))"
        }.joined(separator: ":")
        
        if parameterKeyParts.isEmpty {
            return "\"\(originalName)\""
        } else {
            return "\"\(originalName):\(parameterKeyParts)\""
        }
    }
    
    private static func generateReturnHandling(functionInfo: CacheFunctionInfo) -> String {
        if functionInfo.returnType != "Void" {
            return "return result"
        } else {
            return ""
        }
    }
}

// MARK: - Supporting Types

private struct CacheConfig {
    let ttl: Double
    let maxEntries: Int
    let evictionPolicy: String
    let keyParameters: [String]
    let shouldCache: String?
    let refreshInBackground: Bool
    let serializationStrategy: String
}

private struct CacheFunctionInfo {
    let name: String
    let parameters: [CacheParameterInfo]
    let returnType: String
    let isAsync: Bool
    let canThrow: Bool
    let isStatic: Bool
    let accessLevel: String
}

private struct CacheParameterInfo {
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

private struct CacheMacroError: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "CacheError")
    let severity: DiagnosticSeverity = .error
}

private struct CacheMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "CacheWarning")
    let severity: DiagnosticSeverity = .warning
}