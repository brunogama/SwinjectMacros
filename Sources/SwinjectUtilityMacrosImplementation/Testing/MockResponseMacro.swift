// MockResponseMacro.swift - @MockResponse macro implementation

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

/// Implementation of the @MockResponse macro for declarative mock response configuration.
public struct MockResponseMacro: PeerMacro {
    
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        // Validate that this is applied to a function
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: MockResponseMacroError(message: """
                @MockResponse can only be applied to methods.
                
                ✅ Correct usage:
                class APIService {
                    @MockResponse([.success(UserData.mock)])
                    func fetchUser(_ id: String) async throws -> UserData {
                        // Real implementation
                        return try await apiClient.fetchUser(id)
                    }
                }
                
                ❌ Invalid usage:
                @MockResponse([.success("test")])
                class APIService { ... } // Classes not supported
                
                @MockResponse([.success(true)])
                var isLoading: Bool // Properties not supported
                
                💡 Solution: Apply @MockResponse to methods that need mock responses.
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
        let config = try parseMockResponseConfig(from: node)
        
        // Extract parameter and return type information
        let parameters = extractParameters(from: funcDecl)
        let returnType = extractReturnType(from: funcDecl)
        
        // Generate mock response infrastructure
        var generatedDeclarations: [DeclSyntax] = []
        
        // Generate mock response storage
        let mockStorage = try generateMockResponseStorage(
            methodName: methodName,
            parameters: parameters,
            returnType: returnType,
            isAsync: isAsync,
            isThrows: isThrows,
            config: config
        )
        generatedDeclarations.append(contentsOf: mockStorage)
        
        // Generate mock response methods
        let mockMethods = try generateMockResponseMethods(
            methodName: methodName,
            parameters: parameters,
            returnType: returnType,
            config: config
        )
        generatedDeclarations.append(contentsOf: mockMethods)
        
        return generatedDeclarations
    }
    
    // MARK: - Configuration Parsing
    
    private static func parseMockResponseConfig(from node: AttributeSyntax) throws -> MockResponseConfig {
        var fallbackToOriginal = false
        var resetBetweenCalls = false
        var trackCallMetrics = true
        
        // Parse attribute arguments
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                switch argument.label?.text {
                case "fallbackToOriginal":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        fallbackToOriginal = boolLiteral.literal.text == "true"
                    }
                case "resetBetweenCalls":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        resetBetweenCalls = boolLiteral.literal.text == "true"
                    }
                case "trackCallMetrics":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        trackCallMetrics = boolLiteral.literal.text == "true"
                    }
                default:
                    break
                }
            }
        }
        
        return MockResponseConfig(
            fallbackToOriginal: fallbackToOriginal,
            resetBetweenCalls: resetBetweenCalls,
            trackCallMetrics: trackCallMetrics
        )
    }
    
    // MARK: - Parameter and Return Type Extraction
    
    private static func extractParameters(from funcDecl: FunctionDeclSyntax) -> [MockParameter] {
        var parameters: [MockParameter] = []
        
        for parameter in funcDecl.signature.parameterClause.parameters {
            let paramName = parameter.secondName?.text ?? parameter.firstName.text
            let paramType = parameter.type.trimmedDescription
            let externalName = parameter.firstName.text
            
            parameters.append(MockParameter(
                name: paramName,
                type: paramType,
                externalName: externalName
            ))
        }
        
        return parameters
    }
    
    private static func extractReturnType(from funcDecl: FunctionDeclSyntax) -> String? {
        return funcDecl.signature.returnClause?.type.trimmedDescription
    }
    
    // MARK: - Code Generation
    
    private static func generateMockResponseStorage(
        methodName: String,
        parameters: [MockParameter],
        returnType: String?,
        isAsync: Bool,
        isThrows: Bool,
        config: MockResponseConfig
    ) throws -> [DeclSyntax] {
        
        var declarations: [DeclSyntax] = []
        
        // Generate response storage
        let responseStorage = """
        private var _\(methodName)MockResponses: [MockResponseConfiguration] = []
        private var _\(methodName)MockResponseIndex: Int = 0
        private let _\(methodName)MockLock = NSLock()
        """
        declarations.append(DeclSyntax.fromString(responseStorage))
        
        // Generate call metrics storage if enabled
        if config.trackCallMetrics {
            let metricsStorage = """
            private var _\(methodName)MockCallCount: Int = 0
            private var _\(methodName)MockCallHistory: [(arguments: Any, timestamp: Date)] = []
            """
            declarations.append(DeclSyntax.fromString(metricsStorage))
        }
        
        // Generate custom behavior storage
        let behaviorType = generateBehaviorType(parameters: parameters, returnType: returnType, isAsync: isAsync, isThrows: isThrows)
        let behaviorStorage = """
        var \(methodName)MockBehavior: \(behaviorType)?
        """
        declarations.append(DeclSyntax.fromString(behaviorStorage))
        
        return declarations
    }
    
    private static func generateMockResponseMethods(
        methodName: String,
        parameters: [MockParameter],
        returnType: String?,
        config: MockResponseConfig
    ) throws -> [DeclSyntax] {
        
        var declarations: [DeclSyntax] = []
        
        // Generate call count accessor
        if config.trackCallMetrics {
            let callCountAccessor = """
            var \(methodName)MockCallCount: Int {
                _\(methodName)MockLock.lock()
                defer { _\(methodName)MockLock.unlock() }
                return _\(methodName)MockCallCount
            }
            """
            declarations.append(DeclSyntax.fromString(callCountAccessor))
            
            // Generate call history accessor
            let callHistoryAccessor = """
            var \(methodName)MockCallHistory: [(arguments: Any, timestamp: Date)] {
                _\(methodName)MockLock.lock()
                defer { _\(methodName)MockLock.unlock() }
                return _\(methodName)MockCallHistory
            }
            """
            declarations.append(DeclSyntax.fromString(callHistoryAccessor))
        }
        
        // Generate reset method
        let resetMethod = """
        func reset\(methodName.capitalized)MockResponses() {
            _\(methodName)MockLock.lock()
            defer { _\(methodName)MockLock.unlock() }
            _\(methodName)MockResponseIndex = 0
            \(config.trackCallMetrics ? "_\(methodName)MockCallCount = 0" : "")
            \(config.trackCallMetrics ? "_\(methodName)MockCallHistory.removeAll()" : "")
        }
        """
        declarations.append(DeclSyntax.fromString(resetMethod))
        
        // Generate response setter method
        let setResponsesMethod = """
        func set\(methodName.capitalized)MockResponses(_ responses: [MockResponseConfiguration]) {
            _\(methodName)MockLock.lock()
            defer { _\(methodName)MockLock.unlock() }
            _\(methodName)MockResponses = responses
            _\(methodName)MockResponseIndex = 0
        }
        """
        declarations.append(DeclSyntax.fromString(setResponsesMethod))
        
        // Generate behavior setter method
        let setBehaviorMethod = generateSetBehaviorMethod(methodName: methodName, parameters: parameters, returnType: returnType)
        declarations.append(DeclSyntax.fromString(setBehaviorMethod))
        
        return declarations
    }
    
    private static func generateBehaviorType(
        parameters: [MockParameter],
        returnType: String?,
        isAsync: Bool,
        isThrows: Bool
    ) -> String {
        let paramTypes = parameters.map { $0.type }
        let paramTypesString = paramTypes.isEmpty ? "" : "(\(paramTypes.joined(separator: ", ")))"
        let returnTypeString = returnType ?? "Void"
        
        let asyncKeyword = isAsync ? "async " : ""
        let throwsKeyword = isThrows ? "throws " : ""
        
        if paramTypes.isEmpty {
            return "(() \(asyncKeyword)\(throwsKeyword)-> \(returnTypeString))"
        } else {
            return "((\(paramTypes.joined(separator: ", "))) \(asyncKeyword)\(throwsKeyword)-> \(returnTypeString))"
        }
    }
    
    private static func generateSetBehaviorMethod(
        methodName: String,
        parameters: [MockParameter],
        returnType: String?
    ) -> String {
        let paramTypes = parameters.map { $0.type }
        let returnTypeString = returnType ?? "Void"
        
        if paramTypes.isEmpty {
            return """
            func set\(methodName.capitalized)MockBehavior(_ behavior: @escaping () async throws -> \(returnTypeString)) {
                \(methodName)MockBehavior = behavior
            }
            """
        } else {
            return """
            func set\(methodName.capitalized)MockBehavior(_ behavior: @escaping (\(paramTypes.joined(separator: ", "))) async throws -> \(returnTypeString)) {
                \(methodName)MockBehavior = behavior
            }
            """
        }
    }
}

// MARK: - Supporting Types

private struct MockResponseConfig {
    let fallbackToOriginal: Bool
    let resetBetweenCalls: Bool
    let trackCallMetrics: Bool
}

private struct MockParameter {
    let name: String
    let type: String
    let externalName: String
}

// MARK: - Diagnostic Messages

private struct MockResponseMacroError: DiagnosticMessage, Error {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "MockResponseError")
    let severity: DiagnosticSeverity = .error
}

private struct MockResponseMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "MockResponseWarning")
    let severity: DiagnosticSeverity = .warning
}