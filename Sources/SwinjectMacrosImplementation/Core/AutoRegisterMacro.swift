// AutoRegisterMacro.swift - Automatic batch service registration

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @AutoRegister macro
///
/// Automatically registers multiple services in a container using batch registration.
/// This macro can be applied to assemblies, containers, or service collections to
/// automatically register all marked services in one operation.
public struct AutoRegisterMacro: MemberMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // Generate simple auto-registration method
        [
            DeclSyntax("""
            /// Automatically register all services marked with dependency injection macros
            func autoRegisterAllServices() {
                // Build plugin will generate service registration calls
                #if AUTOREGISTER_GENERATED
                // Generated service registrations will be inserted here
                #endif
            }

            /// Auto-registration metadata
            static let autoRegisterEnabled = true
            """)
        ]
    }
}
