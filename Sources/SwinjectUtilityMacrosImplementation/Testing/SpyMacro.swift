// SpyMacro.swift - @Spy macro implementation

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @Spy macro for method call tracking in tests.
public struct SpyMacro: PeerMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // Validate that this is applied to a function
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: SpyMacroError(message: """
                @Spy can only be applied to methods.

                ✅ Correct usage:
                class UserService {
                    @Spy
                    func getUserById(_ id: String) -> User? {
                        return repository.findUser(id: id)
                    }
                }

                ❌ Invalid usage:
                @Spy
                class UserService { ... } // Classes not supported

                @Spy
                var userName: String // Properties not supported

                💡 Solution: Apply @Spy to individual methods that need call tracking.
                """)
            )
            context.diagnose(diagnostic)
            return []
        }

        // Extract method information
        let methodName = funcDecl.name.text
        let isAsync = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let isThrows = funcDecl.signature.effectSpecifiers?.throwsSpecifier != nil

        // Parse macro configuration
        let config = try parseSpyConfig(from: node)

        // Extract parameter information
        let parameters = extractParameters(from: funcDecl)

        // Extract return type
        let returnType = extractReturnType(from: funcDecl)

        // Generate spy infrastructure
        var generatedDeclarations: [DeclSyntax] = []

        // Generate spy call structure
        let callStructure = try generateSpyCallStructure(
            methodName: methodName,
            parameters: parameters,
            returnType: returnType,
            isThrows: isThrows,
            config: config
        )
        generatedDeclarations.append(callStructure)

        // Generate spy storage properties
        let spyStorage = try generateSpyStorage(
            methodName: methodName,
            parameters: parameters,
            returnType: returnType,
            config: config
        )
        generatedDeclarations.append(contentsOf: spyStorage)

        // Generate spy access methods
        let spyMethods = try generateSpyMethods(
            methodName: methodName,
            parameters: parameters,
            returnType: returnType,
            config: config
        )
        generatedDeclarations.append(contentsOf: spyMethods)

        return generatedDeclarations
    }

    // MARK: - Configuration Parsing

    private static func parseSpyConfig(from node: AttributeSyntax) throws -> SpyConfig {
        var captureArguments = true
        var captureReturnValue = true
        var captureErrors = true
        var threadSafe = true

        // Parse attribute arguments
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                switch argument.label?.text {
                case "captureArguments":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        captureArguments = boolLiteral.literal.text == "true"
                    }
                case "captureReturnValue":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        captureReturnValue = boolLiteral.literal.text == "true"
                    }
                case "captureErrors":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        captureErrors = boolLiteral.literal.text == "true"
                    }
                case "threadSafe":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        threadSafe = boolLiteral.literal.text == "true"
                    }
                default:
                    break
                }
            }
        }

        return SpyConfig(
            captureArguments: captureArguments,
            captureReturnValue: captureReturnValue,
            captureErrors: captureErrors,
            threadSafe: threadSafe
        )
    }

    // MARK: - Parameter Extraction

    private static func extractParameters(from funcDecl: FunctionDeclSyntax) -> [SpyParameter] {
        var parameters: [SpyParameter] = []

        for parameter in funcDecl.signature.parameterClause.parameters {
            let paramName = parameter.secondName?.text ?? parameter.firstName.text
            let paramType = parameter.type.trimmedDescription
            let externalName = parameter.firstName.text

            parameters.append(SpyParameter(
                name: paramName,
                type: paramType,
                externalName: externalName
            ))
        }

        return parameters
    }

    private static func extractReturnType(from funcDecl: FunctionDeclSyntax) -> String? {
        funcDecl.signature.returnClause?.type.trimmedDescription
    }

    // MARK: - Code Generation

    private static func generateSpyCallStructure(
        methodName: String,
        parameters: [SpyParameter],
        returnType: String?,
        isThrows: Bool,
        config: SpyConfig
    ) throws -> DeclSyntax {

        let capitalizedMethodName = methodName.capitalized
        let structName = "\(capitalizedMethodName)SpyCall"

        // Generate arguments tuple type
        let argumentsType = if parameters.isEmpty {
            "Void"
        } else {
            "(\(parameters.map { $0.type }.joined(separator: ", ")))"
        }

        // Generate struct properties
        var properties: [String] = [
            "let timestamp: Date",
            "let methodName: String"
        ]

        if config.captureArguments && !parameters.isEmpty {
            properties.append("let arguments: \(argumentsType)")
        }

        if config.captureReturnValue, let returnType = returnType {
            properties.append("let returnValue: \(returnType)?")
        }

        if config.captureErrors && isThrows {
            properties.append("let thrownError: Error?")
        }

        let structCode = """
        struct \(structName): SpyCall {
            \(properties.joined(separator: "\n    "))
        }
        """

        return DeclSyntax.fromString(structCode)
    }

    private static func generateSpyStorage(
        methodName: String,
        parameters: [SpyParameter],
        returnType: String?,
        config: SpyConfig
    ) throws -> [DeclSyntax] {

        let capitalizedMethodName = methodName.capitalized
        let callStructName = "\(capitalizedMethodName)SpyCall"

        var declarations: [DeclSyntax] = []

        // Generate call storage
        let callsStorage = """
        private var _\(methodName)SpyCalls: [\(callStructName)] = []
        """
        declarations.append(DeclSyntax.fromString(callsStorage))

        if config.threadSafe {
            let lockStorage = """
            private let _\(methodName)SpyLock = NSLock()
            """
            declarations.append(DeclSyntax.fromString(lockStorage))
        }

        // Generate behavior override storage
        let behaviorType = generateBehaviorType(parameters: parameters, returnType: returnType)
        let behaviorStorage = """
        var \(methodName)SpyBehavior: \(behaviorType)?
        """
        declarations.append(DeclSyntax.fromString(behaviorStorage))

        return declarations
    }

    private static func generateSpyMethods(
        methodName: String,
        parameters: [SpyParameter],
        returnType: String?,
        config: SpyConfig
    ) throws -> [DeclSyntax] {

        let capitalizedMethodName = methodName.capitalized
        let callStructName = "\(capitalizedMethodName)SpyCall"

        var declarations: [DeclSyntax] = []

        // Generate calls accessor
        let lockingCode = if config.threadSafe {
            """
            _\(methodName)SpyLock.lock()
            defer { _\(methodName)SpyLock.unlock() }
            """
        } else {
            ""
        }

        let callsAccessor = """
        var \(methodName)SpyCalls: [\(callStructName)] {
            \(lockingCode)
            return _\(methodName)SpyCalls
        }
        """
        declarations.append(DeclSyntax.fromString(callsAccessor))

        // Generate reset method
        let resetMethod = """
        func reset\(capitalizedMethodName)Spy() {
            \(lockingCode)
            _\(methodName)SpyCalls.removeAll()
        }
        """
        declarations.append(DeclSyntax.fromString(resetMethod))

        return declarations
    }

    private static func generateBehaviorType(
        parameters: [SpyParameter],
        returnType: String?
    ) -> String {
        let paramTypes = parameters.map { $0.type }
        let paramTypesString = paramTypes.isEmpty ? "" : "(\(paramTypes.joined(separator: ", ")))"
        let returnTypeString = returnType ?? "Void"

        if paramTypes.isEmpty {
            return "(() -> \(returnTypeString))"
        } else {
            return "((\(paramTypes.joined(separator: ", "))) -> \(returnTypeString))"
        }
    }
}

// MARK: - Supporting Types

private struct SpyConfig {
    let captureArguments: Bool
    let captureReturnValue: Bool
    let captureErrors: Bool
    let threadSafe: Bool
}

private struct SpyParameter {
    let name: String
    let type: String
    let externalName: String
}

// MARK: - Diagnostic Messages

private struct SpyMacroError: DiagnosticMessage, Error {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "SpyError")
    let severity: DiagnosticSeverity = .error
}

private struct SpyMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "SpyWarning")
    let severity: DiagnosticSeverity = .warning
}
