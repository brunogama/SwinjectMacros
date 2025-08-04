// ScopedServiceMacro.swift - Service lifecycle scoping implementation

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @ScopedService macro
///
/// Automatically configures service registration with specific object scopes,
/// providing fine-grained control over service lifecycle management.
public struct ScopedServiceMacro: MemberMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // Generate basic scoped service infrastructure
        [
            DeclSyntax("""
            /// Scoped service configuration
            static let scopeConfiguration = "container"

            /// Register with configured scope
            static func registerScoped(in container: Container) {
                container.register(Self.self) { resolver in
                    return Self()
                }.inObjectScope(.container)
            }
            """)
        ]
    }
}
