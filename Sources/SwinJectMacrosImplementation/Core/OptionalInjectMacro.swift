// OptionalInjectMacro.swift - Optional dependency injection implementation

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

/// Implementation of the @OptionalInject macro
/// 
/// Enables optional dependency injection where services may or may not be available,
/// providing graceful degradation when dependencies are not registered.
public struct OptionalInjectMacro: AccessorMacro {
    
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        
        // Generate basic getter for optional injection
        let getter = AccessorDeclSyntax(
            accessorSpecifier: .keyword(.get)
        ) {
            CodeBlockItemListSyntax([
                CodeBlockItemSyntax(item: .expr(ExprSyntax(stringLiteral: """
                return Container.shared?.resolve(ServiceType.self)
                """)))
            ])
        }
        
        return [getter]
    }
}