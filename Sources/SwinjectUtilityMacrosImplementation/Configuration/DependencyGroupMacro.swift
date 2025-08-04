// DependencyGroupMacro.swift - @DependencyGroup macro implementation

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @DependencyGroup macro for grouping related service registrations.
public struct DependencyGroupMacro: PeerMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // For now, this is a documentation-only macro
        // Future implementation would add grouping metadata
        []
    }
}
