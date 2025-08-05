// ServiceGroupMacro.swift - Service group annotation implementation

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @ServiceGroup macro
///
/// Annotates service registration methods for documentation and validation.
/// This macro primarily serves as a marker for code organization and generates
/// documentation and validation metadata.
public struct ServiceGroupMacro: PeerMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // Generate simple service group metadata
        [
            DeclSyntax("""
            /// Service group metadata
            private static let _serviceGroupInfo = "ServiceGroup"
            """)
        ]
    }
}
