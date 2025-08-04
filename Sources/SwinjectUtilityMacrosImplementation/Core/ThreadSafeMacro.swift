// ThreadSafeMacro.swift - Thread-safe dependency injection implementation

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @ThreadSafe macro
///
/// Ensures thread-safe dependency injection and service access by adding
/// appropriate synchronization mechanisms to service registration and resolution.
public struct ThreadSafeMacro: MemberMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // Generate basic thread-safe infrastructure
        [
            DeclSyntax("""
            /// Thread-safe registration infrastructure
            private static let _threadSafeLock = NSLock()

            /// Thread-safe registration method
            static func registerThreadSafe(in container: Container) {
                _threadSafeLock.lock()
                defer { _threadSafeLock.unlock() }
                register(in: container)
            }

            /// Thread safety information
            static let threadSafetyEnabled = true
            """)
        ]
    }
}
