// AutoFactory2Macro.swift - Two-parameter factory generation

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

/// Implementation of the @AutoFactory2 macro
/// 
/// Generates factory patterns specifically for services that require exactly two runtime parameters.
public struct AutoFactory2Macro: MemberMacro {
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        // Generate simple two-parameter factory
        return [
            DeclSyntax("""
            /// Two-parameter factory protocol
            protocol Factory2 {
                func makeInstance(param1: Any, param2: Any) -> Self
            }
            
            /// Factory registration
            static func registerFactory2(in container: Container) {
                // Factory implementation will be generated
            }
            """)
        ]
    }
}