// NamedMacro.swift - Named service registration implementation

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

/// Implementation of the @Named macro
/// 
/// Enables named service registration for scenarios where multiple implementations
/// of the same protocol need to be distinguished by name.
public struct NamedMacro: MemberMacro {
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        // Generate basic named service infrastructure
        return [
            DeclSyntax("""
            /// Named service configuration
            static let serviceName = "defaultName"
            
            /// Register with name
            static func registerNamed(in container: Container, name: String = serviceName) {
                container.register(Self.self, name: name) { resolver in
                    return Self()
                }
            }
            
            /// Check if name is valid
            static func isValidName(_ name: String) -> Bool {
                return !name.isEmpty
            }
            """)
        ]
    }
}