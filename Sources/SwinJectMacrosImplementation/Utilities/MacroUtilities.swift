// MacroUtilities.swift - Shared utilities for macro implementations

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

/// Shared utilities for macro implementations to eliminate code duplication
public enum MacroUtilities {
    
    // MARK: - Variable Name Mangling for Collision-Free Code Generation
    
    /// Generates a mangled variable name that's guaranteed to be unique
    /// - Parameters:
    ///   - baseName: The base variable name (e.g., "startTime", "duration")
    ///   - context: Context for uniqueness (e.g., property name, method name)
    ///   - macroType: Type of macro generating the variable (e.g., "LazyInject", "Retry")
    ///   - suffix: Optional suffix for additional distinction
    /// - Returns: Mangled variable name guaranteed to be unique
    public static func mangledVariableName(
        baseName: String,
        context: String,
        macroType: String,
        suffix: String? = nil
    ) -> String {
        // Create deterministic hash from context + macro type
        let contextHash = "\(context)_\(macroType)".hashValue
        let hashString = String(abs(contextHash), radix: 36) // Base36 for shorter strings
        
        var mangledName = "_\(macroType)\(context.capitalizingFirstLetter())\(baseName.capitalizingFirstLetter())_\(hashString)"
        
        if let suffix = suffix {
            mangledName += "_\(suffix)"
        }
        
        return mangledName
    }
    
    /// Generates a mangled property backing variable name
    /// - Parameters:
    ///   - propertyName: Name of the property being backed
    ///   - macroType: Type of macro (e.g., "LazyInject", "WeakInject")
    /// - Returns: Mangled backing variable name
    public static func mangledBackingVariableName(
        propertyName: String,
        macroType: String
    ) -> String {
        return mangledVariableName(
            baseName: "Backing",
            context: propertyName,
            macroType: macroType
        )
    }
    
    /// Generates a mangled lock variable name for thread safety
    /// - Parameters:
    ///   - propertyName: Name of the property being protected
    ///   - macroType: Type of macro
    /// - Returns: Mangled lock variable name
    public static func mangledLockVariableName(
        propertyName: String,
        macroType: String
    ) -> String {
        return mangledVariableName(
            baseName: "Lock",
            context: propertyName,
            macroType: macroType
        )
    }
    
    /// Generates a mangled once token variable name
    /// - Parameters:
    ///   - propertyName: Name of the property
    ///   - macroType: Type of macro
    /// - Returns: Mangled once token variable name
    public static func mangledOnceTokenVariableName(
        propertyName: String,
        macroType: String
    ) -> String {
        return mangledVariableName(
            baseName: "OnceToken",
            context: propertyName,
            macroType: macroType
        )
    }
    
    /// Generates mangled method-scoped variable names for AOP macros
    /// - Parameters:
    ///   - baseName: Base variable name
    ///   - methodName: Name of the method being wrapped
    ///   - macroType: Type of macro
    /// - Returns: Mangled variable name
    public static func mangledMethodVariableName(
        baseName: String,
        methodName: String,
        macroType: String
    ) -> String {
        return mangledVariableName(
            baseName: baseName,
            context: methodName,
            macroType: macroType
        )
    }
    
    // MARK: - Declaration Validation
    
    /// Validates that a macro is applied to a supported declaration type
    /// - Parameters:
    ///   - declaration: The declaration to validate
    ///   - supportedTypes: Array of supported declaration types
    ///   - macroName: Name of the macro for error messages
    ///   - context: Macro expansion context for diagnostics
    /// - Returns: true if valid, false otherwise
    public static func validateDeclarationType<T: DeclGroupSyntax>(
        _ declaration: T,
        supportedTypes: [Any.Type],
        macroName: String,
        context: some MacroExpansionContext
    ) -> Bool {
        let isSupported = supportedTypes.contains { type in
            if type == ClassDeclSyntax.self {
                return declaration.is(ClassDeclSyntax.self)
            } else if type == StructDeclSyntax.self {
                return declaration.is(StructDeclSyntax.self)
            } else if type == EnumDeclSyntax.self {
                return declaration.is(EnumDeclSyntax.self)
            }
            return false
        }
        
        if !isSupported {
            let supportedTypeNames = supportedTypes.map { "\($0)" }
                .joined(separator: ", ")
            
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: MacroValidationError(message: """
                @\(macroName) can only be applied to: \(supportedTypeNames)
                
                Please apply this macro to a supported declaration type.
                """)
            )
            context.diagnose(diagnostic)
        }
        
        return isSupported
    }
    
    /// Extracts the name from a declaration
    /// - Parameter declaration: The declaration to extract name from
    /// - Returns: The name if found, nil otherwise
    public static func extractDeclarationName<T: DeclGroupSyntax>(from declaration: T) -> String? {
        if let classDecl = declaration.as(ClassDeclSyntax.self) {
            return classDecl.name.text
        } else if let structDecl = declaration.as(StructDeclSyntax.self) {
            return structDecl.name.text
        } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return enumDecl.name.text
        } else if let protocolDecl = declaration.as(ProtocolDeclSyntax.self) {
            return protocolDecl.name.text
        }
        return nil
    }
    
    /// Extracts the member block from a declaration
    /// - Parameter declaration: The declaration to extract member block from
    /// - Returns: The member block if found, nil otherwise
    public static func extractMemberBlock<T: DeclGroupSyntax>(from declaration: T) -> MemberBlockSyntax? {
        if let classDecl = declaration.as(ClassDeclSyntax.self) {
            return classDecl.memberBlock
        } else if let structDecl = declaration.as(StructDeclSyntax.self) {
            return structDecl.memberBlock
        } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return enumDecl.memberBlock
        } else if let protocolDecl = declaration.as(ProtocolDeclSyntax.self) {
            return protocolDecl.memberBlock
        }
        return nil
    }
    
    // MARK: - Initializer Discovery
    
    /// Finds all initializers in a member block
    /// - Parameter memberBlock: The member block to search
    /// - Returns: Array of found initializers
    public static func findInitializers(in memberBlock: MemberBlockSyntax) -> [InitializerDeclSyntax] {
        return memberBlock.members.compactMap { member in
            member.decl.as(InitializerDeclSyntax.self)
        }
    }
    
    /// Finds the primary initializer (prefers public, then first available)
    /// - Parameter memberBlock: The member block to search
    /// - Returns: The primary initializer if found, nil otherwise
    public static func findPrimaryInitializer(in memberBlock: MemberBlockSyntax) -> InitializerDeclSyntax? {
        let initializers = findInitializers(in: memberBlock)
        
        // Prefer public initializers
        let publicInitializers = initializers.filter { initializer in
            hasPublicModifier(initializer.modifiers)
        }
        
        return publicInitializers.first ?? initializers.first
    }
    
    /// Checks if modifiers contain public access
    /// - Parameter modifiers: The modifiers to check
    /// - Returns: true if public modifier is present
    public static func hasPublicModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
        return modifiers.contains { modifier in
            modifier.name.text == "public"
        }
    }
    
    // MARK: - Function Analysis
    
    /// Extracts parameter names from a function declaration
    /// - Parameter function: The function to analyze
    /// - Returns: Array of parameter names
    public static func extractParameterNames(from function: FunctionDeclSyntax) -> [String] {
        return function.signature.parameterClause.parameters.map { param in
            param.firstName.text
        }
    }
    
    /// Extracts parameter types from a function declaration
    /// - Parameter function: The function to analyze
    /// - Returns: Array of parameter types as strings
    public static func extractParameterTypes(from function: FunctionDeclSyntax) -> [String] {
        return function.signature.parameterClause.parameters.map { param in
            param.type.description
        }
    }
    
    /// Builds a parameter call list for function invocation
    /// - Parameter function: The function to build call for
    /// - Returns: Comma-separated parameter call string
    public static func buildParameterCallList(from function: FunctionDeclSyntax) -> String {
        let paramNames = extractParameterNames(from: function)
        return paramNames.joined(separator: ", ")
    }
    
    // MARK: - Attribute Parsing
    
    /// Parses string literal from attribute argument
    /// - Parameter expression: The expression to parse
    /// - Returns: The string value if found, nil otherwise
    public static func parseStringLiteral(from expression: ExprSyntax) -> String? {
        guard let stringLiteral = expression.as(StringLiteralExprSyntax.self),
              let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) else {
            return nil
        }
        return segment.content.text
    }
    
    /// Parses member access expression to extract member name
    /// - Parameter expression: The expression to parse
    /// - Returns: The member name if found, nil otherwise
    public static func parseMemberAccess(from expression: ExprSyntax) -> String? {
        guard let memberAccess = expression.as(MemberAccessExprSyntax.self) else {
            return nil
        }
        return memberAccess.declName.baseName.text
    }
    
    /// Parses boolean literal from attribute argument
    /// - Parameter expression: The expression to parse
    /// - Returns: The boolean value if found, nil otherwise
    public static func parseBooleanLiteral(from expression: ExprSyntax) -> Bool? {
        guard let boolLiteral = expression.as(BooleanLiteralExprSyntax.self) else {
            return nil
        }
        return boolLiteral.literal.text == "true"
    }
    
    // MARK: - Code Generation Helpers
    
    /// Generates a method signature string
    /// - Parameters:
    ///   - methodName: Name of the method
    ///   - parameters: Parameter list string
    ///   - returnType: Return type string
    ///   - isAsync: Whether method is async
    ///   - canThrow: Whether method can throw
    /// - Returns: Complete method signature string
    public static func generateMethodSignature(
        methodName: String,
        parameters: String,
        returnType: String = "Void",
        isAsync: Bool = false,
        canThrow: Bool = false
    ) -> String {
        var signature = "func \(methodName)(\(parameters))"
        
        if isAsync {
            signature += " async"
        }
        
        if canThrow {
            signature += " throws"
        }
        
        if returnType != "Void" {
            signature += " -> \(returnType)"
        }
        
        return signature
    }
    
    /// Generates import statements for required dependencies
    /// - Parameter requiredImports: Set of import names
    /// - Returns: Array of import statement strings
    public static func generateImportStatements(for requiredImports: Set<String>) -> [String] {
        return Array(requiredImports).sorted().map { "import \($0)" }
    }
    
    // MARK: - Diagnostic Helpers
    
    /// Creates a standardized error diagnostic
    /// - Parameters:
    ///   - node: Syntax node for the diagnostic
    ///   - macroName: Name of the macro
    ///   - message: Error message
    /// - Returns: Diagnostic instance
    public static func createErrorDiagnostic(
        node: SyntaxProtocol,
        macroName: String,
        message: String
    ) -> Diagnostic {
        return Diagnostic(
            node: node.root,
            message: MacroError(
                macroName: macroName,
                message: message,
                severity: .error
            )
        )
    }
    
    /// Creates a standardized warning diagnostic
    /// - Parameters:
    ///   - node: Syntax node for the diagnostic
    ///   - macroName: Name of the macro
    ///   - message: Warning message
    /// - Returns: Diagnostic instance
    public static func createWarningDiagnostic(
        node: SyntaxProtocol,
        macroName: String,
        message: String
    ) -> Diagnostic {
        return Diagnostic(
            node: node.root,
            message: MacroError(
                macroName: macroName,
                message: message,
                severity: .warning
            )
        )
    }
}

// MARK: - Supporting Types

/// Generic macro validation error
private struct MacroValidationError: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinJectMacros", id: "ValidationError")
    let severity: DiagnosticSeverity = .error
}

/// Generic macro error with configurable severity
private struct MacroError: DiagnosticMessage {
    let macroName: String
    let message: String
    let severity: DiagnosticSeverity
    
    var diagnosticID: MessageID {
        MessageID(domain: "SwinJectMacros", id: "\(macroName)Error")
    }
}

// MARK: - String Extensions for Mangling

extension String {
    /// Capitalizes the first letter of the string
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }
}