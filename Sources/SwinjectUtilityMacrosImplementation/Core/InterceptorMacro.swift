// InterceptorMacro.swift - @Interceptor macro implementation for AOP
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @Interceptor macro for aspect-oriented programming
public struct InterceptorMacro: PeerMacro {

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
                message: InterceptorMacroError(message: "@Interceptor can only be applied to functions and methods")
            )
            context.diagnose(diagnostic)
            return []
        }

        // Parse macro configuration
        let config = try parseInterceptorConfig(from: node)

        // Extract function information
        let functionInfo = extractFunctionInfo(from: functionDecl)

        // Generate intercepted version of the function
        let interceptedFunction = try generateInterceptedFunction(
            original: functionDecl,
            functionInfo: functionInfo,
            config: config,
            context: context
        )

        return [interceptedFunction]
    }

    // MARK: - Configuration Parsing

    private static func parseInterceptorConfig(from node: AttributeSyntax) throws -> InterceptorConfig {
        var beforeInterceptors: [String] = []
        var afterInterceptors: [String] = []
        var onErrorInterceptors: [String] = []
        var order = 0
        var isAsync: Bool? = nil
        var measureTime = true

        // Parse attribute arguments
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                switch argument.label?.text {
                case "before":
                    beforeInterceptors = parseStringArray(from: argument.expression)
                case "after":
                    afterInterceptors = parseStringArray(from: argument.expression)
                case "onError":
                    onErrorInterceptors = parseStringArray(from: argument.expression)
                case "order":
                    if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                        order = Int(intLiteral.literal.text) ?? 0
                    }
                case "async":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        isAsync = boolLiteral.literal.text == "true"
                    }
                case "measureTime":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        measureTime = boolLiteral.literal.text == "true"
                    }
                default:
                    break
                }
            }
        }

        return InterceptorConfig(
            beforeInterceptors: beforeInterceptors,
            afterInterceptors: afterInterceptors,
            onErrorInterceptors: onErrorInterceptors,
            order: order,
            isAsync: isAsync,
            measureTime: measureTime
        )
    }

    private static func parseStringArray(from expression: ExprSyntax) -> [String] {
        guard let arrayExpr = expression.as(ArrayExprSyntax.self) else { return [] }

        return arrayExpr.elements.compactMap { element in
            if let stringLiteral = element.expression.as(StringLiteralExprSyntax.self),
               let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
            {
                return segment.content.text
            }
            return nil
        }
    }

    // MARK: - Function Information Extraction

    private static func extractFunctionInfo(from functionDecl: FunctionDeclSyntax) -> InterceptorFunctionInfo {
        let functionName = functionDecl.name.text
        let isAsync = functionDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let canThrow = functionDecl.signature.effectSpecifiers?.throwsSpecifier != nil
        let returnType = functionDecl.signature.returnClause?.type.trimmedDescription ?? "Void"

        // Extract parameters
        let parameters = functionDecl.signature.parameterClause.parameters.map { param in
            InterceptorParameterInfo(
                name: param.firstName.text,
                type: param.type.trimmedDescription,
                isOptional: param.type.isOptional,
                defaultValue: param.defaultValue?.value.trimmedDescription
            )
        }

        return InterceptorFunctionInfo(
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

    private static func generateInterceptedFunction(
        original: FunctionDeclSyntax,
        functionInfo: InterceptorFunctionInfo,
        config: InterceptorConfig,
        context: some MacroExpansionContext
    ) throws -> DeclSyntax {

        let originalName = functionInfo.name
        let interceptedName = "\(originalName)Intercepted"

        // Generate parameter list for function signature
        let parameterList = functionInfo.parameters.map { param in
            if let defaultValue = param.defaultValue {
                "\(param.name): \(param.type) = \(defaultValue)"
            } else {
                "\(param.name): \(param.type)"
            }
        }.joined(separator: ", ")

        // Generate parameter names for original function call
        let parameterNames = functionInfo.parameters.map { param in
            "\(param.name): \(param.name)"
        }.joined(separator: ", ")

        // Generate parameter dictionary for context
        let parameterDict = functionInfo.parameters.map { param in
            "\"\(param.name)\": \(param.name)"
        }.joined(separator: ", ")

        // Generate parameter types dictionary for context
        let parameterTypesDict = functionInfo.parameters.map { param in
            "\"\(param.name)\": \(param.type).self"
        }.joined(separator: ", ")

        // Build function signature - always use public for peer generated methods
        var functionSignature = "public"
        if functionInfo.isStatic {
            functionSignature += " static"
        }
        functionSignature += " func \(interceptedName)(\(parameterList))"

        if functionInfo.isAsync {
            functionSignature += " async"
        }

        if functionInfo.canThrow {
            functionSignature += " throws"
        }

        if functionInfo.returnType != "Void" {
            functionSignature += " -> \(functionInfo.returnType)"
        }

        // Generate interceptor execution code
        let beforeInterceptorCode = generateInterceptorCalls(
            interceptors: config.beforeInterceptors,
            phase: "before",
            hasResult: false
        )

        let afterInterceptorCode = generateInterceptorCalls(
            interceptors: config.afterInterceptors.reversed(), // Execute in reverse order (LIFO)
            phase: "after",
            hasResult: functionInfo.returnType != "Void"
        )

        let errorInterceptorCode = generateInterceptorCalls(
            interceptors: config.onErrorInterceptors,
            phase: "onError",
            hasResult: false
        )

        // Generate the intercepted function body
        let awaitKeyword = functionInfo.isAsync ? "await " : ""
        let tryKeyword = functionInfo.canThrow ? "try " : ""
        let returnKeyword = functionInfo.returnType != "Void" ? "let result = " : ""
        let returnStatement = functionInfo.returnType != "Void" ? "return result" : ""

        let functionBody = """
        \(functionSignature) {
            let startTime = CFAbsoluteTimeGetCurrent()
            let context = InterceptorContext(
                methodName: "\(originalName)",
                typeName: String(describing: type(of: self)),
                parameters: [\(parameterDict)],
                parameterTypes: [\(parameterTypesDict)],
                isAsync: \(functionInfo.isAsync),
                canThrow: \(functionInfo.canThrow),
                returnType: \(functionInfo.returnType).self,
                startTime: startTime
            )

            do {
                // Execute before interceptors
        \(beforeInterceptorCode.isEmpty ? "        // No before interceptors" : beforeInterceptorCode)

                // Execute original method
                \(returnKeyword)\(tryKeyword)\(awaitKeyword)\(originalName)(\(parameterNames))

                // Execute after interceptors
        \(afterInterceptorCode.isEmpty ? "        // No after interceptors" : afterInterceptorCode)

                \(returnStatement)
            } catch {
                // Execute error interceptors
        \(errorInterceptorCode.isEmpty ? "        // No error interceptors - re-throw" : errorInterceptorCode)
                throw error
            }
        }
        """

        return DeclSyntax.fromString(functionBody)
    }

    private static func generateInterceptorCalls(
        interceptors: [String],
        phase: String,
        hasResult: Bool
    ) -> String {
        guard !interceptors.isEmpty else { return "" }

        return interceptors.map { interceptorName in
            let registryCall = "InterceptorRegistry.get(name: \"\(interceptorName)\")"

            switch phase {
            case "before":
                return """
                        if let interceptor = \(registryCall) {
                            try interceptor.before(context: context)
                        }
                """
            case "after":
                return """
                        if let interceptor = \(registryCall) {
                            try interceptor.after(context: context, result: \(hasResult ? "result" : "nil"))
                        }
                """
            case "onError":
                return """
                        if let interceptor = \(registryCall) {
                            try interceptor.onError(context: context, error: error)
                        }
                """
            default:
                return ""
            }
        }.joined(separator: "\n")
    }
}

// MARK: - Supporting Types

private struct InterceptorConfig {
    let beforeInterceptors: [String]
    let afterInterceptors: [String]
    let onErrorInterceptors: [String]
    let order: Int
    let isAsync: Bool?
    let measureTime: Bool
}

private struct InterceptorFunctionInfo {
    let name: String
    let parameters: [InterceptorParameterInfo]
    let returnType: String
    let isAsync: Bool
    let canThrow: Bool
    let isStatic: Bool
    let accessLevel: String
}

private struct InterceptorParameterInfo {
    let name: String
    let type: String
    let isOptional: Bool
    let defaultValue: String?
}

// MARK: - Diagnostic Messages

private struct InterceptorMacroError: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "InterceptorError")
    let severity: DiagnosticSeverity = .error
}

private struct InterceptorMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "InterceptorWarning")
    let severity: DiagnosticSeverity = .warning
}
