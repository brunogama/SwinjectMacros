// InjectedStateObjectMacro.swift - SwiftUI StateObject dependency injection implementation

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftDiagnostics

/// Implementation of the @InjectedStateObject macro for SwiftUI StateObject dependency injection
/// 
/// Generates SwiftUI StateObject property wrappers that resolve dependencies from the DI container
/// while maintaining proper SwiftUI lifecycle semantics and ObservableObject integration.
public struct InjectedStateObjectMacro: AccessorMacro {
    
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        
        // Validate that this is applied to a property
        guard let variableDecl = declaration.as(VariableDeclSyntax.self),
              let binding = variableDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
              let typeAnnotation = binding.typeAnnotation?.type else {
            
            context.diagnose(Diagnostic(
                node: declaration,
                message: InjectedStateObjectMacroError(message: """
                @InjectedStateObject can only be applied to properties with explicit type annotations.
                
                Example:
                @InjectedStateObject var viewModel: UserViewModel
                """)
            ))
            return []
        }
        
        // Extract macro arguments
        let arguments = extractArguments(from: node)
        let propertyName = identifier.text
        let typeName = typeAnnotation.description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Generate backing storage property name
        let backingStorageName = "_\(propertyName)StateObject"
        
        // Create the StateObject property wrapper getter
        let getter = AccessorDeclSyntax(
            accessorSpecifier: .keyword(.get)
        ) {
            CodeBlockItemListSyntax([
                // Generate lazy StateObject initialization
                CodeBlockItemSyntax(item: .expr(ExprSyntax(stringLiteral: """
                if \(backingStorageName) == nil {
                    \(backingStorageName) = StateObject(wrappedValue: {
                        let container = \(arguments.containerAccess)
                        guard let dependency = container.\(arguments.resolveCall) else {
                            fatalError("Failed to resolve \(typeName)\(arguments.nameDescription) - ensure it's registered in the container")
                        }
                        return dependency
                    }())
                }
                return \(backingStorageName)!.wrappedValue
                """)))
            ])
        }
        
        // Create the StateObject property wrapper setter (for @StateObject compatibility)
        let setter = AccessorDeclSyntax(
            accessorSpecifier: .keyword(.set)
        ) {
            CodeBlockItemListSyntax([
                CodeBlockItemSyntax(item: .expr(ExprSyntax(stringLiteral: """
                if \(backingStorageName) == nil {
                    \(backingStorageName) = StateObject(wrappedValue: newValue)
                } else {
                    \(backingStorageName)!.wrappedValue = newValue
                }
                """)))
            ])
        }
        
        return [getter, setter]
    }
}

// MARK: - Argument Extraction

private extension InjectedStateObjectMacro {
    
    struct MacroArguments {
        let name: String?
        let containerName: String?
        let resolverName: String
        
        var containerAccess: String {
            if let containerName = containerName {
                return "Container.named(\"\(containerName)\")"
            } else {
                return "Container.shared ?? Environment(\\.stateObjectContainer).wrappedValue ?? Container()"
            }
        }
        
        var resolveCall: String {
            if let name = name {
                return "resolve(\(resolverName == "resolver" ? "" : "\(resolverName): ")\(name.isEmpty ? "" : "name: \"\(name)\", "))"
            } else {
                return "resolve(\(resolverName == "resolver" ? "" : "\(resolverName): "))"
            }
        }
        
        var nameDescription: String {
            if let name = name, !name.isEmpty {
                return " with name '\(name)'"
            }
            return ""
        }
    }
    
    static func extractArguments(from node: AttributeSyntax) -> MacroArguments {
        var name: String? = nil
        var containerName: String? = nil
        var resolverName = "resolver"
        
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                if argument.label == nil {
                    // First unlabeled argument is the name
                    if let stringValue = argument.expression.as(StringLiteralExprSyntax.self) {
                        name = stringValue.segments.first?.description
                    }
                } else if argument.label?.text == "container" {
                    if let stringValue = argument.expression.as(StringLiteralExprSyntax.self) {
                        containerName = stringValue.segments.first?.description
                    }
                } else if argument.label?.text == "resolver" {
                    if let stringValue = argument.expression.as(StringLiteralExprSyntax.self) {
                        resolverName = stringValue.segments.first?.description ?? "resolver"
                    }
                }
            }
        }
        
        return MacroArguments(
            name: name,
            containerName: containerName,
            resolverName: resolverName
        )
    }
}

// MARK: - Error Types

private struct InjectedStateObjectMacroError: DiagnosticMessage, Error {
    let message: String
    let diagnosticID = MessageID(domain: "SwinJectMacros", id: "InjectedStateObjectMacro")
    let severity = DiagnosticSeverity.error
}