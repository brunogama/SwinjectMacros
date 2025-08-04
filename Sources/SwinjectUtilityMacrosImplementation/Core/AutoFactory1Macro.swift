// AutoFactory1Macro.swift - Single-parameter factory generation

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @AutoFactory1 macro
///
/// Generates factory patterns specifically for services that require exactly one runtime parameter,
/// in addition to their injected dependencies. This is optimized for the common case of single-parameter factories.
public struct AutoFactory1Macro: MemberMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // Generate simple single-parameter factory
        [
            DeclSyntax("""
            /// Single-parameter factory protocol
            protocol Factory {
                func makeInstance(param1: Any) -> Self
            }

            /// Factory registration
            static func registerFactory1(in container: Container) {
                // Factory implementation will be generated
            }
            """)
        ]
    }
}
