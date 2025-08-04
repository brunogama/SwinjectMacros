// RetryMacro.swift - @Retry macro implementation
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @Retry macro for automatic retry logic with backoff strategies.
public struct RetryMacro: PeerMacro {

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
                message: RetryMacroError(message: """
                @Retry can only be applied to functions and methods.

                ✅ Correct usage:
                @Retry(maxAttempts: 3, backoffStrategy: .exponential)
                func fetchUserData() throws -> UserData {
                    // Network operation that might fail
                }

                @Retry(maxAttempts: 5, jitter: true)
                func syncDatabase() async throws {
                    // Async operation with retry logic
                }

                ❌ Invalid usage:
                @Retry
                var retryCount: Int = 0 // Properties not supported

                @Retry
                struct Configuration { ... } // Types not supported

                💡 Tips:
                - Use on throwing functions for error handling
                - Combine with async for non-blocking retries
                - Set appropriate maxAttempts for your use case
                """)
            )
            context.diagnose(diagnostic)
            return []
        }

        // Parse macro configuration
        let config = try parseRetryConfig(from: node)

        // Extract function information
        let functionInfo = extractFunctionInfo(from: functionDecl)

        // Generate retry-enabled version of the function
        let retryFunction = try generateRetryFunction(
            original: functionDecl,
            functionInfo: functionInfo,
            config: config,
            context: context
        )

        return [retryFunction]
    }

    // MARK: - Configuration Parsing

    private static func parseRetryConfig(from node: AttributeSyntax) throws -> RetryConfig {
        var maxAttempts = 3
        var backoffStrategy = "exponential"
        let baseDelay = 1.0
        let multiplier = 2.0
        let increment = 1.0
        let fixedDelay = 1.0
        var jitter = false
        var maxDelay = 60.0
        var timeout: Double? = nil
        let retryableErrors: [String] = []

        // Parse attribute arguments
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                switch argument.label?.text {
                case "maxAttempts":
                    if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                        maxAttempts = Int(intLiteral.literal.text) ?? 3
                    }
                case "backoffStrategy":
                    // For now, we'll handle basic parsing - more complex parsing would be needed for full enum support
                    if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
                        backoffStrategy = memberAccess.declName.baseName.text
                    }
                case "jitter":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        jitter = boolLiteral.literal.text == "true"
                    }
                case "maxDelay":
                    if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self) {
                        maxDelay = Double(floatLiteral.literal.text) ?? 60.0
                    } else if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                        maxDelay = Double(intLiteral.literal.text) ?? 60.0
                    }
                case "timeout":
                    if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self) {
                        timeout = Double(floatLiteral.literal.text)
                    } else if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                        timeout = Double(intLiteral.literal.text)
                    }
                default:
                    break
                }
            }
        }

        return RetryConfig(
            maxAttempts: maxAttempts,
            backoffStrategy: backoffStrategy,
            baseDelay: baseDelay,
            multiplier: multiplier,
            increment: increment,
            fixedDelay: fixedDelay,
            jitter: jitter,
            maxDelay: maxDelay,
            timeout: timeout,
            retryableErrors: retryableErrors
        )
    }

    // MARK: - Function Information Extraction

    private static func extractFunctionInfo(from functionDecl: FunctionDeclSyntax) -> RetryFunctionInfo {
        let functionName = functionDecl.name.text
        let isAsync = functionDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let canThrow = functionDecl.signature.effectSpecifiers?.throwsSpecifier != nil
        let returnType = functionDecl.signature.returnClause?.type.trimmedDescription ?? "Void"

        // Extract parameters
        let parameters = functionDecl.signature.parameterClause.parameters.map { param in
            let externalName = param.firstName.text
            let internalName = param.secondName?.text ?? param.firstName.text

            return RetryParameterInfo(
                externalName: externalName,
                internalName: internalName,
                type: param.type.trimmedDescription,
                isOptional: param.type.isOptional,
                defaultValue: param.defaultValue?.value.trimmedDescription
            )
        }

        return RetryFunctionInfo(
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

    private static func generateRetryFunction(
        original: FunctionDeclSyntax,
        functionInfo: RetryFunctionInfo,
        config: RetryConfig,
        context: some MacroExpansionContext
    ) throws -> DeclSyntax {

        let originalName = functionInfo.name
        let retryName = "\(originalName)Retry"

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
        functionSignature += " func \(retryName)(\(parameterList))"

        if functionInfo.isAsync {
            functionSignature += " async"
        }

        // Always make retry functions throwing since they handle errors
        functionSignature += " throws"

        if functionInfo.returnType != "Void" {
            functionSignature += " -> \(functionInfo.returnType)"
        }

        // Generate the retry function body
        let functionBody = try createRetryFunctionBody(
            signature: functionSignature,
            originalName: originalName,
            parameterNames: parameterNames,
            config: config,
            functionInfo: functionInfo
        )

        return DeclSyntax.fromString(functionBody)
    }

    // MARK: - Helper Methods

    private static func createRetryFunctionBody(
        signature: String,
        originalName: String,
        parameterNames: String,
        config: RetryConfig,
        functionInfo: RetryFunctionInfo
    ) throws -> String {

        // Generate backoff calculation based on strategy
        let backoffCalculation = generateBackoffCalculation(for: config)

        // Generate timeout setup if specified
        let timeoutSetup = if let timeout = config.timeout {
            """
            let startTime = Date()
            let timeoutInterval: TimeInterval = \(timeout)
            """
        } else {
            ""
        }

        // Generate timeout check
        let timeoutCheck = if config.timeout != nil {
            """
            // Check overall timeout
            if Date().timeIntervalSince(startTime) >= timeoutInterval {
                throw RetryError.timeoutExceeded(timeout: timeoutInterval)
            }
            """
        } else {
            ""
        }

        // Generate return statement
        let returnStatement = if functionInfo.returnType != "Void" {
            "return result"
        } else {
            ""
        }

        // Generate method call
        let methodCall = if functionInfo.canThrow {
            "try \(functionInfo.isAsync ? "await " : "")\(originalName)(\(parameterNames))"
        } else {
            "\(functionInfo.isAsync ? "await " : "")\(originalName)(\(parameterNames))"
        }

        // Generate the complete retry function body
        return """
        \(signature) {
            let methodKey = "\\(String(describing: type(of: self))).\(originalName)"
            var lastError: Error?
            var totalDelay: TimeInterval = 0.0
            \(timeoutSetup)

            for attempt in 1...\(config.maxAttempts) {
                \(timeoutCheck)

                do {
                    let result = \(methodCall)

                    // Record successful call
                    RetryMetricsManager.recordResult(
                        for: methodKey,
                        succeeded: true,
                        attemptCount: attempt,
                        totalDelay: totalDelay
                    )

                    \(returnStatement)
                } catch {
                    lastError = error

                    // Check if this is the last attempt
                    if attempt == \(config.maxAttempts) {
                        // Record final failure
                        RetryMetricsManager.recordResult(
                            for: methodKey,
                            succeeded: false,
                            attemptCount: attempt,
                            totalDelay: totalDelay,
                            finalError: error
                        )
                        throw error
                    }

                    // Calculate backoff delay
                    \(backoffCalculation)

                    // Add to total delay tracking
                    totalDelay += delay

                    // Record retry attempt
                    let retryAttempt = RetryAttempt(
                        attemptNumber: attempt,
                        error: error,
                        delay: delay
                    )
                    RetryMetricsManager.recordAttempt(retryAttempt, for: methodKey)

                    // Wait before retry
                    if delay > 0 {
                        \(
                            functionInfo
                                .isAsync ? "try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))" :
                                "Thread.sleep(forTimeInterval: delay)"
        )
                    }
                }
            }

            // This should never be reached, but just in case
            throw lastError ?? RetryError.maxAttemptsExceeded(attempts: \(config.maxAttempts))
        }
        """
    }

    private static func generateBackoffCalculation(for config: RetryConfig) -> String {
        let baseCalculation = switch config.backoffStrategy {
        case "exponential":
            "let baseDelay = \(config.baseDelay) * pow(\(config.multiplier), Double(attempt - 1))"
        case "linear":
            "let baseDelay = \(config.baseDelay) + (\(config.increment) * Double(attempt - 1))"
        case "fixed":
            "let baseDelay = \(config.fixedDelay)"
        default:
            "let baseDelay = \(config.baseDelay) * pow(\(config.multiplier), Double(attempt - 1))"
        }

        let maxDelayCheck = "let cappedDelay = min(baseDelay, \(config.maxDelay))"

        let jitterApplication = if config.jitter {
            """
            let jitterRange = cappedDelay * 0.25
            let randomJitter = Double.random(in: -jitterRange...jitterRange)
            let delay = max(0, cappedDelay + randomJitter)
            """
        } else {
            "let delay = cappedDelay"
        }

        return """
        \(baseCalculation)
        \(maxDelayCheck)
        \(jitterApplication)
        """
    }
}

// MARK: - Supporting Types

private struct RetryConfig {
    let maxAttempts: Int
    let backoffStrategy: String
    let baseDelay: Double
    let multiplier: Double
    let increment: Double
    let fixedDelay: Double
    let jitter: Bool
    let maxDelay: Double
    let timeout: Double?
    let retryableErrors: [String]
}

private struct RetryFunctionInfo {
    let name: String
    let parameters: [RetryParameterInfo]
    let returnType: String
    let isAsync: Bool
    let canThrow: Bool
    let isStatic: Bool
    let accessLevel: String
}

private struct RetryParameterInfo {
    let externalName: String // The external parameter name (e.g., "from")
    let internalName: String // The internal parameter name (e.g., "url")
    let type: String
    let isOptional: Bool
    let defaultValue: String?

    // Helper to get the full parameter for function signature
    var fullSignatureParameter: String {
        if externalName == internalName || externalName == "_" {
            internalName
        } else {
            "\(externalName) \(internalName)"
        }
    }

    // Helper to get the parameter for calling the original function
    var callParameter: String {
        if externalName == "_" {
            internalName
        } else {
            "\(externalName): \(internalName)"
        }
    }
}

// MARK: - Retry Error Types (defined in public API)

// MARK: - Diagnostic Messages

private struct RetryMacroError: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "RetryError")
    let severity: DiagnosticSeverity = .error
}

private struct RetryMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "RetryWarning")
    let severity: DiagnosticSeverity = .warning
}
