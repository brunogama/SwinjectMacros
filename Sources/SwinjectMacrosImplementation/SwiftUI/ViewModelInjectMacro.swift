// ViewModelInjectMacro.swift - @ViewModelInject macro implementation

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @ViewModelInject macro for SwiftUI ViewModel dependency injection.
public struct ViewModelInjectMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro Implementation

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // Validate that this is applied to a class
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: ViewModelInjectMacroError(message: """
                @ViewModelInject can only be applied to classes.

                ✅ Correct usage:
                @ViewModelInject
                class UserProfileViewModel {
                    private let userService: UserServiceProtocol
                    private let analytics: AnalyticsProtocol

                    @Published var user: User?
                    @Published var isLoading = false
                }

                ❌ Invalid usage:
                @ViewModelInject
                struct UserProfileViewModel { ... } // Structs not supported

                @ViewModelInject
                protocol ViewModelProtocol { ... } // Protocols not supported

                💡 Tip: ViewModels should be classes to work with SwiftUI's ObservableObject.
                """)
            )
            context.diagnose(diagnostic)
            return []
        }

        let className = classDecl.name.text

        // Parse macro configuration
        let config = try parseViewModelInjectConfig(from: node)

        // Analyze existing initializers and dependencies
        let dependencyAnalysis = try analyzeDependencies(in: classDecl, context: context)

        var generatedMembers: [DeclSyntax] = []

        // Generate dependency injection initializer
        if let diInitializer = try generateDependencyInjectionInitializer(
            className: className,
            dependencies: dependencyAnalysis.dependencies,
            config: config,
            context: context
        ) {
            generatedMembers.append(diInitializer)
        }

        // Generate factory method if requested
        if config.generateFactory {
            if let factoryMethod = try generateFactoryMethod(
                className: className,
                dependencies: dependencyAnalysis.dependencies,
                config: config,
                context: context
            ) {
                generatedMembers.append(factoryMethod)
            }
        }

        // Generate preview support if requested
        if config.previewSupport {
            if let previewInit = try generatePreviewInitializer(
                className: className,
                dependencies: dependencyAnalysis.dependencies,
                config: config,
                context: context
            ) {
                generatedMembers.append(previewInit)
            }
        }

        return generatedMembers
    }

    // MARK: - ExtensionMacro Implementation

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {

        // Check if the class already conforms to ObservableObject
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            return []
        }

        let alreadyConforms = classDecl.inheritanceClause?.inheritedTypes.contains { inheritedType in
            inheritedType.type.trimmedDescription.contains("ObservableObject")
        } ?? false

        if alreadyConforms {
            return []
        }

        // Generate ObservableObject conformance extension
        let typeName = type.trimmedDescription

        let extensionDecl = try ExtensionDeclSyntax(
            extensionKeyword: .keyword(.extension),
            extendedType: IdentifierTypeSyntax(name: .identifier(typeName)),
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier("ObservableObject")))
            }
        ) {
            // Empty extension body - conformance is automatic for classes with @Published properties
        }

        return [extensionDecl]
    }

    // MARK: - Configuration Parsing

    private static func parseViewModelInjectConfig(from node: AttributeSyntax) throws -> ViewModelInjectConfig {
        var containerName = "default"
        var scope = "transient"
        var generateFactory = false
        var previewSupport = true

        // Parse attribute arguments
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                switch argument.label?.text {
                case "container":
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
                    {
                        containerName = segment.content.text
                    }
                case "scope":
                    scope = argument.expression.trimmedDescription
                case "generateFactory":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        generateFactory = boolLiteral.literal.text == "true"
                    }
                case "previewSupport":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        previewSupport = boolLiteral.literal.text == "true"
                    }
                default:
                    break
                }
            }
        }

        return ViewModelInjectConfig(
            containerName: containerName,
            scope: scope,
            generateFactory: generateFactory,
            previewSupport: previewSupport
        )
    }

    // MARK: - Dependency Analysis

    private static func analyzeDependencies(
        in classDecl: ClassDeclSyntax,
        context: some MacroExpansionContext
    ) throws -> ViewModelDependencyAnalysis {

        var dependencies: [ViewModelDependencyInfo] = []

        // Look for private/internal properties that could be dependencies
        for member in classDecl.memberBlock.members {
            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                // Skip @Published properties and computed properties
                let hasPublishedAttribute = varDecl.attributes.contains { attribute in
                    attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "Published"
                }

                if hasPublishedAttribute || varDecl.bindings.first?.accessorBlock != nil {
                    continue
                }

                // Check if it's a potential dependency (private/internal, has type annotation)
                if let binding = varDecl.bindings.first,
                   let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                   let typeAnnotation = binding.typeAnnotation
                {

                    let propertyName = identifier.identifier.text
                    let propertyType = typeAnnotation.type.trimmedDescription
                    let isOptional = propertyType.hasSuffix("?")

                    // Check for private/internal access level
                    let isPrivateOrInternal = varDecl.modifiers.contains { modifier in
                        modifier.name.text == "private" || modifier.name.text == "internal"
                    } || varDecl.modifiers.isEmpty // default is internal

                    if isPrivateOrInternal {
                        // Extract service name from attributes like @Named("serviceName") or @Service("customService")
                        let serviceName = extractServiceName(from: varDecl.attributes)

                        dependencies.append(ViewModelDependencyInfo(
                            name: propertyName,
                            type: propertyType,
                            isOptional: isOptional,
                            serviceName: serviceName
                        ))
                    }
                }
            }
        }

        return ViewModelDependencyAnalysis(dependencies: dependencies)
    }

    // MARK: - Service Name Extraction

    private static func extractServiceName(from attributes: AttributeListSyntax) -> String? {
        for attribute in attributes {
            if let attributeSyntax = attribute.as(AttributeSyntax.self) {
                let attributeName = attributeSyntax.attributeName.trimmedDescription

                // Check for @Named("serviceName") or @Service("customService")
                if attributeName == "Named" || attributeName == "Service" {
                    // Parse the first string argument
                    if let arguments = attributeSyntax.arguments?.as(LabeledExprListSyntax.self),
                       let firstArgument = arguments.first
                    {
                        // Handle both labeled and unlabeled string arguments
                        if let stringLiteral = firstArgument.expression.as(StringLiteralExprSyntax.self),
                           let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
                        {
                            return segment.content.text
                        }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Code Generation

    private static func generateDependencyInjectionInitializer(
        className: String,
        dependencies: [ViewModelDependencyInfo],
        config: ViewModelInjectConfig,
        context: some MacroExpansionContext
    ) throws -> DeclSyntax? {

        guard !dependencies.isEmpty else {
            // Generate simple container-based initializer
            let simpleInitializer = """
            /// Dependency injection initializer
            public init(container: DIContainer) {
                // No dependencies to inject
            }
            """

            return DeclSyntax.fromString(simpleInitializer)
        }

        // Generate parameter list
        let parameters = dependencies.map { dep in
            let paramType = dep.isOptional ? dep.type : dep.type
            return "\(dep.name): \(paramType)"
        }.joined(separator: ", ")

        // Generate property assignments
        let assignments = dependencies.map { dep in
            "self.\(dep.name) = \(dep.name)"
        }.joined(separator: "\n        ")

        let containerLookup = if config.containerName == "default" {
            "container"
        } else {
            "Container.named(\"\(config.containerName)\")"
        }

        // Generate resolution code for each dependency
        let resolutions = dependencies.map { dep in
            let nonOptionalType = dep.isOptional ? String(dep.type.dropLast()) : dep.type
            let serviceLookup = if let serviceName = dep.serviceName {
                "\(containerLookup).resolve(\(nonOptionalType).self, name: \"\(serviceName)\")"
            } else {
                "\(containerLookup).resolve(\(nonOptionalType).self)"
            }

            if dep.isOptional {
                return "let \(dep.name) = \(serviceLookup)"
            } else {
                return """
                guard let \(dep.name) = \(serviceLookup) else {
                    fatalError("Failed to resolve required dependency '\(dep.name)' of type '\(nonOptionalType)'")
                }
                """
            }
        }.joined(separator: "\n        ")

        let initializerCode = """
        /// Dependency injection initializer
        public convenience init(container: DIContainer) {
            // Resolve dependencies from container
            \(resolutions)

            // Call designated initializer with resolved dependencies
            self.init(\(dependencies.map { "\($0.name): \($0.name)" }.joined(separator: ", ")))
        }

        /// Designated initializer with explicit dependencies
        public init(\(parameters)) {
            \(assignments)
        }
        """

        return DeclSyntax.fromString(initializerCode)
    }

    private static func generateFactoryMethod(
        className: String,
        dependencies: [ViewModelDependencyInfo],
        config: ViewModelInjectConfig,
        context: some MacroExpansionContext
    ) throws -> DeclSyntax? {

        let factoryMethod = """
        /// Factory method for container registration
        public static func register(in container: Container) {
            container.register(\(className).self) { resolver in
                \(className)(container: DIContainer(resolver as! Container))
            }.inObjectScope(.\(config.scope))
        }
        """

        return DeclSyntax.fromString(factoryMethod)
    }

    private static func generatePreviewInitializer(
        className: String,
        dependencies: [ViewModelDependencyInfo],
        config: ViewModelInjectConfig,
        context: some MacroExpansionContext
    ) throws -> DeclSyntax? {

        guard !dependencies.isEmpty else { return nil }

        // Generate mock parameter list with default values
        let mockParameters = dependencies.map { dep in
            let mockValue = generateMockValue(for: dep.type, isOptional: dep.isOptional)
            return "\(dep.name): \(dep.type) = \(mockValue)"
        }.joined(separator: ", ")

        let previewInit = """
        /// Preview-friendly initializer with mock dependencies
        public static func preview(\(mockParameters)) -> \(className) {
            \(className)(\(dependencies.map { "\($0.name): \($0.name)" }.joined(separator: ", ")))
        }
        """

        return DeclSyntax.fromString(previewInit)
    }

    private static func generateMockValue(for type: String, isOptional: Bool) -> String {
        if isOptional {
            return "nil"
        }

        // Generate appropriate mock values based on type
        let baseType = type.replacingOccurrences(of: "Protocol", with: "")
        return "Mock\(baseType)()"
    }
}

// MARK: - Supporting Types

private struct ViewModelInjectConfig {
    let containerName: String
    let scope: String
    let generateFactory: Bool
    let previewSupport: Bool
}

private struct ViewModelDependencyInfo {
    let name: String
    let type: String
    let isOptional: Bool
    let serviceName: String?
}

private struct ViewModelDependencyAnalysis {
    let dependencies: [ViewModelDependencyInfo]
}

// MARK: - Diagnostic Messages

private struct ViewModelInjectMacroError: DiagnosticMessage, Error {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "ViewModelInjectError")
    let severity: DiagnosticSeverity = .error
}

private struct ViewModelInjectMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "ViewModelInjectWarning")
    let severity: DiagnosticSeverity = .warning
}
