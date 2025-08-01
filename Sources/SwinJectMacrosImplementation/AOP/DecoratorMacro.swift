// DecoratorMacro.swift - AOP Decorator pattern implementation

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

/// Implementation of the @Decorator macro for AOP decorator pattern
/// 
/// Generates decorator implementations that wrap service instances with additional behavior
/// while maintaining the same interface. This enables aspect-oriented programming patterns
/// like logging, caching, validation, etc.
public struct DecoratorMacro: MemberMacro {
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        // Generate basic decorator infrastructure
        return [
            DeclSyntax("""
            /// Decorator infrastructure
            private var _decorators: [AnyDecorator] = []
            
            /// Add decorator to this service
            func addDecorator(_ decorator: AnyDecorator) {
                _decorators.append(decorator)
            }
            
            /// Execute with decorator chain
            func executeWithDecorators<T>(_ operation: () throws -> T) rethrows -> T {
                return _decorators.reduce(operation) { currentOp, decorator in
                    return {
                        return try decorator.decorate(execution: currentOp)
                    }
                }()
            }
            """)
        ]
    }
}

/// Simple decorator protocol
public protocol AnyDecorator {
    func decorate<T>(execution: () throws -> T) rethrows -> T
}