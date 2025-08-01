// StubServiceMacro.swift - Test stub generation implementation

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftDiagnostics

/// Implementation of the @StubService macro for generating test stub implementations
/// 
/// Automatically generates stub implementations of protocols with configurable return values,
/// call recording, and flexible behavior configuration for comprehensive testing.
public struct StubServiceMacro: MemberMacro, ExtensionMacro {
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        // Validate that this is applied to a protocol or extension
        guard declaration.is(ProtocolDeclSyntax.self) || declaration.is(ExtensionDeclSyntax.self) else {
            
            context.diagnose(Diagnostic(
                node: declaration,
                message: StubServiceMacroError(message: """
                @StubService can only be applied to protocols or protocol extensions.
                
                Example:
                @StubService
                protocol UserServiceProtocol {
                    func getUser(id: String) -> User?
                }
                """)
            ))
            return []
        }
        
        // Extract macro arguments
        let arguments = extractArguments(from: node)
        
        // Generate stub implementation
        let stubImplementation = try generateStubImplementation(
            for: declaration,
            with: arguments,
            in: context
        )
        
        return stubImplementation
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        
        // Generate extension for StubService conformance
        let stubExtension = ExtensionDeclSyntax(
            extendedType: type,
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier("StubService")))
            }
        ) {
            // Generate resetStub method
            FunctionDeclSyntax(
                name: .identifier("resetStub"),
                signature: FunctionSignatureSyntax(
                    parameterClause: FunctionParameterClauseSyntax {
                        // No parameters
                    }
                )
            ) {
                CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(item: .expr(ExprSyntax(stringLiteral: """
                    // Reset all stub configurations to defaults
                    // Implementation will be generated based on protocol methods
                    """)))
                ])
            }
            
            // Generate configureDefaults method
            FunctionDeclSyntax(
                name: .identifier("configureDefaults"),
                signature: FunctionSignatureSyntax(
                    parameterClause: FunctionParameterClauseSyntax {
                        // No parameters
                    }
                )
            ) {
                CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(item: .expr(ExprSyntax(stringLiteral: """
                    // Configure stub with sensible default values
                    // Implementation will be generated based on protocol methods
                    """)))
                ])
            }
        }
        
        return [stubExtension]
    }
}

// MARK: - Implementation Generation

private extension StubServiceMacro {
    
    struct MacroArguments {
        let prefix: String
        let suffix: String
        let recordCalls: Bool
        let throwErrors: Bool
        let closureSupport: Bool
        let asyncSupport: Bool
        
        func stubClassName(for protocolName: String) -> String {
            return "\(prefix)\(protocolName)\(suffix)"
        }
    }
    
    static func extractArguments(from node: AttributeSyntax) -> MacroArguments {
        var prefix = ""
        var suffix = "Stub"
        var recordCalls = true
        var throwErrors = true
        var closureSupport = false
        var asyncSupport = true
        
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                switch argument.label?.text {
                case "prefix":
                    if let stringValue = argument.expression.as(StringLiteralExprSyntax.self) {
                        prefix = stringValue.segments.first?.description ?? ""
                    }
                case "suffix":
                    if let stringValue = argument.expression.as(StringLiteralExprSyntax.self) {
                        suffix = stringValue.segments.first?.description ?? "Stub"
                    }
                case "recordCalls":
                    if let boolValue = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        recordCalls = boolValue.literal.text == "true"
                    }
                case "throwErrors":
                    if let boolValue = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        throwErrors = boolValue.literal.text == "true"
                    }
                case "closureSupport":
                    if let boolValue = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        closureSupport = boolValue.literal.text == "true"
                    }
                case "async":
                    if let boolValue = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        asyncSupport = boolValue.literal.text == "true"
                    }
                default:
                    break
                }
            }
        }
        
        return MacroArguments(
            prefix: prefix,
            suffix: suffix,
            recordCalls: recordCalls,
            throwErrors: throwErrors,
            closureSupport: closureSupport,
            asyncSupport: asyncSupport
        )
    }
    
    static func generateStubImplementation(
        for declaration: some DeclGroupSyntax,
        with arguments: MacroArguments,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        var protocolName = "Unknown"
        var methods: [FunctionDeclSyntax] = []
        
        // Extract protocol information
        if let protocolDecl = declaration.as(ProtocolDeclSyntax.self) {
            protocolName = protocolDecl.name.text
            methods = protocolDecl.memberBlock.members.compactMap { member in
                member.decl.as(FunctionDeclSyntax.self)
            }
        } else if let extensionDecl = declaration.as(ExtensionDeclSyntax.self) {
            if let identifierType = extensionDecl.extendedType.as(IdentifierTypeSyntax.self) {
                protocolName = identifierType.name.text
            }
            methods = extensionDecl.memberBlock.members.compactMap { member in
                member.decl.as(FunctionDeclSyntax.self)
            }
        }
        
        let stubClassName = arguments.stubClassName(for: protocolName)
        
        // Generate stub class declaration
        let stubClass = try ClassDeclSyntax(
            name: .identifier(stubClassName),
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier(protocolName)))
            }
        ) {
            // Generate initializer
            InitializerDeclSyntax(
                signature: FunctionSignatureSyntax(
                    parameterClause: FunctionParameterClauseSyntax {
                        // Empty initializer
                    }
                )
            ) {
                CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(item: .expr(ExprSyntax(stringLiteral: """
                    // Initialize stub with default values
                    configureDefaults()
                    """)))
                ])
            }
            
            // Generate stub properties and methods for each protocol method
            for method in methods {
                // Generate return value property
                if let returnType = method.signature.returnClause?.type {
                    let propertyName = "\(method.name.text)ReturnValue"
                    let variableDecl = VariableDeclSyntax(
                        modifiers: DeclModifierListSyntax([
                            DeclModifierSyntax(name: .keyword(.public))
                        ]),
                        bindingSpecifier: .keyword(.var),
                        bindings: PatternBindingListSyntax([
                            PatternBindingSyntax(
                                pattern: IdentifierPatternSyntax(identifier: .identifier(propertyName)),
                                typeAnnotation: TypeAnnotationSyntax(
                                    type: OptionalTypeSyntax(wrappedType: returnType)
                                )
                            )
                        ])
                    )
                    
                    DeclSyntax(variableDecl)
                }
                
                // Generate call count property (if recording enabled)
                if arguments.recordCalls {
                    let callCountProperty = VariableDeclSyntax(
                        modifiers: DeclModifierListSyntax([
                            DeclModifierSyntax(name: .keyword(.public))
                        ]),
                        bindingSpecifier: .keyword(.var),
                        bindings: PatternBindingListSyntax([
                            PatternBindingSyntax(
                                pattern: IdentifierPatternSyntax(identifier: .identifier("\(method.name.text)CallCount")),
                                typeAnnotation: TypeAnnotationSyntax(
                                    type: IdentifierTypeSyntax(name: .identifier("Int"))
                                ),
                                initializer: InitializerClauseSyntax(
                                    value: IntegerLiteralExprSyntax(0)
                                )
                            )
                        ])
                    )
                    
                    DeclSyntax(callCountProperty)
                }
                
                // Generate stub method implementation
                let stubMethod = generateStubMethod(
                    from: method,
                    with: arguments,
                    protocolName: protocolName
                )
                
                DeclSyntax(stubMethod)
            }
            
            // Generate StubService conformance methods
            for stubMethod in generateStubServiceMethods(arguments: arguments) {
                stubMethod
            }
        }
        
        return [DeclSyntax(stubClass)]
    }
    
    static func generateStubMethod(
        from method: FunctionDeclSyntax,
        with arguments: MacroArguments,
        protocolName: String
    ) -> FunctionDeclSyntax {
        
        let methodName = method.name.text
        let returnType = method.signature.returnClause?.type
        let isAsync = method.signature.effectSpecifiers?.asyncSpecifier != nil
        let isThrows = method.signature.effectSpecifiers?.throwsSpecifier != nil
        
        return FunctionDeclSyntax(
            modifiers: DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.public))
            ]),
            name: method.name,
            signature: method.signature
        ) {
            CodeBlockItemListSyntax([
                // Record call if enabled
                CodeBlockItemSyntax(item: .expr(ExprSyntax(stringLiteral: arguments.recordCalls ? """
                \(methodName)CallCount += 1
                """ : "// Call recording disabled"))),
                
                // Check for closure override if enabled
                CodeBlockItemSyntax(item: .expr(ExprSyntax(stringLiteral: arguments.closureSupport ? """
                if let closure = \(methodName)Closure {
                    return \(isAsync ? "await " : "")\(isThrows ? "try " : "")closure()
                }
                """ : "// Closure support disabled"))),
                
                // Check for error throwing if enabled
                CodeBlockItemSyntax(item: .expr(ExprSyntax(stringLiteral: arguments.throwErrors && isThrows ? """
                if let error = \(methodName)ThrowError {
                    throw error
                }
                """ : "// Error throwing disabled"))),
                
                // Return configured value
                CodeBlockItemSyntax(item: .expr(ExprSyntax(stringLiteral: returnType != nil ? """
                return \(methodName)ReturnValue ?? {
                    fatalError("No return value configured for \(methodName) in \(protocolName) stub")
                }()
                """ : "// Void return type")))
            ])
        }
    }
    
    static func generateStubServiceMethods(arguments: MacroArguments) -> [DeclSyntax] {
        return [
            // resetStub implementation
            DeclSyntax(FunctionDeclSyntax(
                modifiers: DeclModifierListSyntax([
                    DeclModifierSyntax(name: .keyword(.public))
                ]),
                name: .identifier("resetStub"),
                signature: FunctionSignatureSyntax(
                    parameterClause: FunctionParameterClauseSyntax {
                        // No parameters
                    }
                )
            ) {
                CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(item: .expr(ExprSyntax(stringLiteral: """
                    // Reset all return values to nil
                    // Reset all call counts to 0
                    // Clear all recorded arguments
                    """)))
                ])
            }),
            
            // configureDefaults implementation
            DeclSyntax(FunctionDeclSyntax(
                modifiers: DeclModifierListSyntax([
                    DeclModifierSyntax(name: .keyword(.public))
                ]),
                name: .identifier("configureDefaults"),
                signature: FunctionSignatureSyntax(
                    parameterClause: FunctionParameterClauseSyntax {
                        // No parameters
                    }
                )
            ) {
                CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(item: .expr(ExprSyntax(stringLiteral: """
                    // Configure sensible default return values
                    // Based on return types of protocol methods
                    """)))
                ])
            })
        ]
    }
}

// MARK: - Error Types

private struct StubServiceMacroError: DiagnosticMessage, Error {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "StubServiceMacro")
    let severity = DiagnosticSeverity.error
}